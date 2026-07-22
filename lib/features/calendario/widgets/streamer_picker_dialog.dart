import "package:flutter/material.dart";
import "../services/calendar_service.dart";

/// Retorna a lista de streamers selecionados (pode ser mais de um).
class StreamerPickerDialog extends StatefulWidget {
  const StreamerPickerDialog({super.key});

  @override
  State<StreamerPickerDialog> createState() => _StreamerPickerDialogState();
}

class _StreamerPickerDialogState extends State<StreamerPickerDialog> {
  final _service = CalendarService();
  List<Map<String, dynamic>> _options = [];
  final Set<String> _selectedIds = {};
  String _search = "";
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _service.fetchStreamerOptions(search: _search);
    if (mounted) {
      setState(() {
        _options = rows;
        _loading = false;
      });
    }
  }

  void _confirm() {
    final selected = _options.where((s) => _selectedIds.contains(s["id"])).toList();
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Selecionar streamer(s)", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.white54), hintText: "Pesquisar streamer", hintStyle: TextStyle(color: Colors.white38), isDense: true),
                onChanged: (v) {
                  _search = v;
                  _load();
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _options.isEmpty
                        ? const Center(child: Text("Nenhum streamer encontrado.", style: TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            itemCount: _options.length,
                            itemBuilder: (context, index) {
                              final s = _options[index];
                              final id = s["id"] as String;
                              final tiktokUsername = s["tiktok_username"] as String?;
                              final avatarUrl = s["avatar_url"] as String?;
                              final selected = _selectedIds.contains(id);
                              return CheckboxListTile(
                                value: selected,
                                onChanged: (_) => setState(() => selected ? _selectedIds.remove(id) : _selectedIds.add(id)),
                                controlAffinity: ListTileControlAffinity.leading,
                                activeColor: const Color(0xFF7A0BD4),
                                secondary: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white24,
                                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                  onBackgroundImageError: avatarUrl != null && avatarUrl.isNotEmpty ? (_, _) {} : null,
                                  child: avatarUrl == null || avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white70, size: 18) : null,
                                ),
                                title: Text(s["display_name"] as String? ?? "", style: const TextStyle(color: Colors.white, fontSize: 13)),
                                subtitle: Text(tiktokUsername != null ? "@" + tiktokUsername : "", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedIds.isEmpty ? null : _confirm,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: Text("Adicionar" + (_selectedIds.isEmpty ? "" : " (" + _selectedIds.length.toString() + ")")),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
