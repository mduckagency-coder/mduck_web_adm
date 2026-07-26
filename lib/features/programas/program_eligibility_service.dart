import "package:supabase_flutter/supabase_flutter.dart";
import "program_phase_service.dart";

/// Criterios configuraveis de um programa (development_programs.criteria).
/// Chave ausente/nula = criterio desativado. required_material_ids fica
/// guardado e mostrado na tela, mas ainda NAO bloqueia elegibilidade -- o
/// sistema hoje nao tem como saber se um streamer "concluiu" um material
/// especifico (o modulo Materiais e so de conteudo, sem registro de
/// conclusao por streamer). Quando esse rastreamento existir, e so passar
/// a checar aqui.
class ProgramCriteria {
  final int? minDays;
  final int? minDaysValidated;
  final double? minHours;
  final num? minDiamonds;
  final num? minHeartMe;
  final int? minBattles;

  /// Sobrepoe minBattles por categoria do streamer (chave = category_id):
  /// quando a categoria do streamer tiver uma entrada aqui, ela vale no
  /// lugar do padrao -- ex. Batalha precisa de mais batalhas que Musica.
  final Map<String, int> battlesByCategory;

  /// Cada meta pode ser ativada/desativada independente de ter um valor
  /// preenchido (o valor fica guardado mesmo desativada, pra nao se perder
  /// se o gestor reativar depois) e marcada como obrigatoria ou opcional --
  /// usado pela regra de aprovacao abaixo.
  final bool daysEnabled;
  final bool daysRequired;
  final bool daysValidatedEnabled;
  final bool daysValidatedRequired;
  final bool hoursEnabled;
  final bool hoursRequired;
  final bool diamondsEnabled;
  final bool diamondsRequired;
  final bool heartMeEnabled;
  final bool heartMeRequired;
  final bool battlesEnabled;
  final bool battlesRequired;

  /// "todas" (padrao, precisa bater todas as metas ativas), "obrigatorias"
  /// (so as marcadas obrigatorias bloqueiam) ou "percentual" (elegivel ao
  /// bater approvalMinPercentage% das metas ativas).
  final String approvalRuleMode;
  final int approvalMinPercentage;

  final List<String> categoryIds;
  final List<String> requiredMaterialIds;

  const ProgramCriteria({
    this.minDays,
    this.minDaysValidated,
    this.minHours,
    this.minDiamonds,
    this.minHeartMe,
    this.minBattles,
    this.battlesByCategory = const {},
    this.daysEnabled = true,
    this.daysRequired = true,
    this.daysValidatedEnabled = true,
    this.daysValidatedRequired = true,
    this.hoursEnabled = true,
    this.hoursRequired = true,
    this.diamondsEnabled = true,
    this.diamondsRequired = true,
    this.heartMeEnabled = true,
    this.heartMeRequired = true,
    this.battlesEnabled = true,
    this.battlesRequired = true,
    this.approvalRuleMode = "todas",
    this.approvalMinPercentage = 100,
    this.categoryIds = const [],
    this.requiredMaterialIds = const [],
  });

