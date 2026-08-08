import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "include_participation_dialog.dart";
import "program_eligibility_service.dart";
import "program_participation_service.dart";
import "programa_history_helpers.dart";

class ProgramaParticipantesTab extends StatefulWidget {
  final Map<String, dynamic> program;
  const ProgramaParticipantesTab({super.key, required this.program});

  @override
  State<ProgramaParticipantesTab> createState() => _ProgramaParticipantesTabState();
}

class _ProgramaParticipantesTabState extends State<ProgramaParticipantesTab> {
  bool _loading = true;
  String? _errorMessage;
  List<StreamerSnapshot> _candidates = [];
  List<ProgramParticipation> _participations = [];
  String? _tenureFilter;
  String? _diamondsFilter;
  final _minDaysController = TextEditingController();
  final _minHoursController = TextEditingController();
  final _minDaysThisMonthController = TextEditingController();
  final _minHoursThisMonthController = TextEditingController();
  String _search = "";
  final Set<String> _selectedCandidateIds = {};
  bool _showHistory = false;
  DateTime? _lastLoadedAt;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  String get _programId => widget.program["id"] as String;
  String get _agencyId => widget.program["agency_id"] as String;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final candidates = await fetchCandidateSnapshots(agencyId: _agencyId);
      final participations = await fetchParticipations(
        programId: _programId,
        includeRemoved: _showHistory,
      );
      setState(() {
        _candidates = candidates;
        _participations = participations;
        _loading = false;
        _lastLoadedAt = DateTime.now();
        _selectedCandidateIds.clear();
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  void _toggleHistory() {
    setState(() => _showHistory = !_showHistory);
    _load();
  }

  Set<String> get _activeStreamerIds => _participations
      .where((p) => p.status == "ativo")
      .map((p) => p.streamerId)
      .toSet();

  List<StreamerSnapshot> get _filteredCandidates {
    final enrolled = _activeStreamerIds;
    final term = _search.trim().toLowerCase();
    final minDays = int.tryParse(_minDaysController.text.trim());
    final minHours = double.tryParse(_minHoursController.text.trim().replaceAll(",", "."));
    final minDaysThisMonth = int.tryParse(_minDaysThisMonthController.text.trim());
    final minHoursThisMonth = double.tryParse(
      _minHoursThisMonthController.text.trim().replaceAll(",", "."),
    );
    final list = _candidates.where((s) {
      if (enrolled.contains(s.id)) return false;
      if (_tenureFilter != null && tenureBucketKeyFor(s.daysInAgency) != _tenureFilter)
        return false;
      if (_diamondsFilter != null &&
          diamondsBucketKeyFor(s.diamondsLastMonth) != _diamondsFilter)
        return false;
      if (minDays != null && (s.daysValidatedLastMonth ?? 0) < minDays) return false;
      if (minHours != null && (s.hoursLastMonth ?? 0) < minHours) return false;
      if (minDaysThisMonth != null && (s.daysValidatedThisMonth ?? 0) < minDaysThisMonth)
        return false;
      if (minHoursThisMonth != null && (s.hoursThisMonth ?? 0) < minHoursThisMonth)
        return false;
      if (term.isNotEmpty && !s.displayName.toLowerCase().contains(term)) return false;
      return true;
    }).toList();
    list.sort(
      (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return list;
  }

  /// Ordena pela coluna clicada. Colunas numericas comecam do maior pro
  /// menor no primeiro clique (o que o gestor espera ao clicar em
  /// "Diamantes", por exemplo); colunas de texto comecam de A a Z. Clicar
  /// de novo na mesma coluna inverte a direcao.
  void _onSort(int columnIndex, {required bool numeric}) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = !numeric;
      }
    });
  }

