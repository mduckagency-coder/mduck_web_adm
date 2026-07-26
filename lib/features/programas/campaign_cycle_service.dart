import "package:supabase_flutter/supabase_flutter.dart";
import "program_eligibility_service.dart";
import "program_phase_service.dart";
import "programa_history_helpers.dart";

const defaultCycleChecklistTemplate = [
  "Criar campanha no Backstage",
  "Enviar mensagem no grupo",
  "Publicar banner",
  "Confirmar participantes",
  "Finalizar campanha",
  "Entregar premiacoes",
];

const _monthNames = ["Janeiro", "Fevereiro", "Marco", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];

String periodKeyFor(DateTime date) => date.year.toString() + "-" + date.month.toString().padLeft(2, "0");

String periodLabelFor(DateTime date) => _monthNames[date.month - 1] + " " + date.year.toString();

/// Mescla a missao do ciclo com o criterio base do programa: campo
/// preenchido na missao sobrepoe; campo vazio cai pro criterio do
/// programa. Assim a missao so precisa declarar o que for diferente do
/// padrao do programa (ex: meta de diamantes so deste mes). Ativar/
/// desativar meta, obrigatoriedade e a regra de aprovacao sao configuracao
/// do PROGRAMA, nao do mes -- a missao so ajusta valores-alvo, entao esses
/// campos sempre vem do base, nunca da missao.
ProgramCriteria mergeCriteria(ProgramCriteria base, ProgramCriteria mission) {
  return ProgramCriteria(
    minDays: mission.minDays ?? base.minDays,
    minDaysValidated: mission.minDaysValidated ?? base.minDaysValidated,
    minHours: mission.minHours ?? base.minHours,
    minDiamonds: mission.minDiamonds ?? base.minDiamonds,
    minHeartMe: mission.minHeartMe ?? base.minHeartMe,
    minBattles: mission.minBattles ?? base.minBattles,
    battlesByCategory: base.battlesByCategory,
    daysEnabled: base.daysEnabled,
    daysRequired: base.daysRequired,
    daysValidatedEnabled: base.daysValidatedEnabled,
    daysValidatedRequired: base.daysValidatedRequired,
    hoursEnabled: base.hoursEnabled,
    hoursRequired: base.hoursRequired,
    diamondsEnabled: base.diamondsEnabled,
    diamondsRequired: base.diamondsRequired,
    heartMeEnabled: base.heartMeEnabled,
    heartMeRequired: base.heartMeRequired,
    battlesEnabled: base.battlesEnabled,
    battlesRequired: base.battlesRequired,
    approvalRuleMode: base.approvalRuleMode,
    approvalMinPercentage: base.approvalMinPercentage,
    categoryIds: mission.categoryIds.isNotEmpty ? mission.categoryIds : base.categoryIds,
    requiredMaterialIds: mission.requiredMaterialIds.isNotEmpty ? mission.requiredMaterialIds : base.requiredMaterialIds,
  );
}

Future<ProgramCriteria> _cycleCriteria(Map<String, dynamic> program, String cycleId) async {
  final client = Supabase.instance.client;
  final cycle = await client.from("campaign_cycles").select("mission_criteria").eq("id", cycleId).single();
  final base = ProgramCriteria.fromMap(program["criteria"] as Map<String, dynamic>?);
  final mission = ProgramCriteria.fromMap(cycle["mission_criteria"] as Map<String, dynamic>?);
  return mergeCriteria(base, mission);
}

/// Cria (ou reaproveita, se ja existir) o ciclo do mes de referencia,
/// seeda o checklist padrao e ja busca+vincula os streamers elegiveis --
/// nada e selecionado na mao.
Future<String> startNewCycle({required Map<String, dynamic> program, DateTime? referenceDate}) async {
  final client = Supabase.instance.client;
  final date = referenceDate ?? DateTime.now();
  final periodKey = periodKeyFor(date);
  final periodLabel = periodLabelFor(date);
  final programId = program["id"] as String;
  final userId = client.auth.currentUser!.id;

  final existing = await client.from("campaign_cycles").select("id").eq("program_id", programId).eq("period_key", periodKey).maybeSingle();
  String cycleId;
  if (existing != null) {
    cycleId = existing["id"] as String;
  } else {
    final baseCriteria = ProgramCriteria.fromMap(program["criteria"] as Map<String, dynamic>?);
    final inserted = await client.from("campaign_cycles").insert({
      "program_id": programId,
      "period_key": periodKey,
      "period_label": periodLabel,
      "mission_title": "Missao " + periodLabel,
      "mission_criteria": baseCriteria.toMap(),
      "default_message": program["default_message"],
      "created_by": userId,
    }).select("id").single();
    cycleId = inserted["id"] as String;

    await client.from("campaign_cycle_checklist").insert(
      defaultCycleChecklistTemplate.asMap().entries.map((e) => {"cycle_id": cycleId, "label": e.value, "order_index": e.key}).toList(),
    );
  }

  await syncCycleParticipants(program: program, cycleId: cycleId);
  return cycleId;
}

