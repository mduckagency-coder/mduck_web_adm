import "package:supabase_flutter/supabase_flutter.dart";

/// Chave da primeira fase do acompanhamento por fases da Gestao. Fases
/// futuras (Acompanhamento 15-30, Novatos, etc.) reaproveitam as mesmas
/// tabelas streamer_phase_* com uma chave diferente.
const onboardingPhaseKey = "onboarding_0_15";

/// Coluna de espera: streamers ja oficialmente na agencia (vinculados ao
/// cadastro), aguardando o gestor puxar o card para "Dia 1" e comecar a
/// contagem do onboarding. Sem checklist obrigatorio, entao o card sempre
/// pode ser arrastado dali pra frente livremente.
const _stagingStageKey = "dia_0";

/// Chave da etapa final de decisao (aprovado / plano de recuperacao /
/// desligado), depois do dia_15. Sem checklist obrigatorio, mesmo padrao do
/// dia_0. Exibida hoje como "Conclusao do Onboarding" (o nome mudou, a
/// stage_key continua "avaliacao" pra nao mexer em dado ja gravado).
const _evaluationStageKey = "avaliacao";

/// Etapa pra onde o card vai quando o gestor escolhe "Plano de Recuperacao"
/// na conclusao -- fica parado ali (card continua ativo, sem completed_at)
/// ate uma reavaliacao (ver sendOnboardingCardToRecovery/evaluateOnboardingCard).
const _recoveryStageKey = "plano_recuperacao";

const _defaultStages = [
  (_stagingStageKey, "0 - Proximos Agenciados"),
  ("dia_1", "Dia 1 - Boas-vindas"),
  ("dia_2", "Dia 2 - Materiais"),
  ("dia_3", "Dia 3 - Configuracao"),
  ("dia_4", "Dia 4 - Primeira Live"),
  ("dia_5", "Dia 5 - Primeiro Acompanhamento"),
  ("dia_6", "Dia 6 - Duvidas"),
  ("dia_7", "Dia 7 - Primeira Semana"),
  ("dia_8", "Dia 8 - Engajamento"),
  ("dia_9", "Dia 9 - Acompanhamento"),
  ("dia_10", "Dia 10 - Correcoes"),
  ("dia_11", "Dia 11 - Desenvolvimento"),
  ("dia_12", "Dia 12 - Evolucao"),
  ("dia_13", "Dia 13 - Preparacao"),
  ("dia_14", "Dia 14 - Pre-avaliacao"),
  ("dia_15", "Dia 15 - Ultimo Dia"),
  (_evaluationStageKey, "Conclusão do Onboarding"),
  (_recoveryStageKey, "Plano de Recuperação"),
];

/// Cor padrao de cada coluna por faixa de dias: dia 0 sozinho, dias 1-3,
/// dias 4-7, dias 8-15, a etapa de decisao final e a de recuperacao com cor
/// propria.
String _defaultStageColor(String stageKey) {
  if (stageKey == _stagingStageKey) return "#F2994A";
  if (stageKey == _evaluationStageKey) return "#EB5757";
  if (stageKey == _recoveryStageKey) return "#F2C94C";
  const faixa1a3 = {"dia_1", "dia_2", "dia_3"};
  const faixa4a7 = {"dia_4", "dia_5", "dia_6", "dia_7"};
  if (faixa1a3.contains(stageKey)) return "#2D9CDB";
  if (faixa4a7.contains(stageKey)) return "#7A0BD4";
  return "#27AE60"; // dia_8..dia_15
}

