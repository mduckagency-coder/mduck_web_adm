import "package:flutter/material.dart";

/// batalha_oficial | evento
enum CalendarRequestType { batalhaOficial, evento }

CalendarRequestType calendarRequestTypeFromDb(String value) {
  return value == "evento" ? CalendarRequestType.evento : CalendarRequestType.batalhaOficial;
}

String calendarRequestTypeToDb(CalendarRequestType type) {
  return type == CalendarRequestType.evento ? "evento" : "batalha_oficial";
}

String calendarRequestTypeLabel(CalendarRequestType type) {
  return type == CalendarRequestType.evento ? "Evento" : "Batalha Oficial";
}

/// aguardando_analise | buscando_oponente | oponente_confirmado | aprovada |
/// rejeitada | cancelada | concluida -- buscando_oponente/oponente_confirmado
/// e concluida sao exclusivos do fluxo estendido de batalha_oficial; evento
/// vai direto de aguardando_analise pra aprovada.
enum CalendarRequestStatus { aguardandoAnalise, buscandoOponente, oponenteConfirmado, aprovada, rejeitada, cancelada, concluida }

CalendarRequestStatus calendarRequestStatusFromDb(String value) {
  switch (value) {
    case "buscando_oponente":
      return CalendarRequestStatus.buscandoOponente;
    case "oponente_confirmado":
      return CalendarRequestStatus.oponenteConfirmado;
    case "aprovada":
      return CalendarRequestStatus.aprovada;
    case "rejeitada":
      return CalendarRequestStatus.rejeitada;
    case "cancelada":
      return CalendarRequestStatus.cancelada;
    case "concluida":
      return CalendarRequestStatus.concluida;
    case "aguardando_analise":
    default:
      return CalendarRequestStatus.aguardandoAnalise;
  }
}

String calendarRequestStatusToDb(CalendarRequestStatus status) {
  switch (status) {
    case CalendarRequestStatus.buscandoOponente:
      return "buscando_oponente";
    case CalendarRequestStatus.oponenteConfirmado:
      return "oponente_confirmado";
    case CalendarRequestStatus.aprovada:
      return "aprovada";
    case CalendarRequestStatus.rejeitada:
      return "rejeitada";
    case CalendarRequestStatus.cancelada:
      return "cancelada";
    case CalendarRequestStatus.concluida:
      return "concluida";
    case CalendarRequestStatus.aguardandoAnalise:
      return "aguardando_analise";
  }
}

String calendarRequestStatusLabel(CalendarRequestStatus status) {
  switch (status) {
    case CalendarRequestStatus.buscandoOponente:
      return "Buscando oponente";
    case CalendarRequestStatus.oponenteConfirmado:
      return "Oponente confirmado";
    case CalendarRequestStatus.aprovada:
      return "Aprovada";
    case CalendarRequestStatus.rejeitada:
      return "Rejeitada";
    case CalendarRequestStatus.cancelada:
      return "Cancelada";
    case CalendarRequestStatus.concluida:
      return "Concluída";
    case CalendarRequestStatus.aguardandoAnalise:
      return "Aguardando análise";
  }
}

Color calendarRequestStatusColor(CalendarRequestStatus status) {
  switch (status) {
    case CalendarRequestStatus.buscandoOponente:
      return const Color(0xFF2E86DE);
    case CalendarRequestStatus.oponenteConfirmado:
      return const Color(0xFF16A085);
    case CalendarRequestStatus.aprovada:
      return const Color(0xFF27AE60);
    case CalendarRequestStatus.rejeitada:
      return const Color(0xFFE74C3C);
    case CalendarRequestStatus.cancelada:
      return Colors.white38;
    case CalendarRequestStatus.concluida:
      return const Color(0xFF7A0BD4);
    case CalendarRequestStatus.aguardandoAnalise:
      return const Color(0xFFF39C12);
  }
}

/// agencia | externo | tanto_faz -- somente para batalha_oficial
enum BattleOpponentType { agencia, externo, tantoFaz }

BattleOpponentType? battleOpponentTypeFromDb(String? value) {
  switch (value) {
    case "agencia":
      return BattleOpponentType.agencia;
    case "externo":
      return BattleOpponentType.externo;
    case "tanto_faz":
      return BattleOpponentType.tantoFaz;
    default:
      return null;
  }
}

String battleOpponentTypeToDb(BattleOpponentType type) {
  switch (type) {
    case BattleOpponentType.agencia:
      return "agencia";
    case BattleOpponentType.externo:
      return "externo";
    case BattleOpponentType.tantoFaz:
      return "tanto_faz";
  }
}

String battleOpponentTypeLabel(BattleOpponentType type) {
  switch (type) {
    case BattleOpponentType.agencia:
      return "Oponente da agência";
    case BattleOpponentType.externo:
      return "Oponente externo";
    case BattleOpponentType.tantoFaz:
      return "Tanto faz";
  }
}

