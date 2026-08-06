import "package:flutter/material.dart";
import "demanda_model.dart";

/// Card pequeno e discreto usado dentro das celulas do calendario (Mes/Semana).
class DemandCard extends StatelessWidget {
  final Demanda demanda;
  final VoidCallback? onTap;

  const DemandCard({super.key, required this.demanda, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = demandaCor(demanda);
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
                Icon(demandaIconFor(demanda.icone), size: 11, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    demanda.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (demanda.repeteMensalmente)
                  Icon(Icons.repeat, size: 11, color: color),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
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
                  demandaCorLabel(demanda),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
