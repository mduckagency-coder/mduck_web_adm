const _categoryEmojis = {
  "musico": "\u{1F3B5}",
  "gamer": "\u{1F3AE}",
  "batalha": "⚔️",
  "lifestyle": "\u{1F4AC}",
  "entretenimento": "\u{1F3A4}",
};

/// Emoji da categoria do streamer para deixa-la em destaque nos cards do
/// Onboarding 0-15 Dias. Usa `icon_key` quando definido; senao tenta
/// reconhecer pelo nome da categoria (streamer_categories.name), para
/// funcionar mesmo antes de um admin configurar o icon_key manualmente.
String categoryEmoji({String? iconKey, String? categoryName}) {
  if (iconKey != null && _categoryEmojis.containsKey(iconKey)) return _categoryEmojis[iconKey]!;
  final name = categoryName?.toLowerCase() ?? "";
  for (final entry in _categoryEmojis.entries) {
    if (name.contains(entry.key)) return entry.value;
  }
  if (name.contains("music")) return _categoryEmojis["musico"]!;
  if (name.contains("game")) return _categoryEmojis["gamer"]!;
  if (name.contains("humor") || name.contains("entreten")) return _categoryEmojis["entretenimento"]!;
  return "⭐";
}
