import "package:flutter/material.dart";
import "../ilha_top_service.dart";

/// Editor visual de posicoes: arraste cada slot (Top 1..Top 10, Area 11+)
/// sobre um fundo de referencia (vertical, celular). As coordenadas (% x/y)
/// sao salvas em island_slots e usadas pelo app do streamer pra posicionar
/// os patos. O slot 11+ e uma AREA (retangulo) redimensionavel, porque pode
/// ter varios avatares dentro ao mesmo tempo.
class IlhaSlotsEditorTab extends StatefulWidget {
  const IlhaSlotsEditorTab({super.key});

  @override
  State<IlhaSlotsEditorTab> createState() => _IlhaSlotsEditorTabState();
}

class _IlhaSlotsEditorTabState extends State<IlhaSlotsEditorTab> {
  final _service = IlhaTopService();
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _slots = [];
  List<Map<String, dynamic>> _backgrounds = [];
  String? _selectedBackgroundId;
  String? _selectedSlotKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([_service.fetchSlots(), _service.fetchBackgrounds()]);
    final slots = results[0];
    final backgrounds = results[1];
    final withRef = backgrounds.firstWhere(
      (b) => b["media_type"] == "image" || (b["preview_image_url"] as String?)?.isNotEmpty == true,
      orElse: () => <String, dynamic>{},
    );
    if (mounted) {
      setState(() {
        _slots = slots.map((s) => Map<String, dynamic>.from(s)).toList();
        _backgrounds = backgrounds;
        _selectedBackgroundId = withRef.isNotEmpty ? withRef["id"] as String : null;
        _loading = false;
      });
    }
  }

  /// URL de imagem estatica pra usar de referencia: se o fundo for imagem,
  /// usa ela mesma; se for video, usa o print cadastrado (se tiver).
  String? _referenceImageUrl(Map<String, dynamic> bg) {
    if (bg.isEmpty) return null;
    if (bg["media_type"] == "image") return bg["media_url"] as String?;
    return bg["preview_image_url"] as String?;
  }

  void _restoreDefaults() {
    setState(() {
      _slots = [
        for (final d in islandSlotDefaults)
          {
            ...d,
            "id": _slots.firstWhere((s) => s["slot_key"] == d["slot_key"], orElse: () => <String, dynamic>{})["id"],
          },
      ];
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.saveSlots(_slots);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Posições salvas.")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _slot(String slotKey) => _slots.firstWhere((s) => s["slot_key"] == slotKey);

  void _movePoint(String slotKey, Offset deltaPx, Size containerSize) {
    setState(() {
      final slot = _slot(slotKey);
      final newX = ((slot["pos_x"] as num).toDouble() + deltaPx.dx / containerSize.width * 100).clamp(0.0, 100.0);
      final newY = ((slot["pos_y"] as num).toDouble() + deltaPx.dy / containerSize.height * 100).clamp(0.0, 100.0);
      slot["pos_x"] = newX;
      slot["pos_y"] = newY;
    });
  }

  void _moveArea(String slotKey, Offset deltaPx, Size containerSize) {
    setState(() {
      final slot = _slot(slotKey);
      final w = (slot["area_width"] as num?)?.toDouble() ?? 40.0;
      final h = (slot["area_height"] as num?)?.toDouble() ?? 18.0;
      final newX = ((slot["pos_x"] as num).toDouble() + deltaPx.dx / containerSize.width * 100).clamp(0.0, 100.0 - w);
      final newY = ((slot["pos_y"] as num).toDouble() + deltaPx.dy / containerSize.height * 100).clamp(0.0, 100.0 - h);
      slot["pos_x"] = newX;
      slot["pos_y"] = newY;
    });
  }

  void _resizeArea(String slotKey, Offset deltaPx, Size containerSize) {
    setState(() {
      final slot = _slot(slotKey);
      final x = (slot["pos_x"] as num).toDouble();
      final y = (slot["pos_y"] as num).toDouble();
      final newW = (((slot["area_width"] as num?)?.toDouble() ?? 40.0) + deltaPx.dx / containerSize.width * 100).clamp(10.0, 100.0 - x);
      final newH = (((slot["area_height"] as num?)?.toDouble() ?? 18.0) + deltaPx.dy / containerSize.height * 100).clamp(10.0, 100.0 - y);
      slot["area_width"] = newW;
      slot["area_height"] = newH;
    });
  }

  void _updateScale(String slotKey, double scale) => setState(() => _slot(slotKey)["scale"] = scale);

  void _updateMinScale(String slotKey, double minScale) => setState(() => _slot(slotKey)["min_scale"] = minScale);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final selectedBg = _backgrounds.firstWhere((b) => b["id"] == _selectedBackgroundId, orElse: () => <String, dynamic>{});
    final refUrl = _referenceImageUrl(selectedBg);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Fundo de referência:", style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _selectedBackgroundId,
              hint: const Text("nenhum (usar grade)", style: TextStyle(color: Colors.white54, fontSize: 13)),
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: [
                for (final b in _backgrounds)
                  DropdownMenuItem(
                    value: b["id"] as String,
                    child: Text(b["label"] as String, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _selectedBackgroundId = v),
            ),
            const Spacer(),
            TextButton(onPressed: _restoreDefaults, child: const Text("Restaurar padrão")),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
              child: Text(_saving ? "Salvando..." : "Salvar posições"),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            selectedBg.isNotEmpty && selectedBg["media_type"] == "video" && refUrl == null
                ? "Esse fundo é um vídeo sem print cadastrado — edite-o na aba Vídeos de Fundo e envie um print pra ter uma referência visual aqui."
                : "Arraste cada slot sobre a imagem. A tela do app é vertical (celular) — a área de edição abaixo segue essa proporção.",
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
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
                              image: refUrl != null ? DecorationImage(image: NetworkImage(refUrl), fit: BoxFit.cover) : null,
                              gradient: refUrl == null
                                  ? const LinearGradient(colors: [Color(0xFF14263B), Color(0xFF0B1622)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  for (final slot in _slots)
                                    if (islandSlotIsArea(slot["slot_key"] as String))
                                      _buildAreaSlot(slot, size)
                                    else
                                      _buildPointSlot(slot, size),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ListView.builder(
                    itemCount: _slots.length,
                    itemBuilder: (context, index) => _buildSlotCard(_slots[index]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointSlot(Map<String, dynamic> slot, Size size) {
    final slotKey = slot["slot_key"] as String;
    final scale = (slot["scale"] as num).toDouble();
    return Positioned(
      left: (slot["pos_x"] as num).toDouble() / 100 * size.width - (14 * scale),
      top: (slot["pos_y"] as num).toDouble() / 100 * size.height - (14 * scale),
      child: GestureDetector(
        onPanUpdate: (details) => _movePoint(slotKey, details.delta, size),
        onTap: () => setState(() => _selectedSlotKey = slotKey),
        child: _SlotMarker(
          label: slot["label"] as String,
          scale: scale,
          selected: _selectedSlotKey == slotKey,
          highlight: slotKey == "top_1",
          icon: islandSlotIsPhotoSlot(slotKey) ? Icons.photo_camera : Icons.pets,
        ),
      ),
    );
  }

  Widget _buildAreaSlot(Map<String, dynamic> slot, Size size) {
    final slotKey = slot["slot_key"] as String;
    final w = ((slot["area_width"] as num?)?.toDouble() ?? 40.0) / 100 * size.width;
    final h = ((slot["area_height"] as num?)?.toDouble() ?? 18.0) / 100 * size.height;
    final selected = _selectedSlotKey == slotKey;
    return Positioned(
      left: (slot["pos_x"] as num).toDouble() / 100 * size.width,
      top: (slot["pos_y"] as num).toDouble() / 100 * size.height,
      child: GestureDetector(
        onPanUpdate: (details) => _moveArea(slotKey, details.delta, size),
        onTap: () => setState(() => _selectedSlotKey = slotKey),
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.12),
            border: Border.all(color: Colors.amber, width: selected ? 2.5 : 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  slot["label"] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanUpdate: (details) => _resizeArea(slotKey, details.delta, size),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                    child: const Icon(Icons.open_in_full, size: 10, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotCard(Map<String, dynamic> slot) {
    final slotKey = slot["slot_key"] as String;
    final isArea = islandSlotIsArea(slotKey);
    final selected = _selectedSlotKey == slotKey;
    return Card(
      color: selected ? const Color(0xFF7A0BD4).withOpacity(0.15) : Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(slot["label"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(
              "x: " + (slot["pos_x"] as num).toStringAsFixed(1) + "%  y: " + (slot["pos_y"] as num).toStringAsFixed(1) + "%",
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            if (isArea)
              Text(
                "largura: " + ((slot["area_width"] as num?)?.toDouble() ?? 40).toStringAsFixed(1) + "%  altura: " + ((slot["area_height"] as num?)?.toDouble() ?? 18).toStringAsFixed(1) + "%",
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            Row(children: [
              Text(isArea ? "Tamanho (poucos)" : "Tamanho", style: const TextStyle(color: Colors.white54, fontSize: 11)),
              Expanded(
                child: Slider(
                  value: (slot["scale"] as num).toDouble().clamp(0.5, 1.6),
                  min: 0.5,
                  max: 1.6,
                  activeColor: const Color(0xFF7A0BD4),
                  onChanged: (v) => _updateScale(slotKey, v),
                ),
              ),
            ]),
            if (isArea)
              Row(children: [
                const Text("Tamanho (lotado)", style: TextStyle(color: Colors.white54, fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: ((slot["min_scale"] as num?)?.toDouble() ?? 0.55).clamp(0.3, 1.2),
                    min: 0.3,
                    max: 1.2,
                    activeColor: Colors.amber,
                    onChanged: (v) => _updateMinScale(slotKey, v),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

class _SlotMarker extends StatelessWidget {
  const _SlotMarker({required this.label, required this.scale, required this.selected, required this.highlight, this.icon = Icons.pets});

  final String label;
  final double scale;
  final bool selected;
  final bool highlight;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final size = 28 * scale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: highlight ? Colors.amber : const Color(0xFF7A0BD4),
            border: Border.all(color: selected ? Colors.white : Colors.white54, width: selected ? 2.5 : 1.5),
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.55),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          constraints: const BoxConstraints(maxWidth: 56),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
          child: Text(
            label,
            textAlign: TextAlign.center,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 9),
          ),
        ),
      ],
    );
  }
}
