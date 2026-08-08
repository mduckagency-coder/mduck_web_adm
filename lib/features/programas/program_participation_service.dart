import "package:supabase_flutter/supabase_flutter.dart";
import "program_eligibility_service.dart";

/// Faixas de tempo de agencia (dias desde joined_at) -- filtro de selecao
/// unica na aba Participantes; nenhuma selecionada = sem filtro de tempo.
/// (key, label, minDays, maxDays)
const tenureBuckets = [
  ("ate_30", "Até 30 dias", 0, 30),
  ("segundo_mes", "2º mês (31-60 dias)", 31, 60),
  ("terceiro_mes", "3º mês (61-90 dias)", 61, 90),
];

/// Faixas de diamantes do MES PASSADO (fechado) -- mesmo padrao de selecao
/// unica, combinavel com tenureBuckets (os dois filtros se cruzam com E).
/// Sempre o mes real mais recente ja fechado (nao depende do navegador de
/// mes da tela do programa, que so serve pra Visao Geral/Premiacoes
/// historicas). (key, label, min, max)
const diamondsBuckets = [
  ("0_5k", "0 - 5k", 0, 5000),
  ("5_10k", "5k - 10k", 5000, 10000),
  ("10_20k", "10k - 20k", 10000, 20000),
  ("20_40k", "20k - 40k", 20000, 40000),
  ("40_80k", "40k - 80k", 40000, 80000),
  ("80_150k", "80k - 150k", 80000, 150000),
  ("150_250k", "150k - 250k", 150000, 250000),
  ("250_350k", "250k - 350k", 250000, 350000),
  ("350_500k", "350k - 500k", 350000, 500000),
  ("500_800k", "500k - 800k", 500000, 800000),
  ("800k_1m", "800k - 1M", 800000, 1000000),
];

/// Regra de fronteira: min <= valor < max, exceto a ultima faixa de cada
/// grupo (<= dos dois lados, pra nao deixar quem bate o teto exato de fora).
String? _bucketKeyFor(num value, List<(String, String, num, num)> buckets) {
  for (var i = 0; i < buckets.length; i++) {
    final b = buckets[i];
    final isLast = i == buckets.length - 1;
    if (value >= b.$3 && (isLast ? value <= b.$4 : value < b.$4)) return b.$1;
  }
  return null;
}

String? tenureBucketKeyFor(int daysInAgency) => _bucketKeyFor(daysInAgency, tenureBuckets);

String? diamondsBucketKeyFor(num? diamondsLastMonth) {
  if (diamondsLastMonth == null) return null;
  return _bucketKeyFor(diamondsLastMonth, diamondsBuckets);
}

String _periodKeyForOffset(int monthsFromNow) {
  final now = DateTime.now();
  var year = now.year;
  var month = now.month + monthsFromNow;
  while (month > 12) {
    month -= 12;
    year += 1;
  }
  while (month < 1) {
    month += 12;
    year -= 1;
  }
  return year.toString() + "-" + month.toString().padLeft(2, "0");
}

String currentPeriodKey() => _periodKeyForOffset(0);

