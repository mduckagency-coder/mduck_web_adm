import "package:flutter/material.dart";
import "max_lessons_service.dart";
import "models/max_lesson.dart";
import "widgets/lesson_form_dialog.dart";

class MaxAulasPage extends StatefulWidget {
  const MaxAulasPage({super.key});

  @override
  State<MaxAulasPage> createState() => _MaxAulasPageState();
}

class _MaxAulasPageState extends State<MaxAulasPage> {
  final _service = MaxLessonsService();
  List<MaxLesson> _lessons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _service.fetchLessons();
    if (mounted) {
      setState(() {
        _lessons = rows;
        _loading = false;
      });
    }
  }

  Future<void> _openForm({MaxLesson? existing}) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => LessonFormDialog(existing: existing));
    if (saved == true) _load();
  }

  Widget _lessonCard(MaxLesson lesson) {
    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openForm(existing: lesson),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(lesson.coverImageUrl, width: 96, height: 64, fit: BoxFit.cover),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(lesson.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                      if (!lesson.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
                          child: const Text("Inativa", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ]),
                    if (lesson.description != null && lesson.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(lesson.description!, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _tag(maxLessonCategoryLabel(lesson.category), const Color(0xFF2E86DE)),
                      _tag(maxLessonLevelLabel(lesson.level), const Color(0xFF7A0BD4)),
                      _tag(lesson.videoSource == MaxLessonVideoSource.youtube ? "YouTube" : "Upload", Colors.white24),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color == Colors.white24 ? Colors.white70 : color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("MAX Aulas", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text("Nova aula"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            "Aulas exibidas no botão MAX do aplicativo do streamer.",
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _lessons.isEmpty
                    ? const Center(child: Text("Nenhuma aula cadastrada ainda.", style: TextStyle(color: Colors.white54)))
                    : ListView(children: _lessons.map(_lessonCard).toList()),
          ),
        ],
      ),
    );
  }
}
