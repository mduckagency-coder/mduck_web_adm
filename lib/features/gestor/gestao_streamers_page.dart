import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../metricas/level_maintenance_page.dart"
    show levelThresholds, levelActivityDays, levelActivityHours, levelForDiamonds;
import "../whatsapp/whatsapp_dialog.dart";
import "diamond_ranges.dart";
import "gestor_streamer_service.dart";
import "streamer_action_dialog.dart";
import "streamer_card.dart";
import "streamer_manager_picker_dialog.dart";
import "streamer_managers_service.dart";
import "streamer_side_panel.dart";
import "streamer_stage_service.dart";

/// Libera arrastar com o mouse (nao so touch/stylus) -- por padrao o
/// MaterialScrollBehavior do Flutter web/desktop nao inclui
/// PointerDeviceKind.mouse em dragDevices.
class _MouseDragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}

/// "Gestao de Streamers" -- Kanban no mesmo espirito do Onboard 15 Dias: o
/// streamer so muda de coluna quando o gestor registra uma acao (chip
/// "Registrar Ação" no card, streamer_action_dialog.dart) ou arrasta o card
/// -- nenhum calculo automatico decide isso (streamer_stage_service.dart),
/// a unica excecao e a coluna Reaver/Desligar (30+ dias sem live, sempre
/// automatica). Os sinais que antes moviam card sozinho (risco de
/// manutencao, ritmo, etc.) viram filtros de busca no Painel Geral, pra
/// ajudar o gestor a decidir, nao pra decidir por ele.
class GestaoStreamersPage extends StatefulWidget {
  final bool showManagerAggregates;
  const GestaoStreamersPage({super.key, this.showManagerAggregates = false});

  @override
  State<GestaoStreamersPage> createState() => _GestaoStreamersPageState();
}

class _ColumnDef {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _ColumnDef(this.key, this.label, this.icon, this.color);
}

final _columns = [
  const _ColumnDef(painelGeralKey, "Painel Geral", Icons.home, Colors.white70),
  for (final s in streamerStages) _ColumnDef(s.key, s.label, s.icon, const Color(0xFF7A0BD4)),
  const _ColumnDef(reaverDesligarKey, "Reaver ou Desligar", Icons.report, Colors.redAccent),
];

const _inatividadeDiasLimite = 30;

class _GestaoStreamersPageState extends State<GestaoStreamersPage> {
  late Future<void> _future;
  final _hScrollController = ScrollController();
  String _agencyId = "";
  List<GestorStreamerRow> _all = [];
  Map<String, StreamerStageInfo> _stages = {};
  Map<String, int> _contactCountsByManager = {};
  Map<String, List<StreamerManager>> _managersByStreamer = {};
  List<Map<String, dynamic>> _agencyManagers = [];

  String _search = "";
  String? _categoryFilter;
  String? _rangeFilter;
  bool _showAdvancedFilters = false;

  final _minDaysController = TextEditingController();
  final _maxDaysController = TextEditingController();
  final _minHoursController = TextEditingController();
  final _maxHoursController = TextEditingController();
  final _minDaysLastMonthController = TextEditingController();
  final _maxDaysLastMonthController = TextEditingController();
  final _minHoursLastMonthController = TextEditingController();
  final _maxHoursLastMonthController = TextEditingController();
  final _minBattlesController = TextEditingController();
  final _maxBattlesController = TextEditingController();

