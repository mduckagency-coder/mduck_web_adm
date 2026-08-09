import "package:flutter/material.dart";
import "../ilha_top_service.dart";

Color _hexToColor(String hex) {
  try {
    final cleaned = hex.replaceFirst("#", "");
    return Color(int.parse("FF" + cleaned, radix: 16));
  } catch (_) {
    return Colors.white54;
  }
}

/// Multiplicador de tamanho a aplicar sobre o diametro base do slot, de
/// acordo com as opcoes de tamanho do avatar (padrao = 1, sem mudanca).
double _avatarSizeMultiplier(Map<String, dynamic>? streamer) {
  if (streamer == null) return 1;
  if (streamer["avatar_size_mode"] != "percent") return 1;
  final percent = streamer["avatar_size_percent"] as double?;
  if (percent == null) return 1;
  return percent / 100;
}

/// Pre-visualizacao da Ilha: renderiza o fundo escolhido + cada slot com o
/// streamer que ocuparia aquela posicao hoje, usando o ranking atual.
///
/// O "modo teste" (agencia inteira, compartilhado com a aba Ranking) tem
/// aqui a configuracao completa: diamantes minimos customizados (em vez de
/// 80k fixo), quem fica fixo no Top 1/2/3 (manual, independente dos
/// diamantes) e quais raridades de avatar ficam bloqueadas/desbloqueadas.
/// Tudo isso fica salvo (chave "island_test_config" em app_settings) pro
/// app poder ler e aplicar quando o modo teste estiver ligado.
class IlhaPreviewTab extends StatefulWidget {
  const IlhaPreviewTab({super.key});

  @override
  State<IlhaPreviewTab> createState() => _IlhaPreviewTabState();
}

class _IlhaPreviewTabState extends State<IlhaPreviewTab> {
  final _service = IlhaTopService();
  final _thresholdController = TextEditingController(text: "0");

