import "package:supabase_flutter/supabase_flutter.dart";
import "program_phase_service.dart";
import "program_monthly_stats_service.dart";

/// Sobrepoe qualquer uma das 4 metas numericas pra uma categoria especifica
/// de streamer (ex: Batalha precisa de mais batalhas que Musica, Games tem
/// outra meta de horas) -- campo ausente = usa o padrao do programa.
class CategoryOverride {
  final int? minDaysValidated;
  final double? minHours;
  final num? minDiamonds;
  final int? minBattles;
  const CategoryOverride({
    this.minDaysValidated,
    this.minHours,
    this.minDiamonds,
    this.minBattles,
  });

  factory CategoryOverride.fromMap(Map<String, dynamic> map) =>
      CategoryOverride(
        minDaysValidated: map["min_days_validated"] as int?,
        minHours: (map["min_hours"] as num?)?.toDouble(),
        minDiamonds: map["min_diamonds"] as num?,
        minBattles: map["min_battles"] as int?,
      );

  Map<String, dynamic> toMap() => {
    "min_days_validated": minDaysValidated,
    "min_hours": minHours,
    "min_diamonds": minDiamonds,
    "min_battles": minBattles,
  };

  bool get isEmpty =>
      minDaysValidated == null &&
      minHours == null &&
      minDiamonds == null &&
      minBattles == null;
}

/// Criterios configuraveis de um programa (development_programs.criteria).
/// Chave ausente/nula = criterio desativado.
class ProgramCriteria {
  final int? minDays;

  /// Limite superior de dias na agencia (oposto do minDays) -- ex: "novato
  /// dentro de 90 dias" usa minDays=0/null e maxDaysInAgency=90. Funciona
  /// como filtro duro (igual categoryIds), fora da regra de aprovacao:
  /// quem esta ha mais dias que isso nunca e elegivel neste programa.
  final int? maxDaysInAgency;
  final int? minDaysValidated;
  final double? minHours;
  final num? minDiamonds;

  /// Limite superior de diamantes (oposto do minDiamonds) -- ex: "ate 20k"/
  /// "abaixo de 40k". Tambem um filtro duro, resolvido pelo mesmo
  /// diamondsPeriod usado pelo minDiamonds (mesma metrica, mesmo recorte de
  /// mes) -- sem dado ainda pro periodo pedido, o gate fica bloqueado (nao
  /// libera enquanto nao houver numero).
  final num? maxDiamonds;
  final num? minHeartMe;
  final int? minBattles;

  /// Pra diamantes/horas/dias validados, decide se o valor comparado e o
  /// total acumulado do streamer, so o que ele fez no mes atual/anterior, ou
  /// o MAIOR entre mes atual e mes anterior ("mes_atual_ou_anterior" -- cobre
  /// "bateu 80k mes passado, ja entra esse mes tambem"). Calculado sob
  /// demanda a partir de streamer_stat_snapshots -- ver
  /// program_monthly_stats_service.dart. "total" preserva o comportamento de
  /// sempre.
  final String diamondsPeriod;
  final String hoursPeriod;
  final String daysValidatedPeriod;

  /// Sobrepoe qualquer uma das 4 metas numericas por categoria do streamer
  /// (chave = category_id) -- generaliza o antigo battlesByCategory (que so
  /// cobria batalhas) pra dias validados/horas/diamantes/batalhas.
  final Map<String, CategoryOverride> categoryOverrides;

  /// "fluxo" (padrao): Kanban + avaliacao final manual, auto-inscricao so
  /// promove. "faixa": sem avaliacao manual, o sistema entra E sai sozinho
  /// conforme os criterios batem ou deixam de bater (ver syncFaixaMembership).
  final String membershipMode;

  /// Quantidade de tickets de sorteio concedidos automaticamente quando o
  /// streamer bate a meta (0 = desativado). Em modo faixa, um ticket por
  /// mes enquanto elegivel; em modo fluxo, um ticket na aprovacao final.
  final int ticketQuantity;

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

  /// "criterios" (padrao, faixa min/max abaixo) ou "manual" (lista fixa de
  /// streamers escolhidos a dedo, ignorando as faixas -- ver
  /// manualStreamerIds).
  final String selectionMode;
  final List<String> manualStreamerIds;

  /// "metas" (padrao, aprova/reprova por meta batida) ou "pontos" (so
  /// ranqueia os candidatos pela metrica escolhida em pointsMetric, sem
  /// aprovar/reprovar ninguem -- ver rankByPoints).
  final String trackingMode;
  final String pointsMetric;

  /// Filtros de inclusao aplicados como hard gate, junto de categoria/dias-
  /// maximo/diamantes-maximo: novato = ate 90 dias na agencia; inativo = sem
  /// live nos ultimos 30 dias (StreamerSnapshot.isInactive).
  final bool includeNovatos;
  final bool includeInativos;