  factory ProgramCriteria.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ProgramCriteria();
    final minDays = map["min_days"] as int?;
    final minDaysValidated = map["min_days_validated"] as int?;
    final minHours = (map["min_hours"] as num?)?.toDouble();
    final minDiamonds = map["min_diamonds"] as num?;
    final minHeartMe = map["min_heart_me"] as num?;
    final minBattles = map["min_battles"] as int?;
    final battlesByCategoryMap = map["battles_by_category"] as Map<String, dynamic>?;
    return ProgramCriteria(
      minDays: minDays,
      minDaysValidated: minDaysValidated,
      minHours: minHours,
      minDiamonds: minDiamonds,
      minHeartMe: minHeartMe,
      minBattles: minBattles,
      battlesByCategory: battlesByCategoryMap == null ? const {} : battlesByCategoryMap.map((k, v) => MapEntry(k, v as int)),
      // Dado antigo (sem essas chaves): habilitada = tinha valor preenchido,
      // obrigatoria = true -- preserva exatamente o comportamento de antes
      // dessas duas flags existirem.
      daysEnabled: map["days_enabled"] as bool? ?? (minDays != null),
      daysRequired: map["days_required"] as bool? ?? true,
      daysValidatedEnabled: map["days_validated_enabled"] as bool? ?? (minDaysValidated != null),
      daysValidatedRequired: map["days_validated_required"] as bool? ?? true,
      hoursEnabled: map["hours_enabled"] as bool? ?? (minHours != null),
      hoursRequired: map["hours_required"] as bool? ?? true,
      diamondsEnabled: map["diamonds_enabled"] as bool? ?? (minDiamonds != null),
      diamondsRequired: map["diamonds_required"] as bool? ?? true,
      heartMeEnabled: map["heart_me_enabled"] as bool? ?? (minHeartMe != null),
      heartMeRequired: map["heart_me_required"] as bool? ?? true,
      battlesEnabled: map["battles_enabled"] as bool? ?? (minBattles != null),
      battlesRequired: map["battles_required"] as bool? ?? true,
      approvalRuleMode: map["approval_rule_mode"] as String? ?? "todas",
      approvalMinPercentage: map["approval_min_percentage"] as int? ?? 100,
      categoryIds: ((map["category_ids"] as List?) ?? const []).cast<String>(),
      requiredMaterialIds: ((map["required_material_ids"] as List?) ?? const []).cast<String>(),
    );
  }

  Map<String, dynamic> toMap() => {
        "min_days": minDays,
        "min_days_validated": minDaysValidated,
        "min_hours": minHours,
        "min_diamonds": minDiamonds,
        "min_heart_me": minHeartMe,
        "min_battles": minBattles,
        "battles_by_category": battlesByCategory,
        "days_enabled": daysEnabled,
        "days_required": daysRequired,
        "days_validated_enabled": daysValidatedEnabled,
        "days_validated_required": daysValidatedRequired,
        "hours_enabled": hoursEnabled,
        "hours_required": hoursRequired,
        "diamonds_enabled": diamondsEnabled,
        "diamonds_required": diamondsRequired,
        "heart_me_enabled": heartMeEnabled,
        "heart_me_required": heartMeRequired,
        "battles_enabled": battlesEnabled,
        "battles_required": battlesRequired,
        "approval_rule_mode": approvalRuleMode,
        "approval_min_percentage": approvalMinPercentage,
        "category_ids": categoryIds,
        "required_material_ids": requiredMaterialIds,
      };

  bool get isEmpty =>
      !(daysEnabled && minDays != null) &&
      !(daysValidatedEnabled && minDaysValidated != null) &&
      !(hoursEnabled && minHours != null) &&
      !(diamondsEnabled && minDiamonds != null) &&
      !(heartMeEnabled && minHeartMe != null) &&
      !(battlesEnabled && minBattles != null) &&
      categoryIds.isEmpty;
}

class StreamerSnapshot {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? categoryId;
  final String? categoryName;
  final int daysInAgency;
  final int daysValidated;
  final double hoursLive;
  final num diamonds;
  final num? heartMe;
  final int battles;
  final DateTime? lastLiveAt;

  const StreamerSnapshot({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.categoryId,
    this.categoryName,
    required this.daysInAgency,
    required this.daysValidated,
    required this.hoursLive,
    required this.diamonds,
    this.heartMe,
    required this.battles,
    this.lastLiveAt,
  });
}

const _profileSnapshotSelect = "id, display_name, avatar_url, joined_at, last_live_at, category_id, streamer_categories(name), streamer_stats(days_live, hours_live, diamonds, battles, heart_me)";

StreamerSnapshot _snapshotFromProfileRow(Map<String, dynamic> r) {
  final statsData = r["streamer_stats"];
  Map<String, dynamic>? stats;
  if (statsData is List && statsData.isNotEmpty) {
    stats = statsData.first as Map<String, dynamic>;
  } else if (statsData is Map) {
    stats = statsData as Map<String, dynamic>;
  }
  final catData = r["streamer_categories"];
  final joinedAt = r["joined_at"] != null ? DateTime.parse(r["joined_at"] as String) : null;

  return StreamerSnapshot(
    id: r["id"] as String,
    displayName: (r["display_name"] as String?) ?? "-",
    avatarUrl: r["avatar_url"] as String?,
    categoryId: r["category_id"] as String?,
    categoryName: catData is Map ? catData["name"] as String? : null,
    daysInAgency: joinedAt != null ? DateTime.now().difference(joinedAt).inDays : 0,
    daysValidated: (stats?["days_live"] as num?)?.toInt() ?? 0,
    hoursLive: (stats?["hours_live"] as num?)?.toDouble() ?? 0,
    diamonds: stats?["diamonds"] as num? ?? 0,
    heartMe: stats?["heart_me"] as num?,
    battles: (stats?["battles"] as num?)?.toInt() ?? 0,
    lastLiveAt: r["last_live_at"] != null ? DateTime.parse(r["last_live_at"] as String) : null,
  );
}