/// Checklist proprio de cada dia (nao e mais o mesmo conjunto generico
/// repetido em todas as etapas -- cada dia tem seus itens especificos).
const _defaultChecklistItemsByStage = {
  "dia_1": [
    ("entrou_grupo", "Entrou no grupo"),
    ("recebeu_boas_vindas", "Recebeu boas-vindas"),
    ("confirmou_recebimento", "Confirmou recebimento"),
  ],
  "dia_2": [
    ("material_enviado", "Material enviado"),
    ("confirmou_recebimento", "Confirmou recebimento"),
  ],
  "dia_3": [
    ("configurou_tiktok", "Configurou TikTok"),
    ("configurou_obs", "Configurou OBS"),
  ],
  "dia_4": [
    ("realizou_primeira_live", "Realizou a primeira live"),
    ("feedback_registrado", "Feedback da live registrado"),
  ],
  "dia_5": [
    ("acompanhamento_realizado", "Acompanhamento realizado"),
    ("duvidas_registradas", "Duvidas registradas"),
  ],
  "dia_6": [
    ("duvidas_esclarecidas", "Duvidas esclarecidas"),
    ("feedback_registrado", "Feedback registrado"),
  ],
  "dia_7": [
    ("resumo_semana_enviado", "Resumo da semana enviado"),
    ("metas_proxima_semana", "Metas da proxima semana definidas"),
  ],
  "dia_8": [
    ("engajamento_verificado", "Engajamento verificado"),
    ("dicas_conteudo_enviadas", "Dicas de conteudo enviadas"),
  ],
  "dia_9": [
    ("acompanhamento_realizado", "Acompanhamento realizado"),
    ("feedback_registrado", "Feedback registrado"),
  ],
  "dia_10": [
    ("pontos_melhoria_identificados", "Pontos de melhoria identificados"),
    ("correcoes_orientadas", "Correcoes orientadas"),
  ],
  "dia_11": [
    ("plano_desenvolvimento_definido", "Plano de desenvolvimento definido"),
    ("acompanhamento_realizado", "Acompanhamento realizado"),
  ],
  "dia_12": [
    ("evolucao_verificada", "Evolucao verificada"),
    ("feedback_registrado", "Feedback registrado"),
  ],
  "dia_13": [
    ("preparacao_avaliacao", "Preparacao para avaliacao final"),
    ("duvidas_finais_esclarecidas", "Duvidas finais esclarecidas"),
  ],
  "dia_14": [
    ("pre_avaliacao_realizada", "Pre-avaliacao realizada"),
    ("pontos_atencao_registrados", "Pontos de atencao registrados"),
  ],
  "dia_15": [
    ("avaliacao_final_preparada", "Avaliacao final preparada"),
    ("resumo_onboarding_enviado", "Resumo do onboarding enviado"),
  ],
};

/// Chave da 2a fase do acompanhamento por fases -- continuacao do
/// Onboarding 0-15 Dias, dias 16 a 31. Usa uma chave nova (nao "onboarding_30")
/// porque essa string ja e usada por um program_key totalmente diferente no
/// modulo Programas de Desenvolvimento (auto-inscricao por criterio de
/// diamantes) -- reusar causaria duas logicas de seed/etapa disputando as
/// mesmas linhas de streamer_phase_stages/streamer_phase_progress.
const onboardingSecondPhaseKey = "onboarding_16_31";

const _secondStagingStageKey = "recebidos";
const _secondEvaluationStageKey = "conclusao";

const _defaultStagesModule2 = [
  (_secondStagingStageKey, "Recebidos"),
  ("dia_16", "Dia 16"),
  ("dia_17", "Dia 17"),
  ("dia_18", "Dia 18"),
  ("dia_19", "Dia 19"),
  ("dia_20", "Dia 20"),
  ("dia_21", "Dia 21"),
  ("dia_22", "Dia 22"),
  ("dia_23", "Dia 23"),
  ("dia_24", "Dia 24"),
  ("dia_25", "Dia 25"),
  ("dia_26", "Dia 26"),
  ("dia_27", "Dia 27"),
  ("dia_28", "Dia 28"),
  ("dia_29", "Dia 29"),
  ("dia_30", "Dia 30"),
  ("dia_31", "Dia 31"),
  (_secondEvaluationStageKey, "Conclusão"),
];

/// Mesma paleta do modulo 1 (dia 0/staging em laranja, faixas de dias em
/// azul/roxo/verde, conclusao em vermelho) -- sem inventar cor nova, pra
/// manter a mesma identidade visual entre os dois modulos.
String _defaultStageColorModule2(String stageKey) {
  if (stageKey == _secondStagingStageKey) return "#F2994A";
  if (stageKey == _secondEvaluationStageKey) return "#EB5757";
  const faixa1 = {"dia_16", "dia_17", "dia_18", "dia_19"};
  const faixa2 = {"dia_20", "dia_21", "dia_22", "dia_23"};
  if (faixa1.contains(stageKey)) return "#2D9CDB";
  if (faixa2.contains(stageKey)) return "#7A0BD4";
  return "#27AE60"; // dia_24..dia_31
}

/// Sem checklist padrao pro modulo 2 ainda -- o gestor configura pela
/// mesma tela "Configurar colunas" (onboarding_stage_config_dialog.dart, ja
/// generica por phase_key) conforme for definindo o processo dessa fase.
const _defaultChecklistItemsByStageModule2 = <String, List<(String, String)>>{};

/// Chave da 3a fase -- continuacao do Onboarding 16-31 Dias pra quem foi
/// destacado como "streamer em potencial" (ver requirePotentialToPromote em
/// evaluateOnboardingCard). Chave propria, sem colisao com o modulo
/// Programas de Desenvolvimento (mesmo motivo do onboarding_16_31: novatos_
/// destaque/veteranos_40k/top_ducker_80k/etc ja usam esse espaco de nomes
/// pra criterios automaticos de diamantes -- aqui e um acompanhamento
/// manual, guiado pelo gestor).
const onboardingThirdPhaseKey = "graduacao_novatos";

const _thirdStagingStageKey = "entrada_graduacao";
const _thirdEvaluationStageKey = "avaliacao_graduacao";