  const ProgramCriteria({
    this.minDays,
    this.maxDaysInAgency,
    this.minDaysValidated,
    this.minHours,
    this.minDiamonds,
    this.maxDiamonds,
    this.minHeartMe,
    this.minBattles,
    this.categoryOverrides = const {},
    this.membershipMode = "fluxo",
    this.ticketQuantity = 0,
    this.diamondsPeriod = "total",
    this.hoursPeriod = "total",
    this.daysValidatedPeriod = "total",
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
    this.selectionMode = "criterios",
    this.manualStreamerIds = const [],
    this.trackingMode = "metas",
    this.pointsMetric = "diamonds_current",
    this.includeNovatos = true,
    this.includeInativos = true,
  });

  factory ProgramCriteria.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ProgramCriteria();
    final minDays = map["min_days"] as int?;
    final minDaysValidated = map["min_days_validated"] as int?;
    final minHours = (map["min_hours"] as num?)?.toDouble();
    final minDiamonds = map["min_diamonds"] as num?;
    final minHeartMe = map["min_heart_me"] as num?;
    final minBattles = map["min_battles"] as int?;

    final categoryOverridesMap =
        map["category_overrides"] as Map<String, dynamic>?;
    final legacyBattlesByCategory =
        map["battles_by_category"] as Map<String, dynamic>?;
    Map<String, CategoryOverride> categoryOverrides;
    if (categoryOverridesMap != null) {
      categoryOverrides = categoryOverridesMap.map(
        (k, v) =>
            MapEntry(k, CategoryOverride.fromMap(v as Map<String, dynamic>)),
      );
    } else if (legacyBattlesByCategory != null) {
      // Dado antigo (so cobria batalhas por categoria) -- migra so esse valor.
      categoryOverrides = legacyBattlesByCategory.map(
        (k, v) => MapEntry(k, CategoryOverride(minBattles: v as int)),
      );
    } else {
      categoryOverrides = const {};
    }

    return ProgramCriteria(
      minDays: minDays,
      maxDaysInAgency: map["max_days_in_agency"] as int?,
      minDaysValidated: minDaysValidated,
      minHours: minHours,
      minDiamonds: minDiamonds,
      maxDiamonds: map["max_diamonds"] as num?,
      minHeartMe: minHeartMe,
      minBattles: minBattles,
      categoryOverrides: categoryOverrides,
      membershipMode: map["membership_mode"] as String? ?? "fluxo",
      ticketQuantity: map["ticket_quantity"] as int? ?? 0,
      diamondsPeriod: map["diamonds_period"] as String? ?? "total",
      hoursPeriod: map["hours_period"] as String? ?? "total",
      daysValidatedPeriod: map["days_validated_period"] as String? ?? "total",
      // Dado antigo (sem essas chaves): habilitada = tinha valor preenchido,
      // obrigatoria = true -- preserva exatamente o comportamento de antes
      // dessas duas flags existirem.
      daysEnabled: map["days_enabled"] as bool? ?? (minDays != null),
      daysRequired: map["days_required"] as bool? ?? true,
      daysValidatedEnabled:
          map["days_validated_enabled"] as bool? ?? (minDaysValidated != null),
      daysValidatedRequired: map["days_validated_required"] as bool? ?? true,
      hoursEnabled: map["hours_enabled"] as bool? ?? (minHours != null),
      hoursRequired: map["hours_required"] as bool? ?? true,
      diamondsEnabled:
          map["diamonds_enabled"] as bool? ?? (minDiamonds != null),
      diamondsRequired: map["diamonds_required"] as bool? ?? true,
      heartMeEnabled: map["heart_me_enabled"] as bool? ?? (minHeartMe != null),
      heartMeRequired: map["heart_me_required"] as bool? ?? true,
      battlesEnabled: map["battles_enabled"] as bool? ?? (minBattles != null),
      battlesRequired: map["battles_required"] as bool? ?? true,
      approvalRuleMode: map["approval_rule_mode"] as String? ?? "todas",
      approvalMinPercentage: map["approval_min_percentage"] as int? ?? 100,
      categoryIds: ((map["category_ids"] as List?) ?? const []).cast<String>(),
      selectionMode: map["selection_mode"] as String? ?? "criterios",
      manualStreamerIds: ((map["manual_streamer_ids"] as List?) ?? const [])
          .cast<String>(),
      trackingMode: map["tracking_mode"] as String? ?? "metas",
      pointsMetric: map["points_metric"] as String? ?? "diamonds_current",
      includeNovatos: map["include_novatos"] as bool? ?? true,
      includeInativos: map["include_inativos"] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    "min_days": minDays,
    "max_days_in_agency": maxDaysInAgency,
    "min_days_validated": minDaysValidated,
    "min_hours": minHours,
    "min_diamonds": minDiamonds,
    "max_diamonds": maxDiamonds,
    "min_heart_me": minHeartMe,
    "min_battles": minBattles,
    "category_overrides": categoryOverrides.map(
      (k, v) => MapEntry(k, v.toMap()),
    ),
    "membership_mode": membershipMode,
    "ticket_quantity": ticketQuantity,
    "diamonds_period": diamondsPeriod,
    "hours_period": hoursPeriod,
    "days_validated_period": daysValidatedPeriod,
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
    "selection_mode": selectionMode,
    "manual_streamer_ids": manualStreamerIds,
    "tracking_mode": trackingMode,
    "points_metric": pointsMetric,
    "include_novatos": includeNovatos,
    "include_inativos": includeInativos,
  };