Future<List<StreamerSnapshot>> fetchActiveStreamerSnapshots({required String agencyId}) async {
  final client = Supabase.instance.client;
  final rows = await client.from("profiles").select(_profileSnapshotSelect).eq("agency_id", agencyId).eq("is_active", true);
  return (rows as List).map((r) => _snapshotFromProfileRow(r as Map<String, dynamic>)).toList();
}

/// Igual fetchActiveStreamerSnapshots, mas por lista explicita de ids e sem
/// filtro de is_active -- usado na aba Participantes, que precisa mostrar
/// tambem quem ja foi desligado/concluiu (fetchActiveStreamerSnapshots so
/// traz quem esta ativo hoje).
Future<List<StreamerSnapshot>> fetchStreamerSnapshotsByIds({required List<String> streamerIds}) async {
  if (streamerIds.isEmpty) return const [];
  final client = Supabase.instance.client;
  final rows = await client.from("profiles").select(_profileSnapshotSelect).inFilter("id", streamerIds);
  return (rows as List).map((r) => _snapshotFromProfileRow(r as Map<String, dynamic>)).toList();
}

/// Quais streamers ja concluiram (com outcome dentre okOutcomes) uma fase
/// -- usado para saber quem ja pode ser considerado no proximo programa da
/// cadeia.
Future<Set<String>> fetchCompletedStreamerIds({required String phaseKey, List<String> okOutcomes = const ["aprovado", "graduado"]}) async {
  final client = Supabase.instance.client;
  final rows = await client.from("streamer_phase_progress").select("streamer_id").eq("phase_key", phaseKey).inFilter("outcome", okOutcomes);
  return (rows as List).map((r) => r["streamer_id"] as String).whereType<String>().toSet();
}

/// Quem ja tem card (participante ativo ou ja concluido) num programa.
Future<Set<String>> fetchEnrolledStreamerIds({required String phaseKey}) async {
  final client = Supabase.instance.client;
  final rows = await client.from("streamer_phase_progress").select("streamer_id").eq("phase_key", phaseKey);
  return (rows as List).map((r) => r["streamer_id"] as String).whereType<String>().toSet();
}

class EligibilityResult {
  final bool eligible;
  final List<String> gaps;
  const EligibilityResult({required this.eligible, this.gaps = const []});
}

class _GoalCheck {
  final bool passed;
  final bool required;
  const _GoalCheck({required this.passed, required this.required});
}

/// Compara os numeros atuais do streamer com as metas ATIVAS do programa.
/// "gaps" so lista o que estiver perto de bater (usado nos alertas tipo
/// "faltam 2 horas") -- metas muito distantes nao geram alerta, so deixam o
/// streamer como nao-elegivel. Categoria continua sendo um filtro duro (fora
/// do conceito de meta), sempre aplicado independente da regra de aprovacao.
/// A regra de aprovacao decide, entre as metas ativas, o que conta pra
/// elegibilidade final: todas / so as obrigatorias / um percentual minimo.
EligibilityResult evaluateEligibility(StreamerSnapshot s, ProgramCriteria c) {
  final gaps = <String>[];
  final checks = <_GoalCheck>[];

  if (c.daysEnabled && c.minDays != null) {
    final missing = c.minDays! - s.daysInAgency;
    final passed = missing <= 0;
    if (!passed && missing <= 2) gaps.add(missing == 1 ? "Falta 1 dia" : "Faltam " + missing.toString() + " dias");
    checks.add(_GoalCheck(passed: passed, required: c.daysRequired));
  }
  if (c.daysValidatedEnabled && c.minDaysValidated != null) {
    final missing = c.minDaysValidated! - s.daysValidated;
    final passed = missing <= 0;
    if (!passed && missing <= 2) gaps.add(missing == 1 ? "Falta 1 dia validado" : "Faltam " + missing.toString() + " dias validados");
    checks.add(_GoalCheck(passed: passed, required: c.daysValidatedRequired));
  }
  if (c.hoursEnabled && c.minHours != null) {
    final missing = c.minHours! - s.hoursLive;
    final passed = missing <= 0;
    if (!passed && missing <= 5) gaps.add("Faltam " + missing.toStringAsFixed(0) + " horas");
    checks.add(_GoalCheck(passed: passed, required: c.hoursRequired));
  }
  if (c.diamondsEnabled && c.minDiamonds != null) {
    final missing = c.minDiamonds! - s.diamonds;
    final passed = missing <= 0;
    if (!passed && missing <= 1000) gaps.add("Faltam " + missing.toStringAsFixed(0) + " diamantes");
    checks.add(_GoalCheck(passed: passed, required: c.diamondsRequired));
  }
  final battlesThreshold = (s.categoryId != null ? c.battlesByCategory[s.categoryId] : null) ?? c.minBattles;
  if (c.battlesEnabled && battlesThreshold != null) {
    final missing = battlesThreshold - s.battles;
    final passed = missing <= 0;
    if (!passed && missing <= 2) gaps.add(missing == 1 ? "Falta 1 batalha" : "Faltam " + missing.toString() + " batalhas");
    checks.add(_GoalCheck(passed: passed, required: c.battlesRequired));
  }
  if (c.heartMeEnabled && c.minHeartMe != null) {
    final current = s.heartMe;
    final passed = current != null && current >= c.minHeartMe!;
    if (!passed) gaps.add("Heart Me abaixo da meta");
    checks.add(_GoalCheck(passed: passed, required: c.heartMeRequired));
  }

  final categoryOk = c.categoryIds.isEmpty || (s.categoryId != null && c.categoryIds.contains(s.categoryId));

  bool eligible;
  if (checks.isEmpty) {
    eligible = categoryOk;
  } else {
    switch (c.approvalRuleMode) {
      case "obrigatorias":
        final requiredChecks = checks.where((g) => g.required);
        eligible = categoryOk && requiredChecks.every((g) => g.passed);
        break;
      case "percentual":
        final passedCount = checks.where((g) => g.passed).length;
        eligible = categoryOk && (passedCount / checks.length * 100) >= c.approvalMinPercentage;
        break;
      default:
        eligible = categoryOk && checks.every((g) => g.passed);
    }
  }

  return EligibilityResult(eligible: eligible, gaps: gaps);
}