/// Busca elegiveis (criterio do programa mesclado com a missao do ciclo) e
/// vincula quem ainda nao esta na lista. Chamado ao criar o ciclo, e pode
/// ser chamado de novo durante o mes ("verificar elegiveis").
Future<int> syncCycleParticipants({required Map<String, dynamic> program, required String cycleId}) async {
  final client = Supabase.instance.client;
  final criteria = await _cycleCriteria(program, cycleId);

  final snapshots = await fetchActiveStreamerSnapshots(agencyId: program["agency_id"] as String);
  final existingParticipants = await client.from("campaign_cycle_participants").select("streamer_id").eq("cycle_id", cycleId);
  final existingIds = (existingParticipants as List).map((r) => r["streamer_id"] as String).toSet();

  var added = 0;
  for (final s in snapshots) {
    if (existingIds.contains(s.id)) continue;
    if (evaluateEligibility(s, criteria).eligible) {
      await client.from("campaign_cycle_participants").insert({"cycle_id": cycleId, "streamer_id": s.id});
      added++;
    }
  }
  return added;
}

Future<List<Map<String, dynamic>>> fetchCycleParticipants({required String cycleId}) async {
  final client = Supabase.instance.client;
  final rows = await client
      .from("campaign_cycle_participants")
      .select(
          "id, streamer_id, final_status, joined_at, streamer:profiles(id, display_name, avatar_url, is_active, last_live_at, joined_at, category_id, streamer_categories(name), streamer_stats(days_live, hours_live, diamonds, battles, heart_me))")
      .eq("cycle_id", cycleId)
      .order("joined_at");
  return (rows as List).cast<Map<String, dynamic>>();
}

/// Converte a linha de participante (streamer embutido) num
/// StreamerSnapshot, igual ao formato usado no resto do modulo de
/// Programas -- so que sem o filtro is_active da busca geral (aqui
/// queremos ver tambem quem desistiu/ficou inativo depois de entrar).
StreamerSnapshot? snapshotFromParticipantRow(Map<String, dynamic> row) {
  final streamer = row["streamer"];
  if (streamer is! Map) return null;
  final statsData = streamer["streamer_stats"];
  Map<String, dynamic>? stats;
  if (statsData is List && statsData.isNotEmpty) {
    stats = statsData.first as Map<String, dynamic>;
  } else if (statsData is Map) {
    stats = statsData as Map<String, dynamic>;
  }
  final catData = streamer["streamer_categories"];
  final joinedAt = streamer["joined_at"] != null ? DateTime.parse(streamer["joined_at"] as String) : null;

  return StreamerSnapshot(
    id: streamer["id"] as String,
    displayName: (streamer["display_name"] as String?) ?? "-",
    avatarUrl: streamer["avatar_url"] as String?,
    categoryId: streamer["category_id"] as String?,
    categoryName: catData is Map ? catData["name"] as String? : null,
    daysInAgency: joinedAt != null ? DateTime.now().difference(joinedAt).inDays : 0,
    daysValidated: (stats?["days_live"] as num?)?.toInt() ?? 0,
    hoursLive: (stats?["hours_live"] as num?)?.toDouble() ?? 0,
    diamonds: stats?["diamonds"] as num? ?? 0,
    heartMe: stats?["heart_me"] as num?,
    battles: (stats?["battles"] as num?)?.toInt() ?? 0,
  );
}

enum ParticipantStatus { concluido, proximo, atrasado, desistiu, inativo }

class ParticipantEvaluation {
  final ParticipantStatus status;
  final List<String> gaps;
  const ParticipantEvaluation({required this.status, this.gaps = const []});
}

