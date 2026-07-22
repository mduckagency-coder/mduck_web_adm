import "package:flutter/material.dart";

enum CalendarViewMode { day, week, month }

const _monthNames = [
  "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
  "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
];

class CalendarToolbar extends StatelessWidget {
  final DateTime focusedDay;
  final CalendarViewMode viewMode;
  final VoidCallback onToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<CalendarViewMode> onViewModeChanged;

  const CalendarToolbar({
    super.key,
    required this.focusedDay,
    required this.viewMode,
    required this.onToday,
    required this.onPrevious,
    required this.onNext,
    required this.onViewModeChanged,
  });

  String get _periodLabel {
    switch (viewMode) {
      case CalendarViewMode.day:
        return focusedDay.day.toString().padLeft(2, "0") + " de " + _monthNames[focusedDay.month - 1] + " de " + focusedDay.year.toString();
      case CalendarViewMode.week:
      case CalendarViewMode.month:
        return _monthNames[focusedDay.month - 1] + " de " + focusedDay.year.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton(onPressed: onToday, child: const Text("Hoje")),
        const SizedBox(width: 8),
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left, color: Colors.white70)),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right, color: Colors.white70)),
        const SizedBox(width: 8),
        Text(_periodLabel, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const Spacer(),
        SegmentedButton<CalendarViewMode>(
          segments: const [
            ButtonSegment(value: CalendarViewMode.month, label: Text("Mês")),
            ButtonSegment(value: CalendarViewMode.week, label: Text("Semana")),
            ButtonSegment(value: CalendarViewMode.day, label: Text("Dia")),
          ],
          selected: {viewMode},
          onSelectionChanged: (s) => onViewModeChanged(s.first),
        ),
      ],
    );
  }
}
