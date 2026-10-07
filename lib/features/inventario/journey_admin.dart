import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart" show NetworkAssetBundle;
import "data/art_slots.dart";
import "conquistas_admin.dart" show compactValue, parseValue;
import "conquistas_service.dart";
import "widgets/journey_crest.dart";

const _purple = Color(0xFF7A0BD4);
const _gold = Color(0xFFFFC94D);
const _card = Color(0xFF1B1626);

const _monthNames = [
  "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
  "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
];

String _periodKey(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, "0")}";
String _periodLabel(String key) {
  final p = key.split("-");
  return p.length == 2 ? "${_monthNames[(int.tryParse(p[1]) ?? 1) - 1]} ${p[0]}" : key;
}

Widget _intro(String emoji, String title, String text) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.lightBlueAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4)),
          ]),
        ),
      ]),
    );

Widget _errorBox(Object e) => Center(
      child: Text("Erro ao carregar: $e\n\nSe necessário, rode a migration 0095_jornada.sql no Supabase.",
          textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
    );

// ============================================================================
// MARCOS DO MES (escada configuravel)
// ============================================================================
class MarcosDoMesAdmin extends StatefulWidget {
  const MarcosDoMesAdmin({super.key});

  @override
  State<MarcosDoMesAdmin> createState() => _MarcosDoMesAdminState();
}

class _MarcosDoMesAdminState extends State<MarcosDoMesAdmin> {
  final _service = ConquistasService();
  List<Map<String, dynamic>>? _items;
  Map<String, int> _counts = const {};
  Object? _error;
  final _period = _periodKey(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _service.fetchMilestones();
      final counts = await _service.fetchMilestoneCounts(_period);
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

  Future<void> _edit([Map<String, dynamic>? m]) async {
    final value = TextEditingController(text: m == null ? "" : compactValue(m["value"] as num));
    final title = TextEditingController(text: m?["title"] as String? ?? "");
    var importance = (m?["importance"] as num?)?.toInt() ?? 1;
    var active = m?["is_active"] as bool? ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: const Color(0xFF1A1426),
          title: Text(m == null ? "Novo marco do mês" : "Editar marco", style: const TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: value, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Diamantes no mês (ex: 150K)", border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: title, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome exibido (opcional, ex: 150K)", border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: importance,
                dropdownColor: const Color(0xFF221B30),
                decoration: const InputDecoration(labelText: "Importância visual no app", border: OutlineInputBorder(), isDense: true),
                items: [for (final e in milestoneImportanceLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(color: Colors.white, fontSize: 13)))],
                onChanged: (v) => setD(() => importance = v ?? importance),
              ),
              SwitchListTile(
                value: active,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: _purple,
                title: const Text("Ativo", style: TextStyle(color: Colors.white70)),
                onChanged: (v) => setD(() => active = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
              child: const Text("Salvar"),
            ),
          ],
        ),
      ),
    );
    final v = parseValue(value.text);
    if (ok != true || v == null || v <= 0) return;
    try {
      await _service.saveMilestone(id: m?["id"] as String?, value: v, title: title.text, importance: importance, isActive: active);
      await _load();
    } catch (e) {
      _snack("Não foi possível salvar: $e");
    }
  }

  Future<void> _delete(Map<String, dynamic> m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1426),
        title: const Text("Excluir marco?", style: TextStyle(color: Colors.white)),
        content: const Text("Some também o registro de quem bateu esse marco e as artes dele. Para só esconder, desative.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text("Excluir", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    await _service.deleteMilestone(m["id"] as String);
    await _load();
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _items == null) return _errorBox(_error!);
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
      _intro("📅", "MARCOS DO MÊS são recorrentes",
          "Todo mês o sistema registra sozinho cada marco que o streamer bate (ex.: 10K, 20K, 40K, 80K…). Quem bate 300K ganha os degraus de baixo também, "
          "mas o app destaca o MAIOR marco do mês. A mesma escada define a meta adaptativa (\"Seu próximo marco\"). "
          "A importância controla o destaque visual: 4 = especial (80K), 7 = lendário."),
      const SizedBox(height: 16),
      Row(children: [
        Text("ESCADA · bateram em ${_periodLabel(_period).toLowerCase()}", style: const TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add, size: 16),
          label: const Text("Novo marco"),
          style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
        ),
      ]),
      const SizedBox(height: 12),
      for (final m in items)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ((m["importance"] as num?) ?? 1) >= 4 ? _gold.withValues(alpha: 0.5) : Colors.white10),
          ),
          child: Row(children: [
            Text("💎", style: TextStyle(fontSize: 16 + ((m["importance"] as num?) ?? 1) * 1.5)),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: Text((m["title"] as String?)?.isNotEmpty == true ? m["title"] as String : compactValue(m["value"] as num),
                  style: TextStyle(color: m["is_active"] == false ? Colors.white38 : Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            Expanded(
              child: Text(milestoneImportanceLabels[(m["importance"] as num?)?.toInt() ?? 1] ?? "",
                  style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
            ),
            Text("${_counts[m["id"]] ?? 0} streamer(s) no mês", style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12)),
            const SizedBox(width: 10),
            if (m["is_active"] == false) const Text("inativo  ", style: TextStyle(color: Colors.white38, fontSize: 12)),
            IconButton(icon: const Icon(Icons.edit, size: 17, color: Colors.white54), onPressed: () => _edit(m)),
            IconButton(icon: const Icon(Icons.delete_outline, size: 17, color: Colors.white38), onPressed: () => _delete(m)),
          ]),
        ),
    ]);
  }
}

