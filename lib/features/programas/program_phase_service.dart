import "package:supabase_flutter/supabase_flutter.dart";

/// Programas fixos da jornada do streamer, na ordem de progressao. Cada um
/// usa sua propria phase_key nas MESMAS tabelas streamer_phase_* ja usadas
/// pelo Onboarding 0-15 Dias -- nao ha tabela de fluxo/checklist/historico
/// separada por programa.
const developmentProgramKeys = [
  "onboarding_0_15",
  "onboarding_30",
  "novatos",
  "top_ducker_80k",
  "programa_150k",
  "elite",
];

const _defaultPrograms = [
  ("onboarding_0_15", 1, "Onboarding 15 Dias", "Primeiros 15 dias do streamer na agencia: boas-vindas, configuracao e acompanhamento inicial.", "onboarding_30"),
  ("onboarding_30", 2, "Onboarding 30 Dias", "Continuidade do onboarding entre os dias 16 e 30: treinamento de nicho e avaliacao de consistencia.", "novatos"),
  ("novatos", 3, "Novatos (2o e 3o mes)", "Acompanhamento do streamer no 2o e 3o mes de agencia.", "top_ducker_80k"),
  ("top_ducker_80k", 4, "Top Ducker 80k", "Streamers que atingem a marca de 80 mil diamantes.", "programa_150k"),
  ("programa_150k", 5, "Programa 150k", "Streamers que atingem a marca de 150 mil diamantes.", "elite"),
  ("elite", 6, "Elite", "Nivel maximo de streamers da agencia.", null),
];

/// Fluxo (colunas do Kanban) ja definido para os programas que tem exemplo
/// concreto. Programas ausentes daqui nascem sem nenhuma etapa -- ficam
/// 100% configuraveis na aba Configuracoes antes de terem uso.
const _stageSeeds = <String, List<(String key, String name, String color, bool isEvaluation)>>{
  "onboarding_30": [
    ("dia_16", "Dia 16", "#2D9CDB", false),
    ("treinamento_nicho", "Treinamento Nicho", "#2D9CDB", false),
    ("verificar_dias", "Verificar Dias", "#7A0BD4", false),
    ("verificar_horas", "Verificar Horas", "#7A0BD4", false),
    ("verificar_batalhas", "Verificar Batalhas", "#7A0BD4", false),
    ("analise_individual", "Analise Individual", "#F2994A", false),
    ("entrega_premiacao", "Entrega da Premiacao", "#F2994A", false),
    ("avaliacao_final", "Avaliacao Final", "#EB5757", true),
    ("concluido", "Concluido", "#27AE60", false),
  ],
};

Future<String> currentAgencyId() async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser!.id;
  final manager = await client.from("managers").select("agency_id").eq("id", userId).single();
  return manager["agency_id"] as String;
}

/// Garante que a agencia tenha os 6 programas fixos (idempotente, so
/// insere o que ainda nao existe) -- mesmo padrao de
/// CalendarService.seedDefaultCategories / seedOnboardingPhaseStages.
Future<void> seedDevelopmentPrograms({required String agencyId}) async {
  final client = Supabase.instance.client;
  final existing = await client.from("development_programs").select("program_key").eq("agency_id", agencyId);
  final existingKeys = (existing as List).map((r) => r["program_key"] as String).toSet();
  final missing = _defaultPrograms.where((p) => !existingKeys.contains(p.$1)).toList();
  if (missing.isNotEmpty) {
    final rows = missing
        .map((p) => {
              "agency_id": agencyId,
              "program_key": p.$1,
              "order_index": p.$2,
              "name": p.$3,
              "description": p.$4,
              "next_program_key": p.$5,
            })
        .toList();
    await client.from("development_programs").insert(rows);
  }
  await seedProgramStages(phaseKey: "onboarding_30", agencyId: agencyId);
}

/// Semeia as etapas padrao (streamer_phase_stages) de um programa, se
/// houver um fluxo de exemplo definido em _stageSeeds. Idempotente.
Future<void> seedProgramStages({required String phaseKey, required String agencyId}) async {
  final seeds = _stageSeeds[phaseKey];
  if (seeds == null) return;
  final client = Supabase.instance.client;
  final existing = await client.from("streamer_phase_stages").select("stage_key").eq("agency_id", agencyId).eq("phase_key", phaseKey);
  final existingKeys = (existing as List).map((r) => r["stage_key"] as String).toSet();
  final missing = seeds.where((s) => !existingKeys.contains(s.$1)).toList();
  if (missing.isEmpty) return;
  final rows = missing
      .map((s) => {
            "agency_id": agencyId,
            "phase_key": phaseKey,
            "stage_key": s.$1,
            "name": s.$2,
            "order_index": seeds.indexOf(s),
            "color": s.$3,
            "is_evaluation_stage": s.$4,
          })
      .toList();
  await client.from("streamer_phase_stages").insert(rows);
}

