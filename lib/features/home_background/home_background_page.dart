import "dart:html" as html;

import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "../max_estados/widgets/max_video_preview.dart";
import "home_background_service.dart";
import "widgets/home_background_form_dialog.dart";

const _purple = Color(0xFF7A0BD4);

/// Configuracao Animacao APP > Background Home: banco de videos de fundo da
/// Home do app, organizado por faixa de horario, + audio padrao.
class HomeBackgroundPage extends StatefulWidget {
  const HomeBackgroundPage({super.key});

  @override
  State<HomeBackgroundPage> createState() => _HomeBackgroundPageState();
}

class _HomeBackgroundPageState extends State<HomeBackgroundPage> {
  final _service = HomeBackgroundService();

  // A lista fica guardada aqui e e atualizada na hora a cada salvar /
  // ativar / excluir; o banco e consultado de novo so por baixo, pra
  // confirmar. Assim o video salvo aparece sem precisar sair e voltar.
  List<Map<String, dynamic>>? _items;
  Object? _loadError;
  bool _refreshing = false;

  /// Liga/desliga da Inatividade (null enquanto carrega).
  bool? _inactivityEnabled;
  bool _savingToggle = false;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadInactivityToggle();
  }

  Future<void> _loadInactivityToggle() async {
    try {
      final enabled = await _service.fetchInactivityEnabled();
      if (mounted) setState(() => _inactivityEnabled = enabled);
    } catch (_) {
      if (mounted) setState(() => _inactivityEnabled = true);
    }
  }

  Future<void> _setInactivityEnabled(bool enabled) async {
    final previous = _inactivityEnabled;
    setState(() {
      _inactivityEnabled = enabled;
      _savingToggle = true;
    });
    try {
      await _service.saveInactivityEnabled(enabled);
    } catch (e) {
      if (mounted) setState(() => _inactivityEnabled = previous);
      _showError("Não foi possível salvar: $e");
    } finally {
      if (mounted) setState(() => _savingToggle = false);
    }
  }

  Widget _inactivityToggleCard() {
    final enabled = _inactivityEnabled ?? true;
    final color = enabled ? Colors.greenAccent : Colors.white54;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: (enabled ? Colors.green : Colors.white).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        Icon(enabled ? Icons.toggle_on : Icons.toggle_off, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(enabled ? "Inatividade LIGADA" : "Inatividade DESLIGADA",
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(
              enabled
                  ? "Quem está há mais de 7 dias sem live vê os vídeos desta aba."
                  : "Todos os streamers veem os vídeos normais, mesmo quem está sem live. Os vídeos desta aba ficam guardados.",
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ]),
        ),
        if (_inactivityEnabled == null || _savingToggle)
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          Switch(value: enabled, activeThumbColor: Colors.greenAccent, onChanged: _setInactivityEnabled),
      ]),
    );
  }

  Future<void> _reload() async {
    setState(() => _refreshing = true);
    try {
      final items = await _service.fetchAll();
      if (mounted) {
        setState(() {
          _items = items;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// Mesma ordem do banco: horario de inicio, depois ordem/criacao.
  void _sortItems(List<Map<String, dynamic>> items) {
    items.sort((a, b) {
      final byStart = (a["start_time"] as String).compareTo(b["start_time"] as String);
      if (byStart != 0) return byStart;
      final byOrder = ((a["sort_order"] as int?) ?? 0).compareTo((b["sort_order"] as int?) ?? 0);
      if (byOrder != 0) return byOrder;
      return (a["created_at"] as String? ?? "").compareTo(b["created_at"] as String? ?? "");
    });
  }

  Future<void> _openForm({Map<String, dynamic>? existing, String? start, String? end}) async {
    final saved = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (_) => HomeBackgroundFormDialog(existing: existing, initialStart: start, initialEnd: end, initialCategory: _tab),
    );
    if (saved == null || saved.isEmpty || !mounted) return;
    setState(() {
      final items = [...?_items];
      for (final row in saved) {
        final index = items.indexWhere((i) => i["id"] == row["id"]);
        if (index >= 0) {
          items[index] = row;
        } else {
          items.add(row);
        }
      }
      _sortItems(items);
      _items = items;
    });
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Excluir vídeo?", style: TextStyle(color: Colors.white)),
        content: Text("\"${item["label"]}\" será removido. Essa ação não pode ser desfeita.",
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Excluir", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _items = [...?_items]..removeWhere((i) => i["id"] == item["id"]));
      try {
        await _service.delete(item["id"] as String);
      } catch (e) {
        _showError("Não foi possível excluir: $e");
        _reload();
      }
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> item, bool active) async {
    setState(() {
      _items = [
        for (final i in _items ?? <Map<String, dynamic>>[]) i["id"] == item["id"] ? {...i, "is_active": active} : i,
      ];
    });
    try {
      await _service.setActive(item["id"] as String, active);
    } catch (e) {
      _showError("Não foi possível alterar: $e");
      _reload();
    }
  }

  void _showError(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _preview(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 760),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(item["label"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Flexible(child: MaxVideoPreview(url: item["media_url"] as String)),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar")),
            ]),
          ),
        ),
      ),
    );
  }

  static String _hhmm(String? t) => (t ?? "00:00").substring(0, 5);

  static int _minutes(String hhmm) {
    final p = hhmm.split(":");
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  /// Faixas do dia sem nenhum video ativo (a Home cairia no video que estiver
  /// ativo em qualquer horario, sorteado do dia).
  static List<String> _uncoveredRanges(List<Map<String, dynamic>> items) {
    final covered = List<bool>.filled(1440, false);
    for (final it in items.where((i) => i["is_active"] as bool? ?? true)) {
      final s = _minutes(_hhmm(it["start_time"] as String?));
      final e = _minutes(_hhmm(it["end_time"] as String?));
      if (s <= e) {
        for (var m = s; m <= e; m++) {
          covered[m] = true;
        }
      } else {
        for (var m = s; m < 1440; m++) {
          covered[m] = true;
        }
        for (var m = 0; m <= e; m++) {
          covered[m] = true;
        }
      }
    }
    String fmt(int m) => "${(m ~/ 60).toString().padLeft(2, "0")}:${(m % 60).toString().padLeft(2, "0")}";
    final ranges = <String>[];
    int? gapStart;
    for (var m = 0; m <= 1440; m++) {
      final isGap = m < 1440 && !covered[m];
      if (isGap && gapStart == null) gapStart = m;
      if (!isGap && gapStart != null) {
        ranges.add("${fmt(gapStart)}–${fmt(m - 1)}");
        gapStart = null;
      }
    }
    return ranges;
  }

  static String _periodEmoji(String start, String end) {
    for (final p in [...homePeriodPresets, ...homeInactivityPresets]) {
      if (p.start == start && p.end == end) return "${p.emoji} ${p.label}";
    }
    return "🕒 Horário personalizado";
  }

  /// Aba aberta: vídeos normais ou de inatividade.
  String _tab = homeCategoryNormal;

  static String _categoryOf(Map<String, dynamic> item) => item["category"] as String? ?? homeCategoryNormal;

  Widget _tabButton(String category, String label, IconData icon, int count) {
    final selected = _tab == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 16, color: selected ? Colors.white : Colors.white54),
        label: Text("$label ($count)"),
        selected: selected,
        showCheckmark: false,
        selectedColor: _purple,
        backgroundColor: Colors.white10,
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.w600),
        onSelected: (_) => setState(() => _tab = category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Background Home", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
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
              label: Text(_tab == homeCategoryInactivity ? "Adicionar vídeo de inatividade" : "Adicionar vídeos"),
              style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            "Vídeos de fundo da Home do app (o pato na ilha). Cada vídeo tem uma faixa de horário. "
            "Na mesma faixa, os aleatórios são sorteados 1 vez por dia para cada streamer: no mesmo dia ele vê sempre o mesmo vídeo, "
            "no dia seguinte pode ser outro. Os vídeos ficam sempre em loop.",
            style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          const _DefaultAudioCard(),
          const SizedBox(height: 16),
          Expanded(
            child: Builder(
              builder: (context) {
                if (_items == null && _loadError != null) {
                  return Center(
                    child: Text(
                      "Erro ao carregar: $_loadError\n\nSe a tabela ainda não existe, rode a migration 0084_home_backgrounds.sql no Supabase.",
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                if (_items == null) return const Center(child: CircularProgressIndicator());
                final all = _items!;
                final isInactivityTab = _tab == homeCategoryInactivity;
                final items = all.where((i) => _categoryOf(i) == _tab).toList();
                final tabs = Row(children: [
                  _tabButton(homeCategoryNormal, "Vídeos normais", Icons.wb_sunny_outlined,
                      all.where((i) => _categoryOf(i) == homeCategoryNormal).length),
                  _tabButton(
                      homeCategoryInactivity,
                      _inactivityEnabled == false ? "Inatividade · desligada" : "Inatividade",
                      Icons.bedtime_outlined,
                      all.where((i) => _categoryOf(i) == homeCategoryInactivity).length),
                ]);
                final tabHelp = Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      isInactivityTab
                          ? "Quando o streamer está há mais de 7 dias sem live, a Home ignora os vídeos normais e mostra só estes "
                              "(a ilha sem o pato, com o texto por cima). Os horários funcionam igual: ex. um vídeo de Dia e um de Noite. "
                              "Quando ele volta a fazer live, volta sozinho para os vídeos normais."
                          : "Programação do dia a dia, para streamers ativos.",
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    if (isInactivityTab) _inactivityToggleCard(),
                  ]),
                );

                if (items.isEmpty) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    tabs,
                    tabHelp,
                    Expanded(
                      child: Center(
                        child: Text(
                          isInactivityTab
                              ? "Nenhum vídeo de inatividade ainda. Enquanto não houver, quem está inativo continua vendo os vídeos normais."
                              : "Nenhum vídeo cadastrado ainda. Clique em \"Adicionar vídeos\".",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                  ]);
                }

                // agrupa por faixa de horario, na ordem do dia
                final groups = <String, List<Map<String, dynamic>>>{};
                for (final it in items) {
                  final key = "${_hhmm(it["start_time"] as String?)}|${_hhmm(it["end_time"] as String?)}";
                  groups.putIfAbsent(key, () => []).add(it);
                }
                final gaps = _uncoveredRanges(items);

                return ListView(
                  children: [
                    tabs,
                    tabHelp,
                    if (gaps.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          "⚠️ Horários sem vídeo ativo${isInactivityTab ? " de inatividade" : ""}: ${gaps.join(", ")}. "
                          "Nesses horários a Home usa um dos outros vídeos ativos ${isInactivityTab ? "de inatividade" : "normais"}.",
                          style: const TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                    for (final entry in groups.entries)
                      _PeriodGroup(
                        title: _periodEmoji(entry.key.split("|")[0], entry.key.split("|")[1]),
                        range: "${entry.key.split("|")[0]} – ${entry.key.split("|")[1]}",
                        items: entry.value,
                        onAdd: () => _openForm(start: entry.key.split("|")[0], end: entry.key.split("|")[1]),
                        showOverlayText: isInactivityTab,
                        onEdit: (it) => _openForm(existing: it),
                        onDelete: _delete,
                        onToggle: _toggleActive,
                        onPreview: _preview,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodGroup extends StatelessWidget {
  final String title;
  final String range;
  final List<Map<String, dynamic>> items;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;
  final void Function(Map<String, dynamic>, bool) onToggle;
  final void Function(Map<String, dynamic>) onPreview;

  /// Na aba Inatividade, mostra o texto que aparece sobre o video.
  final bool showOverlayText;

  const _PeriodGroup({
    required this.title,
    required this.range,
    required this.items,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onPreview,
    this.showOverlayText = false,
  });

  static String _audioLabel(Map<String, dynamic> it) {
    switch (it["audio_mode"]) {
      case "default":
        return "🎵 áudio padrão";
      case "mute":
        return "🔇 sem som";
      default:
        return "🔊 som do vídeo ${(((it["volume"] as num?) ?? 1) * 100).round()}%";
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = items.where((i) => i["is_active"] as bool? ?? true).toList();
    final fixed = active.where((i) => i["mode"] == "fixed").length;
    final random = active.length - fixed;
    final summary = fixed > 0
        ? "$fixed fixo(s) — o fixo aparece sempre nessa faixa"
        : "$random aleatório(s) — 1 sorteado por dia para cada streamer";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("$title  ·  $range",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text("${items.length} vídeo(s)  ·  $summary", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16, color: Color(0xFFB98CFF)),
                label: const Text("Adicionar nesta faixa", style: TextStyle(color: Color(0xFFB98CFF))),
              ),
            ]),
          ),
          const Divider(color: Colors.white12, height: 1),
          for (final it in items)
            ListTile(
              dense: true,
              leading: IconButton(
                tooltip: "Ver vídeo",
                icon: const Icon(Icons.play_circle_outline, color: Colors.white70),
                onPressed: () => onPreview(it),
              ),
              title: Text(it["label"] as String,
                  style: TextStyle(
                    color: (it["is_active"] as bool? ?? true) ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.w600,
                  )),
              subtitle: Text(
                "${it["mode"] == "fixed" ? "📌 Fixo" : "🎲 Aleatório"}  ·  ${_audioLabel(it)}"
                "${(it["is_active"] as bool? ?? true) ? "" : "  ·  inativo"}"
                "${showOverlayText ? "\n💬 \"${(it["overlay_text"] as String? ?? "(sem texto)").replaceAll("\n", " ")}\"" : ""}",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Tooltip(
                  message: "Ativo",
                  child: Switch(
                    value: it["is_active"] as bool? ?? true,
                    activeThumbColor: _purple,
                    onChanged: (v) => onToggle(it, v),
                  ),
                ),
                IconButton(icon: const Icon(Icons.edit, color: Colors.white54, size: 18), onPressed: () => onEdit(it)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () => onDelete(it)),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Audio padrao da Home: toca por cima dos videos marcados com "Áudio padrão
/// da Home" (o video fica mudo).
class _DefaultAudioCard extends StatefulWidget {
  const _DefaultAudioCard();

  @override
  State<_DefaultAudioCard> createState() => _DefaultAudioCardState();
}

class _DefaultAudioCardState extends State<_DefaultAudioCard> {
  final _service = HomeBackgroundService();
  String? _url;
  double _volume = 1;
  bool _loading = true;
  bool _busy = false;
  String? _message;
  html.AudioElement? _player;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _player?.pause();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final audio = await _service.fetchDefaultAudio();
      if (mounted) {
        setState(() {
          _url = audio.url;
          _volume = audio.volume;
        });
      }
    } catch (_) {
      // sem configuracao ainda
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save({String? url, bool clear = false}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final newUrl = clear ? null : (url ?? _url);
      await _service.saveDefaultAudio(url: newUrl, volume: _volume);
      setState(() {
        _url = newUrl;
        _message = "Salvo ✅";
      });
    } catch (e) {
      setState(() => _message = "Erro ao salvar: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: homeAudioAllowedExtensions, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    if (file.size > 15 * 1024 * 1024) {
      setState(() => _message = "Arquivo acima de 15MB.");
      return;
    }
    setState(() => _busy = true);
    try {
      final url = await _service.uploadAudio(file);
      _stop();
      await _save(url: url);
    } catch (e) {
      setState(() {
        _busy = false;
        _message = "Erro ao enviar: $e";
      });
    }
  }

  void _togglePlay() {
    if (_player != null && !(_player!.paused)) {
      _stop();
      return;
    }
    if (_url == null) return;
    _player = html.AudioElement(_url)
      ..volume = _volume
      ..loop = true;
    _player!.play();
    setState(() {});
  }

  void _stop() {
    _player?.pause();
    _player = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final playing = _player != null && !_player!.paused;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _purple.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _purple.withValues(alpha: 0.5)),
      ),
      child: _loading
          ? const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text("🎵 Áudio padrão da Home",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 10),
                Text(_url == null ? "nenhum áudio enviado" : "áudio configurado",
                    style: TextStyle(color: _url == null ? Colors.white38 : Colors.greenAccent, fontSize: 12)),
                const Spacer(),
                if (_message != null) Text(_message!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
              const SizedBox(height: 2),
              const Text(
                "Toca em loop nos vídeos marcados com \"Áudio padrão da Home\" (o som do vídeo é desligado). MP3, M4A, AAC, WAV ou OGG.",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickAudio,
                  icon: const Icon(Icons.upload_file, size: 16, color: Colors.white70),
                  label: Text(_busy ? "Enviando..." : (_url == null ? "Enviar áudio" : "Trocar áudio"),
                      style: const TextStyle(color: Colors.white70)),
                ),
                if (_url != null) ...[
                  IconButton(
                    tooltip: playing ? "Parar" : "Ouvir",
                    icon: Icon(playing ? Icons.stop_circle : Icons.play_circle, color: Colors.white),
                    onPressed: _togglePlay,
                  ),
                  const Icon(Icons.volume_down, color: Colors.white54, size: 18),
                  SizedBox(
                    width: 180,
                    child: Slider(
                      value: _volume,
                      activeColor: _purple,
                      onChanged: (v) {
                        setState(() => _volume = v);
                        _player?.volume = v;
                      },
                      onChangeEnd: (_) => _save(),
                    ),
                  ),
                  Text("${(_volume * 100).round()}%", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            _stop();
                            _save(clear: true);
                          },
                    child: const Text("Remover", style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ]),
            ]),
    );
  }
}
