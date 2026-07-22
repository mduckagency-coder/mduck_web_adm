String _managerName(Map<String, dynamic> manager) {
  final fullName = manager["full_name"] as String?;
  if (fullName != null && fullName.trim().isNotEmpty) return fullName;
  return (manager["login_email"] as String?) ?? "Colaborador";
}

class EventParticipant {
  final String? id;
  final String participantType; // "streamer" ou "gestor"
  final String? streamerId;
  final String? streamerName;
  final String? streamerTiktokUsername;
  final String? streamerTiktokId;
  final String? streamerAvatarUrl;
  final String? managerId;
  final String? managerName;
  final String? managerPhotoUrl;
  final String? roleLabel;

  const EventParticipant({
    this.id,
    required this.participantType,
    this.streamerId,
    this.streamerName,
    this.streamerTiktokUsername,
    this.streamerTiktokId,
    this.streamerAvatarUrl,
    this.managerId,
    this.managerName,
    this.managerPhotoUrl,
    this.roleLabel,
  });

  bool get isStreamer => participantType == "streamer";
  bool get isGestor => participantType == "gestor";

  factory EventParticipant.fromMap(Map<String, dynamic> map) {
    final streamer = map["streamer"] as Map<String, dynamic>?;
    final manager = map["manager"] as Map<String, dynamic>?;
    return EventParticipant(
      id: map["id"] as String?,
      participantType: map["participant_type"] as String,
      streamerId: map["streamer_id"] as String?,
      streamerName: streamer?["display_name"] as String?,
      streamerTiktokUsername: streamer?["tiktok_username"] as String?,
      streamerTiktokId: streamer?["tiktok_creator_id"] as String?,
      streamerAvatarUrl: streamer?["avatar_url"] as String?,
      managerId: map["manager_id"] as String?,
      managerName: manager != null ? _managerName(manager) : null,
      managerPhotoUrl: manager?["photo_url"] as String?,
      roleLabel: map["role_label"] as String?,
    );
  }
}
