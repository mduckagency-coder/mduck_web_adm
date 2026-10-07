import "package:flutter/material.dart";
import "max_estados_service.dart";
import "models/max_state.dart";
import "models/max_state_media.dart";
import "models/max_state_message.dart";
import "widgets/max_media_form_dialog.dart";
import "widgets/max_message_form_dialog.dart";
import "widgets/max_video_preview.dart";

class MaxEstadoDetailPage extends StatefulWidget {
  final MaxStateKey stateKey;

  const MaxEstadoDetailPage({super.key, required this.stateKey});

  @override
  State<MaxEstadoDetailPage> createState() => _MaxEstadoDetailPageState();
}

class _MaxEstadoDetailPageState extends State<MaxEstadoDetailPage> {
  final _service = MaxEstadosService();
  MaxStateMedia? _media;
  List<MaxStateMessage> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final media = await _service.fetchMedia(widget.stateKey);
    final messages = await _service.fetchMessages(widget.stateKey);
    if (mounted) {
      setState(() {
        _media = media;
        _messages = messages;
        _loading = false;
      });
    }
  }

  Future<void> _openMediaForm() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => MaxMediaFormDialog(stateKey: widget.stateKey, existing: _media),
    );
    if (saved == true) _load();
  }

  Future<void> _openMessageForm({MaxStateMessage? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => MaxMessageFormDialog(stateKey: widget.stateKey, existing: existing),
    );
    if (saved == true) _load();
  }

  Widget _contentPreview() {
    if (_media == null) {
      return Container(
        color: Colors.white12,
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.pets, color: Colors.white38, size: 48),
            SizedBox(height: 8),
            Text("Nenhum conteúdo cadastrado ainda.", style: TextStyle(color: Colors.white54, fontSize: 13)),
          ]),
        ),
      );
    }
    if (_media!.mediaType == MaxMediaType.image) {
      return Image.network(_service.publicUrlFor(_media!.storagePath), fit: BoxFit.cover);
    }
    return Container(
      color: Colors.black,
      child: MaxVideoPreview(key: ValueKey(_media!.storagePath), url: _service.publicUrlFor(_media!.storagePath)),
    );
  }

  Widget _messageTile(MaxStateMessage message) {
    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          Expanded(
            child: Text(
              '"' + message.message + '"',
              style: TextStyle(color: message.isActive ? Colors.white : Colors.white38, fontSize: 14),
            ),
          ),
          Switch(
            value: message.isActive,
            activeThumbColor: const Color(0xFF7A0BD4),
            onChanged: (v) async {
              await _service.setMessageActive(message.id, v);
              _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 20),
            onPressed: () => _openMessageForm(existing: message),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            onPressed: () async {
              await _service.deleteMessage(message.id);
              _load();
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(maxStateKeyLabel(widget.stateKey)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(maxStateKeyDescription(widget.stateKey), style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 16),
                    const Text("Conteúdo do Max", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(aspectRatio: 16 / 9, child: _contentPreview()),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      if (_media == null)
                        const Text("Nenhum conteúdo", style: TextStyle(color: Colors.white70, fontSize: 13))
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(6)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_media!.mediaType == MaxMediaType.image ? Icons.image : Icons.videocam, size: 14, color: Colors.white70),
                            const SizedBox(width: 6),
                            Text(
                              _media!.mediaType == MaxMediaType.image ? "Conteúdo atual: Imagem" : "Conteúdo atual: Vídeo",
                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ]),
                        ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _openMediaForm,
                        icon: const Icon(Icons.upload, size: 16),
                        label: Text(_media == null ? "Adicionar conteúdo" : "Substituir conteúdo"),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                      ),
                    ]),
                    const SizedBox(height: 28),
                    Row(children: [
                      const Text("Mensagens", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _openMessageForm(),
                        icon: const Icon(Icons.add, size: 18, color: Color(0xFF7A0BD4)),
                        label: const Text("Nova mensagem", style: TextStyle(color: Color(0xFF7A0BD4))),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    if (_messages.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text("Nenhuma mensagem cadastrada ainda.", style: TextStyle(color: Colors.white54)),
                      )
                    else
                      ..._messages.map(_messageTile),
                  ],
                ),
              ),
            ),
    );
  }
}
