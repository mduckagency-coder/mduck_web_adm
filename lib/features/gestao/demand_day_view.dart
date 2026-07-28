import "package:flutter/material.dart";
import "demanda_model.dart";

/// Visualizacao Dia: demandas daquele dia em formato de timeline/lista,
/// ordenadas por horario.
class DemandDayView extends StatelessWidget {
  final DateTime day;
  final List<Demanda> demandas;
  final void Function(Demanda)? onTapDemand;

  const DemandDayView({
    super.key,
    required this.day,
    required this.demandas,
    this.onTapDemand,
  });

  @override
  Widget build(BuildContext context) {
    final dayDemandas = demandas.where((d) {
      final prazo = d.prazo;
      return prazo != null &&
          prazo.year == day.year &&
          prazo.month == day.month &&
          prazo.day == day.day;
    }).toList()..sort((a, b) => a.prazo!.compareTo(b.prazo!));

    if (dayDemandas.isEmpty) {
      return const Center(
        child: Text(
          "Nenhuma demanda para este dia.",
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: dayDemandas.length,
      itemBuilder: (context, index) {
        final d = dayDemandas[index];
        final prazo = d.prazo!;
        final hora =
            prazo.hour.toString().padLeft(2, "0") +
            ":" +
            prazo.minute.toString().padLeft(2, "0");
        final color = demandaCor(d);
        final isLast = index == dayDemandas.length - 1;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 56,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    hora,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 14),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Container(width: 1, height: 40, color: Colors.white12),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => onTapDemand?.call(d),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              demandaIconFor(d.icone),
                              size: 16,
                              color: color,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                d.titulo,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d.descricao,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              demandaCorLabel(d),
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                d.categoria,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
