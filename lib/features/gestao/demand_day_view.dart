import "package:flutter/material.dart";
import "atividade_agenda_item.dart";
import "demanda_model.dart";

/// Item da timeline do dia: ou uma demanda (por prazo) ou uma atividade de
/// cronograma (por data/hora) -- ambos plotados juntos, ordenados por
/// horario.
class _DayTimelineItem {
  final DateTime hora;
  final Demanda? demanda;
  final AtividadeAgendaItem? atividade;

  _DayTimelineItem._(this.hora, this.demanda, this.atividade);

  factory _DayTimelineItem.fromDemanda(Demanda d) =>
      _DayTimelineItem._(d.prazo!, d, null);

  factory _DayTimelineItem.fromAtividade(AtividadeAgendaItem a) {
    final horaParts = a.hora?.split(":");
    final dt = horaParts != null
        ? DateTime(
            a.data.year,
            a.data.month,
            a.data.day,
            int.parse(horaParts[0]),
            int.parse(horaParts[1]),
          )
        : DateTime(a.data.year, a.data.month, a.data.day);
    return _DayTimelineItem._(dt, null, a);
  }
}

/// Visualizacao Dia: demandas e atividades de cronograma daquele dia em
/// formato de timeline/lista, ordenadas por horario.
class DemandDayView extends StatelessWidget {
  final DateTime day;
  final List<Demanda> demandas;
  final List<AtividadeAgendaItem> atividades;
  final void Function(Demanda)? onTapDemand;
  final void Function(AtividadeAgendaItem)? onTapAtividade;

  const DemandDayView({
    super.key,
    required this.day,
    required this.demandas,
    this.atividades = const [],
    this.onTapDemand,
    this.onTapAtividade,
  });

  @override
  Widget build(BuildContext context) {
    final dayDemandas = demandas.where((d) {
      final prazo = d.prazo;
      return prazo != null &&
          prazo.year == day.year &&
          prazo.month == day.month &&
          prazo.day == day.day;
    }).toList();
    final dayAtividades = atividades.where((a) {
      return a.data.year == day.year &&
          a.data.month == day.month &&
          a.data.day == day.day;
    }).toList();

    final items = [
      ...dayDemandas.map(_DayTimelineItem.fromDemanda),
      ...dayAtividades.map(_DayTimelineItem.fromAtividade),
    ]..sort((a, b) => a.hora.compareTo(b.hora));

    if (items.isEmpty) {
      return const Center(
        child: Text(
          "Nenhuma demanda ou atividade para este dia.",
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isLast = index == items.length - 1;
        if (item.atividade != null) {
          return _AtividadeTimelineTile(
            atividade: item.atividade!,
            hora: item.hora,
            isLast: isLast,
            onTap: () => onTapAtividade?.call(item.atividade!),
          );
        }
        final d = item.demanda!;
        final prazo = d.prazo!;
        final hora =
            prazo.hour.toString().padLeft(2, "0") +
            ":" +
            prazo.minute.toString().padLeft(2, "0");
        final color = demandaCor(d);

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
                            if (d.repeteMensalmente)
                              Icon(Icons.repeat, size: 14, color: color),
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

/// Item da timeline para uma atividade de cronograma (mesmo layout usado
/// para demandas, mas cor pela prioridade da atividade e sem horario fixo
/// quando a atividade nao tem hora definida).
class _AtividadeTimelineTile extends StatelessWidget {
  final AtividadeAgendaItem atividade;
  final DateTime hora;
  final bool isLast;
  final VoidCallback? onTap;

  const _AtividadeTimelineTile({
    required this.atividade,
    required this.hora,
    required this.isLast,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = prioridadeColor(atividade.prioridade);
    final horaLabel = atividade.hora != null
        ? hora.hour.toString().padLeft(2, "0") +
              ":" +
              hora.minute.toString().padLeft(2, "0")
        : "--:--";

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
                horaLabel,
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
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (!isLast)
                Container(width: 1, height: 40, color: Colors.white12),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onTap,
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
                          atividade.concluida
                              ? Icons.check_circle
                              : Icons.checklist,
                          size: 16,
                          color: color,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            atividade.descricao,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              decoration: atividade.concluida
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      atividade.demandaTitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
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
                          atividade.prioridade.label,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
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
  }
}