  bool _filterMaintenanceRisk = false;
  bool _filterNearUpgrade = false;
  bool _filterGrowing = false;
  bool _filterWentQuiet = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _hScrollController.dispose();
    for (final c in [
      _minDaysController,
      _maxDaysController,
      _minHoursController,
      _maxHoursController,
      _minDaysLastMonthController,
      _maxDaysLastMonthController,
      _minHoursLastMonthController,
      _maxHoursLastMonthController,
      _minBattlesController,
      _maxBattlesController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final me = await client
        .from("managers")
        .select("agency_id")
        .eq("id", userId)
        .single();
    final agencyId = me["agency_id"] as String;
    _agencyId = agencyId;
    _all = await fetchGestorStreamerRows(agencyId: agencyId);
    final ids = _all.map((r) => r.id).toList();
    _stages = await fetchStreamerStages(agencyId: agencyId);
    _managersByStreamer = await fetchStreamerManagersByIds(ids);
    final agencyManagers = await client
        .from("managers")
        .select("id, login_email, photo_url")
        .eq("agency_id", agencyId);
    _agencyManagers = (agencyManagers as List).cast<Map<String, dynamic>>();
    if (widget.showManagerAggregates) {
      _contactCountsByManager = await fetchContactCountsByManager(
        agencyId: agencyId,
      );
    }
  }

  /// Reaproveitada tanto pro carregamento inicial (FutureBuilder) quanto
  /// pra recarregar depois de uma acao -- espera o _load() terminar e SO
  /// ENTAO faz o setState, em vez de so trocar a referencia de _future e
  /// confiar no FutureBuilder pra perceber a troca (mesmo resultado, mas
  /// sem depender de identidade de Future -- mais dificil de mascarar um
  /// erro silencioso).
  Future<void> _reload() async {
    final next = _load();
    setState(() => _future = next);
    await next;
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------
  // Coluna atual de cada streamer -- unica regra automatica e a
  // inatividade (sempre vence sobre qualquer acao registrada); o resto e
  // so o que esta guardado em streamer_stage (ou painel_geral, se nada).
  // ---------------------------------------------------------------------

  int? _daysSemLive(GestorStreamerRow row) => row.lastLiveAt != null
      ? DateTime.now().difference(row.lastLiveAt!).inDays
      : null;

  String _columnFor(GestorStreamerRow row) {
    final dias = _daysSemLive(row);
    if (dias == null || dias > _inatividadeDiasLimite) return reaverDesligarKey;
    return _stages[row.id]?.stageKey ?? painelGeralKey;
  }

  // ---------------------------------------------------------------------
  // Sinais pro Painel Geral -- viram filtro, nunca movem card sozinho.
  // ---------------------------------------------------------------------

  num? _pacedGrowth(GestorStreamerRow row, DateTime now) {
    if (row.diamondsLastMonth == null) return null;
    final daysInLastMonth = DateTime(now.year, now.month, 0).day;
    final pacedExpected = row.diamondsLastMonth! * (now.day / daysInLastMonth);
    return row.diamonds - pacedExpected;
  }

  num _averagePacedGrowth(DateTime now) {
    final values = _all
        .map((r) => _pacedGrowth(r, now))
        .whereType<num>()
        .toList();
    if (values.isEmpty) return 0;
    return values.fold<num>(0, (acc, v) => acc + v) / values.length;
  }

  bool _isMaintenanceAtRisk(GestorStreamerRow row) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final monthFraction = now.day / daysInMonth;
    final daysRemainingInMonth = daysInMonth - now.day;
    final previousLevel = levelForDiamonds(row.diamondsLastMonth ?? 0);
    final requiredThreshold = levelThresholds[previousLevel - 1];
    final requiredDays = levelActivityDays[previousLevel - 1];
    final requiredHours = levelActivityHours[previousLevel - 1];

    final projectedDiamonds = now.day > 0
        ? row.diamonds * (daysInMonth / now.day)
        : row.diamonds;
    final diamondsAtRisk =
        monthFraction >= 0.5 && projectedDiamonds < requiredThreshold;

    final projectedHours = now.day > 0
        ? row.hoursLive * (daysInMonth / now.day)
        : row.hoursLive;
    final hoursAtRisk = monthFraction >= 0.5 && projectedHours < requiredHours;

    final daysStillNeeded = (requiredDays - row.daysLive).clamp(0, requiredDays);
    final daysAtRisk = daysStillNeeded > daysRemainingInMonth;

    return diamondsAtRisk || hoursAtRisk || daysAtRisk;
  }

  bool _isNearUpgrade(GestorStreamerRow row) {
    final currentLevel = levelForDiamonds(row.diamonds);
    if (currentLevel >= levelThresholds.length) return false;
    final nextThreshold = levelThresholds[currentLevel];
    final gap = nextThreshold - row.diamonds;
    return gap >= 0 && gap <= nextThreshold * 0.10;
  }

  bool _isGrowing(GestorStreamerRow row) {
    final now = DateTime.now();
    final g = _pacedGrowth(row, now);
    if (g == null || g <= 0) return false;
    return g > _averagePacedGrowth(now);
  }

  bool _wentQuietAfterGoodPace(GestorStreamerRow row) {
    final dias = _daysSemLive(row);
    if (dias == null || dias < 3 || dias > _inatividadeDiasLimite - 1) {
      return false;
    }
    return (row.diamondsLastMonth ?? 0) > 0;
  }

  // ---------------------------------------------------------------------
  // Filtros
  // ---------------------------------------------------------------------

  bool _matchesTop(GestorStreamerRow r) {
    if (_categoryFilter != null && r.categoryName != _categoryFilter) {
      return false;
    }
    if (_rangeFilter != null && rangeFor(r.diamonds).key != _rangeFilter) {
      return false;
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      final matches =
          r.displayName.toLowerCase().contains(q) ||
          r.nick.toLowerCase().contains(q) ||
          (r.tiktokCreatorId?.toLowerCase().contains(q) ?? false) ||
          r.id.toLowerCase().contains(q);
      if (!matches) return false;
    }
    return true;
  }

  int? _num(TextEditingController c) =>
      c.text.trim().isEmpty ? null : int.tryParse(c.text.trim());

  bool _matchesAdvanced(GestorStreamerRow r) {
    final minDays = _num(_minDaysController);
    final maxDays = _num(_maxDaysController);
    final minHours = _num(_minHoursController);
    final maxHours = _num(_maxHoursController);
    final minDaysLM = _num(_minDaysLastMonthController);
    final maxDaysLM = _num(_maxDaysLastMonthController);
    final minHoursLM = _num(_minHoursLastMonthController);
    final maxHoursLM = _num(_maxHoursLastMonthController);
    final minBattles = _num(_minBattlesController);
    final maxBattles = _num(_maxBattlesController);

    if (minDays != null && r.daysLive < minDays) return false;
    if (maxDays != null && r.daysLive > maxDays) return false;
    if (minHours != null && r.hoursLive < minHours) return false;
    if (maxHours != null && r.hoursLive > maxHours) return false;
    if (minDaysLM != null && (r.daysLiveLastMonth ?? 0) < minDaysLM) return false;
    if (maxDaysLM != null && (r.daysLiveLastMonth ?? 0) > maxDaysLM) return false;
    if (minHoursLM != null && (r.hoursLiveLastMonth ?? 0) < minHoursLM) return false;
    if (maxHoursLM != null && (r.hoursLiveLastMonth ?? 0) > maxHoursLM) return false;
    if (minBattles != null && r.battles < minBattles) return false;
    if (maxBattles != null && r.battles > maxBattles) return false;

    if (_filterMaintenanceRisk && !_isMaintenanceAtRisk(r)) return false;
    if (_filterNearUpgrade && !_isNearUpgrade(r)) return false;
    if (_filterGrowing && !_isGrowing(r)) return false;
    if (_filterWentQuiet && !_wentQuietAfterGoodPace(r)) return false;
    return true;
  }

  // ---------------------------------------------------------------------
  // Acoes
  // ---------------------------------------------------------------------

  Future<void> _moveCard(String streamerId, String stageKey) async {
    try {
      await registerStreamerAction(
        streamerId: streamerId,
        agencyId: _agencyId,
        stageKey: stageKey,
      );
      await _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao mover streamer: " + e.toString())),
        );
      }
    }
  }

  void _openActionDialog(GestorStreamerRow row) {
    showDialog(
      context: context,
      builder: (context) => StreamerActionDialog(
        streamerId: row.id,
        agencyId: _agencyId,
        assignedManagerId: row.assignedManagerId,
        agencyManagers: _agencyManagers,
        onSaved: _reload,
      ),
    );
  }

  void _openManagerPicker(String streamerId) {
    showDialog(
      context: context,
      builder: (context) => StreamerManagerPickerDialog(
        streamerId: streamerId,
        agencyManagers: _agencyManagers,
        onChanged: _reload,
      ),
    );
  }

  void _openWhatsAppColumn(List<GestorStreamerRow> items) {
    showDialog(
      context: context,
      builder: (context) => WhatsAppDialog(
        targets: items
            .map(
              (r) => WhatsAppTarget(
                id: r.id,
                displayName: r.displayName,
                phone: r.phone,
              ),
            )
            .toList(),
        targetLabel: "Coluna (" + items.length.toString() + " streamers)",
      ),
    );
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  Widget _filtersBar() {
    final categories = _all
        .map((r) => r.categoryName)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search, color: Colors.white54, size: 18),
                  hintText: "Buscar por nome, nick ou ID",
                  hintStyle: TextStyle(color: Colors.white38),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Categoria",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  value: _categoryFilter,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  underline: Container(height: 1, color: Colors.white24),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text("Todos"),
                    ),
                    ...categories.map(
                      (c) => DropdownMenuItem<String?>(value: c, child: Text(c)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _categoryFilter = v),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Faixa de Diamantes",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  value: _rangeFilter,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  underline: Container(height: 1, color: Colors.white24),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text("Todos"),
                    ),
                    ...diamondRanges.map(
                      (r) => DropdownMenuItem<String?>(
                        value: r.key,
                        child: Text(r.label),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _rangeFilter = v),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _showAdvancedFilters = !_showAdvancedFilters),
              icon: Icon(
                _showAdvancedFilters ? Icons.expand_less : Icons.tune,
                size: 16,
              ),
              label: Text(
                _showAdvancedFilters
                    ? "Ocultar filtros avançados"
                    : "Filtros avançados (Painel Geral)",
              ),
            ),
          ],
        ),
        if (_showAdvancedFilters) _advancedFiltersPanel(),
      ],
    );
  }

  Widget _numField(String label, TextEditingController c) {
    return SizedBox(
      width: 110,
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _advancedFiltersPanel() {
    Widget chip(String label, bool value, ValueChanged<bool> onChanged) {
      return FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: value,
        selectedColor: const Color(0xFF7A0BD4),
        backgroundColor: Colors.white.withOpacity(0.05),
        labelStyle: TextStyle(color: value ? Colors.white : Colors.white70),
        onSelected: onChanged,
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _numField("Dias mín. (mês)", _minDaysController),
              _numField("Dias máx. (mês)", _maxDaysController),
              _numField("Horas mín. (mês)", _minHoursController),
              _numField("Horas máx. (mês)", _maxHoursController),
              _numField("Dias mín. (mês passado)", _minDaysLastMonthController),
              _numField("Dias máx. (mês passado)", _maxDaysLastMonthController),
              _numField("Horas mín. (mês passado)", _minHoursLastMonthController),
              _numField("Horas máx. (mês passado)", _maxHoursLastMonthController),
              _numField("Batalhas mín. (mês)", _minBattlesController),
              _numField("Batalhas máx. (mês)", _maxBattlesController),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip(
                "⚠️ Risco de manutenção",
                _filterMaintenanceRisk,
                (v) => setState(() => _filterMaintenanceRisk = v),
              ),
              chip(
                "⬆️ Perto de subir de nível",
                _filterNearUpgrade,
                (v) => setState(() => _filterNearUpgrade = v),
              ),
              chip(
                "📈 Em crescimento",
                _filterGrowing,
                (v) => setState(() => _filterGrowing = v),
              ),
              chip(
                "❓ Sumiu depois de bom desempenho",
                _filterWentQuiet,
                (v) => setState(() => _filterWentQuiet = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(GestorStreamerRow row, {required bool draggable}) {
    final card = StreamerCard(
      row: row,
      stageInfo: _stages[row.id],
      onTap: () =>
          openStreamerSidePanel(context, streamerId: row.id).then((_) => _reload()),
      onRegisterAction: () => _openActionDialog(row),
      managers: _managersByStreamer[row.id] ?? const [],
      onManageManagers: () => _openManagerPicker(row.id),
    );
    if (!draggable) return card;
    return Draggable<String>(
      key: ValueKey(row.id),
      data: row.id,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.85, child: card),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: card,
    );
  }

  Widget _column(_ColumnDef def, List<GestorStreamerRow> items) {
    final isAutomatic = def.key == reaverDesligarKey;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(def.icon, size: 15, color: def.color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                def.label,
                style: TextStyle(
                  color: def.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              items.length.toString(),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            if (items.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.chat, size: 16, color: Color(0xFF25D366)),
                tooltip: "WhatsApp para todos desta coluna",
                onPressed: () => _openWhatsAppColumn(items),
              ),
          ],
        ),
        const Divider(color: Colors.white12, height: 12),
        Expanded(
          child: items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    "Nenhum streamer aqui.",
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _card(items[index], draggable: !isAutomatic),
                  ),
                ),
        ),
      ],
    );

    if (isAutomatic) {
      return Tooltip(
        message: "Automático (sem live há 30+ dias) -- não recebe cards arrastados.",
        child: Container(
          width: 300,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: body,
        ),
      );
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) => _moveCard(details.data, def.key),
      builder: (context, candidateData, rejectedData) {
        final highlighting = candidateData.isNotEmpty;
        return Container(
          width: 300,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: highlighting
                ? const Color(0xFF7A0BD4).withOpacity(0.12)
                : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlighting ? const Color(0xFF7A0BD4) : Colors.white12,
            ),
          ),
          child: body,
        );
      },
    );
  }

  Widget _managerAggregates(Map<String, List<GestorStreamerRow>> byColumn) {
    final now = DateTime.now();
    final overdueByManager = <String, int>{};
    for (final entry in _stages.entries) {
      if (entry.value.dueAt == null || entry.value.dueAt!.isAfter(now)) continue;
      final row = _all.where((r) => r.id == entry.key).cast<GestorStreamerRow?>().firstWhere(
            (r) => r != null,
            orElse: () => null,
          );
      if (row == null) continue;
      final label = row.assignedManagerEmail ?? "Sem gestor";
      overdueByManager[label] = (overdueByManager[label] ?? 0) + 1;
    }
    final reaverByManager = <String, int>{};
    for (final r in byColumn[reaverDesligarKey] ?? const []) {
      final label = r.assignedManagerEmail ?? "Sem gestor";
      reaverByManager[label] = (reaverByManager[label] ?? 0) + 1;
    }
    final semAcompanhamento = [..._all]
      ..sort((a, b) => b.daysSinceLastContact.compareTo(a.daysSinceLastContact));

    Widget card(String title, List<Widget> lines) {
      return Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            if (lines.isEmpty)
              const Text("-", style: TextStyle(color: Colors.white38, fontSize: 12))
            else
              ...lines,
          ],
        ),
      );
    }

    Widget line(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          card(
            "Acompanhamentos por gestor (30 dias)",
            _contactCountsByManager.entries
                .map((e) => line(e.key + ": " + e.value.toString()))
                .toList(),
          ),
          card(
            "Ações vencidas por gestor",
            overdueByManager.entries
                .map((e) => line(e.key + ": " + e.value.toString()))
                .toList(),
          ),
          card(
            "Reaver/Desligar por gestor",
            reaverByManager.entries
                .map((e) => line(e.key + ": " + e.value.toString()))
                .toList(),
          ),
          card(
            "Mais tempo sem acompanhamento",
            semAcompanhamento
                .take(5)
                .map(
                  (r) => line(
                    "@" +
                        r.nick +
                        " -- " +
                        (r.daysSinceLastContact > 1000000
                            ? "nunca"
                            : r.daysSinceLastContact.toString() + "d"),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: FutureBuilder<void>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Erro ao carregar: " + snapshot.error.toString(),
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }
          final topFiltered = _all.where(_matchesTop).toList();
          final byColumn = <String, List<GestorStreamerRow>>{
            for (final def in _columns) def.key: [],
          };
          for (final r in topFiltered) {
            final col = _columnFor(r);
            if (col == painelGeralKey && !_matchesAdvanced(r)) continue;
            byColumn[col]!.add(r);
          }
          for (final entry in byColumn.entries) {
            entry.value.sort((a, b) {
              final da = _stages[a.id]?.dueAt;
              final db = _stages[b.id]?.dueAt;
              if (da == null && db == null) return b.diamonds.compareTo(a.diamonds);
              if (da == null) return 1;
              if (db == null) return -1;
              return da.compareTo(db);
            });
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    "Gestão de Streamers",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    onPressed: _reload,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _filtersBar(),
              if (widget.showManagerAggregates) _managerAggregates(byColumn),
              Expanded(
                child: ScrollConfiguration(
                  behavior: _MouseDragScrollBehavior(),
                  child: Scrollbar(
                    controller: _hScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _hScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _columns
                            .map((def) => _column(def, byColumn[def.key]!))
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