/// Streamers ativos da agencia com os numeros do MES PASSADO (fechado) e do
/// MES ATUAL (em andamento) anexados -- via StreamerSnapshot.
/// diamondsLastMonth/daysValidatedLastMonth/hoursLastMonth e os equivalentes
/// ThisMonth -- base da tabela de candidatos na aba Participantes. Os
/// filtros de elegibilidade (buckets/min dias/min horas) continuam usando
/// so os campos LastMonth, ja que o mes atual ainda em andamento nao e
/// comparavel entre streamers com datas de fechamento diferentes -- os
/// campos ThisMonth aqui sao so pra exibicao. Reusa fetchActiveStreamerSnapshots
/// (mesma query base de sempre) e so acrescenta a leitura de monthly_stats,
/// igual resolveMonthlySnapshots faz em program_monthly_stats_service.dart,
/// sem precisar montar um ProgramCriteria falso so pra disparar aquele
/// calculo.
Future<List<StreamerSnapshot>> fetchCandidateSnapshots({
  required String agencyId,
}) async {
  final snapshots = await fetchActiveStreamerSnapshots(agencyId: agencyId);
  if (snapshots.isEmpty) return snapshots;

  final prevPeriodKey = _periodKeyForOffset(-1);
  final client = Supabase.instance.client;
  final streamerIds = snapshots.map((s) => s.id).toList();
  final rows = await client
      .from("monthly_stats")
      .select("streamer_id, diamonds, days_live, hours_live")
      .eq("period_key", prevPeriodKey)
      .inFilter("streamer_id", streamerIds);
  final lastMonthByStreamer = {
    for (final r in (rows as List).cast<Map<String, dynamic>>()) r["streamer_id"] as String: r,
  };

  return snapshots.map((s) {
    final last = lastMonthByStreamer[s.id];
    return s.copyWithMonthly(
      diamondsThisMonth: s.diamonds,
      diamondsLastMonth: last?["diamonds"] as num?,
      daysValidatedThisMonth: s.daysValidated,
      daysValidatedLastMonth: (last?["days_live"] as num?)?.toInt(),
      hoursThisMonth: s.hoursLive,
      hoursLastMonth: (last?["hours_live"] as num?)?.toDouble(),
    );
  }).toList();
}

class GoalTargetInput {
  final int? targetDays;
  final double? targetHours;
  final num? targetDiamonds;
  final int? targetBattles;
  const GoalTargetInput({
    this.targetDays,
    this.targetHours,
    this.targetDiamonds,
    this.targetBattles,
  });
}

class ParticipationGoal {
  final String id;
  final int monthIndex;
  final String periodKey;
  final int? targetDays;
  final double? targetHours;
  final num? targetDiamonds;
  final int? targetBattles;
  final String outcome; // pendente | cumpriu | nao_cumprido
  final DateTime? confirmedAt;

  /// Preenchidos so quando o mes ja comecou (periodStarted) -- vem de
  /// streamer_stats (mes corrente) ou monthly_stats (mes ja fechado), so
  /// exibicao, nunca decide o outcome sozinho (isso e sempre manual).
  /// actualBattles so existe pro mes corrente -- monthly_stats (mes
  /// fechado) nao guarda batalhas, so diamantes/horas/dias.
  final int? actualDays;
  final double? actualHours;
  final num? actualDiamonds;
  final int? actualBattles;
  final bool periodStarted;

  const ParticipationGoal({
    required this.id,
    required this.monthIndex,
    required this.periodKey,
    this.targetDays,
    this.targetHours,
    this.targetDiamonds,
    this.targetBattles,
    required this.outcome,
    this.confirmedAt,
    this.actualDays,
    this.actualHours,
    this.actualDiamonds,
    this.actualBattles,
    required this.periodStarted,
  });
}

class ProgramParticipation {
  final String id;
  final String programId;
  final String streamerId;
  final String status; // ativo | concluido | removido
  final String? stageOverride; // null = automatico, senao a coluna escolhida a mao
  final String? prizeDescription;
  final String? notes;
  final DateTime createdAt;
  final List<ParticipationGoal> goals;
  final String? streamerName;
  final String? streamerAvatarUrl;
  final String? categoryName;

  const ProgramParticipation({
    required this.id,
    required this.programId,
    required this.streamerId,
    required this.status,
    this.stageOverride,
    this.prizeDescription,
    this.notes,
    required this.createdAt,
    required this.goals,
    this.streamerName,
    this.streamerAvatarUrl,
    this.categoryName,
  });

  /// "Em processo (mes X de N)" enquanto houver mes pendente; "Concluido"
  /// quando todos os meses ja foram confirmados (cumpriu ou nao).
  String get statusLabel {
    if (status == "removido") return "Removido";
    final pending = goals.where((g) => g.outcome == "pendente").toList();
    if (pending.isEmpty) return "Concluído";
    final current = pending.reduce(
      (a, b) => a.monthIndex < b.monthIndex ? a : b,
    );
    return "Em processo (mês " +
        current.monthIndex.toString() +
        " de " +
        goals.length.toString() +
        ")";
  }
}

