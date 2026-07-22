import "package:flutter/material.dart";
import "../../metricas/streamer_detail_panel.dart";
import "../../profile/unified_profile_page.dart";
import "../models/event_participant.dart";

/// Avatar clicavel de um participante do evento: abre o perfil do streamer
/// (StreamerDetailPanel) ou do gestor (UnifiedProfilePage), reaproveitando as
/// telas de perfil que ja existem no resto do sistema.
class ParticipantAvatar extends StatelessWidget {
  final EventParticipant participant;
  final double radius;

  const ParticipantAvatar({super.key, required this.participant, this.radius = 11});

  void _open(BuildContext context) {
    if (participant.isStreamer && participant.streamerId != null) {
      showDialog(context: context, builder: (_) => StreamerDetailPanel(item: {"id": participant.streamerId}));
    } else if (participant.isGestor && participant.managerId != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => UnifiedProfilePage(managerId: participant.managerId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = participant.isStreamer ? participant.streamerAvatarUrl : participant.managerPhotoUrl;
    final fallbackIcon = Icon(participant.isStreamer ? Icons.person : Icons.badge, size: radius, color: Colors.white);
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(color: Color(0xFF7A0BD4), shape: BoxShape.circle),
        clipBehavior: Clip.antiAlias,
        child: photoUrl == null || photoUrl.isEmpty
            ? Center(child: fallbackIcon)
            : Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(child: fallbackIcon),
                loadingBuilder: (context, child, progress) => progress == null ? child : Center(child: fallbackIcon),
              ),
      ),
    );
  }
}