  bool get isEmpty {
    if (selectionMode == "manual") return manualStreamerIds.isEmpty;
    return !(daysEnabled && minDays != null) &&
        maxDaysInAgency == null &&
        !(daysValidatedEnabled && minDaysValidated != null) &&
        !(hoursEnabled && minHours != null) &&
        !(diamondsEnabled && minDiamonds != null) &&
        maxDiamonds == null &&
        !(heartMeEnabled && minHeartMe != null) &&
        !(battlesEnabled && minBattles != null) &&
        categoryIds.isEmpty;
  }
}

class StreamerSnapshot {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? tiktokId;
  final String? categoryId;
  final String? categoryName;
  final int daysInAgency;
  final int daysValidated;
  final double hoursLive;
  final num diamonds;
  final num? heartMe;
  final int battles;
  final DateTime? lastLiveAt;

  /// Preenchidos so quando a tela esta calculando pra um mes especifico
  /// (resolveMonthlySnapshots, program_monthly_stats_service.dart) -- vem de
  /// streamer_stats (mes atual) e monthly_stats (mes anterior fechado, mesma
  /// fonte da aba Metricas Streamers). null significa "nao calculado" (quem
  /// so usa criterio "total" nunca preenche isso) ou "sem mes anterior
  /// fechado ainda pra esse streamer".
  final num? diamondsThisMonth;
  final num? diamondsLastMonth;
  final double? hoursThisMonth;
  final double? hoursLastMonth;
  final int? daysValidatedThisMonth;
  final int? daysValidatedLastMonth;

  const StreamerSnapshot({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.tiktokId,
    this.categoryId,
    this.categoryName,
    required this.daysInAgency,
    required this.daysValidated,
    required this.hoursLive,
    required this.diamonds,
    this.heartMe,
    required this.battles,
    this.lastLiveAt,
    this.diamondsThisMonth,
    this.diamondsLastMonth,
    this.hoursThisMonth,
    this.hoursLastMonth,
    this.daysValidatedThisMonth,
    this.daysValidatedLastMonth,
  });

  /// Copia o snapshot acrescentando os numeros mensais calculados pro
  /// periodo selecionado -- o resto dos dados (acumulado/categoria/etc)
  /// continua o mesmo.
  StreamerSnapshot copyWithMonthly({
    num? diamondsThisMonth,
    num? diamondsLastMonth,
    double? hoursThisMonth,
    double? hoursLastMonth,
    int? daysValidatedThisMonth,
    int? daysValidatedLastMonth,
  }) {
    return StreamerSnapshot(
      id: id,
      displayName: displayName,
      avatarUrl: avatarUrl,
      tiktokId: tiktokId,
      categoryId: categoryId,
      categoryName: categoryName,
      daysInAgency: daysInAgency,
      daysValidated: daysValidated,
      hoursLive: hoursLive,
      diamonds: diamonds,
      heartMe: heartMe,
      battles: battles,
      lastLiveAt: lastLiveAt,
      diamondsThisMonth: diamondsThisMonth,
      diamondsLastMonth: diamondsLastMonth,
      hoursThisMonth: hoursThisMonth,
      hoursLastMonth: hoursLastMonth,
      daysValidatedThisMonth: daysValidatedThisMonth,
      daysValidatedLastMonth: daysValidatedLastMonth,
    );
  }

  /// Sem live nos ultimos 30 dias (ou nunca ficou ao vivo) -- usado pelo
  /// filtro "incluir/nao incluir criadores inativos". Usa last_live_at (ja
  /// confiavel, populado pela importacao) em vez de tentar computar dias/
  /// horas validadas numa janela rolante de 30 dias a partir de
  /// streamer_stat_snapshots, que so tem dado quando alguem abre a tela do
  /// programa sob demanda -- a mesma fragilidade ja corrigida em outros
  /// pontos deste modulo.
  bool get isInactive =>
      lastLiveAt == null || DateTime.now().difference(lastLiveAt!).inDays > 30;
}

const _profileSnapshotSelect =
    "id, display_name, avatar_url, tiktok_creator_id, joined_at, last_live_at, category_id, streamer_categories(name), streamer_stats(days_live, hours_live, diamonds, battles, heart_me)";

StreamerSnapshot _snapshotFromProfileRow(Map<String, dynamic> r) {
  final statsData = r["streamer_stats"];
  Map<String, dynamic>? stats;
  if (statsData is List && statsData.isNotEmpty) {
    stats = statsData.first as Map<String, dynamic>;
  } else if (statsData is Map) {
    stats = statsData as Map<String, dynamic>;
  }
  final catData = r["streamer_categories"];
  final joinedAt = r["joined_at"] != null
      ? DateTime.parse(r["joined_at"] as String)
      : null;

  return StreamerSnapshot(
    id: r["id"] as String,
    displayName: (r["display_name"] as String?) ?? "-",
    avatarUrl: r["avatar_url"] as String?,
    tiktokId: r["tiktok_creator_id"] as String?,
    categoryId: r["category_id"] as String?,
    categoryName: catData is Map ? catData["name"] as String? : null,
    daysInAgency: joinedAt != null
        ? DateTime.now().difference(joinedAt).inDays
        : 0,
    daysValidated: (stats?["days_live"] as num?)?.toInt() ?? 0,
    hoursLive: (stats?["hours_live"] as num?)?.toDouble() ?? 0,
    diamonds: stats?["diamonds"] as num? ?? 0,
    heartMe: stats?["heart_me"] as num?,
    battles: (stats?["battles"] as num?)?.toInt() ?? 0,
    lastLiveAt: r["last_live_at"] != null
        ? DateTime.parse(r["last_live_at"] as String)
        : null,
  );
}