  bool _loading = true;
  bool _testMode = true;
  List<Map<String, dynamic>> _slots = [];
  List<Map<String, dynamic>> _backgrounds = [];
  List<Map<String, dynamic>> _ranking = [];
  List<Map<String, dynamic>> _streamers = [];
  List<Map<String, dynamic>> _avatars = [];
  Map<String, dynamic>? _lastMonthTop1;
  int? _maxRank;
  String? _selectedBackgroundId;
  Map<String, dynamic> _testConfig = const {
    "diamond_threshold": 0,
    "pinned_top1": null,
    "pinned_top2": null,
    "pinned_top3": null,
    "rarity_locks": <String, bool>{},
  };

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final results = await Future.wait([
      _service.fetchTestMode(),
      _service.fetchTestConfig(),
      _service.fetchAllActiveStreamersBasic(),
      _service.fetchAvatars(),
      _service.fetchMaxRank(),
    ]);
    _testMode = results[0] as bool;
    _testConfig = results[1] as Map<String, dynamic>;
    _streamers = results[2] as List<Map<String, dynamic>>;
    _avatars = results[3] as List<Map<String, dynamic>>;
    _maxRank = results[4] as int?;
    _thresholdController.text = (_testConfig["diamond_threshold"] as int).toString();
    await _loadRanking();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  void _showSaved() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Configuração de teste salva."), duration: Duration(seconds: 2)));
  }

  Future<void> _setTestMode(bool value) async {
    setState(() => _testMode = value);
    try {
      await _service.saveTestMode(value);
      await _loadRanking();
    } catch (e) {
      _showError("Erro ao salvar modo teste: " + e.toString());
    }
  }

  Future<void> _persistTestConfig() => _service.saveTestConfig(_testConfig);

  Future<void> _applyThreshold() async {
    final value = int.tryParse(_thresholdController.text.trim()) ?? 0;
    setState(() => _testConfig = {..._testConfig, "diamond_threshold": value});
    try {
      await _persistTestConfig();
      await _loadRanking();
      _showSaved();
    } catch (e) {
      _showError("Erro ao salvar diamantes mínimos: " + e.toString());
    }
  }

  Future<void> _setPinned(String key, String? streamerId) async {
    setState(() => _testConfig = {..._testConfig, key: streamerId});
    try {
      await _persistTestConfig();
      await _loadRanking();
      _showSaved();
    } catch (e) {
      _showError("Erro ao salvar posição fixa: " + e.toString());
    }
  }

  Future<void> _toggleRarityLock(String rarity, bool locked) async {
    final locks = Map<String, bool>.from(_testConfig["rarity_locks"] as Map);
    locks[rarity] = locked;
    setState(() => _testConfig = {..._testConfig, "rarity_locks": locks});
    try {
      await _persistTestConfig();
      _showSaved();
    } catch (e) {
      _showError("Erro ao salvar raridade: " + e.toString());
    }
  }

  Future<void> _loadRanking() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _service.fetchSlots(),
      _service.fetchBackgrounds(),
      _service.fetchRanking(
        testMode: _testMode,
        threshold: _testMode ? (_testConfig["diamond_threshold"] as int? ?? 0) : 80000,
        pinnedIds: _testMode
            ? [_testConfig["pinned_top1"] as String?, _testConfig["pinned_top2"] as String?, _testConfig["pinned_top3"] as String?]
            : const [],
        maxRank: _maxRank,
      ),
      _service.fetchLastMonthTop1(),
    ]);
    final backgrounds = results[1] as List<Map<String, dynamic>>;
    final withRef = backgrounds.firstWhere(
      (b) => b["media_type"] == "image" || (b["preview_image_url"] as String?)?.isNotEmpty == true,
      orElse: () => <String, dynamic>{},
    );
    if (mounted) {
      setState(() {
        _slots = results[0] as List<Map<String, dynamic>>;
        _backgrounds = backgrounds;
        _ranking = results[2] as List<Map<String, dynamic>>;
        _lastMonthTop1 = results[3] as Map<String, dynamic>?;
        _selectedBackgroundId ??= withRef.isNotEmpty ? withRef["id"] as String : null;
        _loading = false;
      });
    }
  }

  String? _referenceImageUrl(Map<String, dynamic> bg) {
    if (bg.isEmpty) return null;
    if (bg["media_type"] == "image") return bg["media_url"] as String?;
    return bg["preview_image_url"] as String?;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _slots.isEmpty) return const Center(child: CircularProgressIndicator());

    final selectedBg = _backgrounds.firstWhere((b) => b["id"] == _selectedBackgroundId, orElse: () => <String, dynamic>{});
    final refUrl = _referenceImageUrl(selectedBg);
    final cropScale = (selectedBg["crop_scale"] as num?)?.toDouble() ?? 1.0;
    final cropOffsetX = (selectedBg["crop_offset_x"] as num?)?.toDouble() ?? 0.0;
    final cropOffsetY = (selectedBg["crop_offset_y"] as num?)?.toDouble() ?? 0.0;

    final enabledSlots = _slots.where((s) => s["is_enabled"] as bool? ?? true);
    final pointSlots = enabledSlots.where((s) => !islandSlotIsArea(s["slot_key"] as String) && !islandSlotIsPhotoSlot(s["slot_key"] as String));
    final areaSlot = enabledSlots.firstWhere((s) => islandSlotIsArea(s["slot_key"] as String), orElse: () => <String, dynamic>{});
    final photoSlot = enabledSlots.firstWhere((s) => islandSlotIsPhotoSlot(s["slot_key"] as String), orElse: () => <String, dynamic>{});

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _testMode ? Colors.amber.withOpacity(0.1) : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: _testMode ? Border.all(color: Colors.amber) : null,
            ),
            child: Row(children: [
              Icon(Icons.science_outlined, color: _testMode ? Colors.amber : Colors.white38, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Modo teste (vale pra agência toda, inclusive no app quando o app respeitar essa flag). Lembre de desligar depois de testar.",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              Switch(value: _testMode, activeThumbColor: Colors.amber, onChanged: _setTestMode),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Row(children: [
                        const Text("Fundo:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _selectedBackgroundId,
                          hint: const Text("nenhum", style: TextStyle(color: Colors.white54, fontSize: 13)),
                          dropdownColor: const Color(0xFF1A1A1A),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: [for (final b in _backgrounds) DropdownMenuItem(value: b["id"] as String, child: Text(b["label"] as String))],
                          onChanged: (v) => setState(() => _selectedBackgroundId = v),
                        ),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _loadRanking),
                      ]),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 9 / 16,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final size = Size(constraints.maxWidth, constraints.maxHeight);
                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white24),
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: refUrl == null
                                        ? const LinearGradient(colors: [Color(0xFF14263B), Color(0xFF0B1622)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                                        : null,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      children: [
                                        if (refUrl != null)
                                          Positioned.fill(
                                            child: Align(
                                              alignment: Alignment(cropOffsetX / 50, cropOffsetY / 50),
                                              child: SizedBox(
                                                width: size.width * cropScale,
                                                height: size.height * cropScale,
                                                child: Image.network(refUrl, fit: BoxFit.cover),
                                              ),
                                            ),
                                          ),
                                        for (final slot in pointSlots) _buildPointPreview(slot, size),
                                        if (photoSlot.isNotEmpty) _buildPhotoSlotPreview(photoSlot, size),
                                        if (areaSlot.isNotEmpty) _buildAreaPreview(areaSlot, size),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildTestConfigPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestConfigPanel() {
    if (!_testMode) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text("Ligue o modo teste pra customizar diamantes mínimos, fixar top 1/2/3 e travar raridades.", style: TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
        ),
      );
    }
    final locks = Map<String, bool>.from(_testConfig["rarity_locks"] as Map);
    return ListView(
      children: [
        const Text("Diamantes mínimos (modo teste)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        const Text("Substitui os 80k fixos só enquanto o modo teste estiver ligado.", style: TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _thresholdController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), labelText: "Diamantes mínimos"),
              onSubmitted: (_) => _applyThreshold(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _applyThreshold,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            child: const Text("Aplicar"),
          ),
        ]),
        const SizedBox(height: 20),
        const Text("Fixar manualmente", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        const Text("Escolha quem ocupa Top 1, Top 2 e Top 3, independente dos diamantes.", style: TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 6),
        _pinnedDropdown("Top 1", "pinned_top1"),
        const SizedBox(height: 8),
        _pinnedDropdown("Top 2", "pinned_top2"),
        const SizedBox(height: 8),
        _pinnedDropdown("Top 3", "pinned_top3"),
        const SizedBox(height: 20),
        const Text("Raridades de avatar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        const Text("Bloqueia/desbloqueia a raridade inteira, independente do mínimo de diamantes de cada avatar.", style: TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 6),
        for (final r in islandAvatarRarities) _rarityLockRow(r.$1, r.$2, locks[r.$1] ?? false),
      ],
    );
  }

  Widget _pinnedDropdown(String label, String key) {
    final value = _testConfig[key] as String?;
    return Row(children: [
      SizedBox(width: 48, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
      Expanded(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          hint: const Text("Automático (por diamantes)", style: TextStyle(color: Colors.white38, fontSize: 12)),
          dropdownColor: const Color(0xFF1A1A1A),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text("Automático (por diamantes)")),
            for (final s in _streamers) DropdownMenuItem<String?>(value: s["id"] as String, child: Text(s["display_name"] as String, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => _setPinned(key, v),
        ),
      ),
    ]);
  }

  Widget _rarityLockRow(String rarityKey, String rarityLabel, bool locked) {
    final avatarsOfRarity = _avatars.where((a) => (a["rarity"] as String? ?? "comum") == rarityKey).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 70, child: Text(rarityLabel, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Text(avatarsOfRarity.length.toString() + " avatar(es)", style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const Spacer(),
        Text(locked ? "Bloqueado" : "Desbloqueado", style: TextStyle(color: locked ? Colors.redAccent : Colors.greenAccent, fontSize: 11)),
        Switch(value: locked, activeThumbColor: Colors.redAccent, onChanged: (v) => _toggleRarityLock(rarityKey, v)),
      ]),
    );
  }

  Map<String, dynamic>? _rankedAt(int rank) => rank - 1 < _ranking.length ? _ranking[rank - 1] : null;

  Widget _avatarThumb(String? previewUrl, String? name, double size, {Color borderColor = Colors.white54, String shape = "circle_border"}) {
    final isCircle = shape != "square";
    final showBorder = shape == "circle_border";
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(size * 0.12),
        color: const Color(0xFF2A2A2A),
        border: showBorder ? Border.all(color: borderColor, width: 1.5) : null,
        image: previewUrl != null ? DecorationImage(image: NetworkImage(previewUrl), fit: BoxFit.cover) : null,
      ),
      child: previewUrl == null
          ? Center(
              child: Text(
                name != null && name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?",
                style: TextStyle(color: Colors.white70, fontSize: size * 0.4, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _nameTag(String text) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(maxWidth: 64),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
      child: Text(text, textAlign: TextAlign.center, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 9)),
    );
  }

  Widget _buildPointPreview(Map<String, dynamic> slot, Size size) {
    final slotKey = slot["slot_key"] as String;
    final rank = int.tryParse(slotKey.replaceFirst("top_", "")) ?? 0;
    final scale = (slot["scale"] as num).toDouble();
    final streamer = _rankedAt(rank);
    final diameter = 44 * scale * _avatarSizeMultiplier(streamer);
    final shape = streamer?["avatar_display_shape"] as String? ?? "circle_border";
    final borderColor = shape == "circle_border"
        ? (streamer?["avatar_border_color"] != null ? _hexToColor(streamer!["avatar_border_color"] as String) : (rank == 1 ? Colors.amber : Colors.white54))
        : Colors.transparent;
    return Positioned(
      left: (slot["pos_x"] as num).toDouble() / 100 * size.width - diameter / 2,
      top: (slot["pos_y"] as num).toDouble() / 100 * size.height - diameter / 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _avatarThumb(
            streamer?["avatar_preview_url"] as String?,
            streamer?["display_name"] as String?,
            diameter,
            borderColor: borderColor,
            shape: shape,
          ),
          _nameTag(streamer != null ? streamer["display_name"] as String : "(vazio)"),
        ],
      ),
    );
  }

  Widget _buildPhotoSlotPreview(Map<String, dynamic> slot, Size size) {
    final scale = (slot["scale"] as num).toDouble();
    final diameter = 44 * scale;
    final top1 = _lastMonthTop1;
    return Positioned(
      left: (slot["pos_x"] as num).toDouble() / 100 * size.width - diameter / 2,
      top: (slot["pos_y"] as num).toDouble() / 100 * size.height - diameter / 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _avatarThumb(top1?["avatar_url"] as String?, top1?["display_name"] as String?, diameter, borderColor: Colors.amber),
          _nameTag(top1 != null ? top1["display_name"] as String : "(sem mês anterior)"),
          if (top1 != null)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
              child: Text("💎 " + (top1["diamonds"] as int).toString(), style: const TextStyle(color: Colors.white, fontSize: 9)),
            ),
        ],
      ),
    );
  }

  Widget _buildAreaPreview(Map<String, dynamic> slot, Size size) {
    final w = ((slot["area_width"] as num?)?.toDouble() ?? 40.0) / 100 * size.width;
    final h = ((slot["area_height"] as num?)?.toDouble() ?? 18.0) / 100 * size.height;
    final maxScale = (slot["scale"] as num?)?.toDouble() ?? 0.8;
    final minScale = (slot["min_scale"] as num?)?.toDouble() ?? 0.55;
    final extra = _ranking.length > 10 ? _ranking.sublist(10) : <Map<String, dynamic>>[];
    final count = extra.length;
    final scale = count <= 4 ? maxScale : (maxScale - (count - 4) * 0.04).clamp(minScale, maxScale);
    final diameter = 30 * scale;

    return Positioned(
      left: (slot["pos_x"] as num).toDouble() / 100 * size.width,
      top: (slot["pos_y"] as num).toDouble() / 100 * size.height,
      child: Container(
        width: w,
        height: h,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(border: Border.all(color: Colors.amber.withOpacity(0.4)), borderRadius: BorderRadius.circular(6)),
        child: count == 0
            ? const Center(child: Text("(vazio)", style: TextStyle(color: Colors.white38, fontSize: 10)))
            : SingleChildScrollView(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final s in extra)
                      _avatarThumb(
                        s["avatar_preview_url"] as String?,
                        s["display_name"] as String?,
                        diameter * _avatarSizeMultiplier(s),
                        shape: s["avatar_display_shape"] as String? ?? "circle_border",
                        borderColor: (s["avatar_display_shape"] as String? ?? "circle_border") == "circle_border"
                            ? (s["avatar_border_color"] != null ? _hexToColor(s["avatar_border_color"] as String) : Colors.white54)
                            : Colors.transparent,
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
