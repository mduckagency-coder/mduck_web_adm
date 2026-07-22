import "package:flutter/material.dart";
import "models/calendar_event.dart";
import "models/event_category.dart";
import "services/calendar_service.dart";
import "widgets/calendar_toolbar.dart";
import "widgets/category_manager_dialog.dart";
import "widgets/day_board.dart";
import "widgets/event_form_dialog.dart";
import "widgets/filters_panel.dart";
import "widgets/mini_month_calendar.dart";
import "widgets/month_board.dart";
import "widgets/week_board.dart";

enum CalendarBoardMode {
  /// Home Central / Agenda da Agencia: ve e filtra todos os eventos.
  home,

  /// Area do Gestor / Area do Recrutador: so ve eventos em que a pessoa
  /// logada e participante, mas pode criar (com notificacao para admins).
  mine,
}

class CalendarBoardPage extends StatefulWidget {
  final CalendarBoardMode mode;

  const CalendarBoardPage({super.key, required this.mode});

  @override
  State<CalendarBoardPage> createState() => _CalendarBoardPageState();
}

class _CalendarBoardPageState extends State<CalendarBoardPage> {
  final _service = CalendarService();

  CalendarViewMode _viewMode = CalendarViewMode.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  List<CalendarEvent> _events = [];
  List<EventCategory> _categories = [];
  String _searchText = "";
  String? _scope;
  final Set<String> _selectedCategoryIds = {};
  final Set<String> _selectedManagerIds = {};

  String? _myManagerId;
  bool _loading = true;

  bool get _isMine => widget.mode == CalendarBoardMode.mine;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myManagerId = await _service.currentManagerId();
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _service.seedDefaultCategories();
    final rangeStart = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
    final rangeEnd = DateTime(_focusedDay.year, _focusedDay.month + 2, 0);
    final results = await Future.wait([
      _service.fetchEvents(
        from: rangeStart,
        to: rangeEnd,
        scope: _scope,
        search: _searchText,
        categoryIds: _selectedCategoryIds.isEmpty ? null : _selectedCategoryIds.toList(),
        managerId: _isMine ? _myManagerId : null,
      ),
      _service.fetchCategories(onlyActive: true),
    ]);
    var events = results[0] as List<CalendarEvent>;
    if (!_isMine && _selectedManagerIds.isNotEmpty) {
      events = events.where((e) => e.gestorParticipants.any((p) => _selectedManagerIds.contains(p.managerId))).toList();
    }
    if (mounted) {
      setState(() {
        _events = events;
        _categories = results[1] as List<EventCategory>;
        _loading = false;
      });
    }
  }

  void _onToday() {
    setState(() {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime.now();
    });
    _load();
  }

  void _onPrevious() {
    setState(() {
      switch (_viewMode) {
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
    _load();
  }

  void _onNext() {
    setState(() {
      switch (_viewMode) {
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
    _load();
  }

  void _onMiniCalendarDaySelected(DateTime day) {
    setState(() {
      _selectedDay = day;
      _focusedDay = day;
    });
    _load();
  }

  Future<void> _openNewEvent() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => EventFormDialog(initialDate: _selectedDay, notifyOnCreate: _isMine),
    );
    if (saved == true) _load();
  }

  Future<void> _openEditEvent(CalendarEvent event) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => EventFormDialog(existing: event, notifyOnCreate: _isMine),
    );
    if (saved == true) _load();
  }

  Future<void> _manageCategories() async {
    await showDialog(context: context, builder: (_) => const CategoryManagerDialog());
    _load();
  }

  Widget _buildBoard() {
    switch (_viewMode) {
      case CalendarViewMode.month:
        return MonthBoard(
          focusedMonth: _focusedDay,
          selectedDay: _selectedDay,
          events: _events,
          onDaySelected: (d) => setState(() => _selectedDay = d),
          onEventTap: _openEditEvent,
        );
      case CalendarViewMode.week:
        return WeekBoard(focusedDay: _focusedDay, events: _events, onEventTap: _openEditEvent);
      case CalendarViewMode.day:
        return DayBoard(focusedDay: _focusedDay, events: _events, onEventTap: _openEditEvent);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _events.isEmpty) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 270,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _openNewEvent,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27AE60), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: const Icon(Icons.add),
                    label: const Text("Novo evento"),
                  ),
                  const SizedBox(height: 16),
                  MiniMonthCalendar(
                    focusedMonth: DateTime(_focusedDay.year, _focusedDay.month, 1),
                    selectedDay: _selectedDay,
                    onMonthChanged: (m) {
                      setState(() => _focusedDay = m);
                      _load();
                    },
                    onDaySelected: _onMiniCalendarDaySelected,
                  ),
                  const SizedBox(height: 16),
                  FiltersPanel(
                    categories: _categories,
                    searchText: _searchText,
                    onSearchChanged: (v) {
                      setState(() => _searchText = v);
                      _load();
                    },
                    scope: _scope,
                    onScopeChanged: (v) {
                      setState(() => _scope = v);
                      _load();
                    },
                    selectedManagerIds: _selectedManagerIds,
                    onManagerToggle: (id) {
                      setState(() {
                        if (_selectedManagerIds.contains(id)) {
                          _selectedManagerIds.remove(id);
                        } else {
                          _selectedManagerIds.add(id);
                        }
                      });
                      _load();
                    },
                    selectedCategoryIds: _selectedCategoryIds,
                    onCategoryToggle: (id) {
                      setState(() {
                        if (_selectedCategoryIds.contains(id)) {
                          _selectedCategoryIds.remove(id);
                        } else {
                          _selectedCategoryIds.add(id);
                        }
                      });
                      _load();
                    },
                    showManagerFilter: !_isMine,
                    onManageCategories: _manageCategories,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CalendarToolbar(
                  focusedDay: _focusedDay,
                  viewMode: _viewMode,
                  onToday: _onToday,
                  onPrevious: _onPrevious,
                  onNext: _onNext,
                  onViewModeChanged: (v) => setState(() => _viewMode = v),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(12)),
                    child: _buildBoard(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
