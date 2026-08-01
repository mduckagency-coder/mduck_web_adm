import "package:flutter/material.dart";
import "gestor_streamer_service.dart";
import "streamer_alerts.dart";

/// Card visual da visualizacao "Cards" da tela Streamers -- inspirado no
/// mesmo padrao visual do card do Onboard 15 Dias (_OnboardingCard,
/// onboarding_phase_kanban_page.dart: fundo escuro, cantos arredondados,
/// faixa lateral colorida, avatar com selo), mas essa classe e privada
/// naquele arquivo -- impossivel importar sem mexer no board de Onboarding.
/// Este widget replica o estilo com dados proprios desta fase (diamantes/
/// crescimento/potencial/etc) em vez dos campos de checklist/avaliacao.
class StreamerCard extends StatelessWidget {
  final GestorStreamerRow row;
  final List<StreamerAlert> alerts;
  final VoidCallback onTap;

  const StreamerCard({
    super.key,
    required this.row,
    required this.alerts,
    required this.onTap,
  });

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stripeColor = mostSevereAlertColor(alerts);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 220,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Tooltip(
                  message: alerts.isEmpty
                      ? "Sem alertas"
                      : alerts.map((a) => a.emoji + " " + a.label).join("\n"),
                  child: Container(width: 4, color: stripeColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          backgroundImage: row.avatarUrl != null
                              ? NetworkImage(row.avatarUrl!)
                              : null,
                          child: row.avatarUrl == null
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white54,
                                  size: 16,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "@" + row.nick,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                row.displayName,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (alerts.isNotEmpty)
                          Text(
                            alerts.first.emoji,
                            style: const TextStyle(fontSize: 13),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.diamond,
                              size: 11,
                              color: Color(0xFF7A0BD4),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              row.diamonds.toString(),
                              style: const TextStyle(
                                color: Color(0xFF7A0BD4),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        if (row.diamondsLastMonth != null)
                          Text(
                            (row.growth >= 0 ? "▲ +" : "▼ ") +
                                row.growth.toString(),
                            style: TextStyle(
                              color: row.growth >= 0
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: potentialColor(
                              row.potentialLevel,
                            ).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            potentialLabel(row.potentialLevel),
                            style: TextStyle(
                              color: potentialColor(row.potentialLevel),
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _infoLine("Dias agência", row.daysInAgency.toString()),
                    _infoLine(
                      "Últ. acomp.",
                      row.lastContactAt != null
                          ? row.lastContactAt!.toLocal().toString().substring(
                              0,
                              10,
                            )
                          : "-",
                    ),
                    _infoLine("Próx. ação", row.nextAction?.title ?? "-"),
                    _infoLine("Gestor", row.assignedManagerEmail ?? "-"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
