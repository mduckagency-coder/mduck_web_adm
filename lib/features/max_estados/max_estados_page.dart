import "package:flutter/material.dart";
import "max_estado_detail_page.dart";
import "max_estados_service.dart";
import "widgets/max_config_dialog.dart";
import "models/max_state.dart";
import "models/max_state_media.dart";

class MaxEstadosPage extends StatefulWidget {
  const MaxEstadosPage({super.key});

  @override
  State<MaxEstadosPage> createState() => _MaxEstadosPageState();
}

class _MaxEstadosPageState extends State<MaxEstadosPage> {
  final _service = MaxEstadosService();
  Map<MaxStateKey, MaxStateSummary> _summary = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final summary = await _service.fetchSummary();
    if (mounted) {
      setState(() {
        _summary = summary;
        _loading = false;
      });
    }
  }

  Future<void> _openState(MaxStateKey stateKey) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MaxEstadoDetailPage(stateKey: stateKey)));
    _load();
  }

  Widget _preview(MaxStateMedia? media) {
    if (media == null) {
      return Container(
        color: Colors.white12,
        child: const Center(child: Icon(Icons.pets, color: Colors.white38, size: 40)),
      );
    }
    if (media.mediaType == MaxMediaType.image) {
      return Image.network(_service.publicUrlFor(media.storagePath), fit: BoxFit.cover);
    }
    return Container(
      color: Colors.white12,
      child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.white54, size: 40)),
    );
  }

  Widget _stateCard(MaxStateKey stateKey) {
    final summary = _summary[stateKey];
    final media = summary?.media;
    return Card(
      color: const Color(0xFF1A1A1A),
      child: InkWell(
        onTap: () => _openState(stateKey),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(aspectRatio: 16 / 10, child: _preview(media)),
              ),
              const SizedBox(height: 12),
              Text(maxStateKeyLabel(stateKey), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                maxStateKeyDescription(stateKey),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _tag(
                  media == null ? Icons.hide_image_outlined : (media.mediaType == MaxMediaType.image ? Icons.image : Icons.videocam),
                  media == null ? "Sem conteúdo" : (media.mediaType == MaxMediaType.image ? "Imagem" : "Vídeo"),
                ),
                _tag(Icons.chat_bubble_outline, (summary?.messageCount ?? 0).toString() + " mensagens"),
              ]),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openState(stateKey),
                  icon: const Icon(Icons.edit, size: 16, color: Colors.white70),
                  label: const Text("Editar", style: TextStyle(color: Colors.white70)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.white54),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]),
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
            const Text("🦆 Max — Entrada", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => showDialog(context: context, builder: (_) => const MaxConfigDialog()),
              icon: const Icon(Icons.settings, size: 18, color: Colors.white70),
              label: const Text("Configuração", style: TextStyle(color: Colors.white70)),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            "Estados do Max exibidos quando o streamer abre o aplicativo.",
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 1100 ? 4 : (constraints.maxWidth > 760 ? 2 : 1);
                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.78,
                        children: MaxStateKey.values.map(_stateCard).toList(),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
