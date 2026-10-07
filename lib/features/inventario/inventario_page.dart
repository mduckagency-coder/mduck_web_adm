import "dart:async";

import "package:flutter/material.dart";
import "inventario_service.dart";
import "models/inventory_entry.dart";
import "widgets/inventory_entry_form_dialog.dart";
import "conquistas_admin.dart";
import "journey_admin.dart";
import "journey_config_admin.dart";

const _purple = Color(0xFF7A0BD4);
const _purpleLight = Color(0xFFB98CFF);
const _gold = Color(0xFFFFC94D);
const _card = Color(0xFF1B1626);

const _months = [
  "JANEIRO", "FEVEREIRO", "MARÇO", "ABRIL", "MAIO", "JUNHO",
  "JULHO", "AGOSTO", "SETEMBRO", "OUTUBRO", "NOVEMBRO", "DEZEMBRO",
];

String _thousands(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(".");
    b.write(s[i]);
  }
  return b.toString();
}

String _date(DateTime d) => "${d.day.toString().padLeft(2, "0")}/${d.month.toString().padLeft(2, "0")}/${d.year}";

/// Home Central > Inventario, em duas partes bem separadas:
///   CONQUISTAS     automaticas -- o sistema desbloqueia (conquistas_admin.dart)
///   JORNADA MDUCK  manual -- a equipe registra o que a MDUCK fez pelo
///                  streamer (mesma tabela da linha do tempo do CRM e do app)
class InventarioPage extends StatelessWidget {
  const InventarioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("INVENTÁRIO", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1)),
            Text("No app aparece como JORNADA: marcos do mês, conquistas, constância, primeiros 90 dias e o que a MDUCK Agency fez por cada streamer.", style: TextStyle(color: Colors.white54, fontSize: 14)),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: _gold,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
            tabs: [
              Tab(text: "✦  CONQUISTAS"),
              Tab(text: "✨  JORNADA MDUCK"),
              Tab(text: "📅  MARCOS DO MÊS"),
              Tab(text: "🎨  ARTES DOS MARCOS"),
              Tab(text: "🛡  BRASÕES"),
              Tab(text: "⚙️  CONFIGURAÇÕES"),
            ],
          ),
        ),
        const Expanded(child: TabBarView(children: [
          ConquistasAdmin(),
          _JornadaTab(),
          MarcosDoMesAdmin(),
          ArtesDosMarcosAdmin(),
          BrasoesAdmin(),
          JourneyConfigAdmin(),
        ])),
      ]),
    );
  }
}

/// Jornada MDUCK: escolhe o streamer e registra/gerencia os momentos.
class _JornadaTab extends StatefulWidget {
  const _JornadaTab();

  @override
  State<_JornadaTab> createState() => _JornadaTabState();
}

class _JornadaTabState extends State<_JornadaTab> {
  final _service = InventarioService();
  Map<String, dynamic>? _streamer;

  @override
  Widget build(BuildContext context) {
    final streamer = _streamer;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: streamer == null
          ? _StreamerPicker(key: const ValueKey("picker"), service: _service, onPick: (s) => setState(() => _streamer = s))
          : _StreamerInventory(
              key: ValueKey(streamer["id"]),
              service: _service,
              streamer: streamer,
              onChangeStreamer: () => setState(() => _streamer = null),
            ),
    );
  }
}

// ============================================================================
// 1. Escolher o streamer
// ============================================================================
class _StreamerPicker extends StatefulWidget {
  final InventarioService service;
  final ValueChanged<Map<String, dynamic>> onPick;
  const _StreamerPicker({super.key, required this.service, required this.onPick});

  @override
  State<_StreamerPicker> createState() => _StreamerPickerState();
}

