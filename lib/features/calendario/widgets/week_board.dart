import "package:flutter/material.dart";
import "../models/calendar_event.dart";
import "event_card.dart";

const _weekdayLabels = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"];

/// Visao semanal: 7 colunas, uma por dia, cada uma com a lista de eventos
/// daquele dia (simplificacao consciente — nao e um grid por hora).
class WeekBoard extends StatelessWidget {
  final DateTime focusedDay;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEventTap;

  const WeekBoard({super.key, required this.focusedDay, required this.events, required this.onEventTap});

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<CalendarEvent> _eventsForDay(DateTime day) => events.where((e) => _isSameDay(e.eventDate, day)).toList();

  @override
  Widget build(BuildContext context) {
    final weekStart = focusedDay.subtract(Duration(days: focusedDay.weekday % 7));
    final today = DateTime.now();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(7, (i) {
        final day = weekStart.add(Duration(days: i));
        final isToday = _isSameDay(day, today);
        final dayEvents = _eventsForDay(day);
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(10),
              border: isToday ? Border.all(color: const Color(0xFF7A0BD4), width: 1.4) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _weekdayLabels[i] + " " + day.day.toString().padLeft(2, "0") + "/" + day.month.toString().padLeft(2, "0"),
                    style: TextStyle(color: isToday ? const Color(0xFF7A0BD4) : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: dayEvents.isEmpty
                      ? const Padding(padding: EdgeInsets.all(8), child: Text("—", style: TextStyle(color: Colors.white24, fontSize: 12)))
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          children: dayEvents.map((e) => EventCard(event: e, onTap: () => onEventTap(e))).toList(),
                        ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