/// Sequencia de colunas ate os 3 marcos de diamantes pedidos (40k, 80k,
/// 150k) -- mesmo padrao das outras 2 fases: coluna de entrada sem
/// checklist, colunas de progresso com checklist proprio, avaliacao final
/// no fim.
const _defaultStagesModule3 = [
  (_thirdStagingStageKey, "Entrada na Graduação"),
  ("plano_metas", "Plano de Metas"),
  ("rumo_40k", "Rumo aos 40k"),
  ("rumo_80k", "Rumo aos 80k"),
  ("rumo_150k", "Rumo aos 150k"),
  (_thirdEvaluationStageKey, "Avaliação de Graduação"),
];

String _defaultStageColorModule3(String stageKey) {
  if (stageKey == _thirdStagingStageKey) return "#F2994A";
  if (stageKey == _thirdEvaluationStageKey) return "#EB5757";
  const faixaAzul = {"plano_metas", "rumo_40k"};
  if (faixaAzul.contains(stageKey)) return "#2D9CDB";
  return "#7A0BD4"; // rumo_80k, rumo_150k
}

const _defaultChecklistItemsByStageModule3 = {
  "plano_metas": [
    ("conversa_boas_vindas", "Conversa de boas-vindas a Graduacao realizada"),
    ("metas_explicadas", "Metas de diamantes explicadas (40k/80k/150k)"),
    ("cronograma_definido", "Cronograma de lives definido com o streamer"),
  ],
  "rumo_40k": [
    ("frequencia_acompanhada", "Frequencia de lives acompanhada"),
    ("dicas_conteudo_enviadas", "Dicas de conteudo/categoria enviadas"),
    ("checkin_semanal", "Check-in semanal realizado"),
    ("meta_40k_atingida", "Meta de 40k atingida"),
  ],
  "rumo_80k": [
    ("parabenizacao_40k", "Parabenizacao pelos 40k enviada"),
    ("estrategia_revisada", "Estrategia de crescimento revisada"),
    ("batalhas_incentivadas", "Batalhas/colabs incentivadas"),
    ("meta_80k_atingida", "Meta de 80k atingida"),
  ],
  "rumo_150k": [
    ("parabenizacao_80k", "Parabenizacao pelos 80k enviada"),
    ("plano_consistencia", "Plano de consistencia para 150k definido"),
    ("acompanhamento_horas_dias", "Acompanhamento de horas/dias validos"),
    ("meta_150k_atingida", "Meta de 150k atingida"),
  ],
};

bool _isEvaluationStage(String phaseKey, String stageKey) {
  if (phaseKey == onboardingThirdPhaseKey) return stageKey == _thirdEvaluationStageKey;
  if (phaseKey == onboardingSecondPhaseKey) return stageKey == _secondEvaluationStageKey;
  return stageKey == _evaluationStageKey;
}

bool _isRecoveryStage(String phaseKey, String stageKey) =>
    phaseKey == onboardingPhaseKey && stageKey == _recoveryStageKey;

/// Garante que a agencia tenha as colunas/checklist padrao da fase
/// informada (Onboarding 0-15 Dias por padrao, ou Onboarding 16-31 Dias).
/// Idempotente (so insere o que ainda nao existe), mesmo padrao de
/// CalendarService.seedDefaultCategories. Util como fallback para agencias
/// criadas depois da migration 0007 ja ter rodado.
Future<void> seedOnboardingPhaseStages({
  String? agencyId,
  String phaseKey = onboardingPhaseKey,
}) async {
  final client = Supabase.instance.client;
  agencyId ??=
      (await client
              .from("managers")
              .select("agency_id")
              .eq("id", client.auth.currentUser!.id)
              .single())["agency_id"]
          as String;

  final List<(String, String)> defaultStages;
  final String Function(String) colorFn;
  final Map<String, List<(String, String)>> checklistMap;
  if (phaseKey == onboardingThirdPhaseKey) {
    defaultStages = _defaultStagesModule3;
    colorFn = _defaultStageColorModule3;
    checklistMap = _defaultChecklistItemsByStageModule3;
  } else if (phaseKey == onboardingSecondPhaseKey) {
    defaultStages = _defaultStagesModule2;
    colorFn = _defaultStageColorModule2;
    checklistMap = _defaultChecklistItemsByStageModule2;
  } else {
    defaultStages = _defaultStages;
    colorFn = _defaultStageColor;
    checklistMap = _defaultChecklistItemsByStage;
  }

  final existing = await client
      .from("streamer_phase_stages")
      .select("stage_key")
      .eq("agency_id", agencyId)
      .eq("phase_key", phaseKey);
  final existingKeys = (existing as List)
      .map((r) => r["stage_key"] as String)
      .toSet();
  final missing = defaultStages
      .where((s) => !existingKeys.contains(s.$1))
      .toList();
  if (missing.isEmpty) return;

  final stageRows = missing
      .map(
        (s) => {
          "agency_id": agencyId,
          "phase_key": phaseKey,
          "stage_key": s.$1,
          "name": s.$2,
          "order_index": defaultStages.indexOf(s),
          "color": colorFn(s.$1),
          "is_evaluation_stage": _isEvaluationStage(phaseKey, s.$1),
          "is_recovery_stage": _isRecoveryStage(phaseKey, s.$1),
        },
      )
      .toList();
  await client.from("streamer_phase_stages").insert(stageRows);

  for (final stage in missing) {
    final items = checklistMap[stage.$1];
    if (items == null) continue;
    final itemRows = items
        .asMap()
        .entries
        .map(
          (entry) => {
            "agency_id": agencyId,
            "phase_key": phaseKey,
            "stage_key": stage.$1,
            "item_key": entry.value.$1,
            "label": entry.value.$2,
            "order_index": entry.key + 1,
          },
        )
        .toList();
    await client.from("streamer_phase_checklist_items").insert(itemRows);
  }
}

