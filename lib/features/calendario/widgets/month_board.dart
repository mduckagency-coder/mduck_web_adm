import "package:flutter/material.dart";
import "../calendar_colors.dart";
import "../models/calendar_event.dart";
import "event_card.dart";

const _weekdayLabels = ["DOM", "SEG", "TER", "QUA", "QUI", "SEX", "SÁB"];

/// Quadro mensal customizado: cada dia mostra ate 3 barras coloridas de
/// evento (cor da categoria) + "+N mais" quando estoura, no estilo do
/// calendario de referencia (barras dentro da celula, nao so uma bolinha).
class MonthBoard extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<CalendarEvent> onEventTap;

  const MonthBoard({
    super.key,
    required this.focusedMonth,
    required this.selectedDay,
    required this.events,
    required this.onDaySelected,
    required this.onEventTap,
  });

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<CalendarEvent> _eventsForDay(DateTime day) => events.where((e) => _isSameDay(e.eventDate, day)).toList();

  void _openDayList(BuildContext context, DateTime day, List<CalendarEvent> dayEvents) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.day.toString().padLeft(2, "0") + "/" + day.month.toString().padLeft(2, "0") + "/" + day.year.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: dayEvents.isEmpty
                      ? const Center(child: Text("Nenhum evento neste dia.", style: TextStyle(color: Colors.white38)))
                      : ListView(
                          children: dayEvents
                              .map((e) => EventCard(
                                    event: e,
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      onEventTap(e);
                                    },
                                  ))
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final leadingOffset = firstOfMonth.weekday % 7;
    final gridStart = firstOfMonth.subtract(Duration(days: leadingOffset));
    final daysInMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final totalCells = leadingOffset + daysInMonth;
    final rowCount = (totalCells / 7).ceil();
    final today = DateTime.now();

    return Column(
      children: [
        Row(
          children: _weekdayLabels
              .map((w) => Expanded(child: Center(child: Text(w, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)))))
              .toList(),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Column(
            children: List.generate(rowCount, (week) {
              return Expanded(
                child: Row(
                  children: List.generate(7, (weekday) {
                    final day = gridStart.add(Duration(days: week * 7 + weekday));
                    final isCurrentMonth = day.month == focusedMonth.month;
                    final isToday = _isSameDay(day, today);
                    final isSelected = _isSameDay(day, selectedDay);
                    final dayEvents = _eventsForDay(day);
                    const maxBars = 3;
                    final overflow = dayEvents.length - maxBars;

                    return Expanded(
                      child: InkWell(
                        onTap: () {
                          onDaySelected(day);
                          if (dayEvents.isNotEmpty) _openDayList(context, day, dayEvents);
                        },
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF7A0BD4).withOpacity(0.12) : const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(8),
                            border: isToday ? Border.all(color: const Color(0xFF7A0BD4), width: 1.4) : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                day.day.toString(),
                                style: TextStyle(
                                  color: isCurrentMonth ? Colors.white70 : Colors.white24,
                                  fontSize: 11,
                                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 2),
                              ...dayEvents.take(maxBars).map((e) {
                                final color = e.category != null ? hexToColor(e.category!.color) : Colors.white38;
                                return GestureDetector(
                                  onTap: () => onEventTap(e),
                                  child: Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                                    child: Text(
                                      e.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 9.5),
                                    ),
                                  ),
                                );
                              }),
                              if (overflow > 0)
                                Text("+" + overflow.toString() + " mais", style: const TextStyle(color: Colors.white38, fontSize: 9)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
