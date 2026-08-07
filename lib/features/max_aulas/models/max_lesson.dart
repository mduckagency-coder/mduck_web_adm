/// geral | batalha | musico | games
enum MaxLessonCategory { geral, batalha, musico, games }

MaxLessonCategory maxLessonCategoryFromDb(String value) {
  return MaxLessonCategory.values.firstWhere((c) => c.name == value, orElse: () => MaxLessonCategory.geral);
}

String maxLessonCategoryToDb(MaxLessonCategory category) => category.name;

String maxLessonCategoryLabel(MaxLessonCategory category) {
  switch (category) {
    case MaxLessonCategory.geral:
      return "Geral";
    case MaxLessonCategory.batalha:
      return "Batalha";
    case MaxLessonCategory.musico:
      return "Músico";
    case MaxLessonCategory.games:
      return "Games";
  }
}

/// iniciante | veterano | pro
enum MaxLessonLevel { iniciante, veterano, pro }

MaxLessonLevel maxLessonLevelFromDb(String value) {
  return MaxLessonLevel.values.firstWhere((l) => l.name == value, orElse: () => MaxLessonLevel.iniciante);
}

String maxLessonLevelToDb(MaxLessonLevel level) => level.name;

String maxLessonLevelLabel(MaxLessonLevel level) {
  switch (level) {
    case MaxLessonLevel.iniciante:
      return "Iniciante";
    case MaxLessonLevel.veterano:
      return "Veterano";
    case MaxLessonLevel.pro:
      return "Pro";
  }
}

/// upload | youtube
enum MaxLessonVideoSource { upload, youtube }

MaxLessonVideoSource maxLessonVideoSourceFromDb(String value) {
  return value == "youtube" ? MaxLessonVideoSource.youtube : MaxLessonVideoSource.upload;
}

String maxLessonVideoSourceToDb(MaxLessonVideoSource source) => source == MaxLessonVideoSource.youtube ? "youtube" : "upload";

class MaxLesson {
  final String id;
  final String title;
  final String? description;
  final MaxLessonCategory category;
  final MaxLessonLevel level;
  final String coverImageUrl;
  final MaxLessonVideoSource videoSource;
  final String videoUrl;
  final bool isActive;
  final DateTime createdAt;

  const MaxLesson({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.level,
    required this.coverImageUrl,
    required this.videoSource,
    required this.videoUrl,
    required this.isActive,
    required this.createdAt,
  });

  factory MaxLesson.fromMap(Map<String, dynamic> map) {
    return MaxLesson(
      id: map["id"] as String,
      title: map["title"] as String,
      description: map["description"] as String?,
      category: maxLessonCategoryFromDb(map["category"] as String),
      level: maxLessonLevelFromDb(map["level"] as String),
      coverImageUrl: map["cover_image_url"] as String,
      videoSource: maxLessonVideoSourceFromDb(map["video_source"] as String),
      videoUrl: map["video_url"] as String,
      isActive: map["is_active"] as bool? ?? true,
      createdAt: DateTime.parse(map["created_at"] as String),
    );
  }
}
