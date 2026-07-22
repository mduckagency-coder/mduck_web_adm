import "package:flutter/material.dart";
import "../calendar_colors.dart";
import "../models/calendar_event.dart";
import "../models/event_participant.dart";
import "participant_avatar.dart";

class EventCard extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback? onTap;

  const EventCard({super.key, required this.event, this.onTap});

  String _timeLabel() {
    if (event.allDay) return "Dia inteiro";
    final start = event.startTime;
    if (start == null) return "";
    final startStr = start.hour.toString().padLeft(2, "0") + ":" + start.minute.toString().padLeft(2, "0");
    final end = event.endTime;
    if (end == null) return startStr;
    final endStr = end.hour.toString().padLeft(2, "0") + ":" + end.minute.toString().padLeft(2, "0");
    return startStr + " - " + endStr;
  }

  static String streamerLabel(EventParticipant p) {
    final parts = <String>[p.streamerName ?? ""];
    if (p.streamerTiktokUsername != null && p.streamerTiktokUsername!.isNotEmpty) parts.add("@" + p.streamerTiktokUsername!);
    if (p.streamerTiktokId != null && p.streamerTiktokId!.isNotEmpty) parts.add("ID " + p.streamerTiktokId!);
    return parts.join(" · ");
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = event.category != null ? hexToColor(event.category!.color) : Colors.white38;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF232323),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: categoryColor, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: categoryColor.withOpacity(0.18), borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      event.category?.name ?? "Sem categoria",
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(color: categoryColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (_timeLabel().isNotEmpty) Text(_timeLabel(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                _StatusBadge(status: event.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(event.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            if (event.streamerParticipants.isNotEmpty || event.gestorParticipants.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  ...event.streamerParticipants.map((p) => _ParticipantChip(
                        participant: p,
                        label: streamerLabel(p),
                      )),
                  ...event.gestorParticipants.map((p) => _ParticipantChip(
                        participant: p,
                        label: p.managerName ?? "Gestor",
                      )),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ParticipantChip extends StatelessWidget {
  final EventParticipant participant;
  final String label;

  const _ParticipantChip({required this.participant, required this.label});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 190),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ParticipantAvatar(participant: participant),
          const SizedBox(width: 6),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(6)),
      child: Text(statusLabel(status), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
