import "package:flutter/material.dart";
import "desafio_service.dart";

const _purple = Color(0xFF7A0BD4);
const _gold = Color(0xFFFFD700);

/// Operacoes APP > Desafio: microinteracao do dado na Home do app.
/// No app nao aparece nenhum nome -- so o dado. Aqui no painel:
/// Visao geral, Jogos e Dicas.
class DesafioPage extends StatelessWidget {
  const DesafioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("🎲 Desafio", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 4),
            Text(
              "Microinteração da Home do app: o streamer toca no dado, joga uma partida rápida e no fim recebe uma 💡 Dica do Max. "
              "No app não aparece nenhum nome, só o ícone do dado. Sem moedas, ranking ou recompensas.",
              style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 12),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: _purple,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(icon: Icon(Icons.insights, size: 18), text: "Visão geral"),
                Tab(icon: Icon(Icons.casino, size: 18), text: "Jogos"),
                Tab(icon: Icon(Icons.lightbulb_outline, size: 18), text: "Dicas"),
              ],
            ),
            SizedBox(height: 16),
            Expanded(child: TabBarView(children: [_OverviewTab(), _GamesTab(), _TipsTab()])),
          ],
        ),
      ),
    );
  }
}

String _fmt(DateTime d) =>
    "${d.day.toString().padLeft(2, "0")}/${d.month.toString().padLeft(2, "0")}/${d.year} ${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}";

Widget _migrationError(Object error) => Center(
      child: Text(
        "Erro ao carregar: $error\n\nSe as tabelas ainda não existem, rode a migration 0088_desafio.sql no Supabase.",
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.redAccent),
      ),
    );

// ============================================================================
// Visao geral
// ============================================================================
class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final _service = DesafioService();
  late Future<DesafioOverview> _future = _service.fetchOverview();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DesafioOverview>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _migrationError(snapshot.error!);
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final o = snapshot.data!;
        Widget card(IconData icon, String value, String label, [String? sub]) => Container(
              width: 220,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, color: const Color(0xFFB98CFF)),
                const SizedBox(height: 10),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                if (sub != null) Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ]),
            );
        return ListView(children: [
          Wrap(spacing: 12, runSpacing: 12, children: [
            card(Icons.casino, "${o.activeGames}", "jogo(s) ativo(s)", "${o.totalGames} cadastrado(s)"),
            card(Icons.lightbulb, "${o.activeTips}", "dica(s) ativa(s)", "${o.totalTips} cadastrada(s)"),
            card(Icons.sports_esports, "${o.plays}", "partida(s) jogadas"),
            card(Icons.people, "${o.players}", "streamer(s) já jogaram"),
            card(Icons.update, o.lastUpdate == null ? "—" : _fmt(o.lastUpdate!).split(" ").first, "última atualização",
                o.lastUpdate == null ? null : _fmt(o.lastUpdate!).split(" ").last),
          ]),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _future = _service.fetchOverview()),
              icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
              label: const Text("Atualizar", style: TextStyle(color: Colors.white70)),
            ),
          ),
          if (o.activeGames == 0)
            const Text("⚠️ Nenhum jogo ativo: o dado não aparece no app.", style: TextStyle(color: Colors.orange, fontSize: 12)),
          if (o.activeTips == 0)
            const Text("⚠️ Nenhuma dica ativa: as partidas terminam sem a Dica do Max.", style: TextStyle(color: Colors.orange, fontSize: 12)),
        ]);
      },
    );
  }
}

// ============================================================================
// Jogos
// ============================================================================
class _GamesTab extends StatefulWidget {
  const _GamesTab();

  @override
  State<_GamesTab> createState() => _GamesTabState();
}

class _GamesTabState extends State<_GamesTab> {
  final _service = DesafioService();
  List<Map<String, dynamic>>? _games;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final games = await _service.fetchGames();
      if (mounted) setState(() => _games = games);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _replace(Map<String, dynamic> row) {
    setState(() => _games = [for (final g in _games!) g["id"] == row["id"] ? row : g]);
  }

  Future<void> _toggle(Map<String, dynamic> game, bool active) async {
    _replace({...game, "is_active": active});
    try {
      _replace(await _service.updateGame(game["id"] as String, isActive: active));
    } catch (e) {
      _replace(game);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Não foi possível alterar: $e")));
    }
  }

