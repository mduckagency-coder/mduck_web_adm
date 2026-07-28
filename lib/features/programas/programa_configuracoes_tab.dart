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
  late final _maxDaysController = TextEditingController(text: (widget.program["criteria"]?["max_days_in_agency"])?.toString() ?? "");
  late final _minDaysValidatedController = TextEditingController(text: (widget.program["criteria"]?["min_days_validated"])?.toString() ?? "");
  late final _minHoursController = TextEditingController(text: (widget.program["criteria"]?["min_hours"])?.toString() ?? "");
  late final _minDiamondsController = TextEditingController(text: (widget.program["criteria"]?["min_diamonds"])?.toString() ?? "");
  late final _maxDiamondsController = TextEditingController(text: (widget.program["criteria"]?["max_diamonds"])?.toString() ?? "");
  late final _minHeartMeController = TextEditingController(text: (widget.program["criteria"]?["min_heart_me"])?.toString() ?? "");
  late final _minBattlesController = TextEditingController(text: (widget.program["criteria"]?["min_battles"])?.toString() ?? "");
  late final _ticketQuantityController = TextEditingController(text: ((widget.program["criteria"]?["ticket_quantity"] as int?) ?? 0).toString());
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
  String _membershipMode = "fluxo";

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
  String _diamondsPeriod = "total";
  String _hoursPeriod = "total";
  String _daysValidatedPeriod = "total";
  String _approvalRuleMode = "todas";

  List<Map<String, dynamic>> _managers = [];
  List<Map<String, dynamic>> _otherPrograms = [];
  List<Map<String, dynamic>> _categories = [];
  Map<String, CategoryOverride> _initialCategoryOverrides = {};
  final Map<String, TextEditingController> _catDaysValidatedControllers = {};
  final Map<String, TextEditingController> _catHoursControllers = {};
  final Map<String, TextEditingController> _catDiamondsControllers = {};
  final Map<String, TextEditingController> _catBattlesControllers = {};
  bool _showCategoryOverrides = false;
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
    _membershipMode = criteria.membershipMode;
    _daysEnabled = criteria.daysEnabled;
    _daysRequired = criteria.daysRequired;
    _daysValidatedEnabled = criteria.daysValidatedEnabled;
    _daysValidatedRequired = criteria.daysValidatedRequired;
    _initialCategoryOverrides = criteria.categoryOverrides;
    _showCategoryOverrides = criteria.categoryOverrides.isNotEmpty;
    _hoursEnabled = criteria.hoursEnabled;
    _hoursRequired = criteria.hoursRequired;
    _diamondsEnabled = criteria.diamondsEnabled;
    _diamondsRequired = criteria.diamondsRequired;
    _heartMeEnabled = criteria.heartMeEnabled;
    _heartMeRequired = criteria.heartMeRequired;
    _battlesEnabled = criteria.battlesEnabled;
    _battlesRequired = criteria.battlesRequired;
    _diamondsPeriod = criteria.diamondsPeriod;
    _hoursPeriod = criteria.hoursPeriod;
    _daysValidatedPeriod = criteria.daysValidatedPeriod;
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
    final responsibles = await client.from("development_program_managers").select("manager_id").eq("program_id", widget.program["id"]);
    if (mounted) {
      setState(() {
        _managers = (managers as List).cast<Map<String, dynamic>>();
        _otherPrograms = (programs as List).cast<Map<String, dynamic>>();
        _categories = (categories as List).cast<Map<String, dynamic>>();
        _responsibleIds = (responsibles as List).map((r) => r["manager_id"] as String).toSet();
        _initialResponsibleIds = _responsibleIds.toSet();
        for (final c in _categories) {
          final id = c["id"] as String;
          final o = _initialCategoryOverrides[id];
          _catDaysValidatedControllers[id] = TextEditingController(text: o?.minDaysValidated?.toString() ?? "");
          _catHoursControllers[id] = TextEditingController(text: o?.minHours?.toString() ?? "");
          _catDiamondsControllers[id] = TextEditingController(text: o?.minDiamonds?.toString() ?? "");
          _catBattlesControllers[id] = TextEditingController(text: o?.minBattles?.toString() ?? "");
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
      final categoryOverrides = <String, dynamic>{};
      for (final c in _categories) {
        final id = c["id"] as String;
        final dv = int.tryParse(_catDaysValidatedControllers[id]?.text.trim() ?? "");
        final hr = double.tryParse((_catHoursControllers[id]?.text.trim() ?? "").replaceAll(",", "."));
        final di = num.tryParse(_catDiamondsControllers[id]?.text.trim() ?? "");
        final bt = int.tryParse(_catBattlesControllers[id]?.text.trim() ?? "");
        if (dv != null || hr != null || di != null || bt != null) {
          categoryOverrides[id] = {"min_days_validated": dv, "min_hours": hr, "min_diamonds": di, "min_battles": bt};
        }
      }
      final criteria = {
        "min_days": int.tryParse(_minDaysController.text.trim()),
        "max_days_in_agency": int.tryParse(_maxDaysController.text.trim()),
        "min_days_validated": int.tryParse(_minDaysValidatedController.text.trim()),
        "min_hours": double.tryParse(_minHoursController.text.trim().replaceAll(",", ".")),
        "min_diamonds": num.tryParse(_minDiamondsController.text.trim()),
        "max_diamonds": num.tryParse(_maxDiamondsController.text.trim()),
        "min_heart_me": num.tryParse(_minHeartMeController.text.trim().replaceAll(",", ".")),
        "min_battles": int.tryParse(_minBattlesController.text.trim()),
        "category_overrides": categoryOverrides,
        "membership_mode": _membershipMode,
        "ticket_quantity": int.tryParse(_ticketQuantityController.text.trim()) ?? 0,
        "diamonds_period": _diamondsPeriod,
        "hours_period": _hoursPeriod,
        "days_validated_period": _daysValidatedPeriod,
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

  Widget _sectionTitle(String text, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          if (subtitle != null) Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic)),
        ],
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

  Widget _periodDropdown(String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(left: 48, top: 2),
      child: Row(children: [
        const Text("Considerar: ", style: TextStyle(color: Colors.white38, fontSize: 10)),
        DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: const Color(0xFF232323),
          style: const TextStyle(color: Colors.white70, fontSize: 11),
          underline: Container(height: 1, color: Colors.white24),
          items: const [
            DropdownMenuItem(value: "total", child: Text("Total acumulado")),
            DropdownMenuItem(value: "mes_atual", child: Text("Mes atual")),
            DropdownMenuItem(value: "mes_anterior", child: Text("Mes anterior")),
            DropdownMenuItem(value: "mes_atual_ou_anterior", child: Text("Mes atual ou anterior")),
          ],
          onChanged: (v) => onChanged(v ?? value),
        ),
      ]),
    );
  }

  Widget _smallField(TextEditingController controller, String label, {bool enabled = true}) {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        style: TextStyle(color: enabled ? Colors.white : Colors.white38, fontSize: 12),
        decoration: InputDecoration(isDense: true, labelText: label, labelStyle: const TextStyle(color: Colors.white38, fontSize: 11)),
      ),
    );
  }

  /// Dias na agencia mostrado como uma faixa unica (a partir de / ate no
  /// maximo), em vez de dois campos soltos sem relacao visivel entre eles.
  Widget _dayRangeCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Switch(value: _daysEnabled, activeColor: const Color(0xFF7A0BD4), onChanged: (v) => setState(() => _daysEnabled = v)),
          const Expanded(child: Text("Dias na agencia (faixa)", style: TextStyle(color: Colors.white))),
          Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("Obrigatoria", style: TextStyle(color: Colors.white38, fontSize: 9)),
            Checkbox(value: _daysRequired, activeColor: const Color(0xFF7A0BD4), onChanged: _daysEnabled ? (v) => setState(() => _daysRequired = v ?? true) : null),
          ]),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 48),
          child: Wrap(spacing: 12, runSpacing: 4, children: [
            _smallField(_minDaysController, "A partir de (minimo)", enabled: _daysEnabled),
            _smallField(_maxDaysController, "Ate no maximo (opcional)", enabled: _daysEnabled),
          ]),
        ),
      ],
    );
  }

  /// Diamantes: minimo + maximo (opcional, filtro duro -- ex "ate 20k") +
  /// periodo, tudo junto (o maximo usa o mesmo periodo do minimo).
  Widget _diamondsMetaCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metaRow(
          label: "Diamantes minimos",
          controller: _minDiamondsController,
          enabled: _diamondsEnabled,
          onEnabledChanged: (v) => setState(() => _diamondsEnabled = v),
          required: _diamondsRequired,
          onRequiredChanged: (v) => setState(() => _diamondsRequired = v),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 48),
          child: _smallField(_maxDiamondsController, "Maximo (opcional)"),
        ),
        _periodDropdown(_diamondsPeriod, (v) => setState(() => _diamondsPeriod = v)),
      ],
    );
  }

  Widget _categoryOverridesSection() {
    if (_categories.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _showCategoryOverrides = !_showCategoryOverrides),
          icon: Icon(_showCategoryOverrides ? Icons.expand_less : Icons.expand_more, size: 16),
          label: const Text("Personalizar por categoria", style: TextStyle(fontSize: 12)),
        ),
        if (_showCategoryOverrides)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _categories.map((c) {
                final id = c["id"] as String;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c["name"] as String, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 10, runSpacing: 6, children: [
                        _smallField(_catDaysValidatedControllers[id]!, "Dias validados"),
                        _smallField(_catHoursControllers[id]!, "Horas"),
                        _smallField(_catDiamondsControllers[id]!, "Diamantes"),
                        _smallField(_catBattlesControllers[id]!, "Batalhas"),
                      ]),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
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
          if (_loadingOptions)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator()))
          else ...[
            _sectionTitle("Identidade"),
            _field(_nameController, "Nome"),
            _field(_descriptionController, "Descricao", maxLines: 2),
            _field(_objectiveController, "Objetivo", maxLines: 2),
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
            const SizedBox(height: 20),

            _sectionTitle("Responsaveis"),
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
            const SizedBox(height: 20),

            _sectionTitle(
              "Modo de participacao",
              subtitle: "Fluxo: Kanban com etapas e avaliacao final manual (aprovar/graduar/revisao/desligar). Faixa automatica: sem avaliacao manual, o sistema entra e sai o streamer sozinho conforme os criterios abaixo baterem ou deixarem de bater.",
            ),
            RadioListTile<String>(
              value: "fluxo",
              groupValue: _membershipMode,
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF7A0BD4),
              title: const Text("Fluxo manual (Kanban + avaliacao)", style: TextStyle(color: Colors.white, fontSize: 13)),
              onChanged: (v) => setState(() => _membershipMode = v ?? _membershipMode),
            ),
            RadioListTile<String>(
              value: "faixa",
              groupValue: _membershipMode,
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF7A0BD4),
              title: const Text("Faixa automatica (entra e sai sozinho)", style: TextStyle(color: Colors.white, fontSize: 13)),
              onChanged: (v) => setState(() => _membershipMode = v ?? _membershipMode),
            ),
            const SizedBox(height: 16),

            _sectionTitle("Metas do programa", subtitle: "O interruptor liga/desliga a meta; o valor fica guardado mesmo desligada."),
            const SizedBox(height: 8),
            Wrap(spacing: 16, runSpacing: 12, children: [
              SizedBox(width: 320, child: _dayRangeCard()),
              SizedBox(
                width: 300,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _metaRow(
                    label: "Dias validados (ficou ao vivo)",
                    controller: _minDaysValidatedController,
                    enabled: _daysValidatedEnabled,
                    onEnabledChanged: (v) => setState(() => _daysValidatedEnabled = v),
                    required: _daysValidatedRequired,
                    onRequiredChanged: (v) => setState(() => _daysValidatedRequired = v),
                  ),
                  _periodDropdown(_daysValidatedPeriod, (v) => setState(() => _daysValidatedPeriod = v)),
                ]),
              ),
              SizedBox(
                width: 300,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _metaRow(
                    label: "Horas minimas",
                    controller: _minHoursController,
                    enabled: _hoursEnabled,
                    onEnabledChanged: (v) => setState(() => _hoursEnabled = v),
                    required: _hoursRequired,
                    onRequiredChanged: (v) => setState(() => _hoursRequired = v),
                  ),
                  _periodDropdown(_hoursPeriod, (v) => setState(() => _hoursPeriod = v)),
                ]),
              ),
              SizedBox(width: 320, child: _diamondsMetaCard()),
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
              SizedBox(
                width: 300,
                child: _metaRow(
                  label: "Quantidade minima de batalhas (padrao)",
                  controller: _minBattlesController,
                  enabled: _battlesEnabled,
                  onEnabledChanged: (v) => setState(() => _battlesEnabled = v),
                  required: _battlesRequired,
                  onRequiredChanged: (v) => setState(() => _battlesRequired = v),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            _categoryOverridesSection(),
            const SizedBox(height: 8),

            _sectionTitle("Regra de aprovacao", subtitle: "Decide o que conta pra elegibilidade entre as metas ativas acima."),
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

            _sectionTitle("Categorias elegiveis", subtitle: "Vazio = qualquer categoria pode participar."),
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
            const SizedBox(height: 20),

            _sectionTitle("Tickets de sorteio", subtitle: "Quantidade concedida automaticamente quando o streamer bate a meta (0 = desativado). Em modo faixa, um ticket por mes enquanto elegivel; em modo fluxo, um ticket na aprovacao final."),
            SizedBox(width: 220, child: _field(_ticketQuantityController, "Quantidade de tickets", keyboardType: TextInputType.number)),

            _sectionTitle("Mensagem e premiacoes"),
            _field(_defaultMessageController, "Mensagem padrao", maxLines: 3),
            _field(_awardsController, "Premiacoes (descricao)", maxLines: 2),

            if (_membershipMode == "fluxo") ...[
              const SizedBox(height: 8),
              _sectionTitle("Encadeamento"),
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
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: _openFluxoConfig, icon: const Icon(Icons.view_column, size: 16), label: const Text("Configurar fluxo (colunas do Kanban)"))),
            ],
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
