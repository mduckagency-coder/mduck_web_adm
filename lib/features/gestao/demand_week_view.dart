import "package:flutter/material.dart";
import "atividade_agenda_item.dart";
import "atividade_card.dart";
import "demanda_model.dart";
import "demand_card.dart";

/// Visualizacao Semana: uma coluna por dia, com as demandas e as atividades
/// de cronograma distribuidas dentro de cada coluna.
class DemandWeekView extends StatelessWidget {
  final DateTime weekStart;
  final List<Demanda> demandas;
  final List<AtividadeAgendaItem> atividades;
  final void Function(Demanda)? onTapDemand;
  final void Function(AtividadeAgendaItem)? onTapAtividade;

  const DemandWeekView({
    super.key,
    required this.weekStart,
    required this.demandas,
    this.atividades = const [],
    this.onTapDemand,
    this.onTapAtividade,
  });

  static const _weekDays = ["DOM", "SEG", "TER", "QUA", "QUI", "SEX", "SAB"];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(7, (index) {
        final date = weekStart.add(Duration(days: index));
        final isToday =
            date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
        final dayDemandas = demandas.where((d) {
          final prazo = d.prazo;
          return prazo != null &&
              prazo.year == date.year &&
              prazo.month == date.month &&
              prazo.day == date.day;
        }).toList();
        final dayAtividades = atividades.where((a) {
          return a.data.year == date.year &&
              a.data.month == date.month &&
              a.data.day == date.day;
        }).toList();

        return Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Colors.white12,
                  width: index == 6 ? 0 : 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white12)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _weekDays[index],
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: isToday
                            ? const BoxDecoration(
                                color: Color(0xFF7A0BD4),
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Text(
                          date.day.toString(),
                          style: TextStyle(
                            color: isToday ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      children: [
                        ...dayDemandas.map(
                          (d) => DemandCard(
                            demanda: d,
                            onTap: () => onTapDemand?.call(d),
                          ),
                        ),
                        ...dayAtividades.map(
                          (a) => AtividadeCard(
                            atividade: a,
                            onTap: () => onTapAtividade?.call(a),
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
    );
  }
}