Future<List<StreamerSnapshot>> fetchActiveStreamerSnapshots({
  required String agencyId,
}) async {
  final client = Supabase.instance.client;
  final rows = await client
      .from("profiles")
      .select(_profileSnapshotSelect)
      .eq("agency_id", agencyId)
      .eq("is_active", true);
  return (rows as List)
      .map((r) => _snapshotFromProfileRow(r as Map<String, dynamic>))
      .toList();
}

/// Igual fetchActiveStreamerSnapshots, mas por lista explicita de ids e sem
/// filtro de is_active -- usado na aba Participantes, que precisa mostrar
/// tambem quem ja foi desligado/concluiu (fetchActiveStreamerSnapshots so
/// traz quem esta ativo hoje).
Future<List<StreamerSnapshot>> fetchStreamerSnapshotsByIds({
  required List<String> streamerIds,
}) async {
  if (streamerIds.isEmpty) return const [];
  final client = Supabase.instance.client;
  final rows = await client
      .from("profiles")
      .select(_profileSnapshotSelect)
      .inFilter("id", streamerIds);
  return (rows as List)
      .map((r) => _snapshotFromProfileRow(r as Map<String, dynamic>))
      .toList();
}

/// Quais streamers ja concluiram (com outcome dentre okOutcomes) uma fase
/// -- usado para saber quem ja pode ser considerado no proximo programa da
/// cadeia.
Future<Set<String>> fetchCompletedStreamerIds({
  required String phaseKey,
  List<String> okOutcomes = const ["aprovado", "graduado"],
}) async {
  final client = Supabase.instance.client;
  final rows = await client
      .from("streamer_phase_progress")
      .select("streamer_id")
      .eq("phase_key", phaseKey)
      .inFilter("outcome", okOutcomes);
  return (rows as List)
      .map((r) => r["streamer_id"] as String)
      .whereType<String>()
      .toSet();
}

/// Quem ja tem card (participante ativo ou ja concluido) num programa.
Future<Set<String>> fetchEnrolledStreamerIds({required String phaseKey}) async {
  final client = Supabase.instance.client;
  final rows = await client
      .from("streamer_phase_progress")
      .select("streamer_id")
      .eq("phase_key", phaseKey);
  return (rows as List)
      .map((r) => r["streamer_id"] as String)
      .whereType<String>()
      .toSet();
}

