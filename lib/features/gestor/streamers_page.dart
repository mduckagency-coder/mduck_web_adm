import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../calendario/calendar_colors.dart";
import "../calendario/models/calendar_event.dart";
import "../calendario/models/event_category.dart";
import "../calendario/models/event_participant.dart";
import "../calendario/widgets/calendar_toolbar.dart";
import "../calendario/widgets/day_board.dart";
import "../calendario/widgets/mini_month_calendar.dart";
import "../calendario/widgets/month_board.dart";
import "../calendario/widgets/week_board.dart";
import "activity_types.dart";
import "diamond_tiers.dart";
import "gestor_streamer_service.dart";
import "streamer_alerts.dart";
import "streamer_card.dart";
import "streamer_list_view.dart";
import "streamer_side_panel.dart";
import "streamer_tasks_service.dart";

/// Tela unica "Streamers" -- central de trabalho do gestor, nao so uma
/// listagem: 3 formas de ver o MESMO conjunto de streamers (Lista/Cards/
/// Calendario), com os mesmos filtros de carteira/potencial/gestor
/// aplicados as 3 (o calendario ganha, alem disso, um filtro proprio de
/// tipo de atividade, que so faz sentido nele).
///
/// O calendario nao e um calendario paralelo -- e o MESMO
/// MonthBoard/WeekBoard/DayBoard/CalendarToolbar/MiniMonthCalendar do
/// modulo lib/features/calendario/ (zero alteracao la), alimentado por
/// CalendarEvent sinteticos montados a partir de streamer_tasks
/// (_taskToEvent abaixo). Clicar num evento abre o mesmo painel lateral
/// do streamer, nao o EventFormDialog de evento de agencia.
///
/// Nome do arquivo/classe deliberadamente distinto de
/// lib/features/streamers/streamers_page.dart (StreamersPage), que e uma
/// tela diferente da area Admin -- nao mexida, nao reaproveitada.
class GestorStreamersPage extends StatefulWidget {
  const GestorStreamersPage({super.key});

  @override
  State<GestorStreamersPage> createState() => _GestorStreamersPageState();
}

enum _ViewMode { lista, cards, calendario }

class _GestorStreamersPageState extends State<GestorStreamersPage> {
  late Future<void> _future;
  List<GestorStreamerRow> _all = [];
  List<AgendaTask> _agendaTasks = [];

  _ViewMode _viewMode = _ViewMode.lista;
  String _search = "";

  final Set<String> _carteiraFilter = {}; // "novatos" ou tier.key
  final Set<String> _potentialFilter = {}; // alto/medio/baixo
  String? _managerFilter;

  /// Indicadores "espertos" do dashboard (Sem acompanhamento/Sem próxima
  /// ação/Próximas graduações) -- exclusivos entre si, e independentes da
  /// carteira/potencial (nao sao faixa de diamante, sao status).
  String? _specialFilter;

  final Set<String> _activityTypeFilter =
      {}; // chaves de activityTypeFilterGroups, so calendario