class CalendarRequest {
  final String id;
  final CalendarRequestType requestType;
  final String? title;
  final String? description;
  final String? streamerId;
  final String? streamerName;
  final String? streamerTiktokUsername;
  final String? streamerAvatarUrl;
  final DateTime? proposedDate;
  final TimeOfDay? proposedStartTime;
  final TimeOfDay? proposedEndTime;
  final int? battleRounds;
  final int? battleDiamondsEstimate;
  final BattleOpponentType? battleOpponentType;
  final bool needsBanner;
  final CalendarRequestStatus status;
  final String? reviewNotes;
  final String? approvalMessage;
  final String? battleOpponentName;
  final String? battleScore;
  final String? reviewedByManagerName;
  final DateTime? reviewedAt;
  final String? createdEventId;
  final DateTime createdAt;

  const CalendarRequest({
    required this.id,
    required this.requestType,
    this.title,
    this.description,
    this.streamerId,
    this.streamerName,
    this.streamerTiktokUsername,
    this.streamerAvatarUrl,
    this.proposedDate,
    this.proposedStartTime,
    this.proposedEndTime,
    this.battleRounds,
    this.battleDiamondsEstimate,
    this.battleOpponentType,
    this.needsBanner = false,
    required this.status,
    this.reviewNotes,
    this.approvalMessage,
    this.battleOpponentName,
    this.battleScore,
    this.reviewedByManagerName,
    this.reviewedAt,
    this.createdEventId,
    required this.createdAt,
  });

  /// Titulo pronto para exibicao (batalha oficial nao exige titulo digitado).
  String get displayTitle {
    if (title != null && title!.trim().isNotEmpty) return title!;
    if (requestType == CalendarRequestType.batalhaOficial) return "Batalha Oficial";
    return "Evento";
  }

  static TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(":");
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  factory CalendarRequest.fromMap(Map<String, dynamic> map) {
    final streamer = map["requested_by_streamer"] as Map<String, dynamic>?;
    final reviewer = map["reviewed_by_manager"] as Map<String, dynamic>?;
    return CalendarRequest(
      id: map["id"] as String,
      requestType: calendarRequestTypeFromDb(map["request_type"] as String),
      title: map["title"] as String?,
      description: map["description"] as String?,
      streamerId: map["requested_by_streamer_id"] as String?,
      streamerName: streamer?["display_name"] as String?,
      streamerTiktokUsername: streamer?["tiktok_username"] as String?,
      streamerAvatarUrl: streamer?["avatar_url"] as String?,
      proposedDate: map["proposed_date"] != null ? DateTime.parse(map["proposed_date"] as String) : null,
      proposedStartTime: _parseTime(map["proposed_start_time"] as String?),
      proposedEndTime: _parseTime(map["proposed_end_time"] as String?),
      battleRounds: map["battle_rounds"] as int?,
      battleDiamondsEstimate: map["battle_diamonds_estimate"] as int?,
      battleOpponentType: battleOpponentTypeFromDb(map["battle_opponent_type"] as String?),
      needsBanner: map["needs_banner"] as bool? ?? false,
      status: calendarRequestStatusFromDb(map["status"] as String? ?? "aguardando_analise"),
      reviewNotes: map["review_notes"] as String?,
      approvalMessage: map["approval_message"] as String?,
      battleOpponentName: map["battle_opponent_name"] as String?,
      battleScore: map["battle_score"] as String?,
      reviewedByManagerName: (reviewer?["full_name"] as String?) ?? (reviewer?["login_email"] as String?),
      reviewedAt: map["reviewed_at"] != null ? DateTime.parse(map["reviewed_at"] as String) : null,
      createdEventId: map["created_event_id"] as String?,
      createdAt: DateTime.parse(map["created_at"] as String),
    );
  }
}

class CalendarRequestHistoryEntry {
  final String id;
  final CalendarRequestStatus status;
  final String? note;
  final String? changedByManagerName;
  final DateTime changedAt;

  const CalendarRequestHistoryEntry({
    required this.id,
    required this.status,
    this.note,
    this.changedByManagerName,
    required this.changedAt,
  });

  factory CalendarRequestHistoryEntry.fromMap(Map<String, dynamic> map) {
    final manager = map["changed_by_manager"] as Map<String, dynamic>?;
    return CalendarRequestHistoryEntry(
      id: map["id"] as String,
      status: calendarRequestStatusFromDb(map["status"] as String),
      note: map["note"] as String?,
      changedByManagerName: (manager?["full_name"] as String?) ?? (manager?["login_email"] as String?),
      changedAt: DateTime.parse(map["changed_at"] as String),
    );
  }
}