class _StreamerPickerState extends State<_StreamerPicker> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>>? _results;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _run);
  }

  Future<void> _run() async {
    try {
      final rows = await widget.service.fetchStreamers(search: _search.text);
      if (mounted) setState(() => _results = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("✨ JORNADA MDUCK", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 4),
        const Text("Selecione um streamer para ver e registrar os momentos que a MDUCK Agency fez acontecer com ele.",
            style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: TextField(
            controller: _search,
            autofocus: true,
            onChanged: _onChanged,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              prefixIcon: const Icon(Icons.search, color: _purpleLight),
              hintText: "Buscar por nome, @username ou ID do TikTok",
              hintStyle: const TextStyle(color: Colors.white38),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _purple, width: 2)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: _error != null && results == null
              ? Center(child: Text("Erro ao buscar: $_error", style: const TextStyle(color: Colors.redAccent)))
              : results == null
                  ? const Center(child: CircularProgressIndicator())
                  : results.isEmpty
                      ? const Center(child: Text("Nenhum streamer encontrado.", style: TextStyle(color: Colors.white54)))
                      : LayoutBuilder(builder: (context, c) {
                          final cols = (c.maxWidth / 260).floor().clamp(1, 6);
                          return GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              mainAxisExtent: 84,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: results.length,
                            itemBuilder: (context, i) => _streamerTile(results[i]),
                          );
                        }),
        ),
      ]),
    );
  }

  Widget _streamerTile(Map<String, dynamic> s) {
    final username = s["tiktok_username"] as String?;
    final id = s["tiktok_creator_id"] as String?;
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        hoverColor: _purple.withValues(alpha: 0.12),
        onTap: () => widget.onPick(s),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            _Avatar(url: s["avatar_url"] as String?, name: s["display_name"] as String? ?? "?", size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s["display_name"] as String? ?? "-",
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                if (username != null && username.isNotEmpty)
                  Text("@$username", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _purpleLight, fontSize: 12)),
                if (id != null && id.isNotEmpty)
                  Text("ID $id", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ]),
            ),
            if (s["is_active"] == false)
              const Tooltip(message: "Inativo na agência", child: Icon(Icons.pause_circle_outline, color: Colors.white38, size: 18)),
          ]),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. Inventario do streamer
// ============================================================================
class _StreamerInventory extends StatefulWidget {
  final InventarioService service;
  final Map<String, dynamic> streamer;
  final VoidCallback onChangeStreamer;
  const _StreamerInventory({super.key, required this.service, required this.streamer, required this.onChangeStreamer});

  @override
  State<_StreamerInventory> createState() => _StreamerInventoryState();
}

class _StreamerInventoryState extends State<_StreamerInventory> {
  List<InventoryEntry>? _entries;
  StreamerQuickStats? _stats;
  Object? _error;

  // filtros
  bool _showFilters = false;
  final _search = TextEditingController();
  String? _typeFilter;
  String? _monthFilter; // "AAAA-MM"
  String? _statusFilter;
  bool? _visibleFilter;