/// Cria a participacao + os meses de meta (month_index 1..N, na ordem da
/// lista `months` recebida -- mes 1 = mes corrente + startMonthOffset (0 =
/// este mes, 1 = mes que vem, ...), period_key congelado na criacao.
/// initialStage/initialAwardValue cobrem o caso de cadastrar retroativamente
/// alguem que ja alcancou o resultado antes mesmo de existir o card (ver
/// setParticipationStage).
Future<String> createParticipation({
  required String programId,
  required String streamerId,
  String? prizeDescription,
  String? notes,
  required List<GoalTargetInput> months,
  required String createdBy,
  int startMonthOffset = 0,
  String? initialStage,
  num? initialAwardValue,
}) async {
  final client = Supabase.instance.client;
  final inserted = await client
      .from("program_participations")
      .insert({
        "program_id": programId,
        "streamer_id": streamerId,
        "prize_description": prizeDescription,
        "notes": notes,
        "created_by": createdBy,
      })
      .select("id")
      .single();
  final participationId = inserted["id"] as String;

  if (months.isNotEmpty) {
    await client.from("program_participation_goals").insert([
      for (var i = 0; i < months.length; i++)
        {
          "participation_id": participationId,
          "month_index": i + 1,
          "period_key": _periodKeyForOffset(startMonthOffset + i),
          "target_days": months[i].targetDays,
          "target_hours": months[i].targetHours,
          "target_diamonds": months[i].targetDiamonds,
          "target_battles": months[i].targetBattles,
        },
    ]);
  }

  if (initialStage != null) {
    final all = await fetchParticipations(programId: programId, includeRemoved: true);
    final created = all.firstWhere((p) => p.id == participationId);
    await setParticipationStage(
      participation: created,
      newStage: initialStage,
      performedBy: createdBy,
      awardValue: initialAwardValue,
    );
  }

  return participationId;
}

/// Cria uma participacao por streamer selecionado, com a MESMA missao
/// (mesmos meses/metas/observacao/premio) pra todos -- e o que viabiliza o
/// gestor aplicar de uma vez pra 30 streamers de uma faixa, em vez de
/// adicionar um por um. Tolerante a falha individual (um streamer com dado
/// inconsistente nao trava os demais), mesmo padrao ja usado na aba antiga.
Future<int> createParticipationsBulk({
  required String programId,
  required List<String> streamerIds,
  String? prizeDescription,
  String? notes,
  required List<GoalTargetInput> months,
  required String createdBy,
  int startMonthOffset = 0,
  String? initialStage,
  num? initialAwardValue,
}) async {
  var created = 0;
  for (final streamerId in streamerIds) {
    try {
      await createParticipation(
        programId: programId,
        streamerId: streamerId,
        prizeDescription: prizeDescription,
        notes: notes,
        months: months,
        createdBy: createdBy,
        startMonthOffset: startMonthOffset,
        initialStage: initialStage,
        initialAwardValue: initialAwardValue,
      );
      created++;
    } catch (_) {}
  }
  return created;
}

