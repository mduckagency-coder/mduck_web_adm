import "package:supabase_flutter/supabase_flutter.dart";
import "../calendar_colors.dart";
import "../models/calendar_event.dart";
import "../models/calendar_request.dart";
import "../models/event_category.dart";
import "../models/event_participant.dart";

const _requestSelect =
    "*, requested_by_streamer:profiles!requested_by_streamer_id(id, display_name, tiktok_username, avatar_url), reviewed_by_manager:managers!reviewed_by(id, full_name, login_email)";

const _eventSelect =
    "*, event_categories(*), calendar_event_participants(*, streamer:profiles(id, display_name, tiktok_username, tiktok_creator_id, avatar_url), manager:managers(id, full_name, login_email, photo_url))";

/// Camada unica de acesso aos dados do modulo Calendario.
/// As paginas Agenda da Agencia, Agenda dos Streamers e Solicitacoes devem
/// sempre passar por aqui, para garantir uma unica fonte de eventos.
class CalendarService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> currentAgencyId() async {
    final userId = _client.auth.currentUser!.id;
    final manager = await _client.from("managers").select("agency_id").eq("id", userId).single();
    return manager["agency_id"] as String;
  }

  Future<String> currentManagerLabel() async {
    final userId = _client.auth.currentUser!.id;
    final manager = await _client.from("managers").select("full_name, login_email").eq("id", userId).maybeSingle();
    return (manager?["full_name"] as String?) ?? (manager?["login_email"] as String?) ?? "Um colaborador";
  }

  Future<Map<String, dynamic>> currentManagerInfo() async {
    final userId = _client.auth.currentUser!.id;
    return await _client.from("managers").select("id, full_name, login_email, photo_url").eq("id", userId).single();
  }

  Future<String> currentManagerId() async => _client.auth.currentUser!.id;

  Future<List<EventCategory>> fetchCategories({bool onlyActive = false}) async {
    final agencyId = await currentAgencyId();
    dynamic query = _client.from("event_categories").select().eq("agency_id", agencyId);
    if (onlyActive) query = query.eq("is_active", true);
    final rows = await query.order("order_index");
    return (rows as List).map((r) => EventCategory.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Insere as categorias padrao que ainda nao existem para a agencia
  /// (upsert por key). Nunca apaga categorias existentes, para nao deixar
  /// eventos ja criados sem categoria.
  Future<void> seedDefaultCategories() async {
    final agencyId = await currentAgencyId();
    final existing = await _client.from("event_categories").select("key").eq("agency_id", agencyId);
    final existingKeys = (existing as List).map((r) => r["key"] as String).toSet();

    final missing = defaultEventCategories.where((c) => !existingKeys.contains(c.$1)).toList();
    if (missing.isEmpty) return;

    final baseIndex = existingKeys.length;
    final rows = missing
        .asMap()
        .entries
        .map((entry) => {
              "agency_id": agencyId,
              "key": entry.value.$1,
              "name": entry.value.$2,
              "color": entry.value.$3,
              "scope": entry.value.$4,
              "order_index": baseIndex + entry.key,
              "is_active": true,
            })
        .toList();
    await _client.from("event_categories").insert(rows);
  }

  Future<void> saveCategory({
    String? id,
    required String name,
    required String color,
    String scope = "ambos",
    int orderIndex = 999,
    bool isActive = true,
  }) async {
    if (id != null) {
      await _client.from("event_categories").update({"name": name, "color": color, "scope": scope, "order_index": orderIndex, "is_active": isActive}).eq("id", id);
      return;
    }
    final agencyId = await currentAgencyId();
    final key = name.trim().toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "_");
    await _client.from("event_categories").insert({
      "agency_id": agencyId,
      "key": key,
      "name": name,
      "color": color,
      "scope": scope,
      "order_index": orderIndex,
      "is_active": isActive,
    });
  }

  Future<void> deleteCategory(String id) async {
    await _client.from("event_categories").delete().eq("id", id);
  }

  Future<List<CalendarEvent>> fetchEvents({
    DateTime? from,
    DateTime? to,
    List<String>? categoryIds,
    List<String>? statuses,
    String? scope,
    String? search,
    String? streamerId,
    String? managerId,
    bool? mustShowInAgency,
    bool? mustShowInApp,
  }) async {
    final agencyId = await currentAgencyId();
    dynamic query = _client.from("calendar_events").select(_eventSelect).eq("agency_id", agencyId);

    if (from != null) query = query.gte("event_date", _dateOnly(from));
    if (to != null) query = query.lte("event_date", _dateOnly(to));
    if (categoryIds != null && categoryIds.isNotEmpty) query = query.inFilter("category_id", categoryIds);
    if (statuses != null && statuses.isNotEmpty) query = query.inFilter("status", statuses);
    if (scope != null) query = query.eq("scope", scope);
    if (mustShowInAgency == true) query = query.eq("show_in_agency_calendar", true);
    if (mustShowInApp == true) query = query.eq("show_in_app", true);
    if (search != null && search.trim().isNotEmpty) query = query.ilike("title", "%" + search.trim() + "%");

    final rows = await query.order("event_date").order("start_time");
    var events = (rows as List).map((r) => CalendarEvent.fromMap(r as Map<String, dynamic>)).toList();

    if (streamerId != null) {
      events = events.where((e) => e.streamerParticipants.any((p) => p.streamerId == streamerId)).toList();
    }
    if (managerId != null) {
      events = events.where((e) => e.gestorParticipants.any((p) => p.managerId == managerId)).toList();
    }
    return events;
  }

  Future<String> createEvent({
    required String categoryId,
    required String title,
    String? description,
    required DateTime eventDate,
    String? startTime,
    String? endTime,
    required bool allDay,
    String? location,
    String? meetingLink,
    String? notes,
    required String priority,
    required String status,
    required String scope,
    required String visibility,
    required List<EventParticipant> participants,
    bool showInAgencyCalendar = true,
    bool showInApp = false,
    String? colorOverride,
  }) async {
    final agencyId = await currentAgencyId();
    final userId = _client.auth.currentUser!.id;
    final inserted = await _client
        .from("calendar_events")
        .insert({
          "agency_id": agencyId,
          "category_id": categoryId,
          "title": title,
          "description": description,
          "event_date": _dateOnly(eventDate),
          "start_time": startTime,
          "end_time": endTime,
          "all_day": allDay,
          "location": location,
          "meeting_link": meetingLink,
          "notes": notes,
          "priority": priority,
          "status": status,
          "scope": scope,
          "visibility": visibility,
          "created_by": userId,
          "show_in_agency_calendar": showInAgencyCalendar,
          "show_in_app": showInApp,
          "color_override": colorOverride,
        })
        .select("id")
        .single();
    final eventId = inserted["id"] as String;
    await setParticipants(eventId, participants);
    return eventId;
  }

  Future<void> updateEvent({
    required String id,
    required String categoryId,
    required String title,
    String? description,
    required DateTime eventDate,
    String? startTime,
    String? endTime,
    required bool allDay,
    String? location,
    String? meetingLink,
    String? notes,
    required String priority,
    required String status,
    required String scope,
    required String visibility,
    required List<EventParticipant> participants,
    bool showInAgencyCalendar = true,
    bool showInApp = false,
    String? colorOverride,
  }) async {
    await _client.from("calendar_events").update({
      "category_id": categoryId,
      "title": title,
      "description": description,
      "event_date": _dateOnly(eventDate),
      "start_time": startTime,
      "end_time": endTime,
      "all_day": allDay,
      "location": location,
      "meeting_link": meetingLink,
      "notes": notes,
      "priority": priority,
      "status": status,
      "scope": scope,
      "visibility": visibility,
      "updated_at": DateTime.now().toIso8601String(),
      "show_in_agency_calendar": showInAgencyCalendar,
      "show_in_app": showInApp,
      "color_override": colorOverride,
    }).eq("id", id);
    await setParticipants(id, participants);
  }

  Future<void> deleteEvent(String id) async {
    await _client.from("calendar_events").delete().eq("id", id);
  }

  Future<void> setParticipants(String eventId, List<EventParticipant> participants) async {
    await _client.from("calendar_event_participants").delete().eq("event_id", eventId);
    if (participants.isEmpty) return;
    final rows = participants
        .map((p) => {
              "event_id": eventId,
              "participant_type": p.participantType,
              "streamer_id": p.streamerId,
              "manager_id": p.managerId,
              "role_label": p.roleLabel,
            })
        .toList();
    await _client.from("calendar_event_participants").insert(rows);
  }

  /// Alerta generico pra um ou mais streamers, usado por exemplo quando um
  /// gestor agenda um "Acompanhamento Streamer" no calendario.
  Future<void> notifyStreamersNewEvent({
    required List<String> streamerIds,
    required String type,
    required String subject,
    required String message,
  }) async {
    if (streamerIds.isEmpty) return;
    final agencyId = await currentAgencyId();
    final userId = _client.auth.currentUser!.id;
    final rows = streamerIds
        .map((id) => {
              "agency_id": agencyId,
              "streamer_id": id,
              "type": type,
              "subject": subject,
              "message": message,
              "created_by": userId,
            })
        .toList();
    await _client.from("streamer_notifications").insert(rows);
  }

  Future<List<Map<String, dynamic>>> fetchStreamerOptions({String? search}) async {
    dynamic query = _client.from("profiles").select("id, display_name, tiktok_username, tiktok_creator_id, avatar_url").eq("is_active", true);
    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike("display_name", "%" + search.trim() + "%");
    }
    final rows = await query.order("display_name").limit(500);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchManagerOptions({String? search}) async {
    dynamic query = _client.from("managers").select("id, full_name, login_email, photo_url");
    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim();
      query = query.or("full_name.ilike.%" + term + "%,login_email.ilike.%" + term + "%");
    }
    final rows = await query.order("login_email").limit(200);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<int> countPendingRequests() async {
    final agencyId = await currentAgencyId();
    final rows = await _client.from("calendar_requests").select("id").eq("agency_id", agencyId).eq("status", "aguardando_analise");
    return (rows as List).length;
  }

  Future<List<CalendarRequest>> fetchRequests({List<String>? statuses}) async {
    final agencyId = await currentAgencyId();
    dynamic query = _client.from("calendar_requests").select(_requestSelect).eq("agency_id", agencyId);
    if (statuses != null && statuses.isNotEmpty) query = query.inFilter("status", statuses);
    final rows = await query.order("created_at", ascending: false);
    return (rows as List).map((r) => CalendarRequest.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Aprova uma solicitacao de evento (fluxo direto -- batalha_oficial usa
  /// startBattleOpponentSearch/confirmBattleOpponent), cria o evento
  /// correspondente no calendario e avisa o streamer.
  Future<void> approveRequest({
    required CalendarRequest request,
    required String categoryId,
    required DateTime eventDate,
    String? startTime,
    String? endTime,
    String? approvalMessage,
  }) async {
    final eventId = await createEvent(
      categoryId: categoryId,
      title: request.displayTitle,
      description: request.description,
      eventDate: eventDate,
      startTime: startTime,
      endTime: endTime,
      allDay: false,
      priority: "normal",
      status: "confirmado",
      scope: "streamer",
      visibility: "selecionados",
      showInApp: true,
      participants: request.streamerId == null
          ? const []
          : [
              EventParticipant(
                participantType: "streamer",
                streamerId: request.streamerId!,
                streamerName: request.streamerName,
                streamerTiktokUsername: request.streamerTiktokUsername,
                streamerAvatarUrl: request.streamerAvatarUrl,
                roleLabel: calendarRequestTypeLabel(request.requestType),
              ),
            ],
    );

    final userId = _client.auth.currentUser!.id;
    await _client.from("calendar_requests").update({
      "status": "aprovada",
      "approval_message": approvalMessage,
      "reviewed_by": userId,
      "reviewed_at": DateTime.now().toIso8601String(),
      "created_event_id": eventId,
    }).eq("id", request.id);
    await _logRequestHistory(request.id, "aprovada", approvalMessage);

    if (request.streamerId != null) {
      final agencyId = await currentAgencyId();
      var message = "Sua solicitação de " + calendarRequestTypeLabel(request.requestType).toLowerCase() + " foi aprovada para " + _dateOnly(eventDate) + ".";
      if (approvalMessage != null && approvalMessage.trim().isNotEmpty) message = message + " " + approvalMessage.trim();
      await _client.from("streamer_notifications").insert({
        "agency_id": agencyId,
        "streamer_id": request.streamerId,
        "type": "solicitacao_aprovada",
        "subject": "Solicitação aprovada",
        "message": message,
        "related_request_id": request.id,
        "created_by": userId,
      });
    }
  }

  /// Rejeita a solicitacao com um motivo obrigatorio e avisa o streamer.
  Future<void> rejectRequest({required CalendarRequest request, required String reason}) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from("calendar_requests").update({
      "status": "rejeitada",
      "review_notes": reason,
      "reviewed_by": userId,
      "reviewed_at": DateTime.now().toIso8601String(),
    }).eq("id", request.id);
    await _logRequestHistory(request.id, "rejeitada", reason);

    if (request.streamerId != null) {
      final agencyId = await currentAgencyId();
      await _client.from("streamer_notifications").insert({
        "agency_id": agencyId,
        "streamer_id": request.streamerId,
        "type": "solicitacao_rejeitada",
        "subject": "Solicitação recusada",
        "message": "Sua solicitação de " + calendarRequestTypeLabel(request.requestType).toLowerCase() + " foi recusada. Motivo: " + reason,
        "related_request_id": request.id,
        "created_by": userId,
      });
    }
  }

  /// Passo 1 do fluxo de Batalha Oficial: aprova e avisa o streamer que a
  /// agencia comecou a procurar um oponente (ainda sem data/hora final).
  Future<void> startBattleOpponentSearch({required CalendarRequest request, String? approvalMessage}) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from("calendar_requests").update({
      "status": "buscando_oponente",
      "approval_message": approvalMessage,
      "reviewed_by": userId,
      "reviewed_at": DateTime.now().toIso8601String(),
    }).eq("id", request.id);
    await _logRequestHistory(request.id, "buscando_oponente", approvalMessage);

    if (request.streamerId != null) {
      var message = "Sua solicitação de batalha oficial foi aprovada! Já estamos procurando um oponente pra você.";
      if (approvalMessage != null && approvalMessage.trim().isNotEmpty) message = message + " " + approvalMessage.trim();
      await notifyStreamersNewEvent(streamerIds: [request.streamerId!], type: "solicitacao_aprovada", subject: "Buscando oponente", message: message);
    }
  }

  /// Passo 2: oponente encontrado -- confirma nome do oponente, categoria e
  /// data/hora, cria o evento no calendario e avisa o streamer.
  Future<void> confirmBattleOpponent({
    required CalendarRequest request,
    required String opponentName,
    required String categoryId,
    required DateTime eventDate,
    String? startTime,
    String? endTime,
  }) async {
    final eventId = await createEvent(
      categoryId: categoryId,
      title: "Batalha Oficial vs " + opponentName,
      description: request.description,
      eventDate: eventDate,
      startTime: startTime,
      endTime: endTime,
      allDay: false,
      priority: "normal",
      status: "confirmado",
      scope: "streamer",
      visibility: "selecionados",
      showInApp: true,
      participants: request.streamerId == null
          ? const []
          : [
              EventParticipant(
                participantType: "streamer",
                streamerId: request.streamerId!,
                streamerName: request.streamerName,
                streamerTiktokUsername: request.streamerTiktokUsername,
                streamerAvatarUrl: request.streamerAvatarUrl,
                roleLabel: "Batalha Oficial",
              ),
            ],
    );

    await _client.from("calendar_requests").update({
      "status": "oponente_confirmado",
      "battle_opponent_name": opponentName,
      "created_event_id": eventId,
    }).eq("id", request.id);
    await _logRequestHistory(request.id, "oponente_confirmado", "Oponente: " + opponentName);

    if (request.streamerId != null) {
      final timeLabel = startTime != null ? " às " + startTime.substring(0, 5) : "";
      await notifyStreamersNewEvent(
        streamerIds: [request.streamerId!],
        type: "solicitacao_aprovada",
        subject: "Oponente confirmado!",
        message: "Encontramos seu oponente: " + opponentName + ". Batalha marcada para " + _dateOnly(eventDate) + timeLabel + ".",
      );
    }
  }

  /// Mensagem avulsa de preparo, sem mudar o status (pode ser enviada em
  /// qualquer etapa do fluxo de batalha).
  Future<void> sendBattlePrepMessage({required CalendarRequest request, required String message}) async {
    if (request.streamerId != null) {
      await notifyStreamersNewEvent(streamerIds: [request.streamerId!], type: "geral", subject: "Prepare-se para a batalha!", message: message);
    }
    await _logRequestHistory(request.id, calendarRequestStatusToDb(request.status), "Mensagem de preparo: " + message);
  }

  /// Passo final: marca a batalha como concluida, com pontuacao opcional.
  Future<void> completeBattle({required CalendarRequest request, String? score}) async {
    await _client.from("calendar_requests").update({
      "status": "concluida",
      "battle_score": score,
    }).eq("id", request.id);
    await _logRequestHistory(request.id, "concluida", score != null && score.trim().isNotEmpty ? "Pontuação: " + score.trim() : null);

    if (request.streamerId != null) {
      await notifyStreamersNewEvent(
        streamerIds: [request.streamerId!],
        type: "geral",
        subject: "Batalha concluída",
        message: "Sua batalha oficial foi marcada como concluída. Bom trabalho!",
      );
    }
  }

  Future<void> deleteRequest(String id) async {
    await _client.from("calendar_requests").delete().eq("id", id);
  }

  Future<List<CalendarRequestHistoryEntry>> fetchRequestHistory(String requestId) async {
    final rows = await _client
        .from("calendar_request_status_history")
        .select("*, changed_by_manager:managers!changed_by(id, full_name, login_email)")
        .eq("request_id", requestId)
        .order("changed_at");
    return (rows as List).map((r) => CalendarRequestHistoryEntry.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> _logRequestHistory(String requestId, String status, String? note) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from("calendar_request_status_history").insert({
      "request_id": requestId,
      "status": status,
      "note": note,
      "changed_by": userId,
    });
  }

  /// Pede para um streamer preencher uma solicitacao (batalha ou evento),
  /// deixando um alerta no aplicativo dele.
  Future<void> sendRequestPrompt({
    required String streamerId,
    required CalendarRequestType requestType,
    required String message,
    DateTime? suggestedDateStart,
    DateTime? suggestedDateEnd,
  }) async {
    final agencyId = await currentAgencyId();
    final userId = _client.auth.currentUser!.id;
    final inserted = await _client
        .from("calendar_request_prompts")
        .insert({
          "agency_id": agencyId,
          "streamer_id": streamerId,
          "request_type": calendarRequestTypeToDb(requestType),
          "message": message,
          "suggested_date_start": suggestedDateStart != null ? _dateOnly(suggestedDateStart) : null,
          "suggested_date_end": suggestedDateEnd != null ? _dateOnly(suggestedDateEnd) : null,
          "requested_by_manager_id": userId,
        })
        .select("id")
        .single();

    await _client.from("streamer_notifications").insert({
      "agency_id": agencyId,
      "streamer_id": streamerId,
      "type": "pedido_agencia",
      "subject": "Pedido da agência: " + calendarRequestTypeLabel(requestType),
      "message": message,
      "related_prompt_id": inserted["id"],
      "created_by": userId,
    });
  }

  String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, "0");
    final m = date.month.toString().padLeft(2, "0");
    final d = date.day.toString().padLeft(2, "0");
    return y + "-" + m + "-" + d;
  }
}
