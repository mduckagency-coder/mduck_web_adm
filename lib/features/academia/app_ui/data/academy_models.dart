// Academia MDuck: modelos. (Esta pasta e copiada tal qual para o painel web,
// em mduck_web_adm/lib/features/academia/app_ui, para o "Visualizar como".)

/// Publicos (tipos de streamer). So ordenam/recomendam: nunca bloqueiam.
const academyAudiences = <String, String>{
  "todos": "Todos",
  "games": "🎮 Games",
  "musica": "🎤 Música",
  "batalhas": "⚔️ Batalhas",
  "conversa": "💬 Conversa / variedades",
};

const academyLevels = <String, String>{
  "iniciante": "Iniciante",
  "intermediario": "Intermediário",
  "avancado": "Avançado",
};

List<String> _strings(dynamic v) => v is List ? [for (final x in v) if (x != null) x.toString()] : const [];
int? _int(dynamic v) => v is num ? v.toInt() : int.tryParse("${v ?? ""}");

String academyNormalize(String s) {
  const from = "áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ";
  const to = "aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC";
  final b = StringBuffer();
  for (final ch in s.split("")) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString().toLowerCase();
}

class AcademyCategory {
  final String id;
  final String slug;
  final String title;
  final String? subtitle;
  final String emoji;
  final String theme;
  final String? audience;
  final int sortOrder;

  const AcademyCategory({
    required this.id,
    required this.slug,
    required this.title,
    this.subtitle,
    required this.emoji,
    required this.theme,
    this.audience,
    required this.sortOrder,
  });

  factory AcademyCategory.fromJson(Map j) => AcademyCategory(
        id: j["id"] as String,
        slug: j["slug"] as String? ?? "",
        title: j["title"] as String? ?? "",
        subtitle: j["subtitle"] as String?,
        emoji: j["emoji"] as String? ?? "📚",
        theme: j["theme"] as String? ?? "fundamentos",
        audience: j["audience"] as String?,
        sortOrder: _int(j["sort_order"]) ?? 0,
      );
}

class AcademySeries {
  final String id;
  final String title;
  final String? subtitle;
  final String emoji;
  final String? categoryId;
  final int sortOrder;

  const AcademySeries({required this.id, required this.title, this.subtitle, required this.emoji, this.categoryId, required this.sortOrder});

  factory AcademySeries.fromJson(Map j) => AcademySeries(
        id: j["id"] as String,
        title: j["title"] as String? ?? "",
        subtitle: j["subtitle"] as String?,
        emoji: j["emoji"] as String? ?? "📚",
        categoryId: j["category_id"] as String?,
        sortOrder: _int(j["sort_order"]) ?? 0,
      );
}

/// Aula no catalogo (sem o conteudo).
class AcademyLessonSummary {
  final String id;
  final String? slug;
  final String? categoryId;
  final String? subcategory;
  final String title;
  final String? subtitle;
  final String? summary;
  final List<String> audience;
  final String level;
  final String? thumbnailUrl;
  final String? coverUrl;
  final bool featured;
  final bool recommended;
  final bool startHere;
  final String? seriesId;
  final int? seriesOrder;
  final int sortOrder;
  final int? durationMin;
  final List<String> tags;
  final String availability;
  final String status; // rascunho | revisao | publicado (painel)

  /// open | locked | soon (ja calculado pelo servidor pra quem esta olhando)
  final String access;
  final List<String> blockTypes;
  final String? progressStatus; // null | em_andamento | concluido
  final double progress;
  final DateTime? lastOpenedAt;
  final String? requestStatus; // null | pendente | aprovado | recusado

  const AcademyLessonSummary({
    required this.id,
    this.slug,
    this.categoryId,
    this.subcategory,
    required this.title,
    this.subtitle,
    this.summary,
    required this.audience,
    required this.level,
    this.thumbnailUrl,
    this.coverUrl,
    required this.featured,
    required this.recommended,
    required this.startHere,
    this.seriesId,
    this.seriesOrder,
    required this.sortOrder,
    this.durationMin,
    required this.tags,
    required this.availability,
    required this.status,
    required this.access,
    required this.blockTypes,
    this.progressStatus,
    required this.progress,
    this.lastOpenedAt,
    this.requestStatus,
  });

