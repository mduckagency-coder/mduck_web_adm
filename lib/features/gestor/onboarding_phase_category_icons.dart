import "package:flutter/material.dart";

/// Icone Material por categoria, mesmo padrao visual da pagina de Leads
/// (badge sobre o avatar, ver lead_category_icons.dart -> categoryIcon).
IconData categoryIconData(String? iconKey) {
  switch (iconKey) {
    case "gamer":
      return Icons.sports_esports;
    case "batalha":
      return Icons.sports_mma;
    case "musico":
      return Icons.music_note;
    case "lifestyle":
      return Icons.emoji_emotions;
    case "entretenimento":
      return Icons.theater_comedy;
    default:
      return Icons.category;
  }
}

/// Cor por categoria (independente da cor da etapa/coluna), mesmo padrao
/// da pagina de Leads (categoryColor em lead_category_icons.dart).
Color categoryColorFor(String? iconKey) {
  switch (iconKey) {
    case "gamer":
      return const Color(0xFF7A0BD4);
    case "batalha":
      return Colors.redAccent;
    case "musico":
      return Colors.blueAccent;
    case "lifestyle":
      return Colors.pinkAccent;
    case "entretenimento":
      return Colors.amber;
    default:
      return Colors.tealAccent;
  }
}