String _phaseLabel(String phaseKey) {
  if (phaseKey == onboardingThirdPhaseKey) return "Graduação Novatos";
  if (phaseKey == onboardingSecondPhaseKey) return "Onboarding 16-31 Dias";
  return "Onboarding 0-15 Dias";
}

/// Cria (ou promove) o card do streamer na primeira coluna da fase
/// informada (Onboarding 0-15 Dias por padrao). Chamada sempre que o
/// recrutador conclui o checklist de onboarding (se o streamer ja estiver
/// vinculado), quando o streamer e vinculado depois (se o checklist ja
/// estava concluido), ou pela promocao automatica pro Onboarding 16-31 Dias
/// quando o gestor aprova o card no modulo anterior (ver
/// evaluateOnboardingCard). Se ja existir um card "pre-vinculo" criado a
/// partir do lead (ver createOnboardingLeadCardIfNeeded -- so acontece pra
/// onboardingPhaseKey, leads nunca entram direto na 2a fase), promove essa
/// mesma linha em vez de duplicar -- preserva etapa/historico. Idempotente:
/// nao duplica card se ja existir para esse streamer+fase.
Future<void> createOnboardingPhaseCardIfNeeded({
  required String streamerId,
  String phaseKey = onboardingPhaseKey,
  // Quando o chamador ja sabe de qual lead veio o vinculo (ex: o gestor
  // clicou "Vincular" num card especifico), passa aqui -- evita depender
  // do reverse lookup por leads.converted_streamer_id abaixo, que so acha o
  // lead se aquele update tiver persistido antes (se algo deu errado ali,
  // esse lookup falha e o card antigo fica orfao pra sempre).
  String? leadId,
}) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser!.id;

  final me = await client
      .from("managers")
      .select("agency_id")
      .eq("id", userId)
      .single();
  final agencyId = me["agency_id"] as String;

  final profile = await client
      .from("profiles")
      .select("assigned_manager_id")
      .eq("id", streamerId)
      .maybeSingle();
  final assignedManagerId = profile?["assigned_manager_id"] as String?;

  var resolvedLeadId = leadId;
  if (resolvedLeadId == null) {
    final lead = await client
        .from("leads")
        .select("id")
        .eq("converted_streamer_id", streamerId)
        .maybeSingle();
    resolvedLeadId = lead?["id"] as String?;
  }

  // Resolve todos os gestores ja definidos para este streamer: prioriza os
  // gestores do lead (lead_onboarding_gestores, suporta varios -- e o que
  // o recrutador preenche em "Streamers Agenciados"), com fallback para
  // profiles.assigned_manager_id (streamers sem lead, ex. criados
  // manualmente via "Novo Agenciado" direto no Kanban do Gestor).
  final managerIds = <String>{};
  if (resolvedLeadId != null) {
    final gestores = await client
        .from("lead_onboarding_gestores")
        .select("manager_id")
        .eq("lead_id", resolvedLeadId);
    managerIds.addAll((gestores as List).map((g) => g["manager_id"] as String));
  }
  if (assignedManagerId != null) managerIds.add(assignedManagerId);

  final leadCard = resolvedLeadId != null
      ? await client
            .from("streamer_phase_progress")
            .select("id")
            .eq("lead_id", resolvedLeadId)
            .eq("phase_key", phaseKey)
            .maybeSingle()
      : null;

  final existing = await client
      .from("streamer_phase_progress")
      .select("id")
      .eq("streamer_id", streamerId)
      .eq("phase_key", phaseKey)
      .maybeSingle();

  // Ja existe um card promovido pra esse streamer (de uma tentativa
  // anterior que conseguiu criar o card novo mas nao atualizar/apagar o
  // "pre-vinculo" antigo) -- em vez de deixar o card antigo preso pra
  // sempre mostrando "Aguardando vinculo", junta os gestores dele no card
  // valido e apaga o duplicado.
  if (existing != null && leadCard != null && existing["id"] != leadCard["id"]) {
    final staleManagers = await client
        .from("streamer_phase_progress_managers")
        .select("manager_id")
        .eq("progress_id", leadCard["id"]);
    final staleManagerIds = (staleManagers as List)
        .map((m) => m["manager_id"] as String)
        .toList();
    if (staleManagerIds.isNotEmpty) {
      await addManagersToCard(
        progressId: existing["id"] as String,
        managerIds: staleManagerIds,
        addedBy: userId,
      );
    }
    await client
        .from("streamer_phase_progress")
        .delete()
        .eq("id", leadCard["id"] as String);
    return;
  }

  if (existing != null) return;

  String progressId;
  if (leadCard != null) {
    progressId = leadCard["id"] as String;
    final promoted = await client
        .from("streamer_phase_progress")
        .update({
          "streamer_id": streamerId,
          "lead_id": null,
          "manager_id": assignedManagerId,
        })
        .eq("id", progressId)
        .select("id");
    if ((promoted as List).isEmpty) {
      throw Exception(
        "Nao foi possivel promover o card (sem permissao para editar este registro). Avise um coordenador/admin.",
      );
    }
    try {
      await client.from("streamer_phase_history").insert({
        "streamer_id": streamerId,
        "phase_key": phaseKey,
        "action": "vinculado_streamer",
        "detail": "Streamer oficial vinculado ao card de onboarding",
        "performed_by": userId,
      });
    } catch (_) {}
  } else {
    await seedOnboardingPhaseStages(agencyId: agencyId, phaseKey: phaseKey);

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

    final inserted = await client
        .from("streamer_phase_progress")
        .insert({
          "streamer_id": streamerId,
          "phase_key": phaseKey,
          "stage_key": firstStage["stage_key"],
          "manager_id": assignedManagerId,
          "agency_id": agencyId,
          "created_by": userId,
        })
        .select("id")
        .single();
    progressId = inserted["id"] as String;

    try {
      await client.from("streamer_phase_history").insert({
        "streamer_id": streamerId,
        "phase_key": phaseKey,
        "action": "entrada_onboarding",
        "detail": "Entrou no " + _phaseLabel(phaseKey),
        "performed_by": userId,
      });
    } catch (_) {}
  }

  if (managerIds.isNotEmpty) {
    await addManagersToCard(
      progressId: progressId,
      managerIds: managerIds.toList(),
      addedBy: userId,
    );
    for (final managerId in managerIds) {
      try {
        await client.from("manager_notifications").insert({
          "manager_id": managerId,
          "subject": "Novo streamer no " + _phaseLabel(phaseKey),
          "message":
              "Um streamer sob sua gestao entrou no " +
              _phaseLabel(phaseKey) +
              ".",
          "streamer_id": streamerId,
        });
      } catch (_) {}
    }
  }
}

