import "package:flutter/material.dart";
import "novidades_home_service.dart";
import "widgets/novidade_form_dialog.dart";

const _purple = Color(0xFF7A0BD4);

const _monthNames = [
  "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
  "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
];

/// Operacoes APP > Novidades Home: cadastro e historico completo das
/// novidades que aparecem no pergaminho da Home do app, organizado por mes.
class NovidadesHomePage extends StatefulWidget {
  const NovidadesHomePage({super.key});

  @override
  State<NovidadesHomePage> createState() => _NovidadesHomePageState();
}

class _NovidadesHomePageState extends State<NovidadesHomePage> {
  final _service = NovidadesHomeService();
  final _search = TextEditingController();

  List<Map<String, dynamic>>? _items;
  Map<String, int> _readCounts = const {};
  List<NewsAudienceOption> _groups = const [];
  List<NewsAudienceOption> _streamers = const [];
  Object? _loadError;
  bool _refreshing = false;

  // filtros
  String? _monthFilter; // "AAAA-MM"
  String _statusFilter = "all"; // all | active | inactive
  String _audienceFilter = "all"; // all | all_streamers | group | individual

  @override
  void initState() {
    super.initState();
    _reload();
    _loadAudienceOptions();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _refreshing = true);
    try {
      final results = await Future.wait([_service.fetchAll(), _service.fetchReadCounts().catchError((_) => <String, int>{})]);
      if (mounted) {
        setState(() {
          _items = results[0] as List<Map<String, dynamic>>;
          _readCounts = results[1] as Map<String, int>;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _loadAudienceOptions() async {
    try {
      final results = await Future.wait([_service.fetchGroups(), _service.fetchStreamers()]);
      if (mounted) {
        setState(() {
          _groups = results[0];
          _streamers = results[1];
        });
      }
    } catch (_) {
      // sem grupos/streamers: o formulario so oferece "Todos" funcionando
    }
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => NovidadeFormDialog(existing: existing, groups: _groups, streamers: _streamers),
    );
    if (saved == null || !mounted) return;
    setState(() {
      final items = [...?_items];
      final index = items.indexWhere((i) => i["id"] == saved["id"]);
      if (index >= 0) {
        items[index] = saved;
      } else {
        items.add(saved);
      }
      items.sort((a, b) => (b["published_at"] as String).compareTo(a["published_at"] as String));
      _items = items;
    });
  }

  Future<void> _toggleActive(Map<String, dynamic> item, bool active) async {
    setState(() {
      _items = [for (final i in _items ?? <Map<String, dynamic>>[]) i["id"] == item["id"] ? {...i, "is_active": active} : i];
    });
    try {
      await _service.setActive(item["id"] as String, active);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Não foi possível alterar: $e")));
      _reload();
    }
  }

  // ---------------- helpers ----------------

  static DateTime _date(Map<String, dynamic> item, String key) =>
      DateTime.tryParse(item[key] as String? ?? "")?.toLocal() ?? DateTime.now();

  static String _monthKey(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, "0")}";

  static String _monthLabel(String key) {
    final parts = key.split("-");
    return "${_monthNames[int.parse(parts[1]) - 1]} ${parts[0]}";
  }

  static String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, "0")}/${d.month.toString().padLeft(2, "0")}/${d.year} ${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}";

  String _audienceLabel(Map<String, dynamic> item) {
    final type = item["target_type"] as String? ?? newsTargetAll;
    final id = item["target_id"] as String?;
    if (type == newsTargetGroup) {
      final g = _groups.where((x) => x.id == id).firstOrNull;
      return "👥 Grupo: ${g?.name ?? "(grupo removido)"}";
    }
    if (type == newsTargetIndividual) {
      final s = _streamers.where((x) => x.id == id).firstOrNull;
      return "👤 @${s?.name ?? "(streamer)"}";
    }
    return "🌍 Todos";
  }

  /// Situacao no app agora: no ar, agendada, expirada ou inativa.
  ({String label, Color color}) _status(Map<String, dynamic> item) {
    if (!(item["is_active"] as bool? ?? true)) return (label: "Inativo", color: Colors.white38);
    final now = DateTime.now();
    if (_date(item, "published_at").isAfter(now)) return (label: "Agendado", color: Colors.lightBlueAccent);
    final exp = item["expires_at"] as String?;
    if (exp != null && DateTime.parse(exp).toLocal().isBefore(now)) return (label: "Expirado", color: Colors.orangeAccent);
    return (label: "Ativo", color: Colors.greenAccent);
  }

