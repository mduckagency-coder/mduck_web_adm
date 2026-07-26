import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../gestor/onboarding_stage_config_dialog.dart";
import "program_eligibility_service.dart";
import "program_visual.dart";
import "program_upload_helpers.dart";

class ProgramaConfiguracoesTab extends StatefulWidget {
  final Map<String, dynamic> program;
  final VoidCallback onChanged;
  const ProgramaConfiguracoesTab({super.key, required this.program, required this.onChanged});

  @override
  State<ProgramaConfiguracoesTab> createState() => _ProgramaConfiguracoesTabState();
}

class _ProgramaConfiguracoesTabState extends State<ProgramaConfiguracoesTab> {
  late final _nameController = TextEditingController(text: widget.program["name"] as String? ?? "");
  late final _descriptionController = TextEditingController(text: widget.program["description"] as String? ?? "");
  late final _objectiveController = TextEditingController(text: widget.program["objective"] as String? ?? "");
  late final _awardsController = TextEditingController(text: widget.program["awards_description"] as String? ?? "");
  late final _defaultMessageController = TextEditingController(text: widget.program["default_message"] as String? ?? "");

  late final _minDaysController = TextEditingController(text: (widget.program["criteria"]?["min_days"])?.toString() ?? "");
  late final _minDaysValidatedController = TextEditingController(text: (widget.program["criteria"]?["min_days_validated"])?.toString() ?? "");
  late final _minHoursController = TextEditingController(text: (widget.program["criteria"]?["min_hours"])?.toString() ?? "");
  late final _minDiamondsController = TextEditingController(text: (widget.program["criteria"]?["min_diamonds"])?.toString() ?? "");
  late final _minHeartMeController = TextEditingController(text: (widget.program["criteria"]?["min_heart_me"])?.toString() ?? "");
  late final _minBattlesController = TextEditingController(text: (widget.program["criteria"]?["min_battles"])?.toString() ?? "");
  final _approvalPercentageController = TextEditingController();
  late final _colorController = TextEditingController(text: widget.program["color"] as String? ?? "#7A0BD4");

  String? _iconKey;
  DateTime? _startDate;
  DateTime? _endDate;
  Set<String> _responsibleIds = {};
  Set<String> _initialResponsibleIds = {};
  String? _nextProgramKey;
  String? _graduateProgramKey;
  Set<String> _categoryIds = {};
  Set<String> _materialIds = {};

  bool _daysEnabled = true;
  bool _daysRequired = true;
  bool _daysValidatedEnabled = true;
  bool _daysValidatedRequired = true;
  bool _hoursEnabled = true;
  bool _hoursRequired = true;
  bool _diamondsEnabled = true;
  bool _diamondsRequired = true;
  bool _heartMeEnabled = true;
  bool _heartMeRequired = true;
  bool _battlesEnabled = true;
  bool _battlesRequired = true;
  String _approvalRuleMode = "todas";