  static final List<int Function(StreamerSnapshot a, StreamerSnapshot b)> _columnComparators = [
    (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    (a, b) => (a.tiktokId ?? "").toLowerCase().compareTo((b.tiktokId ?? "").toLowerCase()),
    (a, b) => (a.categoryName ?? "").toLowerCase().compareTo((b.categoryName ?? "").toLowerCase()),
    (a, b) => a.daysInAgency.compareTo(b.daysInAgency),
    (a, b) => (a.daysValidatedLastMonth ?? -1).compareTo(b.daysValidatedLastMonth ?? -1),
    (a, b) => (a.daysValidatedThisMonth ?? -1).compareTo(b.daysValidatedThisMonth ?? -1),
    (a, b) => (a.hoursLastMonth ?? -1).compareTo(b.hoursLastMonth ?? -1),
    (a, b) => (a.hoursThisMonth ?? -1).compareTo(b.hoursThisMonth ?? -1),
    (a, b) => a.battles.compareTo(b.battles),
    (a, b) => (a.diamondsLastMonth ?? -1).compareTo(b.diamondsLastMonth ?? -1),
    (a, b) => (a.diamondsThisMonth ?? a.diamonds).compareTo(b.diamondsThisMonth ?? b.diamonds),
  ];

  List<StreamerSnapshot> _sortedCandidates(List<StreamerSnapshot> list) {
    if (_sortColumnIndex == null) return list;
    final sorted = List<StreamerSnapshot>.from(list);
    final compare = _columnComparators[_sortColumnIndex!];
    sorted.sort((a, b) => _sortAscending ? compare(a, b) : compare(b, a));
    return sorted;
  }

  void _toggleCandidate(String id) {
    setState(() {
      if (_selectedCandidateIds.contains(id)) {
        _selectedCandidateIds.remove(id);
      } else {
        _selectedCandidateIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<StreamerSnapshot> list) {
    setState(() {
      if (_selectedCandidateIds.length == list.length && list.isNotEmpty) {
        _selectedCandidateIds.clear();
      } else {
        _selectedCandidateIds
          ..clear()
          ..addAll(list.map((s) => s.id));
      }
    });
  }

  Future<void> _openIncludeDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => IncludeParticipationDialog(
        programId: _programId,
        streamerIds: _selectedCandidateIds.toList(),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmGoal(ParticipationGoal goal, String outcome) async {
    try {
      await confirmGoalOutcome(
        goalId: goal.id,
        outcome: outcome,
        confirmedBy: Supabase.instance.client.auth.currentUser!.id,
      );
      _load();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  Future<void> _revertGoal(ParticipationGoal goal) async {
    try {
      await revertGoalOutcome(goalId: goal.id);
      _load();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  Future<void> _removeParticipation(ProgramParticipation p) async {
    final ok = await confirmAction(
      context,
      title: "Remover do programa",
      message: "Remover " + (p.streamerName ?? "este streamer") + " deste programa?",
      confirmLabel: "Remover",
      confirmColor: Colors.redAccent,
    );
    if (!ok) return;
    try {
      await removeParticipation(
        participationId: p.id,
        removedBy: Supabase.instance.client.auth.currentUser!.id,
      );
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Removido do programa.")));
      _load();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  Widget _bucketChips<T>(
    String title,
    List<(String, String, num, num)> buckets,
    String? selected,
    ValueChanged<String?> onChange,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: buckets.map((b) {
            final isSelected = selected == b.$1;
            return ChoiceChip(
              label: Text(
                b.$2,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF7A0BD4),
              backgroundColor: Colors.white.withOpacity(0.05),
              visualDensity: VisualDensity.compact,
              onSelected: (_) => onChange(isSelected ? null : b.$1),
            );
          }).toList(),
        ),
      ],
    );
  }

  static const _currentMonthColor = Colors.cyanAccent;
  final _tableScrollController = ScrollController();

  Widget _buildCandidatesTable(List<StreamerSnapshot> list) {
    Widget textCell(String text) =>
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11));

    Widget currentMonthCell(String text) => Text(
      text,
      style: const TextStyle(
        color: _currentMonthColor,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );

    DataColumn column(
      String label, {
      required int index,
      bool numeric = false,
      Color color = Colors.white70,
    }) => DataColumn(
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: color == _currentMonthColor ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      numeric: numeric,
      onSort: (_, _) => _onSort(index, numeric: numeric),
    );

    DataColumn currentMonthColumn(String label, {required int index}) =>
        column(label, index: index, numeric: true, color: _currentMonthColor);

    final sortedList = _sortedCandidates(list);

    return Scrollbar(
      controller: _tableScrollController,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        controller: _tableScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 10),
        child: DataTable(
          columnSpacing: 10,
          headingRowHeight: 28,
          dataRowMinHeight: 30,
          dataRowMaxHeight: 34,
          headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _sortAscending,
          // onSelectAll ja faz o DataTable desenhar sua propria coluna de
          // checkbox (combinada com DataRow.selected/onSelectChanged abaixo)
          // -- nao adicionar uma coluna de Checkbox manual aqui, senao
          // aparecem DUAS colunas de selecao lado a lado.
          onSelectAll: (_) => _toggleSelectAll(sortedList),
          columns: [
            column("Nome", index: 0),
            column("ID", index: 1),
            column("Categoria", index: 2),
            column("Dias agencia", index: 3, numeric: true),
            column("Dias (passado)", index: 4, numeric: true),
            currentMonthColumn("Dias (atual)", index: 5),
            column("Horas (passado)", index: 6, numeric: true),
            currentMonthColumn("Horas (atual)", index: 7),
            column("Batalhas", index: 8, numeric: true),
            column("Diamantes (passado)", index: 9, numeric: true),
            currentMonthColumn("Diamantes (atual)", index: 10),
          ],
          rows: sortedList.map((s) {
          final selected = _selectedCandidateIds.contains(s.id);
          return DataRow(
            selected: selected,
            onSelectChanged: (_) => _toggleCandidate(s.id),
            cells: [
              DataCell(
                Text(
                  s.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              DataCell(textCell(s.tiktokId ?? "-")),
              DataCell(textCell(s.categoryName ?? "-")),
              DataCell(textCell(s.daysInAgency.toString())),
              DataCell(textCell(s.daysValidatedLastMonth?.toString() ?? "-")),
              DataCell(currentMonthCell(s.daysValidatedThisMonth?.toString() ?? "-")),
              DataCell(textCell(s.hoursLastMonth?.toStringAsFixed(1) ?? "-")),
              DataCell(currentMonthCell(s.hoursThisMonth?.toStringAsFixed(1) ?? "-")),
              DataCell(textCell(s.battles.toString())),
              DataCell(textCell(s.diamondsLastMonth?.toStringAsFixed(0) ?? "-")),
              DataCell(
                currentMonthCell(
                  s.diamondsThisMonth?.toStringAsFixed(0) ?? s.diamonds.toStringAsFixed(0),
                ),
              ),
            ],
          );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCandidatesSection(List<StreamerSnapshot> candidates) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bucketChips(
          "Tempo de agencia",
          tenureBuckets,
          _tenureFilter,
          (v) => setState(() {
            _tenureFilter = v;
            _selectedCandidateIds.clear();
          }),
        ),
        const SizedBox(height: 10),
        _bucketChips(
          "Diamantes do mes passado",
          diamondsBuckets,
          _diamondsFilter,
          (v) => setState(() {
            _diamondsFilter = v;
            _selectedCandidateIds.clear();
          }),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 200,
              height: 36,
              child: TextField(
                controller: _minDaysController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: "Dias validos minimos (mes passado)",
                  labelStyle: TextStyle(color: Colors.white38, fontSize: 10),
                  isDense: true,
                ),
                onChanged: (_) => setState(() => _selectedCandidateIds.clear()),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 200,
              height: 36,
              child: TextField(
                controller: _minHoursController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: "Horas minimas (mes passado)",
                  labelStyle: TextStyle(color: Colors.white38, fontSize: 10),
                  isDense: true,
                ),
                onChanged: (_) => setState(() => _selectedCandidateIds.clear()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 200,
              height: 36,
              child: TextField(
                controller: _minDaysThisMonthController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: _currentMonthColor, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: "Dias validos minimos (mes atual)",
                  labelStyle: TextStyle(color: _currentMonthColor, fontSize: 10),
                  isDense: true,
                ),
                onChanged: (_) => setState(() => _selectedCandidateIds.clear()),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 200,
              height: 36,
              child: TextField(
                controller: _minHoursThisMonthController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: _currentMonthColor, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: "Horas minimas (mes atual)",
                  labelStyle: TextStyle(color: _currentMonthColor, fontSize: 10),
                  isDense: true,
                ),
                onChanged: (_) => setState(() => _selectedCandidateIds.clear()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 260,
              height: 36,
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, color: Colors.white54, size: 18),
                  hintText: "Buscar por nome",
                  hintStyle: TextStyle(color: Colors.white38),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              candidates.length.toString() +
                  " streamer(s) correspondem aos filtros selecionados",
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_selectedCandidateIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ElevatedButton.icon(
              onPressed: _openIncludeDialog,
              icon: const Icon(Icons.playlist_add, size: 16),
              label: Text(
                "Incluir participacao (" + _selectedCandidateIds.length.toString() + ")",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A0BD4),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        if (candidates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              "Nenhum streamer corresponde aos filtros selecionados.",
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          _buildCandidatesTable(candidates),
      ],
    );
  }

  Widget _goalRow(ParticipationGoal g) {
    Color color;
    String label;
    if (g.outcome == "cumpriu") {
      color = Colors.greenAccent;
      label = "Cumpriu";
    } else if (g.outcome == "nao_cumprido") {
      color = Colors.redAccent;
      label = "Nao cumpriu";
    } else if (!g.periodStarted) {
      color = Colors.white24;
      label = "Ainda nao comecou";
    } else {
      color = Colors.amber;
      label = "Pendente de confirmacao";
    }

    final parts = <String>[];
    if (g.targetDays != null)
      parts.add((g.actualDays?.toString() ?? "-") + "/" + g.targetDays.toString() + " dias");
    if (g.targetHours != null)
      parts.add(
        (g.actualHours?.toStringAsFixed(1) ?? "-") + "/" + g.targetHours!.toStringAsFixed(1) + "h",
      );
    if (g.targetDiamonds != null)
      parts.add(
        (g.actualDiamonds?.toStringAsFixed(0) ?? "-") +
            "/" +
            g.targetDiamonds!.toStringAsFixed(0) +
            " diamantes",
      );
    if (g.targetBattles != null)
      parts.add(
        (g.actualBattles?.toString() ?? "-") + "/" + g.targetBattles.toString() + " batalhas",
      );

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "Mes " + g.monthIndex.toString() + " (" + g.periodKey + ")",
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              parts.isEmpty ? "Sem meta definida" : parts.join("  -  "),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color),
            ),
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
          if (g.outcome == "pendente" && g.periodStarted) ...[
            const SizedBox(width: 4),
            IconButton(
              iconSize: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: "Cumpriu",
              icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
              onPressed: () => _confirmGoal(g, "cumpriu"),
            ),
            IconButton(
              iconSize: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: "Nao cumpriu",
              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
              onPressed: () => _confirmGoal(g, "nao_cumprido"),
            ),
          ],
          if (g.outcome != "pendente")
            IconButton(
              iconSize: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: "Reverter para pendente",
              icon: const Icon(Icons.undo, color: Colors.white38),
              onPressed: () => _revertGoal(g),
            ),
        ],
      ),
    );
  }

  Widget _participationCard(ProgramParticipation p) {
    final removed = p.status == "removido";
    final concluded = p.status == "concluido";
    final statusColor = removed
        ? Colors.white38
        : concluded
        ? Colors.greenAccent
        : Colors.blueAccent;
    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  backgroundImage: p.streamerAvatarUrl != null
                      ? NetworkImage(p.streamerAvatarUrl!)
                      : null,
                  child: p.streamerAvatarUrl == null
                      ? const Icon(Icons.person, color: Colors.white54, size: 16)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.streamerName ?? "-",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (p.categoryName != null)
                        Text(
                          p.categoryName!,
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    p.statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!removed)
                  IconButton(
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    visualDensity: VisualDensity.compact,
                    tooltip: "Remover do programa",
                    icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                    onPressed: () => _removeParticipation(p),
                  ),
              ],
            ),
            if (p.prizeDescription != null && p.prizeDescription!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.card_giftcard, size: 12, color: Colors.pinkAccent),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      p.prizeDescription!,
                      style: const TextStyle(color: Colors.pinkAccent, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
            if (p.notes != null && p.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                p.notes!,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 8),
            ...p.goals.map(_goalRow),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipationsSection(List<ProgramParticipation> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Participantes no programa (" + list.length.toString() + ")",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _showHistory
                  ? "Nenhum participante no historico ainda."
                  : "Nenhum participante incluido ainda. Use os filtros acima pra encontrar streamers e incluir no programa.",
              style: const TextStyle(color: Colors.white54),
            ),
          )
        else
          ...list.map(_participationCard),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return buildProgramasLoadError(_errorMessage!);

    final candidates = _filteredCandidates;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Participantes",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _load),
              if (_lastLoadedAt != null)
                Text(
                  relativeTimeLabel(_lastLoadedAt!),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: _toggleHistory,
                icon: Icon(
                  _showHistory ? Icons.inventory_2 : Icons.inventory_2_outlined,
                  size: 16,
                  color: Colors.white70,
                ),
                label: Text(
                  _showHistory ? "Voltar aos ativos" : "Ver historico",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            "Filtre streamers por tempo de agencia e faixa de diamantes do mes passado, selecione e inclua no programa.",
            style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_showHistory) ...[
                    _buildCandidatesSection(candidates),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),
                  ],
                  _buildParticipationsSection(_participations),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