// ============================================================================
// ARTES DOS MARCOS: CLASSICAS (padrao) e COMEMORATIVAS (por mes)
// O painel detecta sozinho o circulo da foto e a placa do @/mes em cada arte.
// ============================================================================
class ArtesDosMarcosAdmin extends StatefulWidget {
  const ArtesDosMarcosAdmin({super.key});

  @override
  State<ArtesDosMarcosAdmin> createState() => _ArtesDosMarcosAdminState();
}

class _ArtesDosMarcosAdminState extends State<ArtesDosMarcosAdmin> {
  final _service = ConquistasService();
  bool _special = false;
  late String _period = _periodKey(DateTime.now());
  final _label = TextEditingController();
  List<Map<String, dynamic>>? _milestones;
  Map<String, Map<String, dynamic>> _arts = const {};
  final Set<String> _busy = {};
  Object? _error;

  String get _key => _special ? _period : "classica";

  List<String> get _periods {
    final now = DateTime.now();
    return [for (var i = -1; i <= 12; i++) _periodKey(DateTime(now.year, now.month + i))];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final ms = await _service.fetchMilestones();
      final arts = await _service.fetchArts(_key);
      if (!mounted) return;
      setState(() {
        _milestones = ms.where((m) => m["is_active"] != false).toList();
        _arts = arts;
        _error = null;
        if (_special) _label.text = arts.values.map((a) => a["label"] as String?).whereType<String>().firstOrNull ?? _label.text;
      });
      _detectMissing();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Artes antigas, enviadas antes da deteccao: detecta e salva agora.
  Future<void> _detectMissing() async {
    for (final art in _arts.values.where((a) => a["slots"] == null).toList()) {
      final mid = art["milestone_id"] as String;
      if (_busy.contains(mid)) continue;
      setState(() => _busy.add(mid));
      try {
        final url = art["image_url"] as String;
        final bytes = (await NetworkAssetBundle(Uri.parse(url)).load(url)).buffer.asUint8List();
        final slots = detectArtSlots(bytes);
        if (slots != null) await _service.updateArtSlots(art["id"] as String, slots.toJson());
        if (mounted) setState(() => _arts = {..._arts, mid: {...art, "slots": slots?.toJson(), "_detected": slots != null}});
      } catch (_) {
        // sem acesso a imagem: fica pra deteccao no app
      } finally {
        if (mounted) setState(() => _busy.remove(mid));
      }
    }
  }

  Future<void> _upload(Map<String, dynamic> m) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final id = m["id"] as String;
    setState(() => _busy.add(id));
    try {
      final file = result.files.single;
      final slots = detectArtSlots(file.bytes!);
      final url = await _service.uploadMilestoneArt(file);
      await _service.saveArt(period: _key, milestoneId: id, imageUrl: url, slots: slots?.toJson(), label: _special ? _label.text : null);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(slots == null
              ? "Arte salva, mas não encontrei a área da foto. Use \"Ajustar área\"."
              : "Arte salva. Área da foto${slots.hasPlate ? " e placa" : ""} detectada${slots.hasPlate ? "s" : ""} automaticamente."),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao enviar: $e")));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _adjust(Map<String, dynamic> art) async {
    final current = ArtSlots.fromJson(art["slots"]) ?? const ArtSlots(cx: 0.5, cy: 0.27, r: 0.22);
    final saved = await showDialog<ArtSlots>(context: context, builder: (_) => _SlotsDialog(imageUrl: art["image_url"] as String, initial: current));
    if (saved == null) return;
    await _service.updateArtSlots(art["id"] as String, saved.toJson());
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _milestones == null) return _errorBox(_error!);
    final ms = _milestones;
    if (ms == null) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
      _intro("🎨", "ARTES DOS MARCOS: envie a arte pronta, o sistema monta a de cada streamer",
          "A arte deve ter um CÍRCULO escuro reservado para a foto (e, se quiser, uma PLACA retangular escura para o @ e o mês). "
          "Ao enviar, o painel detecta essas áreas sozinho. No app, cada streamer vê a arte com a própria foto recortada no círculo, "
          "o @, o mês/ano e \"MDuck Agency\" no rodapé — sem editar nada à mão. "
          "CLÁSSICA = padrão do marco (vale todo mês). COMEMORATIVA = versão especial de um mês (Natal, Halloween...); no app o streamer escolhe entre as duas."),
      const SizedBox(height: 16),
      Row(children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text("ARTES CLÁSSICAS")),
            ButtonSegment(value: true, label: Text("ARTES COMEMORATIVAS")),
          ],
          selected: {_special},
          onSelectionChanged: (s) {
            setState(() {
              _special = s.first;
              _milestones = null;
            });
            _load();
          },
        ),
      ]),
      if (_special) ...[
        const SizedBox(height: 14),
        Row(children: [
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              initialValue: _period,
              dropdownColor: const Color(0xFF221B30),
              decoration: const InputDecoration(labelText: "Mês", border: OutlineInputBorder(), isDense: true),
              items: [for (final p in _periods) DropdownMenuItem(value: p, child: Text(_periodLabel(p), style: const TextStyle(color: Colors.white)))],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _period = v;
                  _milestones = null;
                  _label.clear();
                });
                _load();
              },
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 240,
            child: TextField(
              controller: _label,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Nome da ocasião (ex.: Natal)", border: OutlineInputBorder(), isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              await _service.updateArtLabel(_period, _label.text);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nome salvo nas artes deste mês.")));
            },
            child: const Text("Salvar nome"),
          ),
        ]),
      ],
      const SizedBox(height: 16),
      Wrap(spacing: 14, runSpacing: 14, children: [for (final m in ms) _artCard(m)]),
    ]);
  }

  Widget _artCard(Map<String, dynamic> m) {
    final art = _arts[m["id"]];
    final busy = _busy.contains(m["id"]);
    final label = (m["title"] as String?)?.isNotEmpty == true ? m["title"] as String : compactValue(m["value"] as num);
    final slots = ArtSlots.fromJson(art?["slots"]);
    final special = ((m["importance"] as num?) ?? 1) >= 4;
    return Container(
      width: 190,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: special ? _gold.withValues(alpha: 0.5) : Colors.white10),
      ),
      child: Column(children: [
        Text(_special ? "$label ${_label.text}".trim() : label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 2 / 3,
          child: Container(
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
            clipBehavior: Clip.antiAlias,
            child: art == null
                ? Center(
                    child: Text(_special ? "Sem arte comemorativa\n(o app usa a clássica)" : "Sem arte\n(o app usa o cartão padrão)",
                        textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 12)))
                : _ArtPreview(url: art["image_url"] as String, slots: slots),
          ),
        ),
        const SizedBox(height: 6),
        if (art != null)
          Text(
            busy ? "Detectando áreas..." : (slots == null ? "⚠ Área da foto não encontrada" : "✓ Foto${slots.hasPlate ? " + placa" : ""} detectada${slots.hasPlate ? "s" : ""}"),
            style: TextStyle(color: slots == null ? Colors.orangeAccent : Colors.greenAccent, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: busy ? null : () => _upload(m),
              child: Text(busy ? "..." : (art == null ? "Enviar" : "Trocar"), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          ),
          if (art != null) ...[
            IconButton(tooltip: "Ajustar área da foto", icon: const Icon(Icons.tune, size: 17, color: Colors.white54), onPressed: () => _adjust(art)),
            IconButton(
              tooltip: "Remover arte",
              icon: const Icon(Icons.delete_outline, size: 17, color: Colors.white38),
              onPressed: () async {
                await _service.deleteArt(art["id"] as String);
                _load();
              },
            ),
          ],
        ]),
      ]),
    );
  }
}

