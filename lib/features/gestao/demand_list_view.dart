import "package:flutter/material.dart";
import "demanda_model.dart";

enum DemandaOrdenacao { prazo, prioridade, criacao, atualizacao }

extension DemandaOrdenacaoX on DemandaOrdenacao {
  String get label {
    switch (this) {
      case DemandaOrdenacao.prazo:
        return "Prazo";
      case DemandaOrdenacao.prioridade:
        return "Prioridade";
      case DemandaOrdenacao.criacao:
        return "Data de criacao";
      case DemandaOrdenacao.atualizacao:
        return "Ultima atualizacao";
    }
  }
}

int _prioridadeRank(DemandaPrioridade p) {
  switch (p) {
    case DemandaPrioridade.alta:
      return 0;
    case DemandaPrioridade.media:
      return 1;
    case DemandaPrioridade.baixa:
      return 2;
  }
}

Color _statusColor(DemandaStatus s) {
  switch (s) {
    case DemandaStatus.naoIniciada:
      return Colors.white38;
    case DemandaStatus.emAndamento:
      return Colors.amber;
    case DemandaStatus.concluida:
      return const Color(0xFF3DD68C);
  }
}

String _formatPrazo(DateTime? prazo) {
  if (prazo == null) return "Sem prazo";
  return prazo.day.toString().padLeft(2, "0") +
      "/" +
      prazo.month.toString().padLeft(2, "0") +
      "/" +
      prazo.year.toString();
}

/// Visualizacao Lista: todas as demandas em formato de tabela/lista, com
/// checkbox, prioridade, prazo, categoria, status e ordenacao.
class DemandListView extends StatelessWidget {
  final List<Demanda> demandas;
  final DemandaOrdenacao ordenacao;
  final ValueChanged<DemandaOrdenacao> onOrdenacaoChanged;
  final void Function(Demanda) onTapDemand;
  final void Function(Demanda, bool) onToggleConcluida;

  const DemandListView({
    super.key,
    required this.demandas,
    required this.ordenacao,
    required this.onOrdenacaoChanged,
    required this.onTapDemand,
    required this.onToggleConcluida,
  });

  List<Demanda> _sorted() {
    final list = [...demandas];
    switch (ordenacao) {
      case DemandaOrdenacao.prazo:
        list.sort((a, b) {
          if (a.prazo == null && b.prazo == null) return 0;
          if (a.prazo == null) return 1;
          if (b.prazo == null) return -1;
          return a.prazo!.compareTo(b.prazo!);
        });
        break;
      case DemandaOrdenacao.prioridade:
        list.sort(
          (a, b) => _prioridadeRank(
            a.prioridade,
          ).compareTo(_prioridadeRank(b.prioridade)),
        );
        break;
      case DemandaOrdenacao.criacao:
        list.sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
        break;
      case DemandaOrdenacao.atualizacao:
        list.sort((a, b) => b.atualizadoEm.compareTo(a.atualizadoEm));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = _sorted();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Text(
                "Ordenar por:",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(width: 10),
              DropdownButton<DemandaOrdenacao>(
                value: ordenacao,
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                underline: Container(height: 1, color: Colors.white12),
                items: DemandaOrdenacao.values
                    .map(
                      (o) => DropdownMenuItem(value: o, child: Text(o.label)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) onOrdenacaoChanged(v);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text(
                    "Nenhuma demanda encontrada.",
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final d = list[index];
                    final color = demandaCor(d);
                    final isConcluida = d.status == DemandaStatus.concluida;

                    return InkWell(
                      onTap: () => onTapDemand(d),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: isConcluida,
                              activeColor: const Color(0xFF7A0BD4),
                              onChanged: (v) =>
                                  onToggleConcluida(d, v ?? false),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        demandaIconFor(d.icone),
                                        size: 13,
                                        color: color,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          d.titulo,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            decoration: isConcluida
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    d.descricao,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 90,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      demandaCorLabel(d),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                _formatPrazo(d.prazo),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 110,
                              child: Text(
                                d.categoria,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 110,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(
                                      d.status,
                                    ).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    d.status.label,
                                    style: TextStyle(
                                      color: _statusColor(d.status),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