  Future<void> _edit(Map<String, dynamic> game) async {
    final name = TextEditingController(text: game["name"] as String? ?? "");
    final description = TextEditingController(text: game["description"] as String? ?? "");
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Editar jogo", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: name,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Nome (só aparece aqui no painel)", labelStyle: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: description,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Descrição interna", labelStyle: TextStyle(color: Colors.white54)),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
    if (saved == true && name.text.trim().isNotEmpty) {
      try {
        _replace(await _service.updateGame(game["id"] as String, name: name.text, description: description.text));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Não foi possível salvar: $e")));
      }
    }
    name.dispose();
    description.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _games == null) return _migrationError(_error!);
    final games = _games;
    if (games == null) return const Center(child: CircularProgressIndicator());
    if (games.isEmpty) {
      return const Center(child: Text("Nenhum jogo cadastrado. Rode a migration 0088_desafio.sql.", style: TextStyle(color: Colors.white54)));
    }
    return ListView(children: [
      const Text(
        "Com todos os jogos desativados, o dado some da Home do app. Novos jogos poderão ser adicionados aqui no futuro.",
        style: TextStyle(color: Colors.white54, fontSize: 12),
      ),
      const SizedBox(height: 12),
      for (final g in games)
        Card(
          color: Colors.white.withValues(alpha: 0.05),
          child: ListTile(
            leading: const Text("🎲", style: TextStyle(fontSize: 26)),
            title: Text(g["name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
              "${(g["is_active"] as bool? ?? true) ? "🟢 Ativo" : "⚪ Inativo"}"
              "${g["description"] != null ? "  ·  ${g["description"]}" : ""}",
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: "Editar", icon: const Icon(Icons.edit, color: Colors.white54, size: 18), onPressed: () => _edit(g)),
              Switch(value: g["is_active"] as bool? ?? true, activeThumbColor: _purple, onChanged: (v) => _toggle(g, v)),
            ]),
          ),
        ),
    ]);
  }
}

// ============================================================================
// Dicas
// ============================================================================
class _TipsTab extends StatefulWidget {
  const _TipsTab();

  @override
  State<_TipsTab> createState() => _TipsTabState();
}