/// Participacoes do programa com progresso ja resolvido (actual vs meta por
/// mes). includeRemoved=false (padrao) mostra ativos + concluidos; os
/// removidos so aparecem no modo historico.
Future<List<ProgramParticipation>> fetchParticipations({
  required String programId,
  bool includeRemoved = false,
}) async {
  final client = Supabase.instance.client;
  var query = client
      .from("program_participations")
      .select(
        "*, goals:program_participation_goals(*), streamer:profiles(display_name, avatar_url, tiktok_creator_id, streamer_categories(name))",
      )
      .eq("program_id", programId);
  final rows = includeRemoved
      ? await query.order("created_at", ascending: false)
      : await query.neq("status", "removido").order("created_at", ascending: false);
  final list = (rows as List).cast<Map<String, dynamic>>();
  if (list.isEmpty) return const [];

  final nowKey = currentPeriodKey();
  final streamerIds = list.map((r) => r["streamer_id"] as String).toSet();
  final pastPeriodKeys = <String>{};
  for (final r in list) {
    for (final g in ((r["goals"] as List?) ?? const [])) {
      final pk = (g as Map)["period_key"] as String;
      if (pk != nowKey) pastPeriodKeys.add(pk);
    }
  }

  var currentStatsByStreamer = <String, Map<String, dynamic>>{};
  if (streamerIds.isNotEmpty) {
    final rows2 = await client
        .from("streamer_stats")
        .select("streamer_id, days_live, hours_live, diamonds, battles")
        .inFilter("streamer_id", streamerIds.toList());
    currentStatsByStreamer = {
      for (final r in (rows2 as List).cast<Map<String, dynamic>>())
        r["streamer_id"] as String: r,
    };
  }

  // Chave composta streamerId|periodKey -- meses ja fechados leem de
  // monthly_stats, mesma fonte que resolveMonthlySnapshots usa.
  final pastStatsByKey = <String, Map<String, dynamic>>{};
  if (pastPeriodKeys.isNotEmpty && streamerIds.isNotEmpty) {
    final rows3 = await client
        .from("monthly_stats")
        .select("streamer_id, period_key, days_live, hours_live, diamonds")
        .inFilter("streamer_id", streamerIds.toList())
        .inFilter("period_key", pastPeriodKeys.toList());
    for (final r in (rows3 as List).cast<Map<String, dynamic>>()) {
      pastStatsByKey[(r["streamer_id"] as String) + "|" + (r["period_key"] as String)] = r;
    }
  }

  return list.map((r) {
    final streamerId = r["streamer_id"] as String;
    final streamerData = r["streamer"];
    final streamer = streamerData is Map ? streamerData as Map<String, dynamic> : null;
    final catData = streamer?["streamer_categories"];

    final goalsRaw = ((r["goals"] as List?) ?? const []).cast<Map<String, dynamic>>()
      ..sort((a, b) => (a["month_index"] as int).compareTo(b["month_index"] as int));

    final goals = goalsRaw.map((g) {
      final periodKey = g["period_key"] as String;
      final periodStarted = periodKey.compareTo(nowKey) <= 0;
      Map<String, dynamic>? stats;
      if (periodKey == nowKey) {
        stats = currentStatsByStreamer[streamerId];
      } else if (periodStarted) {
        stats = pastStatsByKey[streamerId + "|" + periodKey];
      }
      return ParticipationGoal(
        id: g["id"] as String,
        monthIndex: g["month_index"] as int,
        periodKey: periodKey,
        targetDays: g["target_days"] as int?,
        targetHours: (g["target_hours"] as num?)?.toDouble(),
        targetDiamonds: g["target_diamonds"] as num?,
        targetBattles: g["target_battles"] as int?,
        outcome: g["outcome"] as String? ?? "pendente",
        confirmedAt: g["confirmed_at"] != null
            ? DateTime.parse(g["confirmed_at"] as String)
            : null,
        actualDays: (stats?["days_live"] as num?)?.toInt(),
        actualHours: (stats?["hours_live"] as num?)?.toDouble(),
        actualDiamonds: stats?["diamonds"] as num?,
        actualBattles: (stats?["battles"] as num?)?.toInt(),
        periodStarted: periodStarted,
      );
    }).toList();

    return ProgramParticipation(
      id: r["id"] as String,
      programId: r["program_id"] as String,
      streamerId: streamerId,
      status: r["status"] as String,
      stageOverride: r["stage_override"] as String?,
      prizeDescription: r["prize_description"] as String?,
      notes: r["notes"] as String?,
      createdAt: DateTime.parse(r["created_at"] as String),
      goals: goals,
      streamerName: streamer?["display_name"] as String?,
      streamerAvatarUrl: streamer?["avatar_url"] as String?,
      categoryName: catData is Map ? catData["name"] as String? : null,
    );
  }).toList();
}

