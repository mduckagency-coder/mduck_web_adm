import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

/// Tipos de acao registraveis em Gestao de Streamers -- cada um vira uma
/// coluna do Kanban. Sem CHECK rigido no banco (streamer_stage.stage_key)
/// de proposito, mesmo espirito de streamer_tasks.activity_type
/// (migration 0045): adicionar um tipo novo aqui e o suficiente, sem outra
/// migration.
class StreamerStage {
  final String key;
  final String label;
  final IconData icon;
  const StreamerStage(this.key, this.label, this.icon);
}

/// Coluna inicial (todo streamer sem acao registrada, ausencia de linha em
/// streamer_stage) e a coluna automatica de inatividade (nunca gravada por
/// acao do gestor -- calculada a partir de last_live_at, sempre vence sobre
/// qualquer stage_key salvo).
const painelGeralKey = "painel_geral";
const reaverDesligarKey = "reaver_desligar";

const streamerStages = [
  StreamerStage("treinamento", "Treinamento", Icons.school),
  StreamerStage(
    "acompanhamento_live",
    "Acompanhamento em Live",
    Icons.live_tv,
  ),
  StreamerStage("call_individual", "Call Individual", Icons.call),
  StreamerStage("configuracao_pc", "Configuração PC", Icons.computer),
  StreamerStage(
    "programa_desenvolvimento",
    "Programa de Desenvolvimento",
    Icons.trending_up,
  ),
  StreamerStage("batalha_oficial", "Batalha Oficial", Icons.sports_mma),
  StreamerStage("outros", "Outros", Icons.more_horiz),
];

StreamerStage? stageFor(String key) {
  for (final s in streamerStages) {
    if (s.key == key) return s;
  }
  return null;
}

class StreamerStageInfo {
  final String stageKey;
  final String? note;
  final DateTime? dueAt;
  final String? setByLabel;
  final DateTime setAt;

  const StreamerStageInfo({
    required this.stageKey,
    this.note,
    this.dueAt,
    this.setByLabel,
    required this.setAt,
  });
}

/// Todos os streamers da agencia de uma vez -- sem linha == painel_geral
/// (nao precisa backfill nenhum).
Future<Map<String, StreamerStageInfo>> fetchStreamerStages({
  required String agencyId,
}) async {
  final rows = await Supabase.instance.client
      .from("streamer_stage")
      .select(
        "streamer_id, stage_key, note, due_at, set_at, managers!streamer_stage_set_by_fkey(login_email)",
      )
      .eq("agency_id", agencyId);
  final result = <String, StreamerStageInfo>{};
  for (final r in (rows as List).cast<Map<String, dynamic>>()) {
    final managerData = r["managers"];
    result[r["streamer_id"] as String] = StreamerStageInfo(
      stageKey: r["stage_key"] as String,
      note: r["note"] as String?,
      dueAt: r["due_at"] != null ? DateTime.parse(r["due_at"] as String) : null,
      setByLabel: managerData is Map
          ? managerData["login_email"] as String?
          : null,
      setAt: DateTime.parse(r["set_at"] as String),
    );
  }
  return result;
}

/// Registra uma acao -- move o streamer pra coluna `stageKey`. Usada tanto
/// pelo dialog rico (StreamerActionDialog, com nota/prazo) quanto pelo
/// arrastar direto no kanban (so o stageKey, sem nota/prazo). Quando ha
/// observacao, tambem grava em streamer_contact_logs (mesmo padrao de
/// sempre) pra continuar aparecendo no historico do painel lateral.
Future<void> registerStreamerAction({
  required String streamerId,
  required String agencyId,
  required String stageKey,
  String? note,
  int? dueInDays,
  String? performedByManagerId,
  String? performedByLabel,
}) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser!.id;
  final performedBy = performedByManagerId ?? userId;
  final performedLabel =
      performedByLabel ?? client.auth.currentUser?.email ?? "Gestor";
  final dueAt = dueInDays != null
      ? DateTime.now().add(Duration(days: dueInDays))
      : null;

  await client.from("streamer_stage").upsert({
    "streamer_id": streamerId,
    "agency_id": agencyId,
    "stage_key": stageKey,
    "note": note,
    "due_at": dueAt?.toIso8601String(),
    "set_by": performedBy,
    "set_at": DateTime.now().toIso8601String(),
  }, onConflict: "streamer_id");

  if (note != null && note.trim().isNotEmpty) {
    final label = stageFor(stageKey)?.label ?? stageKey;
    await client.from("streamer_contact_logs").insert({
      "streamer_id": streamerId,
      "manager_id": performedBy,
      "manager_label": performedLabel,
      "message_sent": label + ": " + note.trim(),
      "context": "gestao_streamers",
    });
  }
}