/// Cria o card "pre-vinculo" do Onboarding 0-15 Dias assim que o
/// recrutador marca "Convite enviado", direto a partir do lead -- antes
/// mesmo do streamer ser oficialmente vinculado ao cadastro. streamer_id
/// fica nulo e lead_id preenchido; quando o vinculo oficial acontecer,
/// createOnboardingPhaseCardIfNeeded promove essa mesma linha. Sem
/// checklist (fica na etapa dia_0, que nao tem checklist obrigatorio).
/// Idempotente: nao duplica card se ja existir para esse lead+fase, e nao
/// faz nada se o lead ja tiver sido oficialmente vinculado (nesse caso o
/// fluxo correto e createOnboardingPhaseCardIfNeeded).
Future<void> createOnboardingLeadCardIfNeeded({required String leadId}) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser!.id;

  final lead = await client
      .from("leads")
      .select("id, converted_streamer_id")
      .eq("id", leadId)
      .maybeSingle();
  if (lead == null || lead["converted_streamer_id"] != null) return;

  final existing = await client
      .from("streamer_phase_progress")
      .select("id")
      .eq("lead_id", leadId)
      .eq("phase_key", onboardingPhaseKey)
      .maybeSingle();
  if (existing != null) return;

  final me = await client
      .from("managers")
      .select("agency_id")
      .eq("id", userId)
      .single();
  final agencyId = me["agency_id"] as String;

  await seedOnboardingPhaseStages(agencyId: agencyId);

  final firstStage = await client
      .from("streamer_phase_stages")
      .select("stage_key")
      .eq("agency_id", agencyId)
      .eq("phase_key", onboardingPhaseKey)
      .eq("is_active", true)
      .order("order_index", ascending: true)
      .limit(1)
      .maybeSingle();
  if (firstStage == null) return;

  final gestoresRows = await client
      .from("lead_onboarding_gestores")
      .select("manager_id")
      .eq("lead_id", leadId);
  final managerIds = (gestoresRows as List)
      .map((g) => g["manager_id"] as String)
      .toSet();

  final inserted = await client
      .from("streamer_phase_progress")
      .insert({
        "lead_id": leadId,
        "phase_key": onboardingPhaseKey,
        "stage_key": firstStage["stage_key"],
        "manager_id": managerIds.isEmpty ? null : managerIds.first,
        "agency_id": agencyId,
        "created_by": userId,
      })
      .select("id")
      .single();
  final progressId = inserted["id"] as String;

  try {
    await client.from("streamer_phase_history").insert({
      "lead_id": leadId,
      "phase_key": onboardingPhaseKey,
      "action": "entrada_onboarding_lead",
      "detail": "Convite enviado -- streamer a caminho da agencia",
      "performed_by": userId,
    });
  } catch (_) {}

  if (managerIds.isNotEmpty) {
    await addManagersToCard(
      progressId: progressId,
      managerIds: managerIds.toList(),
      addedBy: userId,
    );
    for (final managerId in managerIds) {
      try {
        await client.from("manager_notifications").insert({
          "manager_id": managerId,
          "subject": "Novo streamer a caminho",
          "message":
              "Convite enviado -- um streamer a caminho da agencia ja aparece no seu Onboarding 0-15 Dias.",
        });
      } catch (_) {}
    }
  }
}