  List<Map<String, dynamic>> _managers = [];
  List<Map<String, dynamic>> _otherPrograms = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _materials = [];
  final Map<String, TextEditingController> _battlesByCategoryControllers = {};
  Map<String, int> _initialBattlesByCategory = {};
  bool _showBattlesByCategory = false;
  PlatformFile? _imageFile;
  String? _imageUrl;
  bool _loadingOptions = true;
  bool _saving = false;
  String? _message;
  bool _messageIsError = false;
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _iconKey = widget.program["icon_key"] as String?;
    _imageUrl = widget.program["image_url"] as String?;
    _startDate = widget.program["start_date"] != null ? DateTime.parse(widget.program["start_date"] as String) : null;
    _endDate = widget.program["end_date"] != null ? DateTime.parse(widget.program["end_date"] as String) : null;
    _nextProgramKey = widget.program["next_program_key"] as String?;
    _graduateProgramKey = widget.program["graduate_program_key"] as String?;
    final criteria = ProgramCriteria.fromMap(widget.program["criteria"] as Map<String, dynamic>?);
    _categoryIds = criteria.categoryIds.toSet();
    _materialIds = criteria.requiredMaterialIds.toSet();
    _daysEnabled = criteria.daysEnabled;
    _daysRequired = criteria.daysRequired;
    _daysValidatedEnabled = criteria.daysValidatedEnabled;
    _daysValidatedRequired = criteria.daysValidatedRequired;
    _showBattlesByCategory = criteria.battlesByCategory.isNotEmpty;
    _initialBattlesByCategory = criteria.battlesByCategory;
    _hoursEnabled = criteria.hoursEnabled;
    _hoursRequired = criteria.hoursRequired;
    _diamondsEnabled = criteria.diamondsEnabled;
    _diamondsRequired = criteria.diamondsRequired;
    _heartMeEnabled = criteria.heartMeEnabled;
    _heartMeRequired = criteria.heartMeRequired;
    _battlesEnabled = criteria.battlesEnabled;
    _battlesRequired = criteria.battlesRequired;
    _approvalRuleMode = criteria.approvalRuleMode;
    _approvalPercentageController.text = criteria.approvalMinPercentage.toString();
    _historyFuture = _loadHistory();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final client = Supabase.instance.client;
    final agencyId = widget.program["agency_id"] as String;
    final managers = await client.from("managers").select("id, login_email").order("login_email");
    final programs = await client.from("development_programs").select("program_key, name").eq("agency_id", agencyId).neq("id", widget.program["id"]).order("order_index");
    final categories = await client.from("streamer_categories").select("id, name").order("name");
    final materials = await client.from("training_materials").select("id, title").eq("is_archived", false).order("title");
    final responsibles = await client.from("development_program_managers").select("manager_id").eq("program_id", widget.program["id"]);
    if (mounted) {
      setState(() {
        _managers = (managers as List).cast<Map<String, dynamic>>();
        _otherPrograms = (programs as List).cast<Map<String, dynamic>>();
        _categories = (categories as List).cast<Map<String, dynamic>>();
        _materials = (materials as List).cast<Map<String, dynamic>>();
        _responsibleIds = (responsibles as List).map((r) => r["manager_id"] as String).toSet();
        _initialResponsibleIds = _responsibleIds.toSet();
        for (final c in _categories) {
          final id = c["id"] as String;
          _battlesByCategoryControllers[id] = TextEditingController(text: _initialBattlesByCategory[id]?.toString() ?? "");
        }
        _loadingOptions = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadHistory() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("program_config_history")
        .select("field, old_value, new_value, created_at, manager:managers(login_email)")
        .eq("program_id", widget.program["id"])
        .order("created_at", ascending: false)
        .limit(30);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Compara os campos salvos agora contra os valores atuais de
  /// widget.program (ainda nao mutados neste ponto) e grava uma linha por
  /// campo que mudou -- generico o bastante pra qualquer programa futuro,
  /// ja que so referencia program_id/agency_id, sem nada especifico do
  /// programa em si.
  String _emailsFor(Set<String> ids) => _managers.where((m) => ids.contains(m["id"])).map((m) => m["login_email"] as String).join(", ");

  Future<void> _logConfigChanges(Map<String, dynamic> updatePayload) async {
    const fieldLabels = {
      "name": "Nome",
      "description": "Descricao",
      "objective": "Objetivo",
      "awards_description": "Premiacoes (descricao)",
      "default_message": "Mensagem padrao",
      "start_date": "Data de inicio",
      "end_date": "Data de termino",
      "color": "Cor",
      "icon_key": "Icone",
      "image_url": "Imagem",
      "next_program_key": "Proximo programa",
      "graduate_program_key": "Programa de destaque",
      "criteria": "Metas e regras",
    };
    final rows = <Map<String, dynamic>>[];
    fieldLabels.forEach((key, label) {
      final oldText = widget.program[key]?.toString() ?? "-";
      final newText = updatePayload[key]?.toString() ?? "-";
      if (oldText != newText) {
        rows.add({
          "program_id": widget.program["id"],
          "agency_id": widget.program["agency_id"],
          "changed_by": Supabase.instance.client.auth.currentUser?.id,
          "field": label,
          "old_value": oldText,
          "new_value": newText,
        });
      }
    });
    final oldResponsibles = _emailsFor(_initialResponsibleIds);
    final newResponsibles = _emailsFor(_responsibleIds);
    if (oldResponsibles != newResponsibles) {
      rows.add({
        "program_id": widget.program["id"],
        "agency_id": widget.program["agency_id"],
        "changed_by": Supabase.instance.client.auth.currentUser?.id,
        "field": "Responsaveis",
        "old_value": oldResponsibles.isEmpty ? "-" : oldResponsibles,
        "new_value": newResponsibles.isEmpty ? "-" : newResponsibles,
      });
    }
    if (rows.isEmpty) return;
    try {
      await Supabase.instance.client.from("program_config_history").insert(rows);
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final client = Supabase.instance.client;
      final battlesByCategory = <String, int>{};
      _battlesByCategoryControllers.forEach((categoryId, controller) {
        final value = int.tryParse(controller.text.trim());
        if (value != null) battlesByCategory[categoryId] = value;
      });
      final criteria = {
        "min_days": int.tryParse(_minDaysController.text.trim()),
        "min_days_validated": int.tryParse(_minDaysValidatedController.text.trim()),
        "min_hours": double.tryParse(_minHoursController.text.trim().replaceAll(",", ".")),
        "min_diamonds": num.tryParse(_minDiamondsController.text.trim()),
        "min_heart_me": num.tryParse(_minHeartMeController.text.trim().replaceAll(",", ".")),
        "min_battles": int.tryParse(_minBattlesController.text.trim()),
        "battles_by_category": battlesByCategory,
        "days_enabled": _daysEnabled,
        "days_required": _daysRequired,
        "days_validated_enabled": _daysValidatedEnabled,
        "days_validated_required": _daysValidatedRequired,
        "hours_enabled": _hoursEnabled,
        "hours_required": _hoursRequired,
        "diamonds_enabled": _diamondsEnabled,
        "diamonds_required": _diamondsRequired,
        "heart_me_enabled": _heartMeEnabled,
        "heart_me_required": _heartMeRequired,
        "battles_enabled": _battlesEnabled,
        "battles_required": _battlesRequired,
        "approval_rule_mode": _approvalRuleMode,
        "approval_min_percentage": int.tryParse(_approvalPercentageController.text.trim()) ?? 100,
        "category_ids": _categoryIds.toList(),
        "required_material_ids": _materialIds.toList(),
      };

      var imageUrl = _imageUrl;
      if (_imageFile != null) {
        imageUrl = await uploadProgramFile(prefix: widget.program["id"] as String, file: _imageFile!);
      }

      final updatePayload = {
        "name": _nameController.text.trim(),
        "description": _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        "objective": _objectiveController.text.trim().isEmpty ? null : _objectiveController.text.trim(),
        "awards_description": _awardsController.text.trim().isEmpty ? null : _awardsController.text.trim(),
        "default_message": _defaultMessageController.text.trim().isEmpty ? null : _defaultMessageController.text.trim(),
        "start_date": _startDate?.toIso8601String().substring(0, 10),
        "end_date": _endDate?.toIso8601String().substring(0, 10),
        "color": _colorController.text.trim().isEmpty ? "#7A0BD4" : _colorController.text.trim(),
        "icon_key": _iconKey,
        "image_url": imageUrl,
        "next_program_key": _nextProgramKey,
        "graduate_program_key": _graduateProgramKey,
        "criteria": criteria,
      };

      await client.from("development_programs").update({
        ...updatePayload,
        "updated_at": DateTime.now().toIso8601String(),
      }).eq("id", widget.program["id"]);

      await client.from("development_program_managers").delete().eq("program_id", widget.program["id"]);
      if (_responsibleIds.isNotEmpty) {
        await client.from("development_program_managers").insert(_responsibleIds.map((id) => {"program_id": widget.program["id"], "manager_id": id}).toList());
      }

      await _logConfigChanges(updatePayload);

      widget.program.addAll(updatePayload);
      widget.onChanged();

      setState(() {
        _saving = false;
        _message = "Configuracoes salvas.";
        _messageIsError = false;
        _initialResponsibleIds = _responsibleIds.toSet();
        _imageUrl = imageUrl;
        _imageFile = null;
        _historyFuture = _loadHistory();
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _message = "Erro: " + e.toString();
        _messageIsError = true;
      });
    }
  }

  Color _tryColor(String hex) {
    try {
      return hexToColor(hex);
    } catch (_) {
      return Colors.white24;
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    setState(() => _imageFile = result.files.first);
  }

  void _openFluxoConfig() {
    showDialog(
      context: context,
      builder: (context) => OnboardingStageConfigDialog(agencyId: widget.program["agency_id"] as String, phaseKey: widget.program["program_key"] as String),
    ).then((_) => widget.onChanged());
  }

  Widget _field(TextEditingController controller, String label, {TextInputType? keyboardType, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54)),
      ),
    );
  }

  Widget _metaRow({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    required ValueChanged<bool> onEnabledChanged,
    required bool required,
    required ValueChanged<bool> onRequiredChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Switch(value: enabled, activeColor: const Color(0xFF7A0BD4), onChanged: onEnabledChanged),
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.number,
            style: TextStyle(color: enabled ? Colors.white : Colors.white38),
            decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54)),
          ),
        ),
        const SizedBox(width: 8),
        Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Obrigatoria", style: TextStyle(color: Colors.white38, fontSize: 9)),
          Checkbox(
            value: required,
            activeColor: const Color(0xFF7A0BD4),
            onChanged: enabled ? (v) => onRequiredChanged(v ?? true) : null,
          ),
        ]),
      ]),
    );
  }

  /// Igual _metaRow, mas so pra Batalhas: alem do padrao geral, permite
  /// abrir um valor diferente por categoria de streamer (ex: Batalha precisa
  /// de mais batalhas que Musica) -- vazio numa categoria usa o padrao.
  Widget _battlesMetaCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metaRow(
          label: "Quantidade minima de batalhas (padrao)",
          controller: _minBattlesController,
          enabled: _battlesEnabled,
          onEnabledChanged: (v) => setState(() => _battlesEnabled = v),
          required: _battlesRequired,
          onRequiredChanged: (v) => setState(() => _battlesRequired = v),
        ),
        if (_battlesEnabled) ...[
          TextButton.icon(
            onPressed: () => setState(() => _showBattlesByCategory = !_showBattlesByCategory),
            icon: Icon(_showBattlesByCategory ? Icons.expand_less : Icons.expand_more, size: 16),
            label: const Text("Personalizar por categoria", style: TextStyle(fontSize: 11)),
          ),
          if (_showBattlesByCategory)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _categories.map((c) {
                  final id = c["id"] as String;
                  final controller = _battlesByCategoryControllers[id];
                  if (controller == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      SizedBox(width: 110, child: Text(c["name"] as String, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: const InputDecoration(isDense: true, hintText: "Usa o padrao", hintStyle: TextStyle(color: Colors.white24)),
                        ),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Configuracoes do programa", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text("Nada fica fixo -- todas as metas abaixo podem ser ativadas/desativadas e marcadas como obrigatorias ou opcionais.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: _openFluxoConfig, icon: const Icon(Icons.view_column, size: 16), label: const Text("Configurar fluxo (colunas do Kanban)"))),
          const SizedBox(height: 20),
          _field(_nameController, "Nome"),
          _field(_descriptionController, "Descricao", maxLines: 2),
          _field(_objectiveController, "Objetivo", maxLines: 2),
          if (_loadingOptions)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator()))
          else ...[
            const Text("Responsaveis", style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: _managers.map((m) {
              final id = m["id"] as String;
              final selected = _responsibleIds.contains(id);
              return FilterChip(
                label: Text(m["login_email"] as String, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 12)),
                selected: selected,
                selectedColor: const Color(0xFF7A0BD4),
                backgroundColor: Colors.white.withOpacity(0.05),
                onSelected: (v) => setState(() => v ? _responsibleIds.add(id) : _responsibleIds.remove(id)),
              );
            }).toList()),
            const SizedBox(height: 16),
            const Text("Identidade visual", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: _imageFile != null
                      ? Image.memory(_imageFile!.bytes!, fit: BoxFit.cover)
                      : (_imageUrl != null && _imageUrl!.isNotEmpty)
                          ? Image.network(_imageUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stack) => Container(color: const Color(0xFF232323), child: const Icon(Icons.image_not_supported, color: Colors.white24, size: 20)))
                          : Container(color: const Color(0xFF232323), child: const Icon(Icons.image_outlined, color: Colors.white24, size: 20)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.upload, size: 16), label: const Text("Escolher imagem")),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(
                child: TextField(
                  controller: _colorController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Cor (ex: #7A0BD4)", labelStyle: TextStyle(color: Colors.white54)),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(radius: 14, backgroundColor: _tryColor(_colorController.text)),
              const SizedBox(width: 16),
              DropdownButton<String?>(
                value: _iconKey,
                dropdownColor: const Color(0xFF232323),
                style: const TextStyle(color: Colors.white),
                hint: const Text("Icone", style: TextStyle(color: Colors.white38)),
                items: programIconOptions.map((o) => DropdownMenuItem<String?>(value: o.$1, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(o.$3, size: 16, color: Colors.white), const SizedBox(width: 6), Text(o.$2)]))).toList(),
                onChanged: (v) => setState(() => _iconKey = v),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: true),
                  icon: const Icon(Icons.event, size: 16),
                  label: Text(_startDate != null ? "Inicio: " + _startDate!.toLocal().toString().substring(0, 10) : "Data de inicio"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: false),
                  icon: const Icon(Icons.event_busy, size: 16),
                  label: Text(_endDate != null ? "Termino: " + _endDate!.toLocal().toString().substring(0, 10) : "Data de termino (opcional)"),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            const Text("Metas do programa", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            const Text("O interruptor liga/desliga a meta; o valor fica guardado mesmo desligada.", style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            Wrap(spacing: 16, runSpacing: 12, children: [
              SizedBox(
                width: 300,
                child: _metaRow(
                  label: "Dias desde que entrou na agencia",
                  controller: _minDaysController,
                  enabled: _daysEnabled,
                  onEnabledChanged: (v) => setState(() => _daysEnabled = v),
                  required: _daysRequired,
                  onRequiredChanged: (v) => setState(() => _daysRequired = v),
                ),
              ),
              SizedBox(
                width: 300,
                child: _metaRow(
                  label: "Dias validados (ficou ao vivo)",
                  controller: _minDaysValidatedController,
                  enabled: _daysValidatedEnabled,
                  onEnabledChanged: (v) => setState(() => _daysValidatedEnabled = v),
                  required: _daysValidatedRequired,
                  onRequiredChanged: (v) => setState(() => _daysValidatedRequired = v),
                ),
              ),
              SizedBox(
                width: 300,
                child: _metaRow(
                  label: "Horas minimas",
                  controller: _minHoursController,
                  enabled: _hoursEnabled,
                  onEnabledChanged: (v) => setState(() => _hoursEnabled = v),
                  required: _hoursRequired,
                  onRequiredChanged: (v) => setState(() => _hoursRequired = v),
                ),
              ),
              SizedBox(
                width: 300,
                child: _metaRow(
                  label: "Diamantes minimos",
                  controller: _minDiamondsController,
                  enabled: _diamondsEnabled,
                  onEnabledChanged: (v) => setState(() => _diamondsEnabled = v),
                  required: _diamondsRequired,
                  onRequiredChanged: (v) => setState(() => _diamondsRequired = v),
                ),
              ),
              SizedBox(
                width: 300,
                child: _metaRow(
                  label: "Heart Me minimo",
                  controller: _minHeartMeController,
                  enabled: _heartMeEnabled,
                  onEnabledChanged: (v) => setState(() => _heartMeEnabled = v),
                  required: _heartMeRequired,
                  onRequiredChanged: (v) => setState(() => _heartMeRequired = v),
                ),
              ),
              SizedBox(width: 300, child: _battlesMetaCard()),
            ]),
            const SizedBox(height: 12),
            const Text("Regra de aprovacao", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            const Text("Decide o que conta pra elegibilidade entre as metas ativas acima.", style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic)),
            RadioListTile<String>(
              value: "todas",
              groupValue: _approvalRuleMode,
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF7A0BD4),
              title: const Text("Cumprir todas as metas ativas", style: TextStyle(color: Colors.white, fontSize: 13)),
              onChanged: (v) => setState(() => _approvalRuleMode = v ?? _approvalRuleMode),
            ),
            RadioListTile<String>(
              value: "obrigatorias",
              groupValue: _approvalRuleMode,
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF7A0BD4),
              title: const Text("Cumprir apenas as metas obrigatorias", style: TextStyle(color: Colors.white, fontSize: 13)),
              onChanged: (v) => setState(() => _approvalRuleMode = v ?? _approvalRuleMode),
            ),
            RadioListTile<String>(
              value: "percentual",
              groupValue: _approvalRuleMode,
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF7A0BD4),
              title: const Text("Cumprir uma porcentagem minima das metas", style: TextStyle(color: Colors.white, fontSize: 13)),
              onChanged: (v) => setState(() => _approvalRuleMode = v ?? _approvalRuleMode),
            ),
            if (_approvalRuleMode == "percentual")
              Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 8),
                child: SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _approvalPercentageController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Percentual minimo (%)", labelStyle: TextStyle(color: Colors.white54)),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            const Text("Categoria (vazio = qualquer categoria)", style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: _categories.map((c) {
              final id = c["id"] as String;
              final selected = _categoryIds.contains(id);
              return FilterChip(
                label: Text(c["name"] as String, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 12)),
                selected: selected,
                selectedColor: const Color(0xFF7A0BD4),
                backgroundColor: Colors.white.withOpacity(0.05),
                onSelected: (v) => setState(() => v ? _categoryIds.add(id) : _categoryIds.remove(id)),
              );
            }).toList()),
            const SizedBox(height: 12),
            const Text("Treinamentos obrigatorios (informativo por enquanto)", style: TextStyle(color: Colors.white54, fontSize: 12)),
            const Text("O sistema ainda nao registra quando um streamer conclui um material -- isso fica listado no programa, mas nao bloqueia a elegibilidade ainda.", style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: _materials.map((m) {
              final id = m["id"] as String;
              final selected = _materialIds.contains(id);
              return FilterChip(
                label: Text(m["title"] as String, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 12)),
                selected: selected,
                selectedColor: const Color(0xFF7A0BD4),
                backgroundColor: Colors.white.withOpacity(0.05),
                onSelected: (v) => setState(() => v ? _materialIds.add(id) : _materialIds.remove(id)),
              );
            }).toList()),
            const SizedBox(height: 16),
            _field(_defaultMessageController, "Mensagem padrao", maxLines: 3),
            _field(_awardsController, "Premiacoes (descricao)", maxLines: 2),
            const SizedBox(height: 8),
            const Text("Proximo programa", style: TextStyle(color: Colors.white54, fontSize: 12)),
            const Text("Quando aprovado na avaliacao final, o streamer entra automaticamente aqui.", style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic)),
            const SizedBox(height: 4),
            DropdownButton<String?>(
              value: _nextProgramKey,
              isExpanded: true,
              hint: const Text("Nenhum (fim da jornada)", style: TextStyle(color: Colors.white38)),
              dropdownColor: const Color(0xFF232323),
              style: const TextStyle(color: Colors.white),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text("Nenhum (fim da jornada)")),
                ..._otherPrograms.map((p) => DropdownMenuItem<String?>(value: p["program_key"] as String, child: Text(p["name"] as String))),
              ],
              onChanged: (v) => setState(() => _nextProgramKey = v),
            ),
            const SizedBox(height: 12),
            const Text("Programa de destaque (Graduar)", style: TextStyle(color: Colors.white54, fontSize: 12)),
            const Text("Quando o gestor clicar em \"Graduar\" na avaliacao final, o streamer vai para este programa em vez do proximo padrao.", style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic)),
            const SizedBox(height: 4),
            DropdownButton<String?>(
              value: _graduateProgramKey,
              isExpanded: true,
              hint: const Text("Nenhum ainda", style: TextStyle(color: Colors.white38)),
              dropdownColor: const Color(0xFF232323),
              style: const TextStyle(color: Colors.white),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text("Nenhum ainda")),
                ..._otherPrograms.map((p) => DropdownMenuItem<String?>(value: p["program_key"] as String, child: Text(p["name"] as String))),
              ],
              onChanged: (v) => setState(() => _graduateProgramKey = v),
            ),
          ],
          if (_message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!, style: TextStyle(color: _messageIsError ? Colors.redAccent : Colors.greenAccent, fontSize: 12))),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
              child: Text(_saving ? "Salvando..." : "Salvar configuracoes"),
            ),
          ),
          const SizedBox(height: 24),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              collapsedIconColor: Colors.white54,
              iconColor: Colors.white54,
              title: const Text("Registro de alteracoes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
                    final list = snapshot.data!;
                    if (list.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text("Nenhuma alteracao registrada ainda.", style: TextStyle(color: Colors.white38, fontSize: 12)));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: list.map((h) {
                        final manager = h["manager"];
                        final email = manager is Map ? manager["login_email"] as String? : null;
                        final date = h["created_at"] != null ? DateTime.parse(h["created_at"] as String).toLocal().toString().substring(0, 16) : "-";
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(h["field"] as String, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text((h["old_value"] as String? ?? "-") + "  ->  " + (h["new_value"] as String? ?? "-"), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                              Text(date + (email != null ? "  -  " + email : ""), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