/// Confirmacao manual do gestor pra um mes especifico -- nunca automatico
/// (o progresso calculado em fetchParticipations e so uma dica visual). Se,
/// apos essa confirmacao, nenhum mes da participacao ficar mais pendente, a
/// participacao inteira vira 'concluido' -- senao ela ficaria 'ativo' pra
/// sempre mesmo com tudo resolvido.
Future<void> confirmGoalOutcome({
  required String goalId,
  required String outcome, // cumpriu | nao_cumprido
  required String confirmedBy,
}) async {
  final client = Supabase.instance.client;
  final goal = await client
      .from("program_participation_goals")
      .update({
        "outcome": outcome,
        "confirmed_at": DateTime.now().toIso8601String(),
        "confirmed_by": confirmedBy,
      })
      .eq("id", goalId)
      .select("participation_id")
      .single();
  final participationId = goal["participation_id"] as String;

  final remaining = await client
      .from("program_participation_goals")
      .select("id")
      .eq("participation_id", participationId)
      .eq("outcome", "pendente");
  if ((remaining as List).isEmpty) {
    await client
        .from("program_participations")
        .update({"status": "concluido"})
        .eq("id", participationId)
        .eq("status", "ativo");
  }
}

/// Desfaz uma confirmacao (volta o mes pra pendente) -- o gestor pode ter
/// confirmado errado. Se a participacao tinha virado 'concluido' por causa
/// desse mes, volta pra 'ativo'.
Future<void> revertGoalOutcome({required String goalId}) async {
  final client = Supabase.instance.client;
  final goal = await client
      .from("program_participation_goals")
      .update({"outcome": "pendente", "confirmed_at": null, "confirmed_by": null})
      .eq("id", goalId)
      .select("participation_id")
      .single();
  await client
      .from("program_participations")
      .update({"status": "ativo"})
      .eq("id", goal["participation_id"])
      .eq("status", "concluido");
}

/// Soft-remove -- nunca apaga a linha (historico preservado), so marca
/// removido e sai da lista de participantes ativos. Readicionar depois cria
/// uma participacao nova (o indice unico so trava enquanto status='ativo').
Future<void> removeParticipation({
  required String participationId,
  required String removedBy,
}) async {
  await Supabase.instance.client
      .from("program_participations")
      .update({
        "status": "removido",
        "removed_at": DateTime.now().toIso8601String(),
        "removed_by": removedBy,
      })
      .eq("id", participationId);
}

/// Contadores pra Visao Geral: quantos participantes ativos, quantos ainda
/// tem algum mes pendente ("em processo") e quantos ja concluiram.
Future<Map<String, int>> fetchParticipationSummary({
  required String programId,
}) async {
  final participations = await fetchParticipations(programId: programId);
  final active = participations.where((p) => p.status == "ativo").toList();
  final emProcesso = active
      .where((p) => p.goals.any((g) => g.outcome == "pendente"))
      .length;
  final concluidos = participations.where((p) => p.status == "concluido").length;
  return {"ativos": active.length, "emProcesso": emProcesso, "concluidos": concluidos};
}

/// Colunas do quadro Fluxo, na ordem de exibicao. "proximos_a_entrar" e pra
/// participacoes cujo primeiro mes da missao ainda nao comecou (agendadas
/// pra um mes futuro, ver startMonthOffset em createParticipation) -- serve
/// de lembrete de quem ja foi programado mas ainda nao entrou de fato.
const participationStageOrder = [
  "proximos_a_entrar",
  "em_andamento",
  "nao_conseguiu",
  "concluido",
  "pendente_entrega",
  "entregue",
];

const participationStageLabels = {
  "proximos_a_entrar": "Proximos a entrar",
  "em_andamento": "Em andamento",
  "nao_conseguiu": "Nao conseguiu",
  "concluido": "Concluido",
  "pendente_entrega": "Pendente de entrega",
  "entregue": "Entregue",
};

/// Coluna do quadro Fluxo pra essa participacao. stageOverride sempre vence
/// (o gestor pode mover qualquer card pra qualquer coluna na mao, mesmo as
/// que normalmente sao calculadas sozinhas). Sem override: primeiro mes
/// ainda no futuro = "Proximos a entrar"; qualquer mes "nao cumpriu" = "Nao
/// conseguiu" (falhar um mes falha a missao inteira, mesmo com outros meses
/// ainda pendentes); todos os meses "cumpriu" = "Concluido"; caso contrario
/// "Em andamento".
String participationStage(ProgramParticipation p) {
  if (p.stageOverride != null) return p.stageOverride!;
  if (p.goals.isNotEmpty) {
    final firstGoal = p.goals.reduce((a, b) => a.monthIndex < b.monthIndex ? a : b);
    if (!firstGoal.periodStarted) return "proximos_a_entrar";
  }
  final hasFailed = p.goals.any((g) => g.outcome == "nao_cumprido");
  if (hasFailed) return "nao_conseguiu";
  final allResolved = p.goals.isNotEmpty && p.goals.every((g) => g.outcome == "cumpriu");
  if (!allResolved) return "em_andamento";
  return "concluido";
}