/// Vincula um ou mais gestores a um card ja existente (tabela N:N
/// streamer_phase_progress_managers). Idempotente via upsert.
Future<void> addManagersToCard({
  required String progressId,
  required List<String> managerIds,
  required String addedBy,
}) async {
  final client = Supabase.instance.client;
  for (final managerId in managerIds) {
    await client.from("streamer_phase_progress_managers").upsert({
      "progress_id": progressId,
      "manager_id": managerId,
      "added_by": addedBy,
    }, onConflict: "progress_id,manager_id");
  }
}

/// Remove um gestor de um card. Nao apaga o card em si -- so o vinculo.
Future<void> removeManagerFromCard({
  required String progressId,
  required String managerId,
}) async {
  final client = Supabase.instance.client;
  await client
      .from("streamer_phase_progress_managers")
      .delete()
      .eq("progress_id", progressId)
      .eq("manager_id", managerId);
}

/// Cria manualmente um card de Onboarding 0-15, chamado pelo dialog "Novo
/// Agenciado" do Gestor. Se existingStreamerId for nulo, cria um streamer
/// novo em profiles com os dados informados; senao, reaproveita o streamer
/// existente (sem sobrescrever o cadastro dele). Retorna o id do card.
Future<String> createManualOnboardingCard({
  String? existingStreamerId,
  String? displayName,
  String? tiktokId,
  String? phone,
  String? email,
  String? categoryId,
  String? notes,
  String phaseKey = onboardingPhaseKey,
}) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser!.id;
  final me = await client
      .from("managers")
      .select("agency_id")
      .eq("id", userId)
      .single();
  final agencyId = me["agency_id"] as String;

  String streamerId;
  if (existingStreamerId != null) {
    streamerId = existingStreamerId;
  } else {
    final inserted = await client
        .from("profiles")
        .insert({
          "display_name": displayName,
          "tiktok_creator_id": tiktokId,
          "phone": phone,
          "email": email,
          "category_id": categoryId,
          "agency_id": agencyId,
          "assigned_manager_id": userId,
          "is_active": true,
          "joined_at": DateTime.now().toIso8601String(),
          // Cadastro criado direto pelo gestor, ainda nao confirmado pela
          // planilha oficial -- os dashboards de "novos agenciados do mes"
          // ignoram essa linha ate a importacao (metricas ou vinculo de
          // agente) casar com esse streamer e limpar essa marca.
          "created_manually": true,
        })
        .select("id")
        .single();
    streamerId = inserted["id"] as String;
  }

  final existingProgress = await client
      .from("streamer_phase_progress")
      .select("id")
      .eq("streamer_id", streamerId)
      .eq("phase_key", phaseKey)
      .maybeSingle();

  String progressId;
  if (existingProgress != null) {
    progressId = existingProgress["id"] as String;
  } else {
    await seedOnboardingPhaseStages(agencyId: agencyId, phaseKey: phaseKey);
    final firstStage = await client
        .from("streamer_phase_stages")
        .select("stage_key")
        .eq("agency_id", agencyId)
        .eq("phase_key", phaseKey)
        .eq("is_active", true)
        .order("order_index", ascending: true)
        .limit(1)
        .single();

    final inserted = await client
        .from("streamer_phase_progress")
        .insert({
          "streamer_id": streamerId,
          "phase_key": phaseKey,
          "stage_key": firstStage["stage_key"],
          "manager_id": userId,
          "agency_id": agencyId,
          "created_by": userId,
        })
        .select("id")
        .single();
    progressId = inserted["id"] as String;

    try {
      await client.from("streamer_phase_history").insert({
        "streamer_id": streamerId,
        "phase_key": phaseKey,
        "action": "entrada_onboarding",
        "detail": "Adicionado manualmente pelo gestor",
        "performed_by": userId,
      });
    } catch (_) {}
  }

  await addManagersToCard(
    progressId: progressId,
    managerIds: [userId],
    addedBy: userId,
  );

  if (notes != null && notes.trim().isNotEmpty) {
    await client.from("streamer_phase_history").insert({
      "streamer_id": streamerId,
      "phase_key": phaseKey,
      "action": "observacao",
      "detail": notes.trim(),
      "performed_by": userId,
    });
  }

  return progressId;
}

