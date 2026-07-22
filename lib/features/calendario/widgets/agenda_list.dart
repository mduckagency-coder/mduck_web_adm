import "package:flutter/material.dart";
import "../models/calendar_event.dart";
import "event_card.dart";

const _weekdayNames = ["Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado", "Domingo"];
const _monthNames = [
  "janeiro", "fevereiro", "março", "abril", "maio", "junho",
  "julho", "agosto", "setembro", "outubro", "novembro", "dezembro",
];

/// Lista de eventos agrupada por dia (usada nas 3 views — dia/semana/mês —
/// da Agenda dos Streamers, sempre em forma de lista colorida por categoria).
class AgendaList extends StatelessWidget {
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEventTap;
  final String emptyMessage;

  const AgendaList({super.key, required this.events, required this.onEventTap, this.emptyMessage = "Nenhum evento neste período."});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(child: Text(emptyMessage, style: const TextStyle(color: Colors.white38)));
    }

    final sorted = List<CalendarEvent>.of(events)
      ..sort((a, b) {
        final dateCompare = a.eventDate.compareTo(b.eventDate);
        if (dateCompare != 0) return dateCompare;
        final aStart = a.startTime;
        final bStart = b.startTime;
        if (aStart == null && bStart == null) return 0;
        if (aStart == null) return 1;
        if (bStart == null) return -1;
        return (aStart.hour * 60 + aStart.minute).compareTo(bStart.hour * 60 + bStart.minute);
      });

    final groups = <DateTime, List<CalendarEvent>>{};
    for (final e in sorted) {
      final day = DateTime(e.eventDate.year, e.eventDate.month, e.eventDate.day);
      groups.putIfAbsent(day, () => []).add(e);
    }

    return ListView(
      children: groups.entries.map((entry) {
        final day = entry.key;
        final dayLabel = _weekdayNames[day.weekday - 1] + ", " + day.day.toString() + " de " + _monthNames[day.month - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dayLabel, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...entry.value.map((e) => EventCard(event: e, onTap: () => onEventTap(e))),
            ],
          ),
        );
      }).toList(),
    );
  }
}
