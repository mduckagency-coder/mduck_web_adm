import "package:flutter/material.dart";

/// Tipo de registro do inventario (coluna category). Cada tipo tem
/// identidade visual propria (emoji + cor) e diz se costuma ter valor.
class InventoryType {
  final String key;
  final String emoji;
  final String label;
  final String plural; // "presentes", "treinamentos"...
  final Color color;
  final bool usuallyHasAmount;

  /// Tipos antigos: continuam aparecendo nos registros existentes, mas nao
  /// sao oferecidos em registros novos (conquistas agora sao automaticas).
  final bool legacy;

  const InventoryType(this.key, this.emoji, this.label, this.plural, this.color, {this.usuallyHasAmount = false, this.legacy = false});
}

/// Tipos da Jornada MDUCK (registros manuais da equipe).
const inventoryTypes = [
  InventoryType("presente", "🎁", "Presente", "presentes", Color(0xFFFF6FAE), usuallyHasAmount: true),
  InventoryType("treinamento", "🎓", "Treinamento", "treinamentos", Color(0xFF5BA8FF)),
  InventoryType("recompensa", "🏅", "Premiação", "premiações", Color(0xFF4DE3E3), usuallyHasAmount: true),
  InventoryType("campanha", "🎯", "Campanha", "campanhas", Color(0xFFFF8A4D)),
  InventoryType("evento", "🎪", "Evento", "eventos", Color(0xFFC77DFF)),
  InventoryType("suporte", "🤝", "Suporte", "suportes", Color(0xFF6EDC8C)),
  InventoryType("pix", "💰", "Pix", "pix", Color(0xFF3DDC97), usuallyHasAmount: true),
  InventoryType("evolucao", "📈", "Evolução", "evoluções", Color(0xFF4FA3FF)),
  InventoryType("objetivo", "🚩", "Objetivo", "objetivos", Color(0xFF8A6CFF)),
  InventoryType("conquista", "🏆", "Conquista", "conquistas", Color(0xFFFFC94D)),
  InventoryType("outros", "📦", "Outros", "outros", Color(0xFFB0A8C0)),
  InventoryType("reconhecimento", "🎖", "Reconhecimento", "reconhecimentos", Color(0xFFE8B86D), legacy: true),
];

InventoryType inventoryTypeOf(String key) =>
    inventoryTypes.firstWhere((t) => t.key == key, orElse: () => inventoryTypes.firstWhere((t) => t.key == "outros"));

const inventoryStatuses = {"concluido": "Concluído", "pendente": "Pendente", "cancelado": "Cancelado"};

/// 1234.5 -> "R$ 1.234,50"
String formatBrl(num value) {
  final cents = (value * 100).round();
  final reais = (cents ~/ 100).abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < reais.length; i++) {
    if (i > 0 && (reais.length - i) % 3 == 0) buf.write(".");
    buf.write(reais[i]);
  }
  return "${cents < 0 ? "-" : ""}R\$ $buf,${(cents.abs() % 100).toString().padLeft(2, "0")}";
}

/// Um registro do historico do streamer (tabela streamer_inventory_entries).
class InventoryEntry {
  final String id;
  final String streamerId;
  final String category;
  final String title;
  final String? description;
  final DateTime occurredAt;
  final String? imageUrl;
  final double? amount;
  final bool showAmount;
  final bool visibleToStreamer;
  final String? internalNote;
  final String status;
  final String? createdByLabel;
  final DateTime createdAt;

  const InventoryEntry({
    required this.id,
    required this.streamerId,
    required this.category,
    required this.title,
    this.description,
    required this.occurredAt,
    this.imageUrl,
    this.amount,
    required this.showAmount,
    required this.visibleToStreamer,
    this.internalNote,
    required this.status,
    this.createdByLabel,
    required this.createdAt,
  });

  InventoryType get type => inventoryTypeOf(category);

  factory InventoryEntry.fromMap(Map<String, dynamic> m) {
    final manager = m["created_by_manager"];
    String? by;
    if (manager is Map) {
      final name = (manager["full_name"] as String?)?.trim();
      by = (name != null && name.isNotEmpty) ? name : manager["login_email"] as String?;
    }
    return InventoryEntry(
      id: m["id"] as String,
      streamerId: m["streamer_id"] as String,
      category: m["category"] as String? ?? "outros",
      title: m["title"] as String? ?? "",
      description: m["description"] as String?,
      occurredAt: DateTime.parse(m["occurred_at"] as String),
      imageUrl: m["image_url"] as String?,
      amount: (m["amount"] as num?)?.toDouble(),
      showAmount: m["show_amount"] as bool? ?? true,
      visibleToStreamer: m["visible_to_streamer"] as bool? ?? true,
      internalNote: m["internal_note"] as String?,
      status: m["status"] as String? ?? "concluido",
      createdByLabel: by,
      createdAt: DateTime.tryParse(m["created_at"] as String? ?? "") ?? DateTime.now(),
    );
  }
}