/// Previa: a arte com um exemplo de foto no circulo, @ e mes na placa.
class _ArtPreview extends StatelessWidget {
  final String url;
  final ArtSlots? slots;
  const _ArtPreview({required this.url, this.slots});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      final s = slots;
      return Stack(fit: StackFit.expand, children: [
        Image.network(url, fit: BoxFit.fill),
        if (s != null) ...[
          Positioned(
            left: (s.cx - s.r) * w,
            top: s.cy * h - s.r * w,
            width: s.r * 2 * w,
            height: s.r * 2 * w,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFFB98CFF), _purple]),
                border: Border.all(color: Colors.greenAccent, width: 1.5),
              ),
              alignment: Alignment.center,
              child: const Text("FOTO", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ),
          if (s.hasPlate)
            Positioned(
              left: s.px! * w,
              top: s.py! * h,
              width: s.pw! * w,
              height: s.ph! * h,
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(children: [
                  Text("@seunick", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                  Text("Outubro 2026", style: TextStyle(color: Color(0xFFE2C6FF), fontSize: 8, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
        ],
      ]);
    });
  }
}

/// Ajuste manual (raro): posicao e tamanho do circulo da foto.
class _SlotsDialog extends StatefulWidget {
  final String imageUrl;
  final ArtSlots initial;
  const _SlotsDialog({required this.imageUrl, required this.initial});

