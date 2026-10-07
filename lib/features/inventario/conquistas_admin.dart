import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "conquistas_service.dart";
import "widgets/achievement_art.dart";

const _purple = Color(0xFF7A0BD4);
const _gold = Color(0xFFFFC94D);
const _card = Color(0xFF1B1626);

String compactValue(num v) {
  if (v >= 1000000) {
    final m = v / 1000000;
    return "${m == m.roundToDouble() ? m.toInt() : m.toStringAsFixed(1).replaceAll(".", ",")}M";
  }
  if (v >= 1000) return "${(v / 1000).floor()}K";
  return v.round().toString();
}

/// "150k" / "1,2M" / "150000" -> numero.
double? parseValue(String text) {
  final raw = text.trim().toLowerCase().replaceAll(".", "").replaceAll(",", ".");
  double? v;
  if (raw.endsWith("k")) {
    v = double.tryParse(raw.substring(0, raw.length - 1));
    if (v != null) v *= 1000;
  } else if (raw.endsWith("m")) {
    v = double.tryParse(raw.substring(0, raw.length - 1));
    if (v != null) v *= 1000000;
  } else {
    v = double.tryParse(raw);
  }
  return v;
}

Map<String, dynamic> _config(Map<String, dynamic> a) => a["config"] is Map ? Map<String, dynamic>.from(a["config"] as Map) : {};

String _ruleSummary(Map<String, dynamic> a) {
  final t = compactValue((a["threshold"] as num?) ?? 0);
  final cfg = _config(a);
  final months = (cfg["months"] as num?)?.toInt() ?? 3;
  return switch (a["rule_type"]) {
    "total_diamonds" => "Soma histórica ≥ $t diamantes",
    "month_diamonds" => "Um mês com ≥ $t diamantes",
    "consecutive_months_diamonds" => "$months meses seguidos ≥ $t diamantes",
    "month_hours" => "Um mês com ≥ ${t}h de live",
    "total_hours" => "Soma histórica ≥ ${t}h de live",
    "month_days" => "Um mês com ≥ $t dias de live",
    "month_combo" => "Mesmo mês: ≥ $t 💎 + ${cfg["days"] ?? 0} dias + ${cfg["hours"] ?? 0}h",
    _ => a["rule_type"]?.toString() ?? "-",
  };
}

/// Inventario > CONQUISTAS (automaticas): a equipe configura, o sistema
/// desbloqueia sozinho. Os pontos da TRILHA do app sao conquistas com etapa
/// e posicao definidas aqui.
class ConquistasAdmin extends StatefulWidget {
  const ConquistasAdmin({super.key});

  @override
  State<ConquistasAdmin> createState() => _ConquistasAdminState();
}

