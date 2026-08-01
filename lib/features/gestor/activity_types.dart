import "package:flutter/material.dart";

/// Tipos de atividade da tela Streamers (visualizacao Calendario) --
/// mesmo padrao de const de diamond_tiers.dart. "Geral" e o fallback
/// pra tarefas sem tipo escolhido (activity_type nulo), como as criadas
/// pelo campo simples "Proxima acao" do painel lateral.
class ActivityType {
  final String key;
  final String label;
  final Color color;
  const ActivityType(this.key, this.label, this.color);
}

const activityTypes = [
  ActivityType("reuniao", "Reunião", Color(0xFF2D9CDB)),
  ActivityType("treinamento", "Treinamento", Color(0xFF7A0BD4)),
  ActivityType("avaliacao", "Avaliação", Colors.amber),
  ActivityType("recuperacao", "Recuperação", Colors.redAccent),
  ActivityType("meta_semanal", "Meta semanal", Colors.cyanAccent),
  ActivityType("meta_mensal", "Meta mensal", Color(0xFF00BCD4)),
  ActivityType("graduacao", "Graduação", Colors.greenAccent),
  ActivityType("followup", "Follow-up", Colors.orangeAccent),
];

const _geral = ActivityType("geral", "Geral", Colors.white38);

ActivityType activityTypeFor(String? key) {
  if (key == null) return _geral;
  for (final t in activityTypes) {
    if (t.key == key) return t;
  }
  return _geral;
}

/// Agrupamento usado pelo filtro "Tipos de atividade" do Calendario --
/// junta os 8 tipos em 6 categorias de filtro, conforme pedido.
const activityTypeFilterGroups = {
  "Reuniões": ["reuniao"],
  "Treinamentos": ["treinamento"],
  "Metas": ["meta_semanal", "meta_mensal"],
  "Avaliações": ["avaliacao"],
  "Recuperações": ["recuperacao"],
  "Graduações": ["graduacao"],
};
