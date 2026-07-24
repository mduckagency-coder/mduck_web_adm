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

/// Chave da etapa final de decisao (aprovado / revisao / desligado),
/// depois do dia_15. Sem checklist obrigatorio, mesmo padrao do dia_0.
const _evaluationStageKey = "avaliacao";

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
  (_evaluationStageKey, "Avaliacao Final"),
];

/// Cor padrao de cada coluna por faixa de dias: dia 0 sozinho, dias 1-3,
/// dias 4-7, dias 8-15, e a etapa de decisao final com cor propria.
String _defaultStageColor(String stageKey) {
  if (stageKey == _stagingStageKey) return "#F2994A";
  if (stageKey == _evaluationStageKey) return "#EB5757";
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

/// Garante que a agencia tenha as colunas/checklist padrao do Onboarding
/// 0-15 Dias. Idempotente (so insere o que ainda nao existe), mesmo padrao
/// de CalendarService.seedDefaultCategories. Util como fallback para
/// agencias criadas depois da migration 0007 ja ter rodado.
Future<void> seedOnboardingPhaseStages({String? agencyId}) async {
  final client = Supabase.instance.client;
  agencyId ??= (await client.from("managers").select("agency_id").eq("id", client.auth.currentUser!.id).single())["agency_id"] as String;

  final existing = await client.from("streamer_phase_stages").select("stage_key").eq("agency_id", agencyId).eq("phase_key", onboardingPhaseKey);
  final existingKeys = (existing as List).map((r) => r["stage_key"] as String).toSet();
  final missing = _defaultStages.where((s) => !existingKeys.contains(s.$1)).toList();
  if (missing.isEmpty) return;

  final stageRows = missing.map((s) => {
        "agency_id": agencyId,
        "phase_key": onboardingPhaseKey,
        "stage_key": s.$1,
        "name": s.$2,
        "order_index": _defaultStages.indexOf(s),
        "color": _defaultStageColor(s.$1),
      }).toList();
  await client.from("streamer_phase_stages").insert(stageRows);

  for (final stage in missing) {
    final items = _defaultChecklistItemsByStage[stage.$1];
    if (items == null) continue;
    final itemRows = items.asMap().entries.map((entry) => {
          "agency_id": agencyId,
          "phase_key": onboardingPhaseKey,
          "stage_key": stage.$1,
          "item_key": entry.value.$1,
          "label": entry.value.$2,
          "order_index": entry.key + 1,
        }).toList();
    await client.from("streamer_phase_checklist_items").insert(itemRows);
  }
}

/// Cria (ou promove) o card do streamer na primeira coluna do Onboarding
/// 0-15 Dias, chamada sempre que o recrutador conclui o checklist de
/// onboarding (se o streamer ja estiver vinculado) ou quando o streamer e
/// vinculado depois (se o checklist ja estava concluido). Se ja existir um
/// card "pre-vinculo" criado a partir do lead (ver
/// createOnboardingLeadCardIfNeeded), promove essa mesma linha em vez de
/// duplicar -- preserva etapa/historico. Idempotente: nao duplica card se
/// ja existir para esse streamer+fase.
Future<void> createOnboardingPhaseCardIfNeeded({required String streamerId}) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser!.id;

  final existing = await client.from("streamer_phase_progress").select("id").eq("streamer_id", streamerId).eq("phase_key", onboardingPhaseKey).maybeSingle();
  if (existing != null) return;

  final me = await client.from("managers").select("agency_id").eq("id", userId).single();
  final agencyId = me["agency_id"] as String;

  final profile = await client.from("profiles").select("assigned_manager_id").eq("id", streamerId).maybeSingle();
  final assignedManagerId = profile?["assigned_manager_id"] as String?;

  // Resolve todos os gestores ja definidos para este streamer: prioriza os
  // gestores do lead (lead_onboarding_gestores, suporta varios -- e o que
  // o recrutador preenche em "Streamers Agenciados"), com fallback para
  // profiles.assigned_manager_id (streamers sem lead, ex. criados
  // manualmente via "Novo Agenciado" direto no Kanban do Gestor).
  final managerIds = <String>{};
  final lead = await client.from("leads").select("id").eq("converted_streamer_id", streamerId).maybeSingle();
  if (lead != null) {
    final gestores = await client.from("lead_onboarding_gestores").select("manager_id").eq("lead_id", lead["id"]);
    managerIds.addAll((gestores as List).map((g) => g["manager_id"] as String));
  }
  if (assignedManagerId != null) managerIds.add(assignedManagerId);

  String progressId;
  final leadCard = lead != null
      ? await client.from("streamer_phase_progress").select("id").eq("lead_id", lead["id"]).eq("phase_key", onboardingPhaseKey).maybeSingle()
      : null;

  if (leadCard != null) {
    progressId = leadCard["id"] as String;
    await client.from("streamer_phase_progress").update({
      "streamer_id": streamerId,
      "lead_id": null,
      "manager_id": assignedManagerId,
    }).eq("id", progressId);
    try {
      await client.from("streamer_phase_history").insert({
        "streamer_id": streamerId,
        "phase_key": onboardingPhaseKey,
        "action": "vinculado_streamer",
        "detail": "Streamer oficial vinculado ao card de onboarding",
        "performed_by": userId,
      });
    } catch (_) {}
  } else {
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

    final inserted = await client.from("streamer_phase_progress").insert({
      "streamer_id": streamerId,
      "phase_key": onboardingPhaseKey,
      "stage_key": firstStage["stage_key"],
      "manager_id": assignedManagerId,
      "agency_id": agencyId,
      "created_by": userId,
    }).select("id").single();
    progressId = inserted["id"] as String;

    try {
      await client.from("streamer_phase_history").insert({
        "streamer_id": streamerId,
        "phase_key": onboardingPhaseKey,
        "action": "entrada_onboarding",
        "detail": "Entrou no Onboarding 0-15 Dias",
        "performed_by": userId,
      });
    } catch (_) {}
  }

  if (managerIds.isNotEmpty) {
    await addManagersToCard(progressId: progressId, managerIds: managerIds.toList(), addedBy: userId);
    for (final managerId in managerIds) {
      try {
        await client.from("manager_notifications").insert({
          "manager_id": managerId,
          "subject": "Novo streamer no Onboarding 0-15 Dias",
          "message": "Um streamer sob sua gestao entrou no Onboarding 0-15 Dias.",
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

  final lead = await client.from("leads").select("id, converted_streamer_id").eq("id", leadId).maybeSingle();
  if (lead == null || lead["converted_streamer_id"] != null) return;

  final existing = await client.from("streamer_phase_progress").select("id").eq("lead_id", leadId).eq("phase_key", onboardingPhaseKey).maybeSingle();
  if (existing != null) return;

  final me = await client.from("managers").select("agency_id").eq("id", userId).single();
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

  final gestoresRows = await client.from("lead_onboarding_gestores").select("manager_id").eq("lead_id", leadId);
  final managerIds = (gestoresRows as List).map((g) => g["manager_id"] as String).toSet();

  final inserted = await client.from("streamer_phase_progress").insert({
    "lead_id": leadId,
    "phase_key": onboardingPhaseKey,
    "stage_key": firstStage["stage_key"],
    "manager_id": managerIds.isEmpty ? null : managerIds.first,
    "agency_id": agencyId,
    "created_by": userId,
  }).select("id").single();
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
    await addManagersToCard(progressId: progressId, managerIds: managerIds.toList(), addedBy: userId);
    for (final managerId in managerIds) {
      try {
        await client.from("manager_notifications").insert({
          "manager_id": managerId,
          "subject": "Novo streamer a caminho",
          "message": "Convite enviado -- um streamer a caminho da agencia ja aparece no seu Onboarding 0-15 Dias.",
        });
      } catch (_) {}
    }
  }
}

/// Vincula um ou mais gestores a um card ja existente (tabela N:N
/// streamer_phase_progress_managers). Idempotente via upsert.
Future<void> addManagersToCard({required String progressId, required List<String> managerIds, required String addedBy}) async {
  final client = Supabase.instance.client;
  for (final managerId in managerIds) {
    await client.from("streamer_phase_progress_managers").upsert(
      {"progress_id": progressId, "manager_id": managerId, "added_by": addedBy},
      onConflict: "progress_id,manager_id",
    );
  }
}

/// Remove um gestor de um card. Nao apaga o card em si -- so o vinculo.
Future<void> removeManagerFromCard({required String progressId, required String managerId}) async {
  final client = Supabase.instance.client;
  await client.from("streamer_phase_progress_managers").delete().eq("progress_id", progressId).eq("manager_id", managerId);
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
}) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser!.id;
  final me = await client.from("managers").select("agency_id").eq("id", userId).single();
  final agencyId = me["agency_id"] as String;

  String streamerId;
  if (existingStreamerId != null) {
    streamerId = existingStreamerId;
  } else {
    final inserted = await client.from("profiles").insert({
      "display_name": displayName,
      "tiktok_creator_id": tiktokId,
      "phone": phone,
      "email": email,
      "category_id": categoryId,
      "agency_id": agencyId,
      "assigned_manager_id": userId,
      "is_active": true,
      "joined_at": DateTime.now().toIso8601String(),
    }).select("id").single();
    streamerId = inserted["id"] as String;
  }

  final existingProgress = await client
      .from("streamer_phase_progress")
      .select("id")
      .eq("streamer_id", streamerId)
      .eq("phase_key", onboardingPhaseKey)
      .maybeSingle();

  String progressId;
  if (existingProgress != null) {
    progressId = existingProgress["id"] as String;
  } else {
    await seedOnboardingPhaseStages(agencyId: agencyId);
    final firstStage = await client
        .from("streamer_phase_stages")
        .select("stage_key")
        .eq("agency_id", agencyId)
        .eq("phase_key", onboardingPhaseKey)
        .eq("is_active", true)
        .order("order_index", ascending: true)
        .limit(1)
        .single();

    final inserted = await client.from("streamer_phase_progress").insert({
      "streamer_id": streamerId,
      "phase_key": onboardingPhaseKey,
      "stage_key": firstStage["stage_key"],
      "manager_id": userId,
      "agency_id": agencyId,
      "created_by": userId,
    }).select("id").single();
    progressId = inserted["id"] as String;

    try {
      await client.from("streamer_phase_history").insert({
        "streamer_id": streamerId,
        "phase_key": onboardingPhaseKey,
        "action": "entrada_onboarding",
        "detail": "Adicionado manualmente pelo gestor",
        "performed_by": userId,
      });
    } catch (_) {}
  }

  await addManagersToCard(progressId: progressId, managerIds: [userId], addedBy: userId);

  if (notes != null && notes.trim().isNotEmpty) {
    await client.from("streamer_phase_history").insert({
      "streamer_id": streamerId,
      "phase_key": onboardingPhaseKey,
      "action": "observacao",
      "detail": notes.trim(),
      "performed_by": userId,
    });
  }

  return progressId;
}

/// Arquiva cards (oculta do board principal, mantem consultavel na aba
/// "Arquivados"). Usado pelo filtro de periodo.
Future<void> archiveOnboardingCards({required List<String> progressIds, required String performedBy}) async {
  final client = Supabase.instance.client;
  final now = DateTime.now().toIso8601String();
  for (final progressId in progressIds) {
    await client.from("streamer_phase_progress").update({"archived_at": now, "archived_by": performedBy}).eq("id", progressId);
  }
}

/// Reativa um card arquivado (volta a aparecer no board, na mesma coluna
/// em que estava).
Future<void> unarchiveOnboardingCard({required String progressId, required String performedBy}) async {
  final client = Supabase.instance.client;
  await client.from("streamer_phase_progress").update({"archived_at": null, "archived_by": null}).eq("id", progressId);
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
  await client.from("profiles").update({
    "display_name": displayName,
    "tiktok_creator_id": tiktokId,
    "phone": phone,
    "email": email,
    "category_id": categoryId,
  }).eq("id", streamerId);
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
  await client.from("leads").update({
    "name": name,
    "tiktok_username": tiktokUsername,
    "phone": phone,
    "category_interest": categoryInterest,
  }).eq("id", leadId);
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

/// Decisao da etapa "Avaliacao Final": aprovado (streamer segue ativo,
/// conclui o onboarding), revisao (fica mais tempo em acompanhamento,
/// card continua na coluna) ou desligado (encerra o streamer na agencia).
Future<void> evaluateOnboardingCard({
  required String progressId,
  required String streamerId,
  required String outcome,
  required String performedBy,
}) async {
  final client = Supabase.instance.client;
  final data = <String, dynamic>{"outcome": outcome};
  String detail;
  if (outcome == "aprovado") {
    data["completed_at"] = DateTime.now().toIso8601String();
    detail = "Avaliacao final: aprovado, streamer segue ativo na agencia";
  } else if (outcome == "desligado") {
    data["completed_at"] = DateTime.now().toIso8601String();
    detail = "Avaliacao final: desligado da agencia";
    await client.from("profiles").update({"is_active": false}).eq("id", streamerId);
  } else {
    detail = "Avaliacao final: colocado em revisao, acompanhamento estendido";
  }

  await client.from("streamer_phase_progress").update(data).eq("id", progressId);
  // Registro de historico -- best effort: a decisao (aprovado/desligado/
  // revisao) ja foi salva acima, nao pode aparecer como "erro" pro gestor
  // so porque o log falhou.
  try {
    await client.from("streamer_phase_history").insert({
      "streamer_id": streamerId,
      "phase_key": onboardingPhaseKey,
      "action": "avaliacao_final",
      "detail": detail,
      "performed_by": performedBy,
    });
  } catch (_) {}
}
