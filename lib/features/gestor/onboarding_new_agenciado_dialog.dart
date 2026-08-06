import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "onboarding_phase_service.dart";

/// Dialog "Novo Agenciado" (ou "Novo card", em fases que nao sao o
/// Onboarding 0-15) do Kanban de Onboarding. Permite buscar e selecionar um
/// streamer ja cadastrado (preenchendo os campos automaticamente, so para
/// conferencia -- nao sobrescreve o cadastro) ou preencher manualmente sem
/// selecionar nenhum (cria um streamer novo em profiles). Em ambos os
/// casos, cria o card na 1a coluna da fase informada (phaseKey), vinculado
/// ao gestor atual -- reusado pelo Onboarding 0-15 Dias e pela Graduacao
/// Novatos (streamer que ja e candidato a graduar, sem precisar esperar a
/// promocao automatica do Acompanhamento 16-31 Dias).
class OnboardingNewAgenciadoDialog extends StatefulWidget {
  final String phaseKey;
  const OnboardingNewAgenciadoDialog({super.key, this.phaseKey = onboardingPhaseKey});

  @override
  State<OnboardingNewAgenciadoDialog> createState() =>
      _OnboardingNewAgenciadoDialogState();
}

class _OnboardingNewAgenciadoDialogState
    extends State<OnboardingNewAgenciadoDialog> {
  final _nameController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();

  String _search = "";
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  String? _selectedStreamerId;

  List<Map<String, dynamic>> _categories = [];
  String? _categoryId;

  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("streamer_categories")
        .select("id, name")
        .order("name", ascending: true);
    if (mounted)
      setState(() => _categories = (rows as List).cast<Map<String, dynamic>>());
  }

  Future<void> _doSearch(String query) async {
    setState(() {
      _search = query;
      _searching = true;
    });
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    final client = Supabase.instance.client;
    final rows = await client
        .from("profiles")
        .select(
          "id, display_name, tiktok_creator_id, avatar_url, phone, email, category_id",
        )
        .or(
          "display_name.ilike.%" +
              query +
              "%,tiktok_creator_id.ilike.%" +
              query +
              "%",
        )
        .limit(20);
    setState(() {
      _results = (rows as List).cast<Map<String, dynamic>>();
      _searching = false;
    });
  }

  void _selectStreamer(Map<String, dynamic> streamer) {
    setState(() {
      _selectedStreamerId = streamer["id"] as String;
      _nameController.text = (streamer["display_name"] as String?) ?? "";
      _tiktokController.text = (streamer["tiktok_creator_id"] as String?) ?? "";
      _phoneController.text = (streamer["phone"] as String?) ?? "";
      _emailController.text = (streamer["email"] as String?) ?? "";
      _categoryId = streamer["category_id"] as String?;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedStreamerId = null;
      _nameController.clear();
      _tiktokController.clear();
      _phoneController.clear();
      _emailController.clear();
      _categoryId = null;
    });
  }

  Future<void> _create() async {
    if (_selectedStreamerId == null && _nameController.text.trim().isEmpty) {
      setState(
        () => _errorMessage =
            "Informe um nome ou selecione um streamer existente.",
      );
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await createManualOnboardingCard(
        existingStreamerId: _selectedStreamerId,
        displayName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        tiktokId: _tiktokController.text.trim().isEmpty
            ? null
            : _tiktokController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        categoryId: _categoryId,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        phaseKey: widget.phaseKey,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = "Erro ao criar: " + e.toString();
      });
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Novo Agenciado",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Busque um streamer ja cadastrado (opcional) ou preencha os dados manualmente.",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedStreamerId == null) ...[
                        TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.white54,
                            ),
                            hintText: "Buscar por nome ou @TikTok",
                            hintStyle: TextStyle(color: Colors.white38),
                            isDense: true,
                          ),
                          onChanged: _doSearch,
                        ),
                        const SizedBox(height: 8),
                        if (_searching)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_search.trim().length >= 2)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white24),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _results.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text(
                                      "Nenhum streamer encontrado.",
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _results.length,
                                    itemBuilder: (context, index) {
                                      final r = _results[index];
                                      return ListTile(
                                        dense: true,
                                        onTap: () => _selectStreamer(r),
                                        leading: CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Colors.white24,
                                          backgroundImage:
                                              r["avatar_url"] != null
                                              ? NetworkImage(
                                                  r["avatar_url"] as String,
                                                )
                                              : null,
                                          child: r["avatar_url"] == null
                                              ? const Icon(
                                                  Icons.person,
                                                  color: Colors.white70,
                                                  size: 14,
                                                )
                                              : null,
                                        ),
                                        title: Text(
                                          r["display_name"] as String? ?? "-",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
                                        subtitle: Text(
                                          "@" +
                                              (r["tiktok_creator_id"]
                                                      as String? ??
                                                  "-"),
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        const SizedBox(height: 12),
                      ] else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7A0BD4).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF7A0BD4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF7A0BD4),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Streamer selecionado: " +
                                        _nameController.text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _clearSelection,
                                  child: const Text("Trocar"),
                                ),
                              ],
                            ),
                          ),
                        ),
                      _field(_nameController, "Nome"),
                      _field(_tiktokController, "@TikTok"),
                      _field(_phoneController, "WhatsApp"),
                      _field(_emailController, "E-mail"),
                      const Text(
                        "Categoria",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: _categoryId,
                        dropdownColor: const Color(0xFF1A1A1A),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(isDense: true),
                        items: _categories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c["id"] as String,
                                child: Text(c["name"] as String),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                      const SizedBox(height: 10),
                      _field(_notesController, "Observacoes", maxLines: 3),
                    ],
                  ),
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text("Cancelar"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _create,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A0BD4),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_saving ? "Criando..." : "Criar"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