  factory AcademyLessonSummary.fromJson(Map j) => AcademyLessonSummary(
        id: j["id"] as String,
        slug: j["slug"] as String?,
        categoryId: j["category_id"] as String?,
        subcategory: j["subcategory"] as String?,
        title: j["title"] as String? ?? "Aula",
        subtitle: j["subtitle"] as String?,
        summary: j["summary"] as String?,
        audience: _strings(j["audience"]),
        level: j["level"] as String? ?? "iniciante",
        thumbnailUrl: j["thumbnail_url"] as String?,
        coverUrl: j["cover_url"] as String?,
        featured: j["featured"] == true,
        recommended: j["recommended"] == true,
        startHere: j["start_here"] == true,
        seriesId: j["series_id"] as String?,
        seriesOrder: _int(j["series_order"]),
        sortOrder: _int(j["sort_order"]) ?? 0,
        durationMin: _int(j["duration_min"]),
        tags: _strings(j["tags"]),
        availability: j["availability"] as String? ?? "disponivel",
        status: j["status"] as String? ?? "publicado",
        access: j["access"] as String? ?? "open",
        blockTypes: _strings(j["block_types"]),
        progressStatus: j["progress_status"] as String?,
        progress: (j["progress"] as num?)?.toDouble() ?? 0,
        lastOpenedAt: DateTime.tryParse("${j["last_opened_at"] ?? ""}"),
        requestStatus: j["request_status"] as String?,
      );

  bool get isOpen => access == "open";
  bool get isLocked => access == "locked";
  bool get isSoon => access == "soon";
  bool get isDone => progressStatus == "concluido";
  bool get isStarted => progressStatus == "em_andamento";

  /// nao_iniciado | em_andamento | concluido
  String get learnStatus => progressStatus ?? "nao_iniciado";

  bool get hasVideo => blockTypes.contains("youtube") || blockTypes.contains("video");
  bool get hasQuiz => blockTypes.contains("quiz");
  bool get hasSimulation => blockTypes.any(const {"simulation", "identify", "tiktok_profile", "gift_gallery", "league_ladder"}.contains);
}

class AcademyCatalog {
  final String audience;
  final bool isManager;
  final bool adminView;
  final bool hasProfile;
  final List<AcademyCategory> categories;
  final List<AcademySeries> series;
  final List<AcademyLessonSummary> lessons;

  const AcademyCatalog({
    required this.audience,
    required this.isManager,
    required this.adminView,
    required this.hasProfile,
    required this.categories,
    required this.series,
    required this.lessons,
  });

  factory AcademyCatalog.fromJson(Map j) => AcademyCatalog(
        audience: j["audience"] as String? ?? "todos",
        isManager: j["is_manager"] == true,
        adminView: j["admin_view"] == true,
        hasProfile: j["has_profile"] == true,
        categories: [for (final c in (j["categories"] as List? ?? const [])) AcademyCategory.fromJson(c as Map)],
        series: [for (final s in (j["series"] as List? ?? const [])) AcademySeries.fromJson(s as Map)],
        lessons: [for (final l in (j["lessons"] as List? ?? const [])) AcademyLessonSummary.fromJson(l as Map)],
      );

  AcademyCategory? categoryOf(AcademyLessonSummary l) {
    for (final c in categories) {
      if (c.id == l.categoryId) return c;
    }
    return null;
  }

  List<AcademyLessonSummary> lessonsOf(String categoryId) =>
      lessons.where((l) => l.categoryId == categoryId).toList()..sort(_byOrder);

  List<AcademyLessonSummary> lessonsOfSeries(String seriesId) =>
      lessons.where((l) => l.seriesId == seriesId).toList()..sort((a, b) => (a.seriesOrder ?? 999).compareTo(b.seriesOrder ?? 999));

  static int _byOrder(AcademyLessonSummary a, AcademyLessonSummary b) {
    final s = a.sortOrder.compareTo(b.sortOrder);
    return s != 0 ? s : a.title.compareTo(b.title);
  }

  bool _matchesAudience(AcademyLessonSummary l) => audience != "todos" && l.audience.contains(audience);