(String, int) _colorlessLabel(ParticipantStatus s) {
  switch (s) {
    case ParticipantStatus.concluido:
      return ("Concluiu", 0);
    case ParticipantStatus.proximo:
      return ("Proximo", 1);
    case ParticipantStatus.atrasado:
      return ("Atrasado", 2);
    case ParticipantStatus.desistiu:
      return ("Desistiu", 3);
    case ParticipantStatus.inativo:
      return ("Inativo", 4);
  }
}

String participantStatusLabel(ParticipantStatus s) => _colorlessLabel(s).$1;

/// Avalia o participante contra a missao do ciclo: desistiu (inativado no
/// cadastro), inativo (sem live ha 3+ dias), concluiu (bate todos os
/// criterios), proximo (perto de bater, mostra o que falta) ou atrasado
/// (longe ainda).
ParticipantEvaluation evaluateParticipant(Map<String, dynamic> participantRow, ProgramCriteria criteria) {
  final streamer = participantRow["streamer"];
  final isActive = streamer is Map ? (streamer["is_active"] as bool? ?? true) : true;
  if (!isActive) return const ParticipantEvaluation(status: ParticipantStatus.desistiu);

  final lastLiveAt = streamer is Map && streamer["last_live_at"] != null ? DateTime.parse(streamer["last_live_at"] as String) : null;
  if (lastLiveAt != null && DateTime.now().difference(lastLiveAt).inDays >= 3) {
    final days = DateTime.now().difference(lastLiveAt).inDays;
    return ParticipantEvaluation(status: ParticipantStatus.inativo, gaps: [days.toString() + " dias sem live"]);
  }

  final snapshot = snapshotFromParticipantRow(participantRow);
  if (snapshot == null) return const ParticipantEvaluation(status: ParticipantStatus.atrasado);
  final result = evaluateEligibility(snapshot, criteria);
  if (result.eligible) return const ParticipantEvaluation(status: ParticipantStatus.concluido);
  if (result.gaps.isNotEmpty) return ParticipantEvaluation(status: ParticipantStatus.proximo, gaps: result.gaps);
  return const ParticipantEvaluation(status: ParticipantStatus.atrasado);
}

/// Fecha o ciclo: grava o status final de cada participante, promove (cria
/// o card no proximo programa) quem estiver marcado em promoteStreamerIds,
/// e gera o relatorio-resumo (guardado no proprio ciclo, nao muda depois).
Future<Map<String, dynamic>> concludeCycle({
  required Map<String, dynamic> program,
  required String cycleId,
  required Set<String> promoteStreamerIds,
}) async {
  final client = Supabase.instance.client;
  final criteria = await _cycleCriteria(program, cycleId);
  final cycle = await client.from("campaign_cycles").select("period_label").eq("id", cycleId).single();
  final participants = await fetchCycleParticipants(cycleId: cycleId);

  var concluded = 0;
  var notConcluded = 0;
  var promotions = 0;

  for (final row in participants) {
    final streamerId = row["streamer_id"] as String;
    final evaluation = evaluateParticipant(row, criteria);
    final finalStatus = evaluation.status == ParticipantStatus.concluido ? "concluido" : "nao_concluido";
    if (finalStatus == "concluido") {
      concluded++;
    } else {
      notConcluded++;
    }
    await client.from("campaign_cycle_participants").update({"final_status": finalStatus}).eq("id", row["id"]);

    if (promoteStreamerIds.contains(streamerId)) {
      final nextKey = program["next_program_key"] as String?;
      if (nextKey != null) {
        await createProgramCardIfNeeded(phaseKey: nextKey, streamerId: streamerId);
        promotions++;
      }
      await logProgramaHistory(
        streamerId: streamerId,
        phaseKey: program["program_key"] as String,
        action: "promovido_campanha",
        detail: "Promovido ao concluir " + (cycle["period_label"] as String? ?? ""),
      );
    }
  }

  final awardRows = await client.from("program_awards").select("id").eq("cycle_id", cycleId);
  final awardsCount = (awardRows as List).length;

  final report = {
    "participant_count": participants.length,
    "concluded_count": concluded,
    "not_concluded_count": notConcluded,
    "promotions_count": promotions,
    "awards_count": awardsCount,
    "reprovals_count": notConcluded,
  };

  await client.from("campaign_cycles").update({
    "status": "finalizado",
    "finished_at": DateTime.now().toIso8601String(),
    "report": report,
  }).eq("id", cycleId);

  return report;
}