/// Arquiva cards (oculta do board principal, mantem consultavel na aba
/// "Arquivados"). Usado pelo filtro de periodo.
Future<void> archiveOnboardingCards({
  required List<String> progressIds,
  required String performedBy,
}) async {
  final client = Supabase.instance.client;
  final now = DateTime.now().toIso8601String();
  for (final progressId in progressIds) {
    await client
        .from("streamer_phase_progress")
        .update({"archived_at": now, "archived_by": performedBy})
        .eq("id", progressId);
  }
}

/// Reativa um card arquivado (volta a aparecer no board, na mesma coluna
/// em que estava).
Future<void> unarchiveOnboardingCard({
  required String progressId,
  required String performedBy,
}) async {
  final client = Supabase.instance.client;
  await client
      .from("streamer_phase_progress")
      .update({"archived_at": null, "archived_by": null})
      .eq("id", progressId);
}

/// Remove definitivamente um card do Onboarding 0-15 Dias -- diferente de
/// arquivar, aqui a linha e apagada (o gestor pediu uma forma de tirar um
/// card criado por engano do board). O cadastro do streamer/lead em si nao
/// e afetado, so o acompanhamento por fases. streamer_phase_progress_managers
/// vinculado cai em cascata (FK on delete cascade); historico e checklist
/// ficam preservados (chave por streamer_id/lead_id, nao por progress_id) --
/// se um novo card for criado depois para o mesmo streamer/lead, eles voltam
/// a aparecer.
Future<void> deleteOnboardingCard({required String progressId}) async {
  final client = Supabase.instance.client;
  await client.from("streamer_phase_progress").delete().eq("id", progressId);
}

/// Edita os dados do streamer ja oficialmente vinculado a um card (mesmos
/// campos do dialog "Novo Agenciado"), a partir do board do Onboarding
/// 0-15 Dias.
Future<void> updateOnboardingStreamerProfile({
  required String streamerId,
  required String displayName,
  String? tiktokId,
  String? phone,
  String? email,
  String? categoryId,
  required String performedBy,
}) async {
  final client = Supabase.instance.client;
  await client
      .from("profiles")
      .update({
        "display_name": displayName,
        "tiktok_creator_id": tiktokId,
        "phone": phone,
        "email": email,
        "category_id": categoryId,
      })
      .eq("id", streamerId);
  // Registro de historico -- best effort: os dados ja foram salvos acima,
  // nao pode aparecer como erro pro gestor so porque o log falhou.
  try {
    await client.from("streamer_phase_history").insert({
      "streamer_id": streamerId,
      "phase_key": onboardingPhaseKey,
      "action": "editado",
      "detail": "Dados do streamer editados pelo gestor",
      "performed_by": performedBy,
    });
  } catch (_) {}
}

/// Edita os dados do lead vinculado a um card "pre-vinculo" (streamer
/// ainda nao oficialmente vinculado), a partir do board do Onboarding 0-15
/// Dias.
Future<void> updateOnboardingLeadInfo({
  required String leadId,
  required String name,
  String? tiktokUsername,
  String? phone,
  String? categoryInterest,
  required String performedBy,
}) async {
  final client = Supabase.instance.client;
  await client
      .from("leads")
      .update({
        "name": name,
        "tiktok_username": tiktokUsername,
        "phone": phone,
        "category_interest": categoryInterest,
      })
      .eq("id", leadId);
  // Registro de historico -- best effort: os dados ja foram salvos acima,
  // nao pode aparecer como erro pro gestor so porque o log falhou.
  try {
    await client.from("streamer_phase_history").insert({
      "lead_id": leadId,
      "phase_key": onboardingPhaseKey,
      "action": "editado",
      "detail": "Dados do lead editados pelo gestor",
      "performed_by": performedBy,
    });
  } catch (_) {}
}

/// Marca/desmarca um card como "streamer em potencial" -- avaliacao do
/// gestor durante o acompanhamento desta fase, mostrada como uma estrela ao
/// lado do icone de categoria na foto do card.
Future<void> updateOnboardingCardPotential({
  required String progressId,
  required bool isPotential,
}) async {
  await Supabase.instance.client
      .from("streamer_phase_progress")
      .update({"is_potential": isPotential})
      .eq("id", progressId);
}