  @override
  State<_SlotsDialog> createState() => _SlotsDialogState();
}

class _SlotsDialogState extends State<_SlotsDialog> {
  late ArtSlots _s = widget.initial;

  @override
  Widget build(BuildContext context) {
    Widget slider(String label, double value, double min, double max, ValueChanged<double> onChanged) => Row(children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          Expanded(child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged)),
        ]);
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1426),
      title: const Text("Ajustar área da foto", style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 520,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 200, child: AspectRatio(aspectRatio: 2 / 3, child: _ArtPreview(url: widget.imageUrl, slots: _s))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              slider("Horizontal", _s.cx, 0.1, 0.9, (v) => setState(() => _s = _s.copyWith(cx: v))),
              slider("Vertical", _s.cy, 0.05, 0.95, (v) => setState(() => _s = _s.copyWith(cy: v))),
              slider("Tamanho", _s.r, 0.05, 0.45, (v) => setState(() => _s = _s.copyWith(r: v))),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_s),
          style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
          child: const Text("Salvar"),
        ),
      ],
    );
  }
}

// ============================================================================
// BRASOES (estagios da jornada: nome, criterio, meta, textos)
// ============================================================================
class BrasoesAdmin extends StatefulWidget {
  const BrasoesAdmin({super.key});

  @override
  State<BrasoesAdmin> createState() => _BrasoesAdminState();
}

class _BrasoesAdminState extends State<BrasoesAdmin> {
  final _service = ConquistasService();
  List<Map<String, dynamic>>? _stages;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await _service.fetchStages();
      if (mounted) {
        setState(() {
          _stages = s;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _stages == null) return _errorBox(_error!);
    final stages = _stages;
    if (stages == null) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
      _intro("🛡", "BRASÕES = estágio da jornada (não é conquista)",
          "O sistema escolhe o brasão pelo histórico recente de diamantes (janela em Configurações): do estágio mais alto para o mais baixo, "
          "o primeiro cujo critério for cumprido. O streamer só vê o NOME do estágio e o brasão — nunca a classificação interna. "
          "Aqui também ficam os textos da meta que aparecem no app."),
      const SizedBox(height: 16),
      for (final s in stages) _StageCard(stage: s, service: _service, onSaved: _load),
    ]);
  }
}

class _StageCard extends StatefulWidget {
  final Map<String, dynamic> stage;
  final ConquistasService service;
  final VoidCallback onSaved;
  const _StageCard({required this.stage, required this.service, required this.onSaved});

  @override
  State<_StageCard> createState() => _StageCardState();
}