  CalendarViewMode _calViewMode = CalendarViewMode.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _future = _load();
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
    final results = await Future.wait([
      fetchGestorStreamerRows(agencyId: agencyId),
      fetchAgendaTasks(agencyId: agencyId),
    ]);
    _all = results[0] as List<GestorStreamerRow>;
    _agendaTasks = results[1] as List<AgendaTask>;
  }

  void _reload() => setState(() => _future = _load());

  bool _matchesCarteira(GestorStreamerRow r) {
    if (_carteiraFilter.isEmpty) return true;
    if (_carteiraFilter.contains("novatos") && r.daysInAgency <= 90) {
      return true;
    }
    final tier = tierFor(r.diamonds);
    return tier != null && _carteiraFilter.contains(tier.key);
  }

  bool _matchesPotential(GestorStreamerRow r) {
    if (_potentialFilter.isEmpty) return true;
    return _potentialFilter.contains(r.potentialLevel);
  }

  bool _matchesManager(GestorStreamerRow r) {
    return _managerFilter == null || r.assignedManagerEmail == _managerFilter;
  }

  bool _matchesSpecial(GestorStreamerRow r) {
    switch (_specialFilter) {
      case "sem_acompanhamento":
        return r.daysSinceLastContact > semAcompanhamentoDiasLimite;
      case "sem_proxima_acao":
        return r.nextAction == null;
      case "proximas_graduacoes":
        return isNearNextTier(r.diamonds);
      default:
        return true;
    }
  }

  bool _matchesSearch(GestorStreamerRow r) {
    if (_search.isEmpty) return true;
    final q = _search.toLowerCase();
    return r.displayName.toLowerCase().contains(q) ||
        r.nick.toLowerCase().contains(q);
  }

  List<GestorStreamerRow> get _filtered {
    return _all.where((r) {
      if (!_matchesCarteira(r)) return false;
      if (!_matchesPotential(r)) return false;
      if (!_matchesManager(r)) return false;
      if (!_matchesSpecial(r)) return false;
      return true;
    }).toList();
  }

  void _toggleCarteira(String key) {
    setState(() {
      if (_carteiraFilter.contains(key)) {
        _carteiraFilter.remove(key);
      } else {
        _carteiraFilter.add(key);
      }
    });
  }

  void _togglePotential(String key) {
    setState(() {
      if (_potentialFilter.contains(key)) {
        _potentialFilter.remove(key);
      } else {
        _potentialFilter.add(key);
      }
    });
  }

  void _toggleSpecial(String key) {
    setState(() => _specialFilter = _specialFilter == key ? null : key);
  }

  // ---------------------------------------------------------------------
  // Calendario: adaptador streamer_tasks -> CalendarEvent (nenhum widget de
  // lib/features/calendario/ e alterado, so consumido).
  // ---------------------------------------------------------------------

  CalendarEvent _taskToEvent(AgendaTask t) {
    final type = activityTypeFor(t.task.activityType);
    final category = EventCategory(
      id: type.key,
      key: type.key,
      name: type.label,
      color: colorToHex(type.color),
      iconKey: null,
      orderIndex: 0,
      isActive: true,
      scope: "streamer",
    );
    return CalendarEvent(
      id: t.task.id,
      categoryId: type.key,
      category: category,
      title: t.task.title,
      eventDate: t.task.dueAt!,
      allDay: true,
      priority: "normal",
      status: t.task.completedAt != null ? "finalizado" : "agendado",
      scope: "streamer",
      participants: [
        EventParticipant(
          participantType: "streamer",
          streamerId: t.task.streamerId,
          streamerName: t.streamerName,
          streamerAvatarUrl: t.streamerAvatarUrl,
        ),
      ],
    );
  }

  List<CalendarEvent> get _calendarEvents {
    final rowById = {for (final r in _all) r.id: r};
    final selectedTypes = _activityTypeFilter.isEmpty
        ? null
        : _activityTypeFilter
              .expand((g) => activityTypeFilterGroups[g] ?? const <String>[])
              .toSet();
    return _agendaTasks
        .where((t) {
          if (t.task.dueAt == null) return false;
          final row = rowById[t.task.streamerId];
          if (row != null) {
            if (!_matchesCarteira(row)) return false;
            if (!_matchesPotential(row)) return false;
            if (!_matchesManager(row)) return false;
          }
          if (selectedTypes != null &&
              !selectedTypes.contains(t.task.activityType)) {
            return false;
          }
          return true;
        })
        .map(_taskToEvent)
        .toList();
  }

  void _onEventTap(CalendarEvent event) {
    final streamerId = event.participants.first.streamerId;
    if (streamerId != null) {
      openStreamerSidePanel(
        context,
        streamerId: streamerId,
      ).then((_) => _reload());
    }
  }

  void _onCalToday() {
    setState(() {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime.now();
    });
  }

  void _onCalPrevious() {
    setState(() {
      switch (_calViewMode) {
        case CalendarViewMode.month:
          _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
          break;
        case CalendarViewMode.week:
          _focusedDay = _focusedDay.subtract(const Duration(days: 7));
          break;
        case CalendarViewMode.day:
          _focusedDay = _focusedDay.subtract(const Duration(days: 1));
          break;
      }
    });
  }

  void _onCalNext() {
    setState(() {
      switch (_calViewMode) {
        case CalendarViewMode.month:
          _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
          break;
        case CalendarViewMode.week:
          _focusedDay = _focusedDay.add(const Duration(days: 7));
          break;
        case CalendarViewMode.day:
          _focusedDay = _focusedDay.add(const Duration(days: 1));
          break;
      }
    });
  }

  Widget _buildBoard() {
    final events = _calendarEvents;
    switch (_calViewMode) {
      case CalendarViewMode.month:
        return MonthBoard(
          focusedMonth: _focusedDay,
          selectedDay: _selectedDay,
          events: events,
          onDaySelected: (d) => setState(() => _selectedDay = d),
          onEventTap: _onEventTap,
        );
      case CalendarViewMode.week:
        return WeekBoard(
          focusedDay: _focusedDay,
          events: events,
          onEventTap: _onEventTap,
        );
      case CalendarViewMode.day:
        return DayBoard(
          focusedDay: _focusedDay,
          events: events,
          onEventTap: _onEventTap,
        );
    }
  }

  // ---------------------------------------------------------------------
  // Dashboard (KPIs) -- sempre visivel, nas 3 visualizacoes.
  // ---------------------------------------------------------------------

  Widget _dashboard() {
    final novatos = _all.where((r) => r.daysInAgency <= 90).length;
    final semAcompanhamento = _all
        .where((r) => r.daysSinceLastContact > semAcompanhamentoDiasLimite)
        .length;
    final semProximaAcao = _all.where((r) => r.nextAction == null).length;
    final proximasGraduacoes = _all
        .where((r) => isNearNextTier(r.diamonds))
        .length;
    final tierCounts = {
      for (final t in diamondTiers)
        t.key: _all.where((r) => tierFor(r.diamonds)?.key == t.key).length,
    };

    Widget kpi(
      String label,
      int value,
      Color color, {
      VoidCallback? onTap,
      bool selected = false,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(0.18)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? color : Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: color, fontSize: 11),
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              Text(
                value.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        kpi(
          "Novatos",
          novatos,
          Colors.cyanAccent,
          selected: _carteiraFilter.contains("novatos"),
          onTap: () => _toggleCarteira("novatos"),
        ),
        kpi(
          "Recuperação",
          tierCounts["recuperacao"] ?? 0,
          Colors.redAccent,
          selected: _carteiraFilter.contains("recuperacao"),
          onTap: () => _toggleCarteira("recuperacao"),
        ),
        kpi(
          "Crescimento",
          tierCounts["crescimento"] ?? 0,
          Colors.orangeAccent,
          selected: _carteiraFilter.contains("crescimento"),
          onTap: () => _toggleCarteira("crescimento"),
        ),
        kpi(
          "Desenvolvimento",
          tierCounts["desenvolvimento"] ?? 0,
          Colors.amber,
          selected: _carteiraFilter.contains("desenvolvimento"),
          onTap: () => _toggleCarteira("desenvolvimento"),
        ),
        kpi(
          "Performance",
          tierCounts["performance"] ?? 0,
          Colors.greenAccent,
          selected: _carteiraFilter.contains("performance"),
          onTap: () => _toggleCarteira("performance"),
        ),
        kpi(
          "Sem acompanhamento",
          semAcompanhamento,
          Colors.pinkAccent,
          selected: _specialFilter == "sem_acompanhamento",
          onTap: () => _toggleSpecial("sem_acompanhamento"),
        ),
        kpi(
          "Sem próxima ação",
          semProximaAcao,
          Colors.deepOrangeAccent,
          selected: _specialFilter == "sem_proxima_acao",
          onTap: () => _toggleSpecial("sem_proxima_acao"),
        ),
        kpi(
          "Próximas graduações",
          proximasGraduacoes,
          const Color(0xFF7A0BD4),
          selected: _specialFilter == "proximas_graduacoes",
          onTap: () => _toggleSpecial("proximas_graduacoes"),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Sidebar (270px, mesmo espirito do CalendarBoardPage): modo de
  // visualizacao + busca + filtros de carteira/potencial/gestor validos
  // pras 3 visualizacoes + (so no Calendario) mini-calendario e tipo de
  // atividade.
  // ---------------------------------------------------------------------

  Widget _carteiraChips() {
    Widget chip(String label, String key) {
      final selected = _carteiraFilter.contains(key);
      return FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 12,
          ),
        ),
        selected: selected,
        selectedColor: const Color(0xFF7A0BD4),
        backgroundColor: Colors.white.withOpacity(0.05),
        onSelected: (_) => _toggleCarteira(key),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        chip("Novatos", "novatos"),
        ...diamondTiers.map((t) => chip(t.label, t.key)),
      ],
    );
  }

  Widget _potentialChips() {
    Widget chip(String label, String key, Color color) {
      final selected = _potentialFilter.contains(key);
      return FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 12,
          ),
        ),
        selected: selected,
        selectedColor: color,
        backgroundColor: Colors.white.withOpacity(0.05),
        onSelected: (_) => _togglePotential(key),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        chip("Alto", "alto", Colors.greenAccent),
        chip("Médio", "medio", Colors.amber),
        chip("Baixo", "baixo", Colors.redAccent),
      ],
    );
  }

  Widget _managerDropdown() {
    final managerEmails =
        _all
            .map((r) => r.assignedManagerEmail)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
    return DropdownButton<String?>(
      value: _managerFilter,
      isExpanded: true,
      hint: const Text(
        "Todos os gestores",
        style: TextStyle(color: Colors.white38, fontSize: 12),
      ),
      dropdownColor: const Color(0xFF232323),
      style: const TextStyle(color: Colors.white, fontSize: 12),
      underline: Container(height: 1, color: Colors.white24),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text("Todos os gestores"),
        ),
        ...managerEmails.map(
          (e) => DropdownMenuItem<String?>(value: e, child: Text(e)),
        ),
      ],
      onChanged: (v) => setState(() => _managerFilter = v),
    );
  }

  Widget _activityTypeChips() {
    Widget chip(String label) {
      final selected = _activityTypeFilter.contains(label);
      return FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 12,
          ),
        ),
        selected: selected,
        selectedColor: const Color(0xFF7A0BD4),
        backgroundColor: Colors.white.withOpacity(0.05),
        onSelected: (_) => setState(() {
          if (_activityTypeFilter.contains(label)) {
            _activityTypeFilter.remove(label);
          } else {
            _activityTypeFilter.add(label);
          }
        }),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: activityTypeFilterGroups.keys.map(chip).toList(),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _sidebar() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_ViewMode>(
            segments: const [
              ButtonSegment(value: _ViewMode.lista, label: Text("Lista")),
              ButtonSegment(value: _ViewMode.cards, label: Text("Cards")),
              ButtonSegment(
                value: _ViewMode.calendario,
                label: Text("Calendário"),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (s) => setState(() => _viewMode = s.first),
          ),
          const SizedBox(height: 16),
          if (_viewMode == _ViewMode.cards) ...[
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, color: Colors.white54, size: 18),
                hintText: "Buscar por nick ou nome",
                hintStyle: TextStyle(color: Colors.white38),
              ),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
            const SizedBox(height: 16),
          ],
          if (_viewMode == _ViewMode.calendario) ...[
            MiniMonthCalendar(
              focusedMonth: DateTime(_focusedDay.year, _focusedDay.month, 1),
              selectedDay: _selectedDay,
              onMonthChanged: (m) => setState(() => _focusedDay = m),
              onDaySelected: (d) => setState(() {
                _selectedDay = d;
                _focusedDay = d;
              }),
            ),
            const SizedBox(height: 16),
          ],
          _sectionLabel("Carteira"),
          _carteiraChips(),
          const SizedBox(height: 16),
          _sectionLabel("Potencial"),
          _potentialChips(),
          const SizedBox(height: 16),
          _sectionLabel("Gestor"),
          _managerDropdown(),
          if (_viewMode == _ViewMode.calendario) ...[
            const SizedBox(height: 16),
            _sectionLabel("Tipos de atividade"),
            _activityTypeChips(),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------

  Widget _cardsView() {
    final rows = _filtered.where(_matchesSearch).toList();
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          "Nenhum streamer encontrado.",
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return SingleChildScrollView(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: rows
            .map(
              (r) => StreamerCard(
                row: r,
                alerts: computeAlerts(r, _all),
                onTap: () => openStreamerSidePanel(
                  context,
                  streamerId: r.id,
                ).then((_) => _reload()),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _calendarioView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CalendarToolbar(
          focusedDay: _focusedDay,
          viewMode: _calViewMode,
          onToday: _onCalToday,
          onPrevious: _onCalPrevious,
          onNext: _onCalNext,
          onViewModeChanged: (v) => setState(() => _calViewMode = v),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildBoard(),
          ),
        ),
      ],
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
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 270, child: _sidebar()),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "Streamers",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.white70,
                          ),
                          onPressed: _reload,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _dashboard(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: switch (_viewMode) {
                        _ViewMode.lista => StreamerListView(
                          rows: _filtered,
                          alertsFor: (r) => computeAlerts(r, _all),
                        ),
                        _ViewMode.cards => _cardsView(),
                        _ViewMode.calendario => _calendarioView(),
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