  String get _id => widget.streamer["id"] as String;
  String get _name {
    final u = widget.streamer["tiktok_username"] as String?;
    return (u != null && u.isNotEmpty) ? u : (widget.streamer["display_name"] as String? ?? "streamer");
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.service.fetchEntries(_id),
        widget.service.fetchStats(_id).catchError((_) => const StreamerQuickStats(diamonds: 0, hours: 0, daysLive: 0)),
      ]);
      if (!mounted) return;
      setState(() {
        _entries = results[0] as List<InventoryEntry>;
        _stats = results[1] as StreamerQuickStats;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _openForm([InventoryEntry? existing]) async {
    final saved = await showDialog<InventoryEntry>(
      context: context,
      builder: (_) => InventoryEntryFormDialog(streamerId: _id, streamerName: _name, existing: existing),
    );
    if (saved == null || !mounted) return;
    setState(() {
      final list = [...?_entries];
      final i = list.indexWhere((e) => e.id == saved.id);
      if (i >= 0) {
        list[i] = saved;
      } else {
        list.add(saved);
      }
      list.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      _entries = list;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: _purple,
      content: Text(existing == null ? "${saved.type.emoji} Registro adicionado ao inventário de @$_name." : "Registro atualizado."),
    ));
  }

  Future<void> _delete(InventoryEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Excluir registro?", style: TextStyle(color: Colors.white)),
        content: Text("\"${e.title}\" sai do inventário, do CRM e do app. Essa ação não pode ser desfeita.",
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Excluir", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _entries = [...?_entries]..removeWhere((x) => x.id == e.id));
    try {
      await widget.service.deleteEntry(e.id);
    } catch (err) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Não foi possível excluir: $err")));
      _load();
    }
  }

  static String _monthKey(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, "0")}";
  static String _monthLabel(String k) => "${_months[int.parse(k.split("-")[1]) - 1]} ${k.split("-")[0]}";

  List<InventoryEntry> _filtered(List<InventoryEntry> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((e) {
      return (_typeFilter == null || e.category == _typeFilter) &&
          (_monthFilter == null || _monthKey(e.occurredAt) == _monthFilter) &&
          (_statusFilter == null || e.status == _statusFilter) &&
          (_visibleFilter == null || e.visibleToStreamer == _visibleFilter) &&
          (q.isEmpty || e.title.toLowerCase().contains(q) || (e.description ?? "").toLowerCase().contains(q));
    }).toList();
  }

  int get _activeFilters =>
      [_typeFilter, _monthFilter, _statusFilter, _visibleFilter].where((f) => f != null).length + (_search.text.trim().isEmpty ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    if (_error != null && entries == null) {
      return Center(
        child: Text("Erro ao carregar: $_error\n\nSe necessário, rode a migration 0090_inventario_v2.sql no Supabase.",
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
      );
    }
    if (entries == null) return const Center(child: CircularProgressIndicator());

    final filtered = _filtered(entries);
    final byMonth = <String, List<InventoryEntry>>{};
    for (final e in filtered) {
      byMonth.putIfAbsent(_monthKey(e.occurredAt), () => []).add(e);
    }

    return ListView(padding: const EdgeInsets.all(24), children: [
      _header(entries),
      const SizedBox(height: 26),
      _sectionTitle("COLEÇÃO", "toque num tipo para filtrar o histórico"),
      const SizedBox(height: 12),
      _collection(entries),
      const SizedBox(height: 28),
      Row(children: [
        Expanded(child: _sectionTitle("HISTÓRICO", "${filtered.length} de ${entries.length} registro(s)")),
        TextButton.icon(
          onPressed: () => setState(() => _showFilters = !_showFilters),
          icon: Icon(_showFilters ? Icons.filter_alt_off : Icons.filter_alt, color: _purpleLight, size: 18),
          label: Text(_activeFilters > 0 ? "Filtros ($_activeFilters)" : "Filtros", style: const TextStyle(color: _purpleLight)),
        ),
      ]),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: _showFilters ? _filters(entries) : const SizedBox(width: double.infinity),
      ),
      const SizedBox(height: 8),
      if (entries.isEmpty)
        _empty()
      else if (filtered.isEmpty)
        const Padding(
          padding: EdgeInsets.all(30),
          child: Center(child: Text("Nada encontrado com esses filtros.", style: TextStyle(color: Colors.white54))),
        )
      else
        for (final m in byMonth.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 10),
            child: Row(children: [
              Text(_monthLabel(m.key), style: const TextStyle(color: _gold, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 1, color: Colors.white12)),
            ]),
          ),
          for (var i = 0; i < m.value.length; i++) _timelineItem(m.value[i], isLast: i == m.value.length - 1),
        ],
    ]);
  }

  Widget _sectionTitle(String title, String sub) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(width: 10),
        Flexible(child: Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 12))),
      ]);

  Widget _header(List<InventoryEntry> entries) {
    final s = widget.streamer;
    final username = s["tiktok_username"] as String?;
    final stats = _stats;
    Widget metric(String emoji, String value, String label) => Container(
          constraints: const BoxConstraints(minWidth: 130),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("$emoji  $value", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
        );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF3A0E66), Color(0xFF1E0B36), Color(0xFF14101C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _purple.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Avatar(url: s["avatar_url"] as String?, name: s["display_name"] as String? ?? "?", size: 76, ring: _gold),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("JORNADA MDUCK DE ${(username ?? s["display_name"] ?? "").toString().toUpperCase()}",
                  style: const TextStyle(color: _purpleLight, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
              const SizedBox(height: 4),
              Text(s["display_name"] as String? ?? "-", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (username != null && username.isNotEmpty) Text("@$username", style: const TextStyle(color: Colors.white70)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _purple.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(8)),
                  child: const Text("MDUCK Agency", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text("REGISTRAR", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: const Color(0xFF2A1600),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: widget.onChangeStreamer,
              icon: const Icon(Icons.swap_horiz, color: Colors.white60, size: 18),
              label: const Text("Trocar streamer", style: TextStyle(color: Colors.white60)),
            ),
          ]),
        ]),
        const SizedBox(height: 18),
        Wrap(spacing: 12, runSpacing: 12, children: [
          metric("💎", stats == null ? "…" : _thousands(stats.diamonds), "diamantes no mês"),
          metric("⏱", stats == null ? "…" : "${_thousands(stats.hours)}h", "horas de live no mês"),
          metric("🔥", stats == null ? "…" : "${stats.daysLive}", "dias ativos no mês"),
          metric("✨", "${entries.length}", "momentos na jornada"),
        ]),
      ]),
    );
  }

  Widget _collection(List<InventoryEntry> entries) {
    final counts = <String, int>{};
    for (final e in entries) {
      counts[e.category] = (counts[e.category] ?? 0) + 1;
    }
    return Wrap(spacing: 12, runSpacing: 12, children: [
      for (final t in inventoryTypes.where((t) => !t.legacy || (counts[t.key] ?? 0) > 0))
        _CollectionTile(
          type: t,
          count: counts[t.key] ?? 0,
          selected: _typeFilter == t.key,
          onTap: () => setState(() => _typeFilter = _typeFilter == t.key ? null : t.key),
        ),
    ]);
  }

  Widget _filters(List<InventoryEntry> all) {
    final months = {for (final e in all) _monthKey(e.occurredAt)}.toList()..sort((a, b) => b.compareTo(a));
    Widget dd<T>(T value, List<(T, String)> options, ValueChanged<T> onChanged) => Container(
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
      child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 240,
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18, color: Colors.white54),
              hintText: "Título ou descrição",
              hintStyle: TextStyle(color: Colors.white38),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        dd<String?>(_monthFilter, [(null, "Todo o período"), for (final m in months) (m, _monthLabel(m))], (v) => setState(() => _monthFilter = v)),
        dd<String?>(_typeFilter, [(null, "Todos os tipos"), for (final t in inventoryTypes) (t.key, "${t.emoji} ${t.label}")], (v) => setState(() => _typeFilter = v)),
        dd<String?>(_statusFilter, [(null, "Qualquer status"), for (final s in inventoryStatuses.entries) (s.key, s.value)], (v) => setState(() => _statusFilter = v)),
        dd<bool?>(_visibleFilter, const [(null, "Visíveis e internos"), (true, "👁 Visíveis no app"), (false, "🔒 Só internos")], (v) => setState(() => _visibleFilter = v)),
        TextButton(
          onPressed: () => setState(() {
            _search.clear();
            _typeFilter = _monthFilter = _statusFilter = null;
            _visibleFilter = null;
          }),
          child: const Text("Limpar", style: TextStyle(color: Colors.white60)),
        ),
      ]),
    );
  }

  Widget _empty() => Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          const Text("🎒", style: TextStyle(fontSize: 46)),
          const SizedBox(height: 8),
          Text("O inventário de @$_name ainda está vazio.", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text("Registre presentes, treinamentos, conquistas, Pix e tudo que a agência fez com esse streamer.",
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text("Primeiro registro"),
            style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
          ),
        ]),
      );

  Widget _timelineItem(InventoryEntry e, {required bool isLast}) {
    final t = e.type;
    Widget chip(String text, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
          child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        );
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // trilho da linha do tempo
        SizedBox(
          width: 64,
          child: Column(children: [
            Text(e.occurredAt.day.toString().padLeft(2, "0"),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: t.color, width: 1.5),
              ),
              child: Text(t.emoji, style: const TextStyle(fontSize: 18)),
            ),
            if (!isLast) Expanded(child: Container(width: 2, margin: const EdgeInsets.only(top: 4), color: Colors.white10)),
          ]),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border(left: BorderSide(color: t.color, width: 3)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(t.label.toUpperCase(), style: TextStyle(color: t.color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(width: 8),
                    Text(_date(e.occurredAt), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ]),
                  const SizedBox(height: 3),
                  Text(e.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  if (e.description != null && e.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(e.description!, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35)),
                  ],
                  if (e.internalNote != null && e.internalNote!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text("📝 ${e.internalNote}", style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (e.amount != null) chip("💰 ${formatBrl(e.amount!)}${e.showAmount ? "" : " (oculto no app)"}", const Color(0xFF3DDC97)),
                    e.visibleToStreamer ? chip("👁 Visível no app", Colors.lightBlueAccent) : chip("🔒 Interno", Colors.white54),
                    if (e.status != "concluido")
                      chip(inventoryStatuses[e.status] ?? e.status, e.status == "pendente" ? Colors.orangeAccent : Colors.redAccent),
                    if (e.createdByLabel != null) chip("por ${e.createdByLabel}", Colors.white38),
                  ]),
                ]),
              ),
              if (e.imageUrl != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(e.imageUrl!, width: 76, height: 76, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(width: 76, height: 76)),
                  ),
                ),
              Column(children: [
                IconButton(tooltip: "Editar", icon: const Icon(Icons.edit, color: Colors.white54, size: 18), onPressed: () => _openForm(e)),
                IconButton(tooltip: "Excluir", icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => _delete(e)),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Cartao de um tipo na "Colecao": emoji grande, quantidade e nome.
class _CollectionTile extends StatelessWidget {
  final InventoryType type;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _CollectionTile({required this.type, required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final empty = count == 0;
    return Opacity(
      opacity: empty ? 0.38 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [type.color.withValues(alpha: selected ? 0.32 : 0.16), _card],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? type.color : type.color.withValues(alpha: 0.35), width: selected ? 2 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(type.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 6),
            Text("$count", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            Text(type.label.toUpperCase(), style: TextStyle(color: type.color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          ]),
        ),
      ),
    );
  }
}

/// Foto do streamer (ou iniciais quando nao houver).
class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final Color? ring;
  const _Avatar({required this.url, required this.name, required this.size, this.ring});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty ? "?" : name.trim().substring(0, 1).toUpperCase();
    final fallback = Container(
      color: _purple.withValues(alpha: 0.4),
      alignment: Alignment.center,
      child: Text(initials, style: TextStyle(color: Colors.white, fontSize: size * 0.4, fontWeight: FontWeight.w900)),
    );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring == null ? 0 : 3),
      decoration: BoxDecoration(shape: BoxShape.circle, color: ring),
      child: ClipOval(
        child: url == null || url!.isEmpty
            ? fallback
            : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      ),
    );
  }
}