  List<Map<String, dynamic>> _filtered() {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final it in _items ?? <Map<String, dynamic>>[])
        if ((_monthFilter == null || _monthKey(_date(it, "published_at")) == _monthFilter) &&
            (_statusFilter == "all" || (_statusFilter == "active") == (it["is_active"] as bool? ?? true)) &&
            (_audienceFilter == "all" ||
                (_audienceFilter == "all_streamers" && it["target_type"] == newsTargetAll) ||
                it["target_type"] == _audienceFilter) &&
            (q.isEmpty ||
                (it["title"] as String).toLowerCase().contains(q) ||
                (it["body"] as String).toLowerCase().contains(q)))
          it,
    ];
  }

  void _preview(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _ParchmentPreview(item: item, date: _fmtDate(_date(item, "published_at"))),
        ),
      ),
    );
  }

  // ---------------- UI ----------------

  Widget _dropdown<T>({required T value, required List<(T, String)> options, required ValueChanged<T> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: const Color(0xFF2A2A2A),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: [for (final o in options) DropdownMenuItem<T>(value: o.$1, child: Text(o.$2))],
          onChanged: (v) => onChanged(v as T),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = _items;
    final months = <String>{for (final it in all ?? <Map<String, dynamic>>[]) _monthKey(_date(it, "published_at"))}.toList()
      ..sort((a, b) => b.compareTo(a));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("📜 Novidades Home", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            _refreshing
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _reload),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text("Nova novidade"),
              style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            "Comunicados da agência que os streamers abrem pelo pergaminho na Home do app. Não geram notificação no sino 🔔. "
            "O histórico fica guardado aqui; o app mostra só as mais recentes.",
            style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),

          // filtros
          Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 260,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search, color: Colors.white54, size: 18),
                  hintText: "Buscar por título ou texto",
                  hintStyle: TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            _dropdown<String?>(
              value: _monthFilter,
              options: [(null, "Todos os meses"), for (final m in months) (m, _monthLabel(m))],
              onChanged: (v) => setState(() => _monthFilter = v),
            ),
            _dropdown<String>(
              value: _statusFilter,
              options: const [("all", "Todos os status"), ("active", "Ativos"), ("inactive", "Inativos")],
              onChanged: (v) => setState(() => _statusFilter = v),
            ),
            _dropdown<String>(
              value: _audienceFilter,
              options: const [
                ("all", "Qualquer público"),
                ("all_streamers", "Para todos"),
                (newsTargetGroup, "Para um grupo"),
                (newsTargetIndividual, "Para um streamer"),
              ],
              onChanged: (v) => setState(() => _audienceFilter = v),
            ),
          ]),
          const SizedBox(height: 16),

          Expanded(child: Builder(builder: (context) {
            if (all == null && _loadError != null) {
              return Center(
                child: Text(
                  "Erro ao carregar: $_loadError\n\nSe a tabela ainda não existe, rode a migration 0087_novidades_home.sql no Supabase.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              );
            }
            if (all == null) return const Center(child: CircularProgressIndicator());
            if (all.isEmpty) {
              return const Center(
                child: Text("Nenhuma novidade ainda. Clique em \"Nova novidade\".", style: TextStyle(color: Colors.white54)),
              );
            }
            final items = _filtered();
            if (items.isEmpty) {
              return const Center(child: Text("Nada encontrado com esses filtros.", style: TextStyle(color: Colors.white54)));
            }

            // historico por mes (mais recente primeiro)
            final byMonth = <String, List<Map<String, dynamic>>>{};
            for (final it in items) {
              byMonth.putIfAbsent(_monthKey(_date(it, "published_at")), () => []).add(it);
            }
            return ListView(children: [
              for (final entry in byMonth.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8),
                  child: Row(children: [
                    Text(_monthLabel(entry.key),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 8),
                    Text("· ${entry.value.length} novidade(s)", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(width: 12),
                    const Expanded(child: Divider(color: Colors.white12)),
                  ]),
                ),
                for (final it in entry.value) _newsCard(it),
                const SizedBox(height: 12),
              ],
            ]);
          })),
        ],
      ),
    );
  }

  Widget _newsCard(Map<String, dynamic> it) {
    final status = _status(it);
    final reads = _readCounts[it["id"]] ?? 0;
    final exp = it["expires_at"] as String?;
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (it["image_url"] != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(it["image_url"] as String, width: 56, height: 56, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(width: 56, height: 56)),
              ),
            ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.circle, size: 10, color: status.color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(it["title"] as String,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(status.label, style: TextStyle(color: status.color, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                (it["body"] as String).replaceAll("\n", " "),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                "Publicado em ${_fmtDate(_date(it, "published_at"))}"
                "${exp != null ? "  ·  expira ${_fmtDate(DateTime.parse(exp).toLocal())}" : ""}"
                "  ·  ${_audienceLabel(it)}  ·  👁 lida por $reads",
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ]),
          ),
          IconButton(
              tooltip: "Visualizar", icon: const Icon(Icons.visibility, color: Colors.white54, size: 18), onPressed: () => _preview(it)),
          IconButton(tooltip: "Editar", icon: const Icon(Icons.edit, color: Colors.white54, size: 18), onPressed: () => _openForm(it)),
          Tooltip(
            message: "Ativo",
            child: Switch(
              value: it["is_active"] as bool? ?? true,
              activeThumbColor: _purple,
              onChanged: (v) => _toggleActive(it, v),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Previa de como a novidade aparece no pergaminho do app.
class _ParchmentPreview extends StatelessWidget {
  final Map<String, dynamic> item;
  final String date;
  const _ParchmentPreview({required this.item, required this.date});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF4A3018);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6E7C1), Color(0xFFEBD49F)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB08A4E), width: 2),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Center(
          child: Text("NOVIDADES", style: TextStyle(color: ink, fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 14)),
        ),
        const Divider(color: Color(0x554A3018)),
        Text(date, style: const TextStyle(color: Color(0xFF8A6A3E), fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(item["title"] as String, style: const TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.bold)),
        if (item["image_url"] != null) ...[
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(item["image_url"] as String)),
        ],
        const SizedBox(height: 6),
        Text(item["body"] as String, style: const TextStyle(color: ink, fontSize: 14, height: 1.4)),
        if (item["link_url"] != null) ...[
          const SizedBox(height: 10),
          Text("🔗 ${item["link_label"] ?? "Saiba mais"}",
              style: const TextStyle(color: Color(0xFF7A0BD4), fontWeight: FontWeight.bold)),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar", style: TextStyle(color: ink))),
        ),
      ]),
    );
  }
}