/// Quantas participacoes cada programa tem em cada coluna do quadro Fluxo --
/// usado nos cards da listagem de Programas (badges de alerta ao lado de
/// "X participantes"). Reusa participationStage, mas monta os objetos so
/// com o que da pra calcular estagio (outcome/stage_override/period_key) --
/// sem streamer/streamer_stats/monthly_stats, que so servem pra EXIBIR
/// progresso, nao pra decidir a coluna. Bem mais leve que chamar
/// fetchParticipations um programa de cada vez. Chave "_total" no mapa de
/// cada programa soma todas as colunas.
Future<Map<String, Map<String, int>>> fetchParticipationStageCountsByProgram({
  required List<String> programIds,
}) async {
  if (programIds.isEmpty) return {};
  final client = Supabase.instance.client;
  final rows = await client
      .from("program_participations")
      .select(
        "id, program_id, streamer_id, status, stage_override, created_at, goals:program_participation_goals(id, month_index, period_key, outcome)",
      )
      .inFilter("program_id", programIds)
      .neq("status", "removido");
  final nowKey = currentPeriodKey();

  final result = <String, Map<String, int>>{};
  for (final r in (rows as List).cast<Map<String, dynamic>>()) {
    final programId = r["program_id"] as String;
    final goalsRaw = ((r["goals"] as List?) ?? const []).cast<Map<String, dynamic>>();
    final goals = goalsRaw.map((g) {
      final periodKey = g["period_key"] as String;
      return ParticipationGoal(
        id: g["id"] as String,
        monthIndex: g["month_index"] as int,
        periodKey: periodKey,
        outcome: g["outcome"] as String? ?? "pendente",
        periodStarted: periodKey.compareTo(nowKey) <= 0,
      );
    }).toList();
    final participation = ProgramParticipation(
      id: r["id"] as String,
      programId: programId,
      streamerId: r["streamer_id"] as String,
      status: r["status"] as String,
      stageOverride: r["stage_override"] as String?,
      createdAt: DateTime.parse(r["created_at"] as String),
      goals: goals,
    );
    final stage = participationStage(participation);
    final byStage = result.putIfAbsent(programId, () => {});
    byStage[stage] = (byStage[stage] ?? 0) + 1;
    byStage["_total"] = (byStage["_total"] ?? 0) + 1;
  }
  return result;
}

num _awardItemsTotal(dynamic items) {
  if (items is! List) return 0;
  var total = 0.0;
  for (final it in items) {
    final value = (it as Map)["value"] as num?;
    if (value != null) total += value.toDouble();
  }
  return total;
}

