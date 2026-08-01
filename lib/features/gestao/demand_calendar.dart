import "package:flutter/material.dart";
import "atividade_agenda_item.dart";
import "atividade_card.dart";
import "demanda_model.dart";
import "demand_card.dart";

/// Visualizacao Mes: grade de calendario ocupando a largura da tela, com as
/// demandas (por prazo) e as atividades de cronograma (por data) de cada
/// dia empilhadas dentro da celula correspondente.
class DemandCalendar extends StatelessWidget {
  final DateTime month;
  final List<Demanda> demandas;
  final List<AtividadeAgendaItem> atividades;
  final void Function(Demanda)? onTapDemand;
  final void Function(AtividadeAgendaItem)? onTapAtividade;

  const DemandCalendar({
    super.key,
    required this.month,
    required this.demandas,
    this.atividades = const [],
    this.onTapDemand,
    this.onTapAtividade,
  });

  static const _weekDays = ["DOM", "SEG", "TER", "QUA", "QUI", "SEX", "SAB"];
  static const _maxCardsPerDay = 3;

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final prevMonthLastDay = DateTime(month.year, month.month, 0).day;
    final leadingEmpty = firstDayOfMonth.weekday % 7;
    final totalCells = ((leadingEmpty + daysInMonth) / 7).ceil() * 7;
    final totalRows = totalCells ~/ 7;
    final today = DateTime.now();

    final byDay = <int, List<Demanda>>{};
    for (final d in demandas) {
      final prazo = d.prazo;
      if (prazo == null ||
          prazo.year != month.year ||
          prazo.month != month.month)
        continue;
      byDay.putIfAbsent(prazo.day, () => []).add(d);
    }

    final atividadesByDay = <int, List<AtividadeAgendaItem>>{};
    for (final a in atividades) {
      if (a.data.year != month.year || a.data.month != month.month) continue;
      atividadesByDay.putIfAbsent(a.data.day, () => []).add(a);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: _weekDays
                .map(
                  (w) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        w,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        ...List.generate(totalRows, (rowIndex) {
          return Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(7, (colIndex) {
                final cellIndex = rowIndex * 7 + colIndex;
                final dayNumber = cellIndex - leadingEmpty + 1;
                final isCurrentMonth =
                    dayNumber >= 1 && dayNumber <= daysInMonth;

                late final DateTime cellDate;
                late final int displayDay;
                if (dayNumber < 1) {
                  displayDay = prevMonthLastDay + dayNumber;
                  cellDate = DateTime(month.year, month.month - 1, displayDay);
                } else if (dayNumber > daysInMonth) {
                  displayDay = dayNumber - daysInMonth;
                  cellDate = DateTime(month.year, month.month + 1, displayDay);
                } else {
                  displayDay = dayNumber;
                  cellDate = DateTime(month.year, month.month, displayDay);
                }

                final isToday =
                    isCurrentMonth &&
                    cellDate.year == today.year &&
                    cellDate.month == today.month &&
                    cellDate.day == today.day;
                final dayDemandas = isCurrentMonth
                    ? (byDay[displayDay] ?? const <Demanda>[])
                    : const <Demanda>[];
                final dayAtividades = isCurrentMonth
                    ? (atividadesByDay[displayDay] ??
                          const <AtividadeAgendaItem>[])
                    : const <AtividadeAgendaItem>[];
                final totalItems = dayDemandas.length + dayAtividades.length;
                final shownDemandas = dayDemandas.take(_maxCardsPerDay).toList();
                final shownAtividades = dayAtividades
                    .take(_maxCardsPerDay - shownDemandas.length)
                    .toList();
                final overflowCount =
                    totalItems - shownDemandas.length - shownAtividades.length;

                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Colors.white12,
                          width: colIndex == 6 ? 0 : 1,
                        ),
                        bottom: const BorderSide(color: Colors.white12),
                      ),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: isToday
                              ? const BoxDecoration(
                                  color: Color(0xFF7A0BD4),
                                  shape: BoxShape.circle,
                                )
                              : null,
                          child: Text(
                            displayDay.toString(),
                            style: TextStyle(
                              color: isToday
                                  ? Colors.white
                                  : (isCurrentMonth
                                        ? Colors.white70
                                        : Colors.white24),
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                ...shownDemandas.map(
                                  (d) => DemandCard(
                                    demanda: d,
                                    onTap: () => onTapDemand?.call(d),
                                  ),
                                ),
                                ...shownAtividades.map(
                                  (a) => AtividadeCard(
                                    atividade: a,
                                    onTap: () => onTapAtividade?.call(a),
                                  ),
                                ),
                                if (overflowCount > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      "+" + overflowCount.toString() + " mais",
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }
}