/// Cria o card do streamer na primeira etapa ativa do programa, se ele
/// ainda nao tiver um (idempotente). Sem fluxo configurado (nenhuma etapa
/// ativa), nao cria nada -- o programa ainda nao esta pronto para uso.
Future<void> createProgramCardIfNeeded({required String phaseKey, required String streamerId}) async {
  final client = Supabase.instance.client;
  final existing = await client.from("streamer_phase_progress").select("id").eq("streamer_id", streamerId).eq("phase_key", phaseKey).maybeSingle();
  if (existing != null) return;

  final profile = await client.from("profiles").select("agency_id").eq("id", streamerId).single();
  final agencyId = profile["agency_id"] as String;

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

  await client.from("streamer_phase_progress").insert({
    "streamer_id": streamerId,
    "phase_key": phaseKey,
    "stage_key": firstStage["stage_key"],
    "agency_id": agencyId,
  });

  try {
    await client.from("streamer_phase_history").insert({
      "streamer_id": streamerId,
      "phase_key": phaseKey,
      "action": "entrada_programa",
      "detail": "Entrou automaticamente no programa (criterios atendidos)",
      "performed_by": client.auth.currentUser?.id,
    });
  } catch (_) {}
}

Future<void> moveProgramCard({required String progressId, required String newStageKey}) async {
  await Supabase.instance.client.from("streamer_phase_progress").update({
    "stage_key": newStageKey,
    "stage_changed_at": DateTime.now().toIso8601String(),
  }).eq("id", progressId);
}

Future<void> deleteProgramCard({required String progressId}) async {
  await Supabase.instance.client.from("streamer_phase_progress").delete().eq("id", progressId);
}

const _reprovalReasonLabels = {
  "baixa_frequencia": "Baixa frequencia",
  "poucas_horas": "Poucas horas",
  "sem_treinamento": "Nao realizou treinamento",
  "desistencia": "Desistencia",
  "outro": "Outro",
};

/// Decisao da etapa de avaliacao final de qualquer programa: aprovado
/// (segue para o proximo programa da cadeia), graduado (segue para o
/// programa de destaque, se configurado), revisao (fica mais tempo neste
/// programa) ou desligado (encerra a parceria). O encadeamento para o
/// proximo programa e automatico -- so a decisao em si depende do gestor.
/// Toda saida final (tudo exceto revisao) arquiva o card automaticamente
/// (archived_at/archived_by -- as mesmas colunas ja usadas pelo board do
/// Onboarding 0-15 Dias), pra sumir da lista ativa de Participantes mas
/// continuar consultavel no filtro "Arquivados" e no Historico.
Future<void> evaluateProgramCard({
  required String programId,
  required String phaseKey,
  required String progressId,
  required String streamerId,
  required String outcome,
  required String performedBy,
  String? reason,
  String? observacao,
}) async {
  final client = Supabase.instance.client;
  final data = <String, dynamic>{"outcome": outcome};
  String outcomeLabel;

  if (outcome == "desligado") {
    data["completed_at"] = DateTime.now().toIso8601String();
    data["archived_at"] = DateTime.now().toIso8601String();
    data["archived_by"] = performedBy;
    data["outcome_reason"] = reason;
    outcomeLabel = "Desligado da agencia";
    await client.from("profiles").update({"is_active": false}).eq("id", streamerId);
  } else if (outcome == "aprovado") {
    data["completed_at"] = DateTime.now().toIso8601String();
    data["archived_at"] = DateTime.now().toIso8601String();
    data["archived_by"] = performedBy;
    outcomeLabel = "Aprovado";
  } else if (outcome == "graduado") {
    data["completed_at"] = DateTime.now().toIso8601String();
    data["archived_at"] = DateTime.now().toIso8601String();
    data["archived_by"] = performedBy;
    outcomeLabel = "Graduado com destaque";
  } else {
    outcomeLabel = "Colocado em revisao, acompanhamento estendido";
  }
  if (observacao != null && observacao.isNotEmpty) data["outcome_note"] = observacao;

  final program = await client.from("development_programs").select("name, agency_id, next_program_key, graduate_program_key").eq("id", programId).single();

  if (outcome != "revisao") {
    final lastStage = await client
        .from("streamer_phase_stages")
        .select("stage_key")
        .eq("agency_id", program["agency_id"])
        .eq("phase_key", phaseKey)
        .eq("is_active", true)
        .order("order_index", ascending: false)
        .limit(1)
        .maybeSingle();
    if (lastStage != null) data["stage_key"] = lastStage["stage_key"];
  }

  await client.from("streamer_phase_progress").update(data).eq("id", progressId);

  String? destinationName;
  final nextKey = outcome == "graduado" ? program["graduate_program_key"] as String? : program["next_program_key"] as String?;
  if ((outcome == "aprovado" || outcome == "graduado") && nextKey != null) {
    final destination = await client.from("development_programs").select("name").eq("agency_id", program["agency_id"]).eq("program_key", nextKey).maybeSingle();
    destinationName = destination?["name"] as String?;
  }

  final detailParts = <String>["Avaliacao final: " + outcomeLabel];
  detailParts.add("Origem: " + (program["name"] as String));
  if (destinationName != null) detailParts.add("Destino: " + destinationName);
  if (reason != null) detailParts.add("Motivo: " + (_reprovalReasonLabels[reason] ?? reason));
  if (observacao != null && observacao.isNotEmpty) detailParts.add("Observacoes: " + observacao);

  try {
    await client.from("streamer_phase_history").insert({
      "streamer_id": streamerId,
      "phase_key": phaseKey,
      "action": "avaliacao_final",
      "detail": detailParts.join(". "),
      "performed_by": performedBy,
    });
  } catch (_) {}

  if ((outcome == "aprovado" || outcome == "graduado") && nextKey != null) {
    await createProgramCardIfNeeded(phaseKey: nextKey, streamerId: streamerId);
  }
}
