import "package:flutter/material.dart";

const _weekdayLetters = ["D", "S", "T", "Q", "Q", "S", "S"];
const _monthNames = [
  "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
  "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
];

/// Calendario compacto de navegacao (sem eventos marcados), no estilo do
/// mini-calendario lateral de referencia. So navega/seleciona dia.
class MiniMonthCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  const MiniMonthCalendar({
    super.key,
    required this.focusedMonth,
    required this.selectedDay,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final leadingOffset = firstOfMonth.weekday % 7;
    final gridStart = firstOfMonth.subtract(Duration(days: leadingOffset));
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _monthNames[focusedMonth.month - 1] + " " + focusedMonth.year.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => onMonthChanged(DateTime(focusedMonth.year, focusedMonth.month - 1, 1)),
                icon: const Icon(Icons.chevron_left, color: Colors.white54, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 14,
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => onMonthChanged(DateTime(focusedMonth.year, focusedMonth.month + 1, 1)),
                icon: const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 14,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: _weekdayLetters
                .map((w) => Expanded(child: Center(child: Text(w, style: const TextStyle(color: Colors.white38, fontSize: 11)))))
                .toList(),
          ),
          const SizedBox(height: 4),
          for (int week = 0; week < 6; week++)
            Row(
              children: List.generate(7, (weekday) {
                final day = gridStart.add(Duration(days: week * 7 + weekday));
                final isCurrentMonth = day.month == focusedMonth.month;
                final isToday = _isSameDay(day, today);
                final isSelected = _isSameDay(day, selectedDay);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: InkWell(
                      onTap: () => onDaySelected(day),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        alignment: Alignment.center,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? const Color(0xFF7A0BD4) : (isToday ? const Color(0xFF7A0BD4).withOpacity(0.25) : null),
                        ),
                        child: Text(
                          day.day.toString(),
                          style: TextStyle(
                            color: isSelected || isToday ? Colors.white : (isCurrentMonth ? Colors.white70 : Colors.white24),
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}
