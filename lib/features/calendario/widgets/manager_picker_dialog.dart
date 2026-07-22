import "package:flutter/material.dart";
import "../calendar_colors.dart";
import "../services/calendar_service.dart";

/// Retorna a lista de gestores selecionados (pode ser mais de um).
class ManagerPickerDialog extends StatefulWidget {
  const ManagerPickerDialog({super.key});

  @override
  State<ManagerPickerDialog> createState() => _ManagerPickerDialogState();
}

class _ManagerPickerDialogState extends State<ManagerPickerDialog> {
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
    final rows = await _service.fetchManagerOptions(search: _search);
    if (mounted) {
      setState(() {
        _options = rows;
        _loading = false;
      });
    }
  }

  void _confirm() {
    final selected = _options.where((m) => _selectedIds.contains(m["id"])).toList();
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
              const Text("Selecionar gestor(es)", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.white54), hintText: "Pesquisar gestor", hintStyle: TextStyle(color: Colors.white38), isDense: true),
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
                        ? const Center(child: Text("Nenhum gestor encontrado.", style: TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            itemCount: _options.length,
                            itemBuilder: (context, index) {
                              final m = _options[index];
                              final id = m["id"] as String;
                              final photoUrl = m["photo_url"] as String?;
                              final selected = _selectedIds.contains(id);
                              return CheckboxListTile(
                                value: selected,
                                onChanged: (_) => setState(() => selected ? _selectedIds.remove(id) : _selectedIds.add(id)),
                                controlAffinity: ListTileControlAffinity.leading,
                                activeColor: const Color(0xFF7A0BD4),
                                secondary: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white24,
                                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                  onBackgroundImageError: photoUrl != null && photoUrl.isNotEmpty ? (_, __) {} : null,
                                  child: photoUrl == null || photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white70, size: 18) : null,
                                ),
                                title: Text(managerDisplayName(m), style: const TextStyle(color: Colors.white, fontSize: 13)),
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
