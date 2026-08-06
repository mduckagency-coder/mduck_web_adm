import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "streamer_managers_service.dart";

/// Selecionar/desmarcar co-gestores de um streamer -- versao generalizada
/// (por streamerId) do _ManagerPickerDialog do Onboard 15 Dias
/// (onboarding_phase_kanban_page.dart), que so funciona por progressId de
/// um card de onboarding.
class StreamerManagerPickerDialog extends StatefulWidget {
  final String streamerId;
  final List<Map<String, dynamic>> agencyManagers;
  final VoidCallback? onChanged;

  const StreamerManagerPickerDialog({
    super.key,
    required this.streamerId,
    required this.agencyManagers,
    this.onChanged,
  });

  @override
  State<StreamerManagerPickerDialog> createState() =>
      _StreamerManagerPickerDialogState();
}

class _StreamerManagerPickerDialogState
    extends State<StreamerManagerPickerDialog> {
  String _search = "";
  Set<String> _selectedIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ids = await fetchStreamerManagerIds(widget.streamerId);
    if (mounted) setState(() {
      _selectedIds = ids;
      _loading = false;
    });
  }

  Future<void> _toggle(String managerId, bool addNow) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    setState(() {
      if (addNow) {
        _selectedIds.add(managerId);
      } else {
        _selectedIds.remove(managerId);
      }
    });
    if (addNow) {
      await addStreamerManager(
        streamerId: widget.streamerId,
        managerId: managerId,
        addedBy: userId,
      );
    } else {
      await removeStreamerManager(
        streamerId: widget.streamerId,
        managerId: managerId,
      );
    }
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.agencyManagers
        .where(
          (m) => (m["login_email"] as String).toLowerCase().contains(
            _search.toLowerCase(),
          ),
        )
        .toList();
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Gestores responsáveis",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, color: Colors.white54),
                        hintText: "Buscar gestor",
                        hintStyle: TextStyle(color: Colors.white38),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                "Nenhum gestor encontrado.",
                                style: TextStyle(color: Colors.white54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final m = filtered[index];
                                final id = m["id"] as String;
                                final checked = _selectedIds.contains(id);
                                return CheckboxListTile(
                                  value: checked,
                                  onChanged: (v) => _toggle(id, v == true),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  activeColor: const Color(0xFF7A0BD4),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    m["login_email"] as String,
                                    style: TextStyle(
                                      color: checked
                                          ? Colors.white
                                          : Colors.white54,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("Fechar"),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
