import "package:supabase_flutter/supabase_flutter.dart";

/// "Proxima acao" de verdade -- uma tarefa com data, nao so um texto
/// calculado na hora (como o Onboarding/Programas ja faziam antes). Uma
/// mesma tarefa alimenta tanto a coluna "Proxima acao" das listas
/// (Novatos/Streamers) quanto o modulo Agenda (fase futura, ainda nao
/// construida) -- um so caminho de escrita, duas formas de exibir.
class StreamerTask {
  final String id;
  final String streamerId;
  final String managerId;
  final String title;
  final String? activityType;
  final DateTime? dueAt;
  final DateTime? completedAt;

  const StreamerTask({
    required this.id,
    required this.streamerId,
    required this.managerId,
    required this.title,
    this.activityType,
    this.dueAt,
    this.completedAt,
  });

  factory StreamerTask.fromRow(Map<String, dynamic> r) => StreamerTask(
    id: r["id"] as String,
    streamerId: r["streamer_id"] as String,
    managerId: r["manager_id"] as String,
    title: r["title"] as String,
    activityType: r["activity_type"] as String?,
    dueAt: r["due_at"] != null ? DateTime.parse(r["due_at"] as String) : null,
    completedAt: r["completed_at"] != null
        ? DateTime.parse(r["completed_at"] as String)
        : null,
  );
}

/// A tarefa aberta mais proxima de cada streamer da lista (sem data vem por
/// ultimo -- "algum dia", nao "urgente"). Usado pra preencher a coluna
/// "Proxima acao" de varias linhas de uma vez, sem 1 consulta por streamer.
Future<Map<String, StreamerTask>> fetchNextActionByStreamerIds(
  List<String> streamerIds,
) async {
  if (streamerIds.isEmpty) return {};
  final client = Supabase.instance.client;
  final rows = await client
      .from("streamer_tasks")
      .select()
      .inFilter("streamer_id", streamerIds)
      .filter("completed_at", "is", null)
      .order("due_at", ascending: true, nullsFirst: false);
  final result = <String, StreamerTask>{};
  for (final r in (rows as List).cast<Map<String, dynamic>>()) {
    final task = StreamerTask.fromRow(r);
    // A consulta ja vem ordenada por due_at -- a primeira tarefa vista pra
    // cada streamer_id e a mais proxima (ou a unica sem data, por ultimo).
    result.putIfAbsent(task.streamerId, () => task);
  }
  return result;
}

Future<StreamerTask?> fetchNextActionFor(String streamerId) async {
  final map = await fetchNextActionByStreamerIds([streamerId]);
  return map[streamerId];
}

Future<void> createTask({
  required String agencyId,
  required String streamerId,
  required String managerId,
  required String title,
  String? activityType,
  DateTime? dueAt,
  required String performedBy,
}) async {
  await Supabase.instance.client.from("streamer_tasks").insert({
    "agency_id": agencyId,
    "streamer_id": streamerId,
    "manager_id": managerId,
    "title": title,
    "activity_type": activityType,
    "due_at": dueAt?.toIso8601String(),
    "created_by": performedBy,
  });
}

Future<void> completeTask(String taskId) async {
  await Supabase.instance.client
      .from("streamer_tasks")
      .update({"completed_at": DateTime.now().toIso8601String()})
      .eq("id", taskId);
}

Future<void> rescheduleTask({required String taskId, DateTime? dueAt}) async {
  await Supabase.instance.client
      .from("streamer_tasks")
      .update({"due_at": dueAt?.toIso8601String()})
      .eq("id", taskId);
}

/// Uma tarefa + os dados do streamer que a Agenda precisa mostrar direto na
/// linha (sem o gestor precisar abrir o painel lateral so pra saber quem e).
class AgendaTask {
  final StreamerTask task;
  final String streamerName;
  final String? streamerAvatarUrl;

  const AgendaTask({
    required this.task,
    required this.streamerName,
    this.streamerAvatarUrl,
  });
}

/// Todas as tarefas da agencia (abertas e concluidas recentemente) --
/// alimenta a tela Agenda, que so agrupa por prazo (Hoje/Esta Semana/
/// Atrasados/Concluidos) o que ja esta aqui, sem uma consulta por grupo.
Future<List<AgendaTask>> fetchAgendaTasks({required String agencyId}) async {
  final client = Supabase.instance.client;
  final rows = await client
      .from("streamer_tasks")
      .select("*, profiles(display_name, avatar_url)")
      .eq("agency_id", agencyId)
      .order("due_at", ascending: true, nullsFirst: false);
  return (rows as List).cast<Map<String, dynamic>>().map((r) {
    final profile = r["profiles"];
    return AgendaTask(
      task: StreamerTask.fromRow(r),
      streamerName: profile is Map
          ? (profile["display_name"] as String? ?? "-")
          : "-",
      streamerAvatarUrl: profile is Map
          ? profile["avatar_url"] as String?
          : null,
    );
  }).toList();
}
