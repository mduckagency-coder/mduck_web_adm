import "package:flutter/material.dart";
import "../models/calendar_event.dart";
import "event_card.dart";

class DayBoard extends StatelessWidget {
  final DateTime focusedDay;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEventTap;

  const DayBoard({super.key, required this.focusedDay, required this.events, required this.onEventTap});

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final dayEvents = events.where((e) => _isSameDay(e.eventDate, focusedDay)).toList();
    if (dayEvents.isEmpty) {
      return const Center(child: Text("Nenhum evento neste dia.", style: TextStyle(color: Colors.white38)));
    }
    return ListView(
      children: dayEvents.map((e) => EventCard(event: e, onTap: () => onEventTap(e))).toList(),
    );
  }
}