class _TipsTabState extends State<_TipsTab> {
  final _service = DesafioService();
  final _search = TextEditingController();
  List<Map<String, dynamic>>? _tips;
  Object? _error;
  String? _categoryFilter; // null = todas; "" = sem categoria
  String _statusFilter = "all";

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
      final tips = await _service.fetchTips();
      if (mounted) setState(() => _tips = tips);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _upsertLocal(Map<String, dynamic> row) {
    setState(() {
      final list = [...?_tips];
      final i = list.indexWhere((t) => t["id"] == row["id"]);
      if (i >= 0) {
        list[i] = row;
      } else {
        list.insert(0, row);
      }
      _tips = list;
    });
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final saved = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _TipFormDialog(existing: existing));
    if (saved != null && mounted) _upsertLocal(saved);
  }

  Future<void> _toggle(Map<String, dynamic> tip, bool active) async {
    _upsertLocal({...tip, "is_active": active});
    try {
      await _service.setTipActive(tip["id"] as String, active);
    } catch (e) {
      _upsertLocal(tip);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Não foi possível alterar: $e")));
    }
  }

  Future<void> _delete(Map<String, dynamic> tip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Excluir dica?", style: TextStyle(color: Colors.white)),
        content: const Text("Se quiser só tirar do app por um tempo, prefira desativar. Excluir não pode ser desfeito.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Excluir", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _tips = [...?_tips]..removeWhere((t) => t["id"] == tip["id"]));
    try {
      await _service.deleteTip(tip["id"] as String);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Não foi possível excluir: $e")));
      _load();
    }
  }

  void _view(Map<String, dynamic> tip) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: _TipPreview(text: tip["text"] as String),
        ),
      ),
    );
  }

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
    if (_error != null && _tips == null) return _migrationError(_error!);
    final tips = _tips;
    if (tips == null) return const Center(child: CircularProgressIndicator());

    final q = _search.text.trim().toLowerCase();
    final filtered = tips.where((t) {
      final cat = t["category"] as String?;
      return (q.isEmpty || (t["text"] as String).toLowerCase().contains(q)) &&
          (_categoryFilter == null || (_categoryFilter == "" ? cat == null : cat == _categoryFilter)) &&
          (_statusFilter == "all" || (_statusFilter == "active") == (t["is_active"] as bool? ?? true));
    }).toList();
    final activeCount = tips.where((t) => t["is_active"] == true).length;
    final categories = {...desafioTipCategories, ...tips.map((t) => t["category"]).whereType<String>()}.toList()..sort();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              hintText: "Buscar dica",
              hintStyle: TextStyle(color: Colors.white38),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        _dropdown<String?>(
          value: _categoryFilter,
          options: [(null, "Todas as categorias"), ("", "Sem categoria"), for (final c in categories) (c, c)],
          onChanged: (v) => setState(() => _categoryFilter = v),
        ),
        _dropdown<String>(
          value: _statusFilter,
          options: const [("all", "Todos os status"), ("active", "Ativas"), ("inactive", "Inativas")],
          onChanged: (v) => setState(() => _statusFilter = v),
        ),
        Text("$activeCount ativa(s) de ${tips.length}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ElevatedButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add, size: 16),
          label: const Text("Nova dica"),
          style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
        ),
      ]),
      const SizedBox(height: 12),
      Expanded(
        child: filtered.isEmpty
            ? const Center(child: Text("Nenhuma dica encontrada.", style: TextStyle(color: Colors.white54)))
            : ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final t = filtered[i];
                  final active = t["is_active"] as bool? ?? true;
                  final created = DateTime.tryParse(t["created_at"] as String? ?? "")?.toLocal();
                  final updated = DateTime.tryParse(t["updated_at"] as String? ?? "")?.toLocal();
                  return Card(
                    color: Colors.white.withValues(alpha: 0.05),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Text("💡", style: TextStyle(fontSize: 20, color: active ? null : Colors.white24)),
                      title: Text(t["text"] as String,
                          style: TextStyle(color: active ? Colors.white : Colors.white38, fontSize: 13, height: 1.35)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "${active ? "🟢 Ativa" : "⚪ Inativa"}"
                          "${t["category"] != null ? "  ·  🏷 ${t["category"]}" : ""}"
                          "${created != null ? "  ·  criada ${_fmt(created)}" : ""}"
                          "${updated != null ? "  ·  atualizada ${_fmt(updated)}" : ""}",
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(tooltip: "Visualizar", icon: const Icon(Icons.visibility, color: Colors.white54, size: 18), onPressed: () => _view(t)),
                        IconButton(tooltip: "Editar", icon: const Icon(Icons.edit, color: Colors.white54, size: 18), onPressed: () => _openForm(t)),
                        Switch(value: active, activeThumbColor: _purple, onChanged: (v) => _toggle(t, v)),
                        IconButton(tooltip: "Excluir", icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () => _delete(t)),
                      ]),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

class _TipFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _TipFormDialog({this.existing});

  @override
  State<_TipFormDialog> createState() => _TipFormDialogState();
}

class _TipFormDialogState extends State<_TipFormDialog> {
  final _service = DesafioService();
  late final _text = TextEditingController(text: widget.existing?["text"] as String? ?? "");
  late String? _category = widget.existing?["category"] as String?;
  late bool _active = widget.existing?["is_active"] as bool? ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_text.text.trim().isEmpty) {
      setState(() => _error = "Escreva o texto da dica.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _service.saveTip(
        id: widget.existing?["id"] as String?,
        text: _text.text,
        category: _category,
        isActive: _active,
      );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) setState(() => _error = "Erro ao salvar: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = {...desafioTipCategories, ?_category}.toList();
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text(widget.existing == null ? "Nova dica" : "Editar dica", style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 480,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _text,
            minLines: 3,
            maxLines: 6,
            maxLength: 300,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: "Ex: Comece a live com energia. Os primeiros minutos ajudam a definir o ritmo da transmissão.",
              hintStyle: TextStyle(color: Colors.white38),
              counterStyle: TextStyle(color: Colors.white38),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _category,
            dropdownColor: const Color(0xFF2A2A2A),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: "Categoria (opcional)", labelStyle: TextStyle(color: Colors.white54)),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text("Sem categoria")),
              for (final c in categories) DropdownMenuItem<String?>(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() => _category = v),
          ),
          SwitchListTile(
            value: _active,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _purple,
            title: const Text("Ativa", style: TextStyle(color: Colors.white70, fontSize: 13)),
            onChanged: (v) => setState(() => _active = v),
          ),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
          child: Text(_saving ? "Salvando..." : "Salvar"),
        ),
      ],
    );
  }
}

/// Previa de como a dica aparece no app ao fim da partida.
class _TipPreview extends StatelessWidget {
  final String text;
  const _TipPreview({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0B2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.6)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("💡 Dica do Max", style: TextStyle(color: _gold, fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45)),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar")),
        ),
      ]),
    );
  }
}
