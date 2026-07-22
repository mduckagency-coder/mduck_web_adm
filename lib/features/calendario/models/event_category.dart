class EventCategory {
  final String id;
  final String key;
  final String name;
  final String color;
  final String? iconKey;
  final int orderIndex;
  final bool isActive;

  /// Para quem essa categoria e relevante: "agencia", "streamer" ou "ambos".
  final String scope;

  EventCategory({
    required this.id,
    required this.key,
    required this.name,
    required this.color,
    required this.iconKey,
    required this.orderIndex,
    required this.isActive,
    this.scope = "ambos",
  });

  bool matchesScope(String? eventScope) => eventScope == null || scope == "ambos" || scope == eventScope;

  factory EventCategory.fromMap(Map<String, dynamic> map) {
    return EventCategory(
      id: map["id"] as String,
      key: map["key"] as String,
      name: map["name"] as String,
      color: map["color"] as String? ?? "#7A0BD4",
      iconKey: map["icon_key"] as String?,
      orderIndex: map["order_index"] as int? ?? 999,
      isActive: map["is_active"] as bool? ?? true,
      scope: map["scope"] as String? ?? "ambos",
    );
  }
}
