import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "onboarding_phase_service.dart";

/// Dialog de edicao de um card do Onboarding 0-15 Dias, acessivel pelo
/// gestor direto no board (menu "..." no card). Edita os dados do
/// streamer (profiles) quando ja vinculado oficialmente, ou do lead
/// (leads) quando o card ainda e "pre-vinculo" -- os campos disponiveis
/// mudam conforme o caso.
class OnboardingCardEditDialog extends StatefulWidget {
  final bool isLeadOnly;
  final String? streamerId;
  final String? leadId;
  final String initialName;
  final String? initialTiktok;
  final String? initialPhone;
  final String? initialEmail;
  final String? initialCategoryId;
  final String? initialCategoryInterest;

  const OnboardingCardEditDialog({
    super.key,
    required this.isLeadOnly,
    this.streamerId,
    this.leadId,
    required this.initialName,
    this.initialTiktok,
    this.initialPhone,
    this.initialEmail,
    this.initialCategoryId,
    this.initialCategoryInterest,
  });

  @override
  State<OnboardingCardEditDialog> createState() => _OnboardingCardEditDialogState();
}

class _OnboardingCardEditDialogState extends State<OnboardingCardEditDialog> {
  late final _nameController = TextEditingController(text: widget.initialName);
  late final _tiktokController = TextEditingController(text: widget.initialTiktok ?? "");
  late final _phoneController = TextEditingController(text: widget.initialPhone ?? "");
  late final _emailController = TextEditingController(text: widget.initialEmail ?? "");
  late final _categoryInterestController = TextEditingController(text: widget.initialCategoryInterest ?? "");
  String? _categoryId;
  List<Map<String, dynamic>> _categories = [];
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
    if (!widget.isLeadOnly) _loadCategories();
  }

  Future<void> _loadCategories() async {
    final rows = await Supabase.instance.client.from("streamer_categories").select("id, name").order("name", ascending: true);
    if (mounted) setState(() => _categories = (rows as List).cast<Map<String, dynamic>>());
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Informe um nome.");
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    final userId = Supabase.instance.client.auth.currentUser!.id;
    try {
      if (widget.isLeadOnly) {
        await updateOnboardingLeadInfo(
          leadId: widget.leadId!,
          name: _nameController.text.trim(),
          tiktokUsername: _tiktokController.text.trim().isEmpty ? null : _tiktokController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          categoryInterest: _categoryInterestController.text.trim().isEmpty ? null : _categoryInterestController.text.trim(),
          performedBy: userId,
        );
      } else {
        await updateOnboardingStreamerProfile(
          streamerId: widget.streamerId!,
          displayName: _nameController.text.trim(),
          tiktokId: _tiktokController.text.trim().isEmpty ? null : _tiktokController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          categoryId: _categoryId,
          performedBy: userId,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = "Erro ao salvar: " + e.toString();
      });
    }
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54, fontSize: 12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Editar card", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              if (widget.isLeadOnly)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    "Streamer ainda nao vinculado oficialmente -- estes campos editam o lead, nao o cadastro oficial.",
                    style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field(_nameController, "Nome"),
                      _field(_tiktokController, "@TikTok"),
                      _field(_phoneController, "WhatsApp"),
                      if (!widget.isLeadOnly) ...[
                        _field(_emailController, "E-mail"),
                        const Text("Categoria", style: TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: _categoryId,
                          dropdownColor: const Color(0xFF1A1A1A),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(isDense: true),
                          items: _categories.map((c) => DropdownMenuItem(value: c["id"] as String, child: Text(c["name"] as String))).toList(),
                          onChanged: (v) => setState(() => _categoryId = v),
                        ),
                      ] else
                        _field(_categoryInterestController, "Categoria de interesse"),
                    ],
                  ),
                ),
              ),
              if (_errorMessage != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: Text(_saving ? "Salvando..." : "Salvar"),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
