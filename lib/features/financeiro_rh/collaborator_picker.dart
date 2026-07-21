import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

/// Points a financial_entries row at exactly one person -- either a system
/// manager or an external (no-login) collaborator -- so payments can be
/// traced back to who received them.
class CollaboratorRef {
  final String? managerId;
  final String? externalCollaboratorId;
  final String label;
  const CollaboratorRef({this.managerId, this.externalCollaboratorId, required this.label});
}

Future<CollaboratorRef?> pickCollaborator(BuildContext context) {
  return showDialog<CollaboratorRef>(context: context, builder: (context) => const _CollaboratorPickerDialog());
}

class _CollaboratorPickerDialog extends StatefulWidget {
  const _CollaboratorPickerDialog();

  @override
  State<_CollaboratorPickerDialog> createState() => _CollaboratorPickerDialogState();
}

class _CollaboratorPickerDialogState extends State<_CollaboratorPickerDialog> {
  String _search = "";
  late Future<List<CollaboratorRef>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CollaboratorRef>> _load() async {
    final client = Supabase.instance.client;
    final managers = await client.from("managers").select("id, login_email, full_name").order("login_email");
    final externals = await client.from("external_collaborators").select("id, full_name").order("full_name");
    return [
      ...(managers as List).map((m) => CollaboratorRef(managerId: m["id"] as String, label: (m["full_name"] as String?)?.isNotEmpty == true ? m["full_name"] as String : m["login_email"] as String)),
      ...(externals as List).map((e) => CollaboratorRef(externalCollaboratorId: e["id"] as String, label: (e["full_name"] as String) + " (externo)")),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Selecionar colaborador", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.white54), hintText: "Buscar por nome", hintStyle: TextStyle(color: Colors.white38), isDense: true),
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: FutureBuilder<List<CollaboratorRef>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                    final list = snapshot.data!.where((c) => _search.isEmpty || c.label.toLowerCase().contains(_search.toLowerCase())).toList();
                    if (list.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text("Ninguem encontrado.", style: TextStyle(color: Colors.white54)));
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final c = list[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(c.externalCollaboratorId != null ? Icons.person_outline : Icons.badge_outlined, color: Colors.white54, size: 18),
                          title: Text(c.label, style: const TextStyle(color: Colors.white)),
                          onTap: () => Navigator.of(context).pop(c),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar"))),
            ],
          ),
        ),
      ),
    );
  }
}
