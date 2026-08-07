import "package:flutter/material.dart";

/// treinamento | acompanhamento | premiacao | conquista
enum InventoryCategory { treinamento, acompanhamento, premiacao, conquista }

InventoryCategory inventoryCategoryFromDb(String value) {
  return InventoryCategory.values.firstWhere((c) => c.name == value, orElse: () => InventoryCategory.conquista);
}

String inventoryCategoryToDb(InventoryCategory category) => category.name;

String inventoryCategoryLabel(InventoryCategory category) {
  switch (category) {
    case InventoryCategory.treinamento:
      return "Treinamento";
    case InventoryCategory.acompanhamento:
      return "Acompanhamento";
    case InventoryCategory.premiacao:
      return "Premiação";
    case InventoryCategory.conquista:
      return "Conquista";
  }
}

/// Frase "de jogo" usada no card, ex: "Ganhou experiência", "Evoluiu
/// habilidades" -- reforca a ideia de progresso pedida pelo usuario.
String inventoryCategoryVerb(InventoryCategory category) {
  switch (category) {
    case InventoryCategory.treinamento:
      return "Ganhou experiência";
    case InventoryCategory.acompanhamento:
      return "Evoluiu habilidades";
    case InventoryCategory.premiacao:
      return "Recebeu premiação";
    case InventoryCategory.conquista:
      return "Desbloqueou conquista";
  }
}

IconData inventoryCategoryIcon(InventoryCategory category) {
  switch (category) {
    case InventoryCategory.treinamento:
      return Icons.school;
    case InventoryCategory.acompanhamento:
      return Icons.trending_up;
    case InventoryCategory.premiacao:
      return Icons.card_giftcard;
    case InventoryCategory.conquista:
      return Icons.emoji_events;
  }
}

Color inventoryCategoryColor(InventoryCategory category) {
  switch (category) {
    case InventoryCategory.treinamento:
      return const Color(0xFFE67E22);
    case InventoryCategory.acompanhamento:
      return const Color(0xFF2E86DE);
    case InventoryCategory.premiacao:
      return const Color(0xFFF1C40F);
    case InventoryCategory.conquista:
      return const Color(0xFF27AE60);
  }
}

class InventoryEntry {
  final String id;
  final String streamerId;
  final InventoryCategory category;
  final String title;
  final String? description;
  final DateTime occurredAt;
  final int? points;
  final String? imageUrl;
  final String source;
  final String? createdByManagerName;
  final DateTime createdAt;

  const InventoryEntry({
    required this.id,
    required this.streamerId,
    required this.category,
    required this.title,
    this.description,
    required this.occurredAt,
    this.points,
    this.imageUrl,
    this.source = "manual",
    this.createdByManagerName,
    required this.createdAt,
  });

  factory InventoryEntry.fromMap(Map<String, dynamic> map) {
    final creator = map["created_by_manager"] as Map<String, dynamic>?;
    return InventoryEntry(
      id: map["id"] as String,
      streamerId: map["streamer_id"] as String,
      category: inventoryCategoryFromDb(map["category"] as String),
      title: map["title"] as String,
      description: map["description"] as String?,
      occurredAt: DateTime.parse(map["occurred_at"] as String),
      points: map["points"] as int?,
      imageUrl: map["image_url"] as String?,
      source: map["source"] as String? ?? "manual",
      createdByManagerName: (creator?["full_name"] as String?) ?? (creator?["login_email"] as String?),
      createdAt: DateTime.parse(map["created_at"] as String),
    );
  }
}
