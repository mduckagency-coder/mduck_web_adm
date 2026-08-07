import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";
import "../app_settings_service.dart";

const inventoryMascotUrlKey = "inventory_mascot_url";
const _maxMascotFileSizeBytes = 5 * 1024 * 1024;

const _videoExtensions = [".mp4", ".mov", ".webm", ".m4v"];

bool _looksLikeVideo(String url) {
  final lower = url.toLowerCase().split("?").first;
  return _videoExtensions.any((ext) => lower.endsWith(ext));
}

/// Configuracao da tela do app ligada ao Inventario. Por enquanto so tem o
/// campo do video/imagem do mascote, mas fica isolada num dialog proprio
/// pra crescer sem bagunçar a pagina de Inventario.
class InventoryAppSettingsDialog extends StatefulWidget {
  const InventoryAppSettingsDialog({super.key});

  @override
  State<InventoryAppSettingsDialog> createState() => _InventoryAppSettingsDialogState();
}

class _InventoryAppSettingsDialogState extends State<InventoryAppSettingsDialog> {
  final _service = AppSettingsService();

  bool _loading = true;
  bool _uploading = false;
  bool _saving = false;
  String? _mascotUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await _service.fetchValue(inventoryMascotUrlKey);
    if (mounted) {
      setState(() {
        _mascotUrl = value;
        _loading = false;
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.media, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    if (file.size > _maxMascotFileSizeBytes) {
      setState(() => _error = "Arquivo muito grande (" + (file.size / (1024 * 1024)).toStringAsFixed(1) + "MB). O limite é 5MB.");
      return;
    }
    setState(() {
      _error = null;
      _uploading = true;
    });
    try {
      final url = await _service.uploadMedia(file);
      if (mounted) setState(() => _mascotUrl = url);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _service.saveValue(inventoryMascotUrlKey, _mascotUrl);
    if (mounted) Navigator.of(context).pop(true);
  }

  Widget _preview() {
    if (_mascotUrl == null || _mascotUrl!.isEmpty) return const SizedBox.shrink();
    if (_looksLikeVideo(_mascotUrl!)) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
        child: Row(children: [
          const Icon(Icons.movie, color: Colors.white54, size: 20),
          const SizedBox(width: 10),
          const Expanded(child: Text("Vídeo enviado", style: TextStyle(color: Colors.white70, fontSize: 12))),
          TextButton(
            onPressed: () => launchUrl(Uri.parse(_mascotUrl!), mode: LaunchMode.externalApplication),
            child: const Text("Ver arquivo"),
          ),
        ]),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(_mascotUrl!, height: 140, fit: BoxFit.contain, alignment: Alignment.centerLeft),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Configuração da tela do app", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text("Inventário", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 16),
                    const Text("Vídeo/Imagem do Mascote (Inventário)", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text(
                      "Vídeo (ou imagem) em loop do Max mostrando a mochila de conquistas. Aparece no banner de boas-vindas da tela de Inventário do app do streamer. "
                      "Recomendado: vídeo MP4 curto (3–6s), em loop, fundo transparente ou combinando com o roxo do app, formato quadrado ou vertical, até 5MB.",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    _preview(),
                    if (_mascotUrl != null && _mascotUrl!.isNotEmpty) const SizedBox(height: 8),
                    Row(children: [
                      OutlinedButton.icon(
                        onPressed: _uploading ? null : _pickFile,
                        icon: const Icon(Icons.upload_file, size: 16, color: Colors.white70),
                        label: Text(_uploading ? "Enviando..." : (_mascotUrl != null && _mascotUrl!.isNotEmpty ? "Trocar arquivo" : "Escolher arquivo"), style: const TextStyle(color: Colors.white70)),
                      ),
                      if (_mascotUrl != null && _mascotUrl!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => setState(() => _mascotUrl = null),
                          child: const Text("Remover", style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ]),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ],
                    const SizedBox(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                        child: Text(_saving ? "Salvando..." : "Salvar"),
                      ),
                    ]),
                  ],
                ),
        ),
      ),
    );
  }
}
