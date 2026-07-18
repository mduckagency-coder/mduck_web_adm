import "package:flutter/material.dart";

IconData categoryIcon(String? iconKey) {
  switch (iconKey) {
    case "gamer":
      return Icons.sports_esports;
    case "batalha":
      return Icons.sports_kabaddi;
    case "desafio":
      return Icons.emoji_events;
    case "musico":
      return Icons.music_note;
    case "modelo":
      return Icons.camera_alt;
    default:
      return Icons.category;
  }
}

Color categoryColor(String? iconKey) {
  switch (iconKey) {
    case "gamer":
      return const Color(0xFF7A0BD4);
    case "batalha":
      return Colors.redAccent;
    case "desafio":
      return Colors.amber;
    case "musico":
      return Colors.blueAccent;
    case "modelo":
      return Colors.pinkAccent;
    default:
      return Colors.tealAccent;
  }
}

const leadOrigins = ["Indicacao Streamers", "TikTok Lead", "Aplicado", "Formulario", "Indicacao CEO / Mduck"];

const categoryIconOptions = [
  ("gamer", "Gamer", Icons.sports_esports),
  ("batalha", "Batalha", Icons.sports_kabaddi),
  ("desafio", "Desafio", Icons.emoji_events),
  ("musico", "Musico", Icons.music_note),
  ("modelo", "Modelo", Icons.camera_alt),
  ("outro", "Outro", Icons.category),
];