class _StageCardState extends State<_StageCard> {
  late final Map<String, dynamic> _s = widget.stage;
  late final _name = TextEditingController(text: _s["name"] as String? ?? "");
  late final _description = TextEditingController(text: _s["description"] as String? ?? "");
  late final _minValue = TextEditingController(text: compactValue((_s["min_value"] as num?) ?? 0));
  late final _minMonths = TextEditingController(text: ((_s["min_months"] as num?) ?? 0).toString());
  late final _goalLabel = TextEditingController(text: _s["goal_label"] as String? ?? "");
  late final _secondaryLabel = TextEditingController(text: _s["secondary_label"] as String? ?? "");
  late String _crest = _s["crest_key"] as String? ?? "prata";
  late String? _crestImage = _s["crest_image_url"] as String?;
  late String _goalMode = _s["goal_mode"] as String? ?? "next_step";
  late String _secondaryMode = _s["secondary_mode"] as String? ?? "horizon";
  late bool _active = _s["is_active"] as bool? ?? true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _description, _minValue, _minMonths, _goalLabel, _secondaryLabel]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCrest() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final url = await widget.service.uploadCrest(result.files.single);
    setState(() => _crestImage = url);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.service.updateStage(_s["id"] as String, {
        "name": _name.text.trim(),
        "description": _description.text.trim().isEmpty ? null : _description.text.trim(),
        "crest_key": _crest,
        "crest_image_url": _crestImage,
        "min_value": parseValue(_minValue.text) ?? 0,
        "min_months": int.tryParse(_minMonths.text.trim()) ?? 0,
        "goal_mode": _goalMode,
        "goal_label": _goalLabel.text.trim().isEmpty ? "Seu próximo marco" : _goalLabel.text.trim(),
        "secondary_mode": _secondaryMode,
        "secondary_label": _secondaryLabel.text.trim().isEmpty ? null : _secondaryLabel.text.trim(),
        "is_active": _active,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Brasão salvo.")));
      widget.onSaved();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String l) => InputDecoration(labelText: l, labelStyle: const TextStyle(color: Colors.white54), border: const OutlineInputBorder(), isDense: true);
    const white = TextStyle(color: Colors.white, fontSize: 13);
    final isBase = ((_s["min_months"] as num?) ?? 0) <= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _gold.withValues(alpha: 0.25))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          JourneyCrest(crestKey: _crest, imageUrl: _crestImage, size: 120),
          const SizedBox(height: 6),
          TextButton(onPressed: _pickCrest, child: const Text("Enviar arte própria", style: TextStyle(fontSize: 12))),
          if (_crestImage != null)
            TextButton(onPressed: () => setState(() => _crestImage = null), child: const Text("Usar desenho", style: TextStyle(fontSize: 12, color: Colors.white54))),
          Text("interno: ${_s["key"]}", style: const TextStyle(color: Colors.white24, fontSize: 10)),
        ]),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: TextField(controller: _name, style: white, decoration: dec("Nome do estágio (aparece no app)"))),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _crest,
                  dropdownColor: const Color(0xFF221B30),
                  decoration: dec("Estilo do brasão"),
                  items: [for (final c in crestLabels.entries) DropdownMenuItem(value: c.key, child: Text(c.value, style: white))],
                  onChanged: (v) => setState(() => _crest = v ?? _crest),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(controller: _description, style: white, decoration: dec("Frase do estágio (aparece no app)")),
            const SizedBox(height: 12),
            const Text("CRITÉRIO", style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 6),
            if (isBase)
              const Text("Estágio inicial: é o padrão de quem ainda não cumpre nenhum outro critério.", style: TextStyle(color: Colors.white54, fontSize: 12))
            else
              Row(children: [
                const Text("Pelo menos ", style: TextStyle(color: Colors.white70)),
                SizedBox(width: 60, child: TextField(controller: _minMonths, style: white, decoration: dec("meses"))),
                const Text("  mês(es) com  ", style: TextStyle(color: Colors.white70)),
                SizedBox(width: 110, child: TextField(controller: _minValue, style: white, decoration: dec("diamantes"))),
                const Text("  ou mais (na janela)", style: TextStyle(color: Colors.white70)),
              ]),
            const SizedBox(height: 10),
            const Text("A meta mostrada no app agora é automática (adaptada ao momento de cada streamer). Ajuste em Configurações.",
                style: TextStyle(color: Colors.white38, fontSize: 11.5)),
            Row(children: [
              Switch(value: _active, activeThumbColor: _purple, onChanged: (v) => setState(() => _active = v)),
              const Text("Ativo", style: TextStyle(color: Colors.white70)),
              const Spacer(),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
                child: Text(_saving ? "Salvando..." : "Salvar"),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