/// Progresso 0.0-1.0: media de quanto cada meta ATIVA ja foi cumprida (cada
/// uma limitada a 100%). Sem nenhuma meta ativa, retorna 1.0 (nao ha meta,
/// entao nao ha o que faltar). Usado na barra de progresso e na ordenacao
/// por "Progresso" da aba Participantes -- reflete o avanco geral, independente
/// da regra de aprovacao (que so decide o corte de elegibilidade).
double progressFraction(StreamerSnapshot s, ProgramCriteria c) {
  final ratios = <double>[];
  if (c.daysEnabled && c.minDays != null && c.minDays! > 0) ratios.add((s.daysInAgency / c.minDays!).clamp(0.0, 1.0));
  if (c.daysValidatedEnabled && c.minDaysValidated != null && c.minDaysValidated! > 0) ratios.add((s.daysValidated / c.minDaysValidated!).clamp(0.0, 1.0));
  if (c.hoursEnabled && c.minHours != null && c.minHours! > 0) ratios.add((s.hoursLive / c.minHours!).clamp(0.0, 1.0));
  if (c.diamondsEnabled && c.minDiamonds != null && c.minDiamonds!.toDouble() > 0) ratios.add((s.diamonds.toDouble() / c.minDiamonds!.toDouble()).clamp(0.0, 1.0));
  final battlesThreshold = (s.categoryId != null ? c.battlesByCategory[s.categoryId] : null) ?? c.minBattles;
  if (c.battlesEnabled && battlesThreshold != null && battlesThreshold > 0) ratios.add((s.battles / battlesThreshold).clamp(0.0, 1.0));
  if (c.heartMeEnabled && c.minHeartMe != null && c.minHeartMe!.toDouble() > 0) ratios.add(((s.heartMe ?? 0).toDouble() / c.minHeartMe!.toDouble()).clamp(0.0, 1.0));
  if (ratios.isEmpty) return 1.0;
  return ratios.reduce((a, b) => a + b) / ratios.length;
}

/// Roda sob demanda (ao abrir a tela, sem depender de tarefa agendada):
/// para cada streamer elegivel que ainda nao tem card neste programa (e,
/// se houver um programa anterior na cadeia, ja concluiu ele), cria o card
/// automaticamente. Programa sem nenhum criterio definido nao auto-inscreve
/// ninguem (evita "todo mundo entra" antes de configurar de verdade).
Future<int> syncEligibleStreamers({
  required String phaseKey,
  required ProgramCriteria criteria,
  required List<StreamerSnapshot> snapshots,
  required Set<String> enrolledStreamerIds,
  Set<String>? previousProgramCompletedStreamerIds,
}) async {
  if (criteria.isEmpty) return 0;
  var created = 0;
  for (final s in snapshots) {
    if (enrolledStreamerIds.contains(s.id)) continue;
    if (previousProgramCompletedStreamerIds != null && !previousProgramCompletedStreamerIds.contains(s.id)) continue;
    if (evaluateEligibility(s, criteria).eligible) {
      await createProgramCardIfNeeded(phaseKey: phaseKey, streamerId: s.id);
      created++;
    }
  }
  return created;
}
