import "package:flutter/material.dart";
import "calendar_colors.dart";
import "models/calendar_event.dart";
import "models/event_category.dart";
import "services/calendar_service.dart";
import "widgets/agenda_list.dart";
import "widgets/calendar_toolbar.dart";
import "widgets/category_manager_dialog.dart";
import "widgets/event_form_dialog.dart";
import "widgets/mini_month_calendar.dart";

/// Agenda dos Streamers: visualizacao focada em eventos de streamer, lendo da
/// mesma fonte de dados da Agenda da Agencia (CalendarService) — mostra todo
/// evento com escopo "streamer" ou que tenha pelo menos um streamer marcado
/// como participante, sempre em forma de lista colorida por categoria.
class AgendaStreamersPage extends StatefulWidget {
  const AgendaStreamersPage({super.key});

  @override
  State<AgendaStreamersPage> createState() => _AgendaStreamersPageState();
}

class _AgendaStreamersPageState extends State<AgendaStreamersPage> {
  final _service = CalendarService();

  CalendarViewMode _viewMode = CalendarViewMode.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  List<CalendarEvent> _events = [];
  List<EventCategory> _categories = [];
  List<Map<String, dynamic>> _streamerOptions = [];
  String _searchText = "";
  String _streamerSearchText = "";
  final Set<String> _selectedCategoryIds = {};
  final Set<String> _selectedStreamerIds = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _load() async {
    setState(() => _loading = true);
    await _service.seedDefaultCategories();
    final rangeStart = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
    final rangeEnd = DateTime(_focusedDay.year, _focusedDay.month + 2, 0);
    final results = await Future.wait([
      _service.fetchEvents(
        from: rangeStart,
        to: rangeEnd,
        search: _searchText,
        categoryIds: _selectedCategoryIds.isEmpty ? null : _selectedCategoryIds.toList(),
      ),
      _service.fetchCategories(onlyActive: true),
      _service.fetchStreamerOptions(),
    ]);

    var events = (results[0] as List<CalendarEvent>).where((e) => e.scope == "streamer" || e.streamerParticipants.isNotEmpty).toList();
    if (_selectedStreamerIds.isNotEmpty) {
      events = events.where((e) => e.streamerParticipants.any((p) => _selectedStreamerIds.contains(p.streamerId))).toList();
    }

    if (mounted) {
      setState(() {
        _events = events;
        _categories = results[1] as List<EventCategory>;
        _streamerOptions = results[2] as List<Map<String, dynamic>>;
        _loading = false;
      });
    }
  }

  List<CalendarEvent> get _visibleEvents {
    switch (_viewMode) {
      case CalendarViewMode.day:
        return _events.where((e) => _isSameDay(e.eventDate, _focusedDay)).toList();
      case CalendarViewMode.week:
        final weekStart = _focusedDay.subtract(Duration(days: _focusedDay.weekday % 7));
        final weekEnd = weekStart.add(const Duration(days: 6));
        return _events.where((e) => !e.eventDate.isBefore(weekStart) && !e.eventDate.isAfter(weekEnd)).toList();
      case CalendarViewMode.month:
        return _events.where((e) => e.eventDate.year == _focusedDay.year && e.eventDate.month == _focusedDay.month).toList();
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

  Future<void> _openNewEvent() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => EventFormDialog(initialDate: _selectedDay, initialScope: "streamer"),
    );
    if (saved == true) _load();
  }

  Future<void> _openEditEvent(CalendarEvent event) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => EventFormDialog(existing: event));
    if (saved == true) _load();
  }

  Future<void> _manageCategories() async {
    await showDialog(context: context, builder: (_) => const CategoryManagerDialog());
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _events.isEmpty) return const Center(child: CircularProgressIndicator());

    final streamerCategories = _categories.where((c) => c.matchesScope("streamer")).toList();

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
                    onDaySelected: (d) {
                      setState(() {
                        _selectedDay = d;
                        _focusedDay = d;
                      });
                      _load();
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search, color: Colors.white54, size: 18),
                            hintText: "Pesquisar evento",
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                            isDense: true,
                          ),
                          onChanged: (v) {
                            _searchText = v;
                            _load();
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(child: Text("Categorias", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
                            IconButton(
                              onPressed: _manageCategories,
                              icon: const Icon(Icons.settings, color: Colors.white38, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              splashRadius: 14,
                              tooltip: "Gerenciar categorias",
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...streamerCategories.map((c) {
                          final checked = _selectedCategoryIds.contains(c.id);
                          return InkWell(
                            onTap: () {
                              setState(() => checked ? _selectedCategoryIds.remove(c.id) : _selectedCategoryIds.add(c.id));
                              _load();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: checked,
                                    onChanged: (_) {
                                      setState(() => checked ? _selectedCategoryIds.remove(c.id) : _selectedCategoryIds.add(c.id));
                                      _load();
                                    },
                                    visualDensity: VisualDensity.compact,
                                    activeColor: hexToColor(c.color),
                                  ),
                                  CircleAvatar(radius: 5, backgroundColor: hexToColor(c.color)),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(c.name, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        const Text("Streamers", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search, color: Colors.white54, size: 18),
                            hintText: "Pesquisar streamer",
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() => _streamerSearchText = v),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: SingleChildScrollView(
                            child: Column(
                              children: _streamerOptions
                                  .where((s) => _streamerSearchText.trim().isEmpty || (s["display_name"] as String? ?? "").toLowerCase().contains(_streamerSearchText.trim().toLowerCase()))
                                  .map((s) {
                                final id = s["id"] as String;
                                final checked = _selectedStreamerIds.contains(id);
                                final avatarUrl = s["avatar_url"] as String?;
                                return InkWell(
                                  onTap: () {
                                    setState(() => checked ? _selectedStreamerIds.remove(id) : _selectedStreamerIds.add(id));
                                    _load();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: checked,
                                          onChanged: (_) {
                                            setState(() => checked ? _selectedStreamerIds.remove(id) : _selectedStreamerIds.add(id));
                                            _load();
                                          },
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        CircleAvatar(
                                          radius: 9,
                                          backgroundColor: Colors.white24,
                                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                          onBackgroundImageError: avatarUrl != null && avatarUrl.isNotEmpty ? (_, _) {} : null,
                                          child: avatarUrl == null || avatarUrl.isEmpty ? const Icon(Icons.person, size: 10, color: Colors.white70) : null,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(child: Text(s["display_name"] as String? ?? "", style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                    child: AgendaList(events: _visibleEvents, onEventTap: _openEditEvent),
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
