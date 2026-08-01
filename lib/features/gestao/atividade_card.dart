import "package:flutter/material.dart";
import "atividade_agenda_item.dart";
import "demanda_model.dart";

/// Card pequeno de uma atividade do cronograma, usado dentro das celulas do
/// calendario de Demandas (Mes/Semana/Dia) ao lado dos cards de demanda --
/// mesmo estilo do DemandCard, mas identificado pelo icone de checklist e
/// colorido pela prioridade da propria atividade.
class AtividadeCard extends StatelessWidget {
  final AtividadeAgendaItem atividade;
  final VoidCallback? onTap;

  const AtividadeCard({super.key, required this.atividade, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = prioridadeColor(atividade.prioridade);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: color, width: 3)),
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
                  size: 11,
                  color: color,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    atividade.descricao,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      decoration: atividade.concluida
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              atividade.demandaTitulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
