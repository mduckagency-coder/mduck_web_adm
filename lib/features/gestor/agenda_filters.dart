import "streamer_tasks_service.dart";

/// Agrupamento por prazo da tela Agenda -- mesma ideia de bucket por data
/// que ja existe em lib/features/gestao/demand_filters.dart (Hoje/Esta
/// Semana/Atrasadas), adaptada pra tarefa por streamer (streamer_tasks) em
/// vez de demanda entre gestores (nenhuma dependencia da tabela demandas,
/// que nao tem streamer_id).
enum AgendaBucket { hoje, estaSemana, atrasados, concluidos }

const agendaBucketLabels = {
  AgendaBucket.hoje: "Hoje",
  AgendaBucket.estaSemana: "Esta Semana",
  AgendaBucket.atrasados: "Atrasados",
  AgendaBucket.concluidos: "Concluídos",
};

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

AgendaBucket bucketFor(AgendaTask agendaTask) {
  final task = agendaTask.task;
  if (task.completedAt != null) return AgendaBucket.concluidos;

  final due = task.dueAt;
  if (due == null) return AgendaBucket.estaSemana;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(due.year, due.month, due.day);

  if (dueDay.isBefore(today)) return AgendaBucket.atrasados;
  if (_isSameDay(dueDay, today)) return AgendaBucket.hoje;
  // Resto do futuro (esta semana ou mais adiante, ainda sem vencer) cai
  // todo em "Esta Semana" -- so 4 grupos, sem um 5o balde silencioso "depois".
  return AgendaBucket.estaSemana;
}

Map<AgendaBucket, List<AgendaTask>> groupAgendaTasks(List<AgendaTask> tasks) {
  final result = {for (final b in AgendaBucket.values) b: <AgendaTask>[]};
  for (final t in tasks) {
    result[bucketFor(t)]!.add(t);
  }
  return result;
}