/// Decisao final da fase (etapa de conclusao): aprovado (streamer segue
/// ativo, conclui esta fase -- se promoteToPhaseKey for informado, entra
/// automaticamente na primeira coluna da proxima fase) ou desligado (encerra
/// o streamer na agencia). "Plano de Recuperacao" NAO passa por aqui -- ver
/// sendOnboardingCardToRecovery, que move o card sem completar a fase.
/// Chamada tanto pelos botoes rapidos no rosto do card quanto pelo
/// formulario "Resultado do Onboarding" no dialog de detalhe, e pela
/// reavaliacao de um card que estava em Plano de Recuperacao -- um so
/// caminho de decisao, sem regra de negocio duplicada entre as telas.
Future<void> evaluateOnboardingCard({
  required String progressId,
  required String streamerId,
  required String outcome,
  required String performedBy,
  String? note,
  String? promoteToPhaseKey,
  bool requirePotentialToPromote = false,
}) async {
  final client = Supabase.instance.client;
  final data = <String, dynamic>{
    "outcome": outcome,
    "outcome_note": note,
    "completed_at": DateTime.now().toIso8601String(),
  };
  String detail;
  if (outcome == "aprovado") {
    detail = "Conclusao: aprovado, streamer segue ativo na agencia";
  } else {
    detail = "Conclusao: desligado da agencia";
    await client
        .from("profiles")
        .update({"is_active": false})
        .eq("id", streamerId);
  }

  await client
      .from("streamer_phase_progress")
      .update(data)
      .eq("id", progressId);
  // Registro de historico -- best effort: a decisao (aprovado/desligado)
  // ja foi salva acima, nao pode aparecer como "erro" pro gestor so porque
  // o log falhou.
  try {
    await client.from("streamer_phase_history").insert({
      "streamer_id": streamerId,
      "phase_key": onboardingPhaseKey,
      "action": "avaliacao_final",
      "detail": detail,
      "performed_by": performedBy,
    });
  } catch (_) {}

  // Promocao automatica pra proxima fase -- best effort, igual ao log
  // acima: a aprovacao em si ja foi salva, um erro aqui nao pode fazer
  // parecer que a aprovacao falhou pro gestor. createOnboardingPhaseCardIfNeeded
  // ja e idempotente (nao duplica se o streamer ja tiver card na fase seguinte).
  // requirePotentialToPromote restringe a promocao a quem estiver marcado
  // com a estrela "streamer em potencial" (ver updateOnboardingCardPotential)
  // -- usado pelo Acompanhamento 16-31 Dias, que so deve seguir pra
  // Graduacao Novatos quem foi destacado, nao todo mundo aprovado.
  if (outcome == "aprovado" && promoteToPhaseKey != null) {
    try {
      var shouldPromote = true;
      if (requirePotentialToPromote) {
        final row = await client
            .from("streamer_phase_progress")
            .select("is_potential")
            .eq("id", progressId)
            .maybeSingle();
        shouldPromote = row?["is_potential"] == true;
      }
      if (shouldPromote) {
        await createOnboardingPhaseCardIfNeeded(
          streamerId: streamerId,
          phaseKey: promoteToPhaseKey,
        );
      }
    } catch (_) {}
  }
}

/// Envia o card pra coluna "Plano de Recuperacao" da fase informada --
/// diferente de evaluateOnboardingCard, NAO completa a fase (sem
/// completed_at, card continua ativo no board, so muda de coluna). Usado
/// quando o gestor escolhe essa opcao na conclusao do onboarding, tanto
/// pelo botao rapido no rosto do card quanto pelo formulario "Resultado do
/// Onboarding" no dialog de detalhe.
Future<void> sendOnboardingCardToRecovery({
  required String progressId,
  required String streamerId,
  required String agencyId,
  required String phaseKey,
  required String note,
  required String performedBy,
}) async {
  final client = Supabase.instance.client;
  final recoveryStage = await client
      .from("streamer_phase_stages")
      .select("stage_key")
      .eq("agency_id", agencyId)
      .eq("phase_key", phaseKey)
      .eq("is_recovery_stage", true)
      .maybeSingle();
  if (recoveryStage == null) return;

  await client
      .from("streamer_phase_progress")
      .update({
        "stage_key": recoveryStage["stage_key"],
        "stage_changed_at": DateTime.now().toIso8601String(),
        "outcome": "plano_recuperacao",
        "outcome_note": note,
      })
      .eq("id", progressId);

  try {
    await client.from("streamer_phase_history").insert({
      "streamer_id": streamerId,
      "phase_key": phaseKey,
      "action": "enviado_plano_recuperacao",
      "detail":
          "Enviado para Plano de Recuperacao" +
          (note.trim().isEmpty ? "" : ": " + note.trim()),
      "performed_by": performedBy,
    });
  } catch (_) {}
}