  /// Categorias com a do perfil primeiro, depois Fundamentos, depois o resto.
  /// Personalizacao ordena; nunca esconde.
  List<AcademyCategory> get orderedCategories {
    int rank(AcademyCategory c) {
      if (audience != "todos" && c.audience == audience) return 0;
      if (c.slug == "fundamentos") return 1;
      return 2;
    }

    final list = categories.where((c) => lessons.any((l) => l.categoryId == c.id)).toList();
    list.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.sortOrder.compareTo(b.sortOrder);
    });
    return list;
  }

  List<AcademyLessonSummary> get continueLearning {
    final list = lessons.where((l) => l.isStarted && !l.isLocked).toList()
      ..sort((a, b) => (b.lastOpenedAt ?? DateTime(2000)).compareTo(a.lastOpenedAt ?? DateTime(2000)));
    return list.take(6).toList();
  }

  bool get isNewcomer => !lessons.any((l) => l.progressStatus != null);

  /// "Nao sabe por onde comecar?": Fundamentos, conexao e um do seu perfil.
  List<AcademyLessonSummary> get startHere {
    final picks = <AcademyLessonSummary>[];
    final marked = lessons.where((l) => l.startHere && !l.isSoon).toList()..sort(_byOrder);
    final fund = categories.where((c) => c.slug == "fundamentos").firstOrNull;
    final first = marked.where((l) => l.categoryId == fund?.id).firstOrNull ?? marked.firstOrNull;
    if (first != null) picks.add(first);
    final conexao = lessons.where((l) => l.tags.contains("conexão") && !picks.contains(l) && !l.isSoon).toList()
      ..sort((a, b) => (b.startHere ? 1 : 0).compareTo(a.startHere ? 1 : 0));
    if (conexao.isNotEmpty) picks.add(conexao.first);
    final mine = lessons.where((l) => _matchesAudience(l) && !picks.contains(l) && !l.isSoon).toList()
      ..sort((a, b) {
        final f = (b.featured ? 1 : 0).compareTo(a.featured ? 1 : 0);
        return f != 0 ? f : _byOrder(a, b);
      });
    if (mine.isNotEmpty) {
      picks.add(mine.first);
    } else {
      for (final l in marked) {
        if (picks.length >= 3) break;
        if (!picks.contains(l)) picks.add(l);
      }
    }
    return picks.take(3).toList();
  }

  /// "Recomendado para voce": perfil + marcado como recomendado + ainda nao
  /// concluido. Fundamentos iniciantes completam a lista.
  List<AcademyLessonSummary> get recommended {
    int score(AcademyLessonSummary l) {
      var s = 0;
      if (_matchesAudience(l)) s += 4;
      if (l.recommended) s += 2;
      if (l.featured) s += 1;
      if (l.level == "iniciante") s += 1;
      if (l.isOpen) s += 1;
      return s;
    }

    final list = lessons.where((l) => !l.isDone && !l.isStarted && !l.isSoon).toList()
      ..sort((a, b) {
        final c = score(b).compareTo(score(a));
        return c != 0 ? c : _byOrder(a, b);
      });
    return list.take(8).toList();
  }

  List<AcademyLessonSummary> get featured => lessons.where((l) => l.featured && !l.isSoon).toList()..sort(_byOrder);
  List<AcademyLessonSummary> get comingSoon => lessons.where((l) => l.isSoon).toList()..sort(_byOrder);

  /// Progresso geral (aulas liberadas concluidas / aulas liberadas).
  ({int done, int total}) get overall {
    final open = lessons.where((l) => l.isOpen).toList();
    return (done: open.where((l) => l.isDone).length, total: open.length);
  }

  List<AcademyLessonSummary> search(String query, {String? categoryId, String? learnStatus}) {
    final q = academyNormalize(query.trim());
    final words = q.split(RegExp(r"\s+")).where((w) => w.isNotEmpty).toList();
    return lessons.where((l) {
      if (categoryId != null && l.categoryId != categoryId) return false;
      if (learnStatus != null && l.learnStatus != learnStatus) return false;
      if (words.isEmpty) return true;
      final hay = academyNormalize([
        l.title,
        l.subtitle ?? "",
        l.summary ?? "",
        l.subcategory ?? "",
        categoryOf(l)?.title ?? "",
        ...l.tags,
      ].join(" "));
      return words.every(hay.contains);
    }).toList()
      ..sort(_byOrder);
  }
}

/// Aula completa.
class AcademyLesson {
  final AcademyLessonSummary info;
  final List<Map<String, dynamic>> blocks;
  final List<Map<String, dynamic>> sources;
  final DateTime? reviewedAt;
  final String infoStatus;
  final Map<String, dynamic> quiz;

  const AcademyLesson({
    required this.info,
    required this.blocks,
    required this.sources,
    this.reviewedAt,
    required this.infoStatus,
    required this.quiz,
  });

  factory AcademyLesson.fromJson(Map j) => AcademyLesson(
        info: AcademyLessonSummary.fromJson(j),
        blocks: [for (final b in (j["blocks"] as List? ?? const [])) if (b is Map) Map<String, dynamic>.from(b)],
        sources: [for (final s in (j["sources"] as List? ?? const [])) if (s is Map) Map<String, dynamic>.from(s)],
        reviewedAt: DateTime.tryParse("${j["reviewed_at"] ?? ""}"),
        infoStatus: j["info_status"] as String? ?? "revisar",
        quiz: j["quiz"] is Map ? Map<String, dynamic>.from(j["quiz"] as Map) : <String, dynamic>{},
      );
}
