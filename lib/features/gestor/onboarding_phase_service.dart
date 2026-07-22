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
  ("dia_15", "Dia 15 - Avaliacao Final"),
];

const _defaultChecklistItems = [
  ("material_enviado", "Material enviado"),
  ("mensagem_enviada", "Mensagem enviada"),
  ("confirmou_recebimento", "Confirmou recebimento"),
  ("assistiu_materiais", "Assistiu aos materiais"),
  ("tirou_duvidas", "Tirou duvidas"),
  ("realizou_live", "Realizou live"),
  ("feedback_registrado", "Feedback registrado"),
  ("etapa_concluida", "Etapa concluida"),
];

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
        "color": "#7A0BD4",
      }).toList();
  await client.from("streamer_phase_stages").insert(stageRows);

  for (final stage in missing) {
    if (stage.$1 == _stagingStageKey) continue;
    final itemRows = _defaultChecklistItems.asMap().entries.map((entry) => {
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

/// Cria automaticamente o card do streamer na primeira coluna do
/// Onboarding 0-15 Dias, chamada sempre que o recrutador conclui o
/// checklist de onboarding (se o streamer ja estiver vinculado) ou quando
/// o streamer e vinculado depois (se o checklist ja estava concluido).
/// Idempotente: nao duplica card se ja existir para esse streamer+fase.
Future<void> createOnboardingPhaseCardIfNeeded({required String streamerId}) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser!.id;

  final existing = await client.from("streamer_phase_progress").select("id").eq("streamer_id", streamerId).eq("phase_key", onboardingPhaseKey).maybeSingle();
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
      .order("order_index")
      .limit(1)
      .maybeSingle();
  if (firstStage == null) return;

  final profile = await client.from("profiles").select("assigned_manager_id").eq("id", streamerId).maybeSingle();
  final managerId = profile?["assigned_manager_id"] as String?;

  await client.from("streamer_phase_progress").insert({
    "streamer_id": streamerId,
    "phase_key": onboardingPhaseKey,
    "stage_key": firstStage["stage_key"],
    "manager_id": managerId,
    "created_by": userId,
  });

  await client.from("streamer_phase_history").insert({
    "streamer_id": streamerId,
    "phase_key": onboardingPhaseKey,
    "action": "entrada_onboarding",
    "detail": "Entrou no Onboarding 0-15 Dias",
    "performed_by": userId,
  });

  if (managerId != null) {
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