/// Programa anterior na cadeia (quem tem next_program_key OU
/// graduate_program_key apontando pra este) -- centraliza a busca que antes
/// estava duplicada em programa_fluxo_tab.dart e programa_visao_geral_tab.dart.
Future<String?> findPreviousProgramKey({
  required String agencyId,
  required String phaseKey,
}) async {
  final client = Supabase.instance.client;
  final previous = await client
      .from("development_programs")
      .select("program_key")
      .eq("agency_id", agencyId)
      .or(
        "next_program_key.eq." +
            phaseKey +
            ",graduate_program_key.eq." +
            phaseKey,
      )
      .maybeSingle();
  return previous?["program_key"] as String?;
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

/// Resolve o valor a comparar conforme o periodo escolhido pra meta
/// (diamantes/horas/dias validados): total acumulado, o ganho do mes
/// atual/anterior, ou o MAIOR entre os dois (so preenchido quando a tela
/// calculou pra um mes -- ver StreamerSnapshot.copyWithMonthly). null = sem
/// dado ainda pro periodo pedido (nao vira 0 -- so nao passa, sem gerar
/// alerta especifico).
T? _resolveMetric<T extends num>(
  String period,
  T total,
  T? thisMonth,
  T? lastMonth,
) {
  switch (period) {
    case "mes_atual":
      return thisMonth;
    case "mes_anterior":
      return lastMonth;
    case "mes_atual_ou_anterior":
      if (thisMonth == null) return lastMonth;
      if (lastMonth == null) return thisMonth;
      return thisMonth >= lastMonth ? thisMonth : lastMonth;
    case "mes_anterior_prioritario":
      // Prioriza o mes fechado (mais estavel que um mes ainda em andamento);
      // so cai pro mes atual quando o streamer ainda nao tem mes anterior
      // fechado (agenciado a pouco tempo). Usado em tetos (max_diamonds) onde
      // um numero parcial do mes atual nao deve empurrar o streamer pra fora
      // da faixa antes da hora.
      if (lastMonth != null) return lastMonth;
      return thisMonth;
    default:
      return total;
  }
}

T? _categoryOverrideValue<T>(
  ProgramCriteria c,
  String? categoryId,
  T? Function(CategoryOverride) pick,
) {
  if (categoryId == null) return null;
  final o = c.categoryOverrides[categoryId];
  if (o == null) return null;
  return pick(o);
}

/// Compara os numeros atuais do streamer com as metas ATIVAS do programa.
/// "gaps" so lista o que estiver perto de bater (usado nos alertas tipo
/// "faltam 2 horas") -- metas muito distantes nao geram alerta, so deixam o
/// streamer como nao-elegivel. Categoria/dias-maximo/diamantes-maximo
/// continuam sendo filtros duros (fora do conceito de meta), sempre
/// aplicados independente da regra de aprovacao. A regra de aprovacao
/// decide, entre as metas ativas, o que conta pra elegibilidade final:
/// todas / so as obrigatorias / um percentual minimo.
EligibilityResult evaluateEligibility(StreamerSnapshot s, ProgramCriteria c) {
  final novatoOk = c.includeNovatos || s.daysInAgency > 90;
  final inativoOk = c.includeInativos || !s.isInactive;

  // Selecao manual: elegibilidade e so "esta na lista escolhida a dedo",
  // ignorando os checks de meta abaixo -- mas ainda passa pelos hard gates
  // de categoria/novato/inativo (um streamer manualmente escolhido pode
  // deixar de contar se ficar inativo, por exemplo).
  if (c.selectionMode == "manual") {
    final categoryOk =
        c.categoryIds.isEmpty ||
        (s.categoryId != null && c.categoryIds.contains(s.categoryId));
    final onList = c.manualStreamerIds.contains(s.id);
    return EligibilityResult(
      eligible: onList && categoryOk && novatoOk && inativoOk,
    );
  }

  final gaps = <String>[];
  final checks = <_GoalCheck>[];

  if (c.daysEnabled && c.minDays != null) {
    final missing = c.minDays! - s.daysInAgency;
    final passed = missing <= 0;
    if (!passed && missing <= 2)
      gaps.add(
        missing == 1 ? "Falta 1 dia" : "Faltam " + missing.toString() + " dias",
      );
    checks.add(_GoalCheck(passed: passed, required: c.daysRequired));
  }

  final daysValidatedThreshold =
      _categoryOverrideValue<int>(c, s.categoryId, (o) => o.minDaysValidated) ??
      c.minDaysValidated;
  if (c.daysValidatedEnabled && daysValidatedThreshold != null) {
    final value = _resolveMetric(
      c.daysValidatedPeriod,
      s.daysValidated,
      s.daysValidatedThisMonth,
      s.daysValidatedLastMonth,
    );
    if (value == null) {
      checks.add(_GoalCheck(passed: false, required: c.daysValidatedRequired));
    } else {
      final missing = daysValidatedThreshold - value;
      final passed = missing <= 0;
      if (!passed && missing <= 2)
        gaps.add(
          missing == 1
              ? "Falta 1 dia validado"
              : "Faltam " + missing.toString() + " dias validados",
        );
      checks.add(_GoalCheck(passed: passed, required: c.daysValidatedRequired));
    }
  }

  final hoursThreshold =
      _categoryOverrideValue<double>(c, s.categoryId, (o) => o.minHours) ??
      c.minHours;
  if (c.hoursEnabled && hoursThreshold != null) {
    final value = _resolveMetric(
      c.hoursPeriod,
      s.hoursLive,
      s.hoursThisMonth,
      s.hoursLastMonth,
    );
    if (value == null) {
      checks.add(_GoalCheck(passed: false, required: c.hoursRequired));
    } else {
      final missing = hoursThreshold - value;
      final passed = missing <= 0;
      if (!passed && missing <= 5)
        gaps.add("Faltam " + missing.toStringAsFixed(0) + " horas");
      checks.add(_GoalCheck(passed: passed, required: c.hoursRequired));
    }
  }

  final diamondsThreshold =
      _categoryOverrideValue<num>(c, s.categoryId, (o) => o.minDiamonds) ??
      c.minDiamonds;
  final diamondsValue = _resolveMetric(
    c.diamondsPeriod,
    s.diamonds,
    s.diamondsThisMonth,
    s.diamondsLastMonth,
  );
  if (c.diamondsEnabled && diamondsThreshold != null) {
    if (diamondsValue == null) {
      checks.add(_GoalCheck(passed: false, required: c.diamondsRequired));
    } else {
      final missing = diamondsThreshold - diamondsValue;
      final passed = missing <= 0;
      if (!passed && missing <= 1000)
        gaps.add("Faltam " + missing.toStringAsFixed(0) + " diamantes");
      checks.add(_GoalCheck(passed: passed, required: c.diamondsRequired));
    }
  }

  final battlesThreshold =
      _categoryOverrideValue<int>(c, s.categoryId, (o) => o.minBattles) ??
      c.minBattles;
  if (c.battlesEnabled && battlesThreshold != null) {
    final missing = battlesThreshold - s.battles;
    final passed = missing <= 0;
    if (!passed && missing <= 2)
      gaps.add(
        missing == 1
            ? "Falta 1 batalha"
            : "Faltam " + missing.toString() + " batalhas",
      );
    checks.add(_GoalCheck(passed: passed, required: c.battlesRequired));
  }

  if (c.heartMeEnabled && c.minHeartMe != null) {
    final current = s.heartMe;
    final passed = current != null && current >= c.minHeartMe!;
    if (!passed) gaps.add("Heart Me abaixo da meta");
    checks.add(_GoalCheck(passed: passed, required: c.heartMeRequired));
  }

  final categoryOk =
      c.categoryIds.isEmpty ||
      (s.categoryId != null && c.categoryIds.contains(s.categoryId));
  final maxDaysOk =
      c.maxDaysInAgency == null || s.daysInAgency <= c.maxDaysInAgency!;
  final maxDiamondsOk =
      c.maxDiamonds == null ||
      (diamondsValue != null && diamondsValue <= c.maxDiamonds!);
  final hardGatesOk =
      categoryOk && maxDaysOk && maxDiamondsOk && novatoOk && inativoOk;

  bool eligible;
  if (checks.isEmpty) {
    eligible = hardGatesOk;
  } else {
    switch (c.approvalRuleMode) {
      case "obrigatorias":
        final requiredChecks = checks.where((g) => g.required);
        eligible = hardGatesOk && requiredChecks.every((g) => g.passed);
        break;
      case "percentual":
        final passedCount = checks.where((g) => g.passed).length;
        eligible =
            hardGatesOk &&
            (passedCount / checks.length * 100) >= c.approvalMinPercentage;
        break;
      default:
        eligible = hardGatesOk && checks.every((g) => g.passed);
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
  if (c.daysEnabled && c.minDays != null && c.minDays! > 0)
    ratios.add((s.daysInAgency / c.minDays!).clamp(0.0, 1.0));

  final daysValidatedThreshold =
      _categoryOverrideValue<int>(c, s.categoryId, (o) => o.minDaysValidated) ??
      c.minDaysValidated;
  if (c.daysValidatedEnabled &&
      daysValidatedThreshold != null &&
      daysValidatedThreshold > 0) {
    final value = _resolveMetric(
      c.daysValidatedPeriod,
      s.daysValidated,
      s.daysValidatedThisMonth,
      s.daysValidatedLastMonth,
    );
    if (value != null)
      ratios.add((value / daysValidatedThreshold).clamp(0.0, 1.0));
  }

  final hoursThreshold =
      _categoryOverrideValue<double>(c, s.categoryId, (o) => o.minHours) ??
      c.minHours;
  if (c.hoursEnabled && hoursThreshold != null && hoursThreshold > 0) {
    final value = _resolveMetric(
      c.hoursPeriod,
      s.hoursLive,
      s.hoursThisMonth,
      s.hoursLastMonth,
    );
    if (value != null) ratios.add((value / hoursThreshold).clamp(0.0, 1.0));
  }

  final diamondsThreshold =
      _categoryOverrideValue<num>(c, s.categoryId, (o) => o.minDiamonds) ??
      c.minDiamonds;
  if (c.diamondsEnabled &&
      diamondsThreshold != null &&
      diamondsThreshold.toDouble() > 0) {
    final value = _resolveMetric(
      c.diamondsPeriod,
      s.diamonds,
      s.diamondsThisMonth,
      s.diamondsLastMonth,
    );
    if (value != null)
      ratios.add(
        (value.toDouble() / diamondsThreshold.toDouble()).clamp(0.0, 1.0),
      );
  }

  final battlesThreshold =
      _categoryOverrideValue<int>(c, s.categoryId, (o) => o.minBattles) ??
      c.minBattles;
  if (c.battlesEnabled && battlesThreshold != null && battlesThreshold > 0)
    ratios.add((s.battles / battlesThreshold).clamp(0.0, 1.0));
  if (c.heartMeEnabled && c.minHeartMe != null && c.minHeartMe!.toDouble() > 0)
    ratios.add(
      ((s.heartMe ?? 0).toDouble() / c.minHeartMe!.toDouble()).clamp(0.0, 1.0),
    );
  if (ratios.isEmpty) return 1.0;
  return ratios.reduce((a, b) => a + b) / ratios.length;
}

/// Faixas de progresso usadas em Participantes e Fluxo pra classificar quem
/// esta indo mal/bem/perto de bater a meta -- fatorado aqui pra nao duplicar
/// o numero magico em cada aba.
const double criticoThreshold = 0.4;
const double proximoMetaThreshold = 0.7;

/// Valor usado pra ranquear um streamer no modo "pontos" (trackingMode ==
/// "pontos"), conforme a metrica escolhida em pointsMetric. Sem dado ainda
/// pro periodo pedido (ex: sem mes anterior fechado), retorna 0 -- entra no
/// ranking, so fica no fim.
num pointsValueFor(StreamerSnapshot s, ProgramCriteria c) {
  switch (c.pointsMetric) {
    case "diamonds_last_month":
      return s.diamondsLastMonth ?? 0;
    case "days_validated":
      return s.daysValidatedThisMonth ?? s.daysValidated;
    case "battles":
      return s.battles;
    case "heart_me":
      return s.heartMe ?? 0;
    default:
      return s.diamondsThisMonth ?? s.diamonds;
  }
}

/// Ranqueia o grupo (do maior pro menor) pela metrica escolhida em
/// pointsMetric -- so exibicao (Visao Geral/Fluxo), nunca decide
/// entrada/saida automatica (isso continua sendo so trackingMode == "metas",
/// via syncEligibleStreamers/syncFaixaMembership).
List<StreamerSnapshot> rankByPoints(
  List<StreamerSnapshot> pool,
  ProgramCriteria c,
) {
  final sorted = [...pool];
  sorted.sort((a, b) => pointsValueFor(b, c).compareTo(pointsValueFor(a, c)));
  return sorted;
}

/// Roda sob demanda (ao abrir a tela, sem depender de tarefa agendada):
/// para cada streamer elegivel que ainda nao tem card neste programa (e,
/// se houver um programa anterior na cadeia, ja concluiu ele), cria o card
/// automaticamente. So promove -- nunca remove. Usado por programas em modo
/// "fluxo" (Onboarding), cuja saida e sempre por avaliacao manual. Programa
/// sem nenhum criterio definido nao auto-inscreve ninguem (evita "todo mundo
/// entra" antes de configurar de verdade).
Future<int> syncEligibleStreamers({
  required String phaseKey,
  required ProgramCriteria criteria,
  required List<StreamerSnapshot> snapshots,
  required Set<String> enrolledStreamerIds,
  Set<String>? previousProgramCompletedStreamerIds,
}) async {
  if (criteria.isEmpty || criteria.trackingMode == "pontos") return 0;
  var created = 0;
  for (final s in snapshots) {
    if (enrolledStreamerIds.contains(s.id)) continue;
    if (previousProgramCompletedStreamerIds != null &&
        !previousProgramCompletedStreamerIds.contains(s.id))
      continue;
    if (evaluateEligibility(s, criteria).eligible) {
      try {
        await createProgramCardIfNeeded(phaseKey: phaseKey, streamerId: s.id);
        created++;
      } catch (_) {
        // Um streamer com dado inconsistente nao pode travar a sincronizacao
        // dos demais -- segue pro proximo.
      }
    }
  }
  return created;
}

/// Reativa o card arquivado existente do streamer nesse programa (limpa
/// completed_at/archived_at/outcome, volta pra primeira etapa ativa) ou cria
/// um novo se ele nunca teve card ali -- usado tanto pela sincronizacao
/// automatica (syncFaixaMembership) quanto pela adicao manual num programa
/// faixa (que precisa reaproveitar a mesma linha, nao criar uma duplicada).
/// Respeita manual_override: nao reativa um card que o gestor marcou como
/// removido manualmente.
Future<void> reactivateOrCreateCard({
  required String phaseKey,
  required String streamerId,
}) async {
  final client = Supabase.instance.client;
  final existing = await client
      .from("streamer_phase_progress")
      .select("id, completed_at, manual_override")
      .eq("streamer_id", streamerId)
      .eq("phase_key", phaseKey)
      .maybeSingle();
  if (existing == null) {
    await createProgramCardIfNeeded(phaseKey: phaseKey, streamerId: streamerId);
    return;
  }
  if (existing["manual_override"] != null) return;
  if (existing["completed_at"] == null) return;

  // Mesma ressalva de createProgramCardIfNeeded: perfil pode nao ter
  // agency_id preenchido -- cai pro agency_id do programa nesse caso.
  final profile = await client
      .from("profiles")
      .select("agency_id")
      .eq("id", streamerId)
      .single();
  var agencyId = profile["agency_id"] as String?;
  if (agencyId == null) {
    final program = await client
        .from("development_programs")
        .select("agency_id")
        .eq("program_key", phaseKey)
        .maybeSingle();
    agencyId = program?["agency_id"] as String?;
  }
  if (agencyId == null) return;
  final firstStage = await client
      .from("streamer_phase_stages")
      .select("stage_key")
      .eq("agency_id", agencyId)
      .eq("phase_key", phaseKey)
      .eq("is_active", true)
      .order("order_index", ascending: true)
      .limit(1)
      .maybeSingle();
  if (firstStage == null) return;

  await client
      .from("streamer_phase_progress")
      .update({
        "completed_at": null,
        "archived_at": null,
        "archived_by": null,
        "outcome": null,
        "outcome_reason": null,
        "outcome_note": null,
        "stage_key": firstStage["stage_key"],
        "stage_changed_at": DateTime.now().toIso8601String(),
      })
      .eq("id", existing["id"]);
}

Future<void> _grantTicketIfNeeded({
  required String programId,
  required String streamerId,
  required int quantity,
  required StreamerSnapshot snapshot,
  required int year,
  required int month,
}) async {
  final client = Supabase.instance.client;
  final periodKey = year.toString() + "-" + month.toString().padLeft(2, "0");
  final existing = await client
      .from("program_awards")
      .select("id")
      .eq("program_id", programId)
      .eq("streamer_id", streamerId)
      .eq("ticket_period_key", periodKey)
      .maybeSingle();
  if (existing != null) return;

  final reason =
      "Ticket automatico -- meta batida em " +
      monthLabel(year, month) +
      ". Dias na agencia: " +
      snapshot.daysInAgency.toString() +
      ", horas: " +
      snapshot.hoursLive.toStringAsFixed(1) +
      "h, diamantes: " +
      snapshot.diamonds.toStringAsFixed(0) +
      ".";

  await client.from("program_awards").insert({
    "program_id": programId,
    "streamer_id": streamerId,
    "title": quantity.toString() + "x Ticket sorteio",
    "items": [
      {"name": "Ticket sorteio", "quantity": quantity, "value": null},
    ],
    "status": "pendente",
    "ticket_period_key": periodKey,
    "reason": reason,
    "created_by": client.auth.currentUser?.id,
  });
}

/// Ponto de entrada unico da sincronizacao automatica, chamado sob demanda
/// (ao abrir Visao Geral ou Participantes) tanto pra programas em modo
/// "fluxo" (so promove) quanto "faixa" (promove e remove) -- centraliza a
/// busca de snapshots/inscritos/programa anterior, que antes seria
/// duplicada em cada tela que precisa disparar a sincronizacao.
Future<void> runProgramSync({
  required String programId,
  required String phaseKey,
  required String agencyId,
  required ProgramCriteria criteria,
  required int year,
  required int month,
}) async {
  if (criteria.isEmpty) return;
  final client = Supabase.instance.client;
  final activeAgencySnapshots = await fetchActiveStreamerSnapshots(
    agencyId: agencyId,
  );
  final enrolledIds = await fetchEnrolledStreamerIds(phaseKey: phaseKey);

  if (criteria.membershipMode == "faixa") {
    final candidateIds = {
      ...activeAgencySnapshots.map((s) => s.id),
      ...enrolledIds,
    }.toList();
    final candidateSnapshotsRaw = await fetchStreamerSnapshotsByIds(
      streamerIds: candidateIds,
    );
    final candidateSnapshots = await resolveMonthlySnapshots(
      snapshots: candidateSnapshotsRaw,
      criteria: criteria,
      agencyId: agencyId,
      year: year,
      month: month,
    );
    final activeRows = await client
        .from("streamer_phase_progress")
        .select("id, streamer_id, manual_override")
        .eq("phase_key", phaseKey)
        .filter("completed_at", "is", null);
    await syncFaixaMembership(
      programId: programId,
      phaseKey: phaseKey,
      criteria: criteria,
      snapshots: candidateSnapshots,
      activeProgressRows: (activeRows as List).cast<Map<String, dynamic>>(),
      year: year,
      month: month,
    );
  } else {
    final previousKey = await findPreviousProgramKey(
      agencyId: agencyId,
      phaseKey: phaseKey,
    );
    final completedPrev = previousKey != null
        ? await fetchCompletedStreamerIds(phaseKey: previousKey)
        : null;
    await syncEligibleStreamers(
      phaseKey: phaseKey,
      criteria: criteria,
      snapshots: activeAgencySnapshots,
      enrolledStreamerIds: enrolledIds,
      previousProgramCompletedStreamerIds: completedPrev,
    );
  }
}

/// Roda sob demanda: para programas em modo "faixa", sincroniza entrada E
/// saida de membros conforme os criterios do mes selecionado -- reativa/cria
/// o card de quem passou a ser elegivel e ainda nao tem card ativo, e arquiva
/// (sem apagar -- outcome "saiu_criterio") o card de quem tinha um card ativo
/// e deixou de ser elegivel. Nunca mexe em card com manual_override setado
/// (correcao manual do gestor). Concede ticket automatico quando configurado
/// (ticketQuantity > 0) e ainda nao concedido pra aquele streamer/mes.
Future<void> syncFaixaMembership({
  required String programId,
  required String phaseKey,
  required ProgramCriteria criteria,
  required List<StreamerSnapshot> snapshots,
  required List<Map<String, dynamic>> activeProgressRows,
  required int year,
  required int month,
}) async {
  if (criteria.isEmpty || criteria.trackingMode == "pontos") return;
  final activeByStreamer = <String, Map<String, dynamic>>{
    for (final r in activeProgressRows) r["streamer_id"] as String: r,
  };

  for (final s in snapshots) {
    final eligible = evaluateEligibility(s, criteria).eligible;
    final activeRow = activeByStreamer[s.id];

    try {
      if (eligible && activeRow == null) {
        await reactivateOrCreateCard(phaseKey: phaseKey, streamerId: s.id);
      } else if (!eligible &&
          activeRow != null &&
          activeRow["manual_override"] == null) {
        await Supabase.instance.client
            .from("streamer_phase_progress")
            .update({
              "completed_at": DateTime.now().toIso8601String(),
              "archived_at": DateTime.now().toIso8601String(),
              "outcome": "saiu_criterio",
            })
            .eq("id", activeRow["id"]);
      }
    } catch (_) {
      // Um streamer com dado inconsistente nao pode travar a sincronizacao
      // dos demais -- segue pro proximo.
    }

    if (eligible && criteria.ticketQuantity > 0) {
      await _grantTicketIfNeeded(
        programId: programId,
        streamerId: s.id,
        quantity: criteria.ticketQuantity,
        snapshot: s,
        year: year,
        month: month,
      );
    }
  }
}