/// Move o card manualmente pra qualquer coluna do quadro Fluxo (null = volta
/// a ser calculado automaticamente). Ao entrar em "Entregue" com um valor
/// definido, registra (ou reaproveita, se ja existir pra essa participacao)
/// a premiacao em program_awards E espelha o gasto em Financeiro RH >
/// Entradas e Saidas (syncParticipationAwardFinancialEntry) -- e isso que
/// faz a premiacao aparecer sozinha na aba Premiacoes do programa e na aba
/// "Programas de Desenvolvimento" do CRM do streamer, sem cadastro manual
/// extra. Ao sair de "Entregue" pra tras, a premiacao e o lancamento
/// financeiro voltam pra pendente (nao apagam o registro).
Future<void> setParticipationStage({
  required ProgramParticipation participation,
  required String? newStage,
  required String performedBy,
  num? awardValue,
}) async {
  final client = Supabase.instance.client;
  await client
      .from("program_participations")
      .update({"stage_override": newStage})
      .eq("id", participation.id);

  final existingAward = await client
      .from("program_awards")
      .select("id, items")
      .eq("participation_id", participation.id)
      .maybeSingle();

  final title = (participation.prizeDescription?.trim().isNotEmpty ?? false)
      ? participation.prizeDescription!.trim()
      : "Premiacao";

  if (newStage == "entregue") {
    final amount = awardValue ?? 0;
    final items = [
      {"name": title, "quantity": 1, "value": amount},
    ];
    String awardId;
    if (existingAward == null) {
      final inserted = await client
          .from("program_awards")
          .insert({
            "program_id": participation.programId,
            "streamer_id": participation.streamerId,
            "participation_id": participation.id,
            "title": title,
            "items": items,
            "status": "entregue",
            "delivered_at": DateTime.now().toIso8601String(),
            "created_by": performedBy,
          })
          .select("id")
          .single();
      awardId = inserted["id"] as String;
    } else {
      awardId = existingAward["id"] as String;
      await client
          .from("program_awards")
          .update({
            "items": items,
            "status": "entregue",
            "delivered_at": DateTime.now().toIso8601String(),
          })
          .eq("id", awardId);
    }
    await syncParticipationAwardFinancialEntry(
      programId: participation.programId,
      awardId: awardId,
      awardTitle: title,
      streamerName: participation.streamerName,
      amount: amount,
      status: "entregue",
    );
  } else if (existingAward != null) {
    await client
        .from("program_awards")
        .update({"status": "pendente", "delivered_at": null})
        .eq("id", existingAward["id"]);
    await syncParticipationAwardFinancialEntry(
      programId: participation.programId,
      awardId: existingAward["id"] as String,
      awardTitle: title,
      streamerName: participation.streamerName,
      amount: _awardItemsTotal(existingAward["items"]),
      status: "pendente",
    );
  }
}

/// Espelha uma premiacao de programa (program_awards) como uma saida
/// (despesa) em Financeiro RH > Entradas e Saidas -- mesmo padrao ja usado
/// por premiacoes de Evento (ver syncAwardFinancialEntry em
/// event_premiacoes_tab.dart). Chamada tanto por setParticipationStage
/// (quadro Fluxo) quanto pela aba Premiacoes, pra qualquer edicao de valor/
/// status ficar sempre refletida no financeiro. Sem valor (amount <= 0),
/// remove o lancamento (nao faz sentido uma saida de R$ 0).
Future<void> syncParticipationAwardFinancialEntry({
  required String programId,
  required String awardId,
  required String awardTitle,
  required String? streamerName,
  required num amount,
  required String status, // entregue | pendente | agendado
}) async {
  final client = Supabase.instance.client;
  if (amount <= 0) {
    await client.from("financial_entries").delete().eq("program_award_id", awardId);
    return;
  }

  final userId = client.auth.currentUser!.id;
  final manager = await client.from("managers").select("agency_id").eq("id", userId).single();
  final program = await client
      .from("development_programs")
      .select("name")
      .eq("id", programId)
      .maybeSingle();
  final financialStatus = status == "entregue" ? "pago" : "pendente";

  final data = {
    "agency_id": manager["agency_id"],
    "entry_type": "despesa",
    "category": "Premiacao de Programa",
    "supplier": program?["name"] as String?,
    "description": awardTitle + (streamerName != null ? "  -  " + streamerName : ""),
    "amount": amount,
    "due_date": DateTime.now().toIso8601String().substring(0, 10),
    "payment_date": financialStatus == "pago" ? DateTime.now().toIso8601String().substring(0, 10) : null,
    "status": financialStatus,
    "is_recurring": false,
    "notes": null,
    "created_by": userId,
    "manager_id": null,
    "external_collaborator_id": null,
    "program_award_id": awardId,
  };

  final existing = await client
      .from("financial_entries")
      .select("id")
      .eq("program_award_id", awardId)
      .maybeSingle();
  if (existing != null) {
    await client.from("financial_entries").update(data).eq("id", existing["id"] as String);
  } else {
    await client.from("financial_entries").insert(data);
  }
}
