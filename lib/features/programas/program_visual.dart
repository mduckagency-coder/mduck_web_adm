import "package:flutter/material.dart";

/// Identidade visual de um programa (cor + icone). Mesmo padrao ja usado
/// pelas categorias de evento/lead (icon_key + hex color), concentrado aqui
/// porque e reaproveitado em 3 telas: card da lista, header do detalhe e
/// Configuracoes.
const programIconOptions = [
  ("foguete", "Foguete", Icons.rocket_launch),
  ("estrela", "Estrela", Icons.star),
  ("medalha", "Medalha", Icons.military_tech),
  ("selo", "Selo Premium", Icons.workspace_premium),
  ("trofeu", "Trofeu", Icons.emoji_events),
  ("diamante", "Diamante", Icons.diamond),
  ("bandeira", "Bandeira", Icons.flag),
];

IconData programIcon(String? key) {
  for (final option in programIconOptions) {
    if (option.$1 == key) return option.$3;
  }
  return Icons.workspace_premium;
}

Color hexToColor(String hex) {
  final cleaned = hex.replaceFirst("#", "");
  return Color(int.parse("FF" + cleaned, radix: 16));
}
