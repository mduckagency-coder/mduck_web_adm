import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "demanda_model.dart";
import "demanda_repository.dart";

/// Formulario de criacao/edicao de demanda. Qualquer gestor pode enviar para
/// qualquer outro gestor da agencia (inclusive para si mesmo). Retorna
/// `true` via Navigator.pop quando a demanda e criada/atualizada com sucesso.
class DemandaFormDialog extends StatefulWidget {
  /// Quando informada, o dialogo abre em modo edicao (campos pre-preenchidos,
  /// atualiza em vez de criar uma nova demanda).
  final Demanda? existing;

  const DemandaFormDialog({super.key, this.existing});

  @override
  State<DemandaFormDialog> createState() => _DemandaFormDialogState();
}

class _DemandaFormDialogState extends State<DemandaFormDialog> {
  final _repository = DemandaRepository();
  late final _tituloController = TextEditingController(
    text: widget.existing?.titulo ?? "",
  );
  late final _descricaoController = TextEditingController(
    text: widget.existing?.descricao ?? "",
  );
  late final _categoriaController = TextEditingController(
    text: widget.existing?.categoria ?? "Geral",
  );

  late DemandaPrioridade _prioridade =
      widget.existing?.prioridade ?? DemandaPrioridade.media;
  late String _icone = widget.existing?.icone ?? "flag";
  late DateTime? _prazo = widget.existing?.prazo;
  late String? _responsavelId = widget.existing?.responsavelId;
  bool _repeteMensalmente = false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  late Future<List<Map<String, dynamic>>> _managersFuture;

  @override
  void initState() {
    super.initState();
    _managersFuture = _repository.loadManagersDaAgencia();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _categoriaController.dispose();
    super.dispose();
  }

  Future<void> _pickPrazo() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _prazo ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_prazo ?? now),
    );
    if (!mounted) return;
    setState(
      () => _prazo = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 9,
        time?.minute ?? 0,
      ),
    );
  }

  Future<void> _save() async {
    final titulo = _tituloController.text.trim();
    if (titulo.isEmpty) {
      setState(() => _error = "Informe um titulo.");
      return;
    }
    if (_responsavelId == null) {
      setState(() => _error = "Selecione para quem enviar a demanda.");
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final categoria = _categoriaController.text.trim().isEmpty
          ? "Geral"
          : _categoriaController.text.trim();

      if (_isEditing) {
        await _repository.atualizarDemanda(
          demandaId: widget.existing!.id,
          titulo: titulo,
          descricao: _descricaoController.text.trim(),
          prioridade: _prioridade,
          categoria: categoria,
          icone: _icone,
          prazo: _prazo,
          responsavelId: _responsavelId!,
        );
      } else {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser!.id;
        final me = await client
            .from("managers")
            .select("full_name, login_email")
            .eq("id", userId)
            .single();
        final criadoPorLabel =
            (me["full_name"] as String?)?.isNotEmpty == true
            ? me["full_name"] as String
            : (me["login_email"] as String);

        await _repository.criarDemanda(
          titulo: titulo,
          descricao: _descricaoController.text.trim(),
          prioridade: _prioridade,
          categoria: categoria,
          icone: _icone,
          prazo: _prazo,
          responsavelId: _responsavelId!,
          criadoPorLabel: criadoPorLabel,
          repeteMensalmente: _repeteMensalmente,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = "Erro ao salvar demanda: $e";
      });
    }
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 14),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? "Editar Demanda" : "Nova Demanda",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isEditing
                    ? "Altere os dados da demanda."
                    : "Envie uma tarefa para qualquer gestor da agencia.",
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel("Titulo"),
                      TextField(
                        controller: _tituloController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: "Ex: Revisar contratos pendentes",
                          hintStyle: TextStyle(color: Colors.white38),
                        ),
                      ),
                      _sectionLabel("Descricao"),
                      TextField(
                        controller: _descricaoController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: "Detalhes da tarefa (opcional)",
                          hintStyle: TextStyle(color: Colors.white38),
                        ),
                      ),
                      _sectionLabel("Prioridade"),
                      Wrap(
                        spacing: 8,
                        children: DemandaPrioridade.values.map((p) {
                          final selected = _prioridade == p;
                          return ChoiceChip(
                            label: Text(p.label),
                            selected: selected,
                            selectedColor: const Color(0xFF7A0BD4),
                            backgroundColor: Colors.white.withOpacity(0.05),
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : Colors.white70,
                            ),
                            onSelected: (_) => setState(() => _prioridade = p),
                          );
                        }).toList(),
                      ),
                      _sectionLabel("Categoria"),
                      TextField(
                        controller: _categoriaController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: "Ex: Financeiro, Marketing...",
                        ),
                      ),
                      _sectionLabel("Icone"),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: demandaIconOptions.entries.map((entry) {
                          final selected = _icone == entry.key;
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() => _icone = entry.key),
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF7A0BD4).withOpacity(0.25)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF7A0BD4)
                                      : Colors.white12,
                                ),
                              ),
                              child: Icon(
                                entry.value,
                                color: selected
                                    ? const Color(0xFF7A0BD4)
                                    : Colors.white70,
                                size: 20,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      _sectionLabel("Prazo"),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickPrazo,
                            icon: const Icon(Icons.calendar_month, size: 16),
                            label: Text(
                              _prazo == null
                                  ? "Definir prazo"
                                  : _prazo!.day.toString().padLeft(2, "0") +
                                        "/" +
                                        _prazo!.month.toString().padLeft(
                                          2,
                                          "0",
                                        ) +
                                        "/" +
                                        _prazo!.year.toString() +
                                        " " +
                                        _prazo!.hour.toString().padLeft(
                                          2,
                                          "0",
                                        ) +
                                        ":" +
                                        _prazo!.minute.toString().padLeft(
                                          2,
                                          "0",
                                        ),
                            ),
                          ),
                          if (_prazo != null)
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.white54,
                              ),
                              tooltip: "Remover prazo",
                              onPressed: () => setState(() {
                                _prazo = null;
                                _repeteMensalmente = false;
                              }),
                            ),
                        ],
                      ),
                      if (!_isEditing && _prazo != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: InkWell(
                            onTap: () => setState(
                              () => _repeteMensalmente = !_repeteMensalmente,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: _repeteMensalmente,
                                  activeColor: const Color(0xFF7A0BD4),
                                  onChanged: (v) => setState(
                                    () => _repeteMensalmente = v ?? false,
                                  ),
                                ),
                                const Flexible(
                                  child: Text(
                                    "Repetir todo mes (cria as proximas 12 ocorrencias)",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      _sectionLabel("Enviar para"),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _managersFuture,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(),
                            );
                          final managers = snapshot.data!;
                          return DropdownButtonFormField<String>(
                            value: _responsavelId,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1A1A1A),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: "Selecione um gestor",
                            ),
                            items: managers.map((m) {
                              final label =
                                  (m["full_name"] as String?)?.isNotEmpty ==
                                      true
                                  ? m["full_name"] as String
                                  : (m["login_email"] as String);
                              return DropdownMenuItem(
                                value: m["id"] as String,
                                child: Text(
                                  label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _responsavelId = v),
                          );
                        },
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text("Cancelar"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A0BD4),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      _saving
                          ? "Salvando..."
                          : (_isEditing ? "Salvar alteracoes" : "Enviar demanda"),
                    ),
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