class _ConquistasAdminState extends State<ConquistasAdmin> {
  final _service = ConquistasService();
  List<Map<String, dynamic>>? _items;
  Map<String, int> _counts = const {};
  Object? _error;
  bool _recalculating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _service.fetchAchievements();
      final counts = await _service.fetchUnlockCounts();
      if (mounted) {
        setState(() {
          _items = items;
          _counts = counts;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _replace(Map<String, dynamic> row) =>
      setState(() => _items = [for (final a in _items!) a["id"] == row["id"] ? row : a]);

  Future<void> _toggle(Map<String, dynamic> a, bool active) async {
    _replace({...a, "is_active": active});
    try {
      _replace(await _service.update(a["id"] as String, {"is_active": active}));
    } catch (e) {
      _replace(a);
      _snack("Não foi possível alterar: $e");
    }
  }

  Future<void> _recalculate() async {
    setState(() => _recalculating = true);
    try {
      final n = await _service.recalculateAll();
      _snack(n == 0 ? "Tudo em dia: nenhuma conquista nova." : "$n conquista(s) desbloqueada(s).");
      await _load();
    } catch (e) {
      _snack("Não foi possível recalcular: $e");
    } finally {
      if (mounted) setState(() => _recalculating = false);
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _edit(Map<String, dynamic> a) async {
    final saved = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _EditDialog(achievement: a, service: _service));
    if (saved != null) _replace(saved);
  }

  /// Nova conquista (ex.: novo marco do Programa de Merito).
  Future<void> _create() async {
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EditDialog(
        service: _service,
        achievement: {
          "title": "",
          "description": "",
          "family": "merito",
          "rule_type": "month_diamonds",
          "threshold": 250000,
          "config": <String, dynamic>{},
          "art_key": "mensal_7",
          "icon_key": "plaque",
          "sort_order": 0,
          "is_active": true,
        },
      ),
    );
    if (saved != null) {
      setState(() => _items = [...?_items, saved]);
      _snack("Conquista criada. Quem já cumpre a regra recebe no próximo cálculo (ou clique em Recalcular agora).");
    }
  }

  /// Reordena dentro da mesma categoria (ordem da aba Conquistas no app).
  Future<void> _move(Map<String, dynamic> a, int dir) async {
    final family = (_items ?? []).where((x) => x["family"] == a["family"]).toList()
      ..sort((x, y) {
        final c = ((x["sort_order"] as num?) ?? 0).compareTo((y["sort_order"] as num?) ?? 0);
        return c != 0 ? c : ((x["threshold"] as num?) ?? 0).compareTo((y["threshold"] as num?) ?? 0);
      });
    final i = family.indexWhere((x) => x["id"] == a["id"]);
    final j = i + dir;
    if (i < 0 || j < 0 || j >= family.length) return;
    final moved = family.removeAt(i);
    family.insert(j, moved);
    try {
      await _service.reorderAchievements([for (final x in family) x["id"] as String]);
      await _load();
    } catch (e) {
      _snack("Não foi possível reordenar: $e");
    }
  }

  Future<void> _delete(Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1426),
        title: Text("Excluir \"${a["title"]}\"?", style: const TextStyle(color: Colors.white)),
        content: const Text("Some do app e apaga o registro de quem já desbloqueou. Para só esconder, desative (botão ao lado).",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text("Excluir", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteAchievement(a["id"] as String);
      await _load();
    } catch (e) {
      _snack("Não foi possível excluir: $e");
    }
  }

  void _unlocks(Map<String, dynamic> a) {
    showDialog(context: context, builder: (_) => _UnlocksDialog(achievement: a, service: _service)).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (_error != null && items == null) {
      return Center(
        child: Text("Erro ao carregar: $_error\n\nSe necessário, rode as migrations 0091 e 0095 no Supabase.",
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
      );
    }
    if (items == null) return const Center(child: CircularProgressIndicator());

    return ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.lightBlueAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          const Text("🤖", style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Conquistas são AUTOMÁTICAS e usam o HISTÓRICO REAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              Text(
                "O sistema desbloqueia sozinho sempre que a Importação TikTok atualiza os números (mês atual e todos os meses fechados). "
                "Quem já tem anos de histórico entra com tudo o que conquistou. Cada conquista é desbloqueada uma vez e guarda a data. "
                "Correções manuais ficam registradas com motivo, sem apagar o cálculo.",
                style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Column(children: [
            OutlinedButton.icon(
              onPressed: _recalculating ? null : _recalculate,
              icon: _recalculating
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 16, color: Colors.white70),
              label: const Text("Recalcular agora", style: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add, size: 16),
              label: const Text("Nova conquista"),
              style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
            ),
          ]),
        ]),
      ),
      for (final family in achievementFamilyLabels.entries)
        if (items.any((a) => a["family"] == family.key)) ...[
          Padding(
            padding: const EdgeInsets.only(top: 26, bottom: 12),
            child: Text(family.value.toUpperCase(),
                style: const TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ),
          Wrap(spacing: 14, runSpacing: 14, children: [
            for (final a in items.where((a) => a["family"] == family.key)) _achievementCard(a),
          ]),
        ],
    ]);
  }

  Widget _achievementCard(Map<String, dynamic> a) {
    final active = a["is_active"] as bool? ?? true;
    final count = _counts[a["id"]] ?? 0;
    return Container(
      width: 230,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: active ? _gold.withValues(alpha: 0.35) : Colors.white10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Opacity(
          opacity: active ? 1 : 0.4,
          child: AchievementArt(artKey: a["art_key"] as String?, imageUrl: a["image_url"] as String?, radius: 14),
        ),
        const SizedBox(height: 10),
        Text(a["title"] as String? ?? "", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
        const SizedBox(height: 2),
        Text(_ruleSummary(a), style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        Row(children: [
          InkWell(
            onTap: () => _unlocks(a),
            child: Text("🔓 $count streamer${count == 1 ? "" : "s"}",
                style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
          ),
          const Spacer(),
          IconButton(tooltip: "Editar", visualDensity: VisualDensity.compact, icon: const Icon(Icons.edit, size: 17, color: Colors.white54), onPressed: () => _edit(a)),
          Switch(value: active, activeThumbColor: _purple, onChanged: (v) => _toggle(a, v)),
        ]),
        Row(children: [
          IconButton(tooltip: "Mover para cima", visualDensity: VisualDensity.compact, icon: const Icon(Icons.arrow_upward, size: 16, color: Colors.white54), onPressed: () => _move(a, -1)),
          IconButton(tooltip: "Mover para baixo", visualDensity: VisualDensity.compact, icon: const Icon(Icons.arrow_downward, size: 16, color: Colors.white54), onPressed: () => _move(a, 1)),
          const Spacer(),
          IconButton(tooltip: "Excluir conquista", visualDensity: VisualDensity.compact, icon: const Icon(Icons.delete_outline, size: 17, color: Colors.white38), onPressed: () => _delete(a)),
        ]),
      ]),
    );
  }
}

class _EditDialog extends StatefulWidget {
  final Map<String, dynamic> achievement;
  final ConquistasService service;
  const _EditDialog({required this.achievement, required this.service});

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final Map<String, dynamic> _a = widget.achievement;
  late final _cfg = _config(_a);
  late final _title = TextEditingController(text: _a["title"] as String? ?? "");
  late final _description = TextEditingController(text: _a["description"] as String? ?? "");
  late final _threshold = TextEditingController(text: ((_a["threshold"] as num?) ?? 0).round().toString());
  late final _months = TextEditingController(text: ((_cfg["months"] as num?) ?? 3).toString());
  late final _days = TextEditingController(text: ((_cfg["days"] as num?) ?? 22).toString());
  late final _hours = TextEditingController(text: ((_cfg["hours"] as num?) ?? 100).toString());
  late final _sortOrder = TextEditingController(text: ((_a["sort_order"] as num?) ?? 0).toString());
  late String? _imageUrl = _a["image_url"] as String?;
  late bool _active = _a["is_active"] as bool? ?? true;
  late String _family = _a["family"] as String? ?? "marco";
  late String _rule = _a["rule_type"] as String? ?? "month_diamonds";
  late String? _icon = _a["icon_key"] as String?;
  bool _uploading = false;
  bool _saving = false;
  String? _error;

  bool get _isNew => _a["id"] == null;
  bool get _isStreak => _rule == "consecutive_months_diamonds";
  bool get _isCombo => _rule == "month_combo";

  @override
  void dispose() {
    for (final c in [_title, _description, _threshold, _months, _days, _hours, _sortOrder]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickArt() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    setState(() => _uploading = true);
    try {
      final url = await widget.service.uploadArt(result.files.single);
      setState(() => _imageUrl = url);
    } catch (e) {
      setState(() => _error = "Erro ao enviar a arte: $e");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final threshold = parseValue(_threshold.text);
    final months = int.tryParse(_months.text.trim());
    final days = int.tryParse(_days.text.trim());
    final hours = int.tryParse(_hours.text.trim());
    if (_title.text.trim().isEmpty || threshold == null || threshold <= 0 || (_isStreak && (months == null || months < 2))) {
      setState(() => _error = "Confira o título, o valor da regra${_isStreak ? " e os meses (mínimo 2)" : ""}.");
      return;
    }
    if (_isCombo && (days == null || hours == null)) {
      setState(() => _error = "Informe os dias e as horas do Grande Marco.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final config = Map<String, dynamic>.from(_cfg);
      if (_isStreak) config["months"] = months;
      if (_isCombo) {
        config["days"] = days;
        config["hours"] = hours;
      }
      final data = <String, dynamic>{
        "title": _title.text.trim(),
        "description": _description.text.trim(),
        "family": _family,
        "threshold": threshold,
        "config": config,
        "image_url": _imageUrl,
        "is_active": _active,
        "icon_key": _icon,
        "sort_order": int.tryParse(_sortOrder.text.trim()) ?? 0,
      };
      final Map<String, dynamic> saved;
      if (_isNew) {
        final slug = _title.text.trim().toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "_");
        saved = await widget.service.create({
          ...data,
          "code": "${slug}_${DateTime.now().millisecondsSinceEpoch}",
          "rule_type": _rule,
          "art_key": _a["art_key"],
        });
      } else {
        saved = await widget.service.update(_a["id"] as String, data);
      }
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) setState(() => _error = "Erro ao salvar: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String label, {String? hint}) =>
        InputDecoration(labelText: label, hintText: hint, labelStyle: const TextStyle(color: Colors.white54), border: const OutlineInputBorder(), isDense: true);
    DropdownMenuItem<T> item<T>(T v, String label) => DropdownMenuItem(value: v, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)));
    return Dialog(
      backgroundColor: const Color(0xFF17131F),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 190,
              child: Column(children: [
                AchievementArt(artKey: _a["art_key"] as String?, imageUrl: _imageUrl, radius: 16),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickArt,
                  icon: const Icon(Icons.image_outlined, size: 16, color: Colors.white70),
                  label: Text(_uploading ? "Enviando..." : "Trocar arte", style: const TextStyle(color: Colors.white70)),
                ),
                if (_imageUrl != null)
                  TextButton(
                    onPressed: () => setState(() => _imageUrl = null),
                    child: const Text("Voltar pra arte padrão", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
                const Text("Arte quadrada (1:1), sem texto. Recomendado 1024×1024. No app, aparece dentro da esfera da conquista.",
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11)),
              ]),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(_isNew ? "Nova conquista" : "Editar conquista", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                TextField(controller: _title, style: const TextStyle(color: Colors.white), decoration: dec("Nome")),
                const SizedBox(height: 10),
                TextField(controller: _description, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: dec("Descrição (aparece no app e no card de compartilhar)")),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _family,
                      dropdownColor: const Color(0xFF221B30),
                      decoration: dec("Categoria"),
                      items: [for (final f in achievementFamilyLabels.entries) item(f.key, f.value)],
                      onChanged: (v) => setState(() => _family = v ?? _family),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _rule,
                      dropdownColor: const Color(0xFF221B30),
                      decoration: dec("Regra"),
                      items: [for (final r in achievementRuleLabels.entries) item(r.key, r.value)],
                      // regra so muda na criacao (quem ja desbloqueou foi pela regra original)
                      onChanged: _isNew ? (v) => setState(() => _rule = v ?? _rule) : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: _threshold, style: const TextStyle(color: Colors.white), decoration: dec(_isCombo ? "Diamantes no mês" : "Requisito (valor)", hint: "ex: 150K"))),
                  if (_isStreak) ...[
                    const SizedBox(width: 10),
                    SizedBox(width: 120, child: TextField(controller: _months, style: const TextStyle(color: Colors.white), decoration: dec("Meses seguidos"))),
                  ],
                  if (_isCombo) ...[
                    const SizedBox(width: 10),
                    SizedBox(width: 90, child: TextField(controller: _days, style: const TextStyle(color: Colors.white), decoration: dec("Dias"))),
                    const SizedBox(width: 10),
                    SizedBox(width: 90, child: TextField(controller: _hours, style: const TextStyle(color: Colors.white), decoration: dec("Horas"))),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(
                  _family == "merito"
                      ? "Programa de Mérito: o valor é o REQUISITO MÍNIMO. Quem fizer mais (250K, 350K…) é reconhecido pelo próprio resultado (o app mostra o valor real do melhor mês)."
                      : "Mudar o requisito não remove quem já desbloqueou: a data original é preservada.",
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: achievementIconLabels.containsKey(_icon) ? _icon : null,
                      dropdownColor: const Color(0xFF221B30),
                      decoration: dec("Ícone no app"),
                      items: [
                        item<String?>(null, "Padrão (pela regra)"),
                        for (final i in achievementIconLabels.entries) item<String?>(i.key, i.value),
                      ],
                      onChanged: (v) => setState(() => _icon = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(width: 200, child: TextField(controller: _sortOrder, style: const TextStyle(color: Colors.white), decoration: dec("Ordem na aba Conquistas"))),
                ]),
                SwitchListTile(
                  value: _active,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: _purple,
                  title: const Text("Ativa (aparece no app)", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  onChanged: (v) => setState(() => _active = v),
                ),
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving || _uploading ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
                    child: Text(_saving ? "Salvando..." : "Salvar"),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Quem desbloqueou + correcao manual (desbloquear / revogar com motivo) +
/// historico das correcoes. O calculo original nunca e apagado.
class _UnlocksDialog extends StatefulWidget {
  final Map<String, dynamic> achievement;
  final ConquistasService service;
  const _UnlocksDialog({required this.achievement, required this.service});

  @override
  State<_UnlocksDialog> createState() => _UnlocksDialogState();
}

class _UnlocksDialogState extends State<_UnlocksDialog> {
  List<Map<String, dynamic>>? _rows;
  List<Map<String, dynamic>> _adjustments = const [];

  String get _id => widget.achievement["id"] as String;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.service.fetchUnlocks(_id);
    List<Map<String, dynamic>> adj = const [];
    try {
      adj = await widget.service.fetchAdjustments(_id);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _rows = rows;
        _adjustments = adj;
      });
    }
  }

  Future<void> _adjust({required String action, String? streamerId, String? streamerName}) async {
    final result = await showDialog<({String streamerId, String reason, double? value})>(
      context: context,
      builder: (_) => _AdjustDialog(
        service: widget.service,
        action: action,
        streamerId: streamerId,
        streamerName: streamerName,
        achievementTitle: widget.achievement["title"] as String? ?? "",
      ),
    );
    if (result == null) return;
    try {
      await widget.service.adjust(
        streamerId: result.streamerId,
        achievementId: _id,
        action: action,
        reason: result.reason,
        manualValue: result.value,
      );
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Não foi possível salvar: $e")));
    }
  }

  String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? "")?.toLocal();
    return d == null ? "" : "${d.day.toString().padLeft(2, "0")}/${d.month.toString().padLeft(2, "0")}/${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return AlertDialog(
      backgroundColor: const Color(0xFF17131F),
      title: Row(children: [
        Expanded(child: Text("🔓 ${widget.achievement["title"]}", style: const TextStyle(color: Colors.white))),
        OutlinedButton.icon(
          onPressed: () => _adjust(action: "unlock"),
          icon: const Icon(Icons.lock_open, size: 16, color: Colors.white70),
          label: const Text("Desbloquear manualmente", style: TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      ]),
      content: SizedBox(
        width: 620,
        height: 520,
        child: rows == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(children: [
                if (rows.isEmpty)
                  const Padding(padding: EdgeInsets.all(30), child: Center(child: Text("Ninguém desbloqueou ainda.", style: TextStyle(color: Colors.white54)))),
                for (final r in rows) _unlockTile(r),
                if (_adjustments.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 18, bottom: 6),
                    child: Text("HISTÓRICO DE CORREÇÕES", style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                  for (final a in _adjustments)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        "${_date(a["created_at"] as String?)} · ${a["action"] == "unlock" ? "Desbloqueio manual" : "Revogação"} · "
                        "${(a["profiles"] is Map ? a["profiles"]["display_name"] : null) ?? "-"} · "
                        "calculado: ${a["calculated_value"] == null ? "-" : compactValue(a["calculated_value"] as num)} "
                        "(${a["calculated_unlocked"] == true ? "cumpria" : "não cumpria"})"
                        "${a["manual_value"] != null ? " · manual: ${compactValue(a["manual_value"] as num)}" : ""}"
                        " · por ${a["by_email"] ?? "-"} · motivo: ${a["reason"]}",
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ),
                ],
              ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar"))],
    );
  }

  Widget _unlockTile(Map<String, dynamic> r) {
    final p = r["profiles"] is Map ? r["profiles"] as Map : const {};
    final revoked = r["revoked_at"] != null;
    final manual = r["source"] == "manual" || r["manual_reason"] != null;
    return Opacity(
      opacity: revoked ? 0.55 : 1,
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: _purple.withValues(alpha: 0.4),
          backgroundImage: (p["avatar_url"] as String?)?.isNotEmpty == true ? NetworkImage(p["avatar_url"] as String) : null,
          child: (p["avatar_url"] as String?)?.isNotEmpty == true ? null : const Icon(Icons.person, size: 16, color: Colors.white70),
        ),
        title: Row(children: [
          Flexible(child: Text(p["display_name"] as String? ?? "-", style: const TextStyle(color: Colors.white))),
          const SizedBox(width: 6),
          _badge(manual ? "AJUSTE MANUAL" : "AUTOMÁTICO", manual ? Colors.orangeAccent : Colors.greenAccent),
          if (revoked) ...[const SizedBox(width: 4), _badge("REVOGADA", Colors.redAccent)],
        ]),
        subtitle: Text(
          "${_date(r["unlocked_at"] as String?)}"
          "${r["period_key"] != null ? "  ·  mês ${r["period_key"]}" : ""}"
          "${r["value_at_unlock"] != null ? "  ·  calculado ${compactValue(r["value_at_unlock"] as num)}" : ""}"
          "${revoked ? "  ·  motivo: ${r["revoke_reason"] ?? "-"}" : (r["manual_reason"] != null ? "  ·  motivo: ${r["manual_reason"]}" : "")}",
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: revoked
            ? TextButton(
                onPressed: () => _adjust(action: "unlock", streamerId: r["streamer_id"] as String?, streamerName: p["display_name"] as String?),
                child: const Text("Restaurar", style: TextStyle(fontSize: 12)),
              )
            : IconButton(
                tooltip: "Revogar (correção manual)",
                icon: const Icon(Icons.block, color: Colors.white38, size: 18),
                onPressed: () => _adjust(action: "revoke", streamerId: r["streamer_id"] as String?, streamerName: p["display_name"] as String?),
              ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.7)), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900)),
      );
}

class _AdjustDialog extends StatefulWidget {
  final ConquistasService service;
  final String action; // unlock | revoke
  final String? streamerId;
  final String? streamerName;
  final String achievementTitle;
  const _AdjustDialog({required this.service, required this.action, this.streamerId, this.streamerName, required this.achievementTitle});

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  final _reason = TextEditingController(text: "Correção de histórico");
  final _value = TextEditingController();
  List<Map<String, dynamic>>? _streamers;
  late String? _streamerId = widget.streamerId;
  String _filter = "";

  @override
  void initState() {
    super.initState();
    if (widget.streamerId == null) {
      widget.service.fetchStreamers().then((s) {
        if (mounted) setState(() => _streamers = s);
      });
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unlock = widget.action == "unlock";
    final list = (_streamers ?? const <Map<String, dynamic>>[])
        .where((s) => _filter.isEmpty ||
            "${s["display_name"]} ${s["tiktok_username"]}".toLowerCase().contains(_filter.toLowerCase()))
        .take(40)
        .toList();
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1426),
      title: Text(unlock ? "Desbloquear manualmente" : "Revogar conquista", style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Conquista: ${widget.achievementTitle}", style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 10),
          if (widget.streamerId != null)
            Text("Streamer: ${widget.streamerName ?? "-"}", style: const TextStyle(color: Colors.white))
          else ...[
            TextField(
              onChanged: (v) => setState(() => _filter = v),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Buscar streamer", border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 180,
              child: _streamers == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(children: [
                      for (final s in list)
                        RadioListTile<String>(
                          dense: true,
                          value: s["id"] as String,
                          groupValue: _streamerId,
                          onChanged: (v) => setState(() => _streamerId = v),
                          title: Text("${s["display_name"] ?? "-"}${s["is_active"] == false ? " (inativo)" : ""}", style: const TextStyle(color: Colors.white, fontSize: 13)),
                          subtitle: Text("@${s["tiktok_username"] ?? "-"}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ),
                    ]),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _reason,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: "Motivo (obrigatório)", border: OutlineInputBorder(), isDense: true),
          ),
          if (unlock) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _value,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Valor manual (opcional, ex: 85K)", border: OutlineInputBorder(), isDense: true),
            ),
          ],
          const SizedBox(height: 8),
          const Text("O valor calculado pelo sistema fica guardado junto com quem alterou, a data e o motivo.",
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
        ElevatedButton(
          onPressed: () {
            if (_streamerId == null || _reason.text.trim().isEmpty) return;
            Navigator.of(context).pop((streamerId: _streamerId!, reason: _reason.text.trim(), value: parseValue(_value.text)));
          },
          style: ElevatedButton.styleFrom(backgroundColor: unlock ? _purple : Colors.redAccent, foregroundColor: Colors.white),
          child: Text(unlock ? "Desbloquear" : "Revogar"),
        ),
      ],
    );
  }
}
