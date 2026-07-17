import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class _Assignment {
  final String streamerId;
  final String missionId;
  final String displayName;
  final String? tiktokId;
  final String? categoryName;
  final String? groupName;
  final String missionTitle;
  final String? missionCategory;
  final DateTime completedAt;
  final DateTime? deadline;
  final String paymentStatus;

  _Assignment({
    required this.streamerId,
    required this.missionId,
    required this.displayName,
    required this.tiktokId,
    required this.categoryName,
    required this.groupName,
    required this.missionTitle,
    required this.missionCategory,
    required this.completedAt,
    required this.deadline,
    required this.paymentStatus,
  });

  (String, Color) get statusInfo {
    if (paymentStatus == "pago") return ("Pago", Colors.greenAccent);
    if (deadline != null && DateTime.now().isAfter(deadline!)) return ("Atrasado", Colors.redAccent);
    return ("Pendente", Colors.amber);
  }
}

class MissoesAtividadesPage extends StatefulWidget {
  const MissoesAtividadesPage({super.key});

  @override
  State<MissoesAtividadesPage> createState() => _MissoesAtividadesPageState();
}

class _MissoesAtividadesPageState extends State<MissoesAtividadesPage> {
  late Future<List<_Assignment>> _future;
  String _monthFilter = "este";
  String? _categoryFilter;
  String? _groupFilter;
  String? _missionFilter;
  String _statusFilter = "todos";
  String _sortKey = "status";
  bool _ascending = true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_Assignment>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("streamer_missions")
        .select(
            "streamer_id, mission_id, completed_at, payment_status, payment_deadline, profiles(display_name, tiktok_creator_id, streamer_categories(name), groups!profiles_group_id_fkey(name)), missions(title, category)")
        .not("completed_at", "is", null);

    return (rows as List).map((r) {
      final profile = r["profiles"];
      final mission = r["missions"];
      final catData = profile is Map ? profile["streamer_categories"] : null;
      final groupData = profile is Map ? profile["groups"] : null;
      return _Assignment(
        streamerId: r["streamer_id"] as String,
        missionId: r["mission_id"] as String,
        displayName: profile is Map ? (profile["display_name"] as String? ?? "-") : "-",
        tiktokId: profile is Map ? profile["tiktok_creator_id"] as String? : null,
        categoryName: catData is Map ? catData["name"] as String? : null,
        groupName: groupData is Map ? groupData["name"] as String? : null,
        missionTitle: mission is Map ? (mission["title"] as String? ?? "-") : "-",
        missionCategory: mission is Map ? mission["category"] as String? : null,
        completedAt: DateTime.parse(r["completed_at"] as String),
        deadline: r["payment_deadline"] != null ? DateTime.parse(r["payment_deadline"]) : null,
        paymentStatus: r["payment_status"] as String? ?? "pendente",
      );
    }).toList();
  }

  List<_Assignment> _filterAndSort(List<_Assignment> all) {
    var list = all.where((a) {
      final now = DateTime.now();
      if (_monthFilter == "este" && !(a.completedAt.year == now.year && a.completedAt.month == now.month)) return false;
      if (_monthFilter == "passado") {
        final lastMonth = DateTime(now.year, now.month - 1);
        if (!(a.completedAt.year == lastMonth.year && a.completedAt.month == lastMonth.month)) return false;
      }
      if (_categoryFilter != null && a.categoryName != _categoryFilter) return false;
      if (_groupFilter != null && a.groupName != _groupFilter) return false;
      if (_missionFilter != null && a.missionTitle != _missionFilter) return false;
      if (_statusFilter != "todos" && a.statusInfo.$1.toLowerCase() != _statusFilter) return false;
      return true;
    }).toList();

    int statusOrder(_Assignment a) => a.statusInfo.$1 == "Atrasado" ? 0 : a.statusInfo.$1 == "Pendente" ? 1 : 2;

    list.sort((a, b) {
      int result;
      switch (_sortKey) {
        case "nick":
          result = a.displayName.compareTo(b.displayName);
          break;
        case "missao":
          result = a.missionTitle.compareTo(b.missionTitle);
          break;
        case "prazo":
          result = (a.deadline ?? DateTime(2100)).compareTo(b.deadline ?? DateTime(2100));
          break;
        default:
          result = statusOrder(a).compareTo(statusOrder(b));
      }
      return _ascending ? result : -result;
    });
    return list;
  }

  void _openManage(_Assignment a) {
    showDialog(context: context, builder: (context) => _ManagePaymentDialog(assignment: a)).then((changed) {
      if (changed == true) setState(() => _future = _load());
    });
  }

  Widget _sortHeader(String label, String key, {int flex = 1}) {
    final active = _sortKey == key;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => setState(() {
          if (_sortKey == key) {
            _ascending = !_ascending;
          } else {
            _sortKey = key;
            _ascending = true;
          }
        }),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: active ? Colors.white : Colors.white54, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
            const SizedBox(width: 2),
            Icon(active ? (_ascending ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more, size: 14, color: active ? Colors.white : Colors.white24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_Assignment>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final all = snapshot.data!;
        final categories = all.map((a) => a.categoryName).whereType<String>().toSet().toList()..sort();
        final groups = all.map((a) => a.groupName).whereType<String>().toSet().toList()..sort();
        final missions = all.map((a) => a.missionTitle).toSet().toList()..sort();
        final filtered = _filterAndSort(all);

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text("Missoes Atividades", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 12),
                  IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
                ],
              ),
              const SizedBox(height: 4),
              const Text("Missoes ja concluidas pelos streamers - prazo padrao de 10 dias para pagamento.", style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ("este", "Este mes"),
                  ("passado", "Mes passado"),
                  ("todos", "Todos"),
                ].map((m) {
                  final selected = _monthFilter == m.$1;
                  return ChoiceChip(
                    label: Text(m.$2),
                    selected: selected,
                    selectedColor: const Color(0xFF7A0BD4),
                    labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
                    onSelected: (_) => setState(() => _monthFilter = m.$1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<String?>(
                    value: _categoryFilter,
                    hint: const Text("Categoria", style: TextStyle(color: Colors.white54)),
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(color: Colors.white),
                    items: [const DropdownMenuItem<String?>(value: null, child: Text("Todas categorias")), ...categories.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c)))],
                    onChanged: (v) => setState(() => _categoryFilter = v),
                  ),
                  DropdownButton<String?>(
                    value: _groupFilter,
                    hint: const Text("Grupo", style: TextStyle(color: Colors.white54)),
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(color: Colors.white),
                    items: [const DropdownMenuItem<String?>(value: null, child: Text("Todos os grupos")), ...groups.map((g) => DropdownMenuItem<String?>(value: g, child: Text(g)))],
                    onChanged: (v) => setState(() => _groupFilter = v),
                  ),
                  DropdownButton<String?>(
                    value: _missionFilter,
                    hint: const Text("Missao", style: TextStyle(color: Colors.white54)),
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(color: Colors.white),
                    items: [const DropdownMenuItem<String?>(value: null, child: Text("Todas missoes")), ...missions.map((m) => DropdownMenuItem<String?>(value: m, child: Text(m)))],
                    onChanged: (v) => setState(() => _missionFilter = v),
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      ("todos", "Todos", Colors.white70),
                      ("atrasado", "Atrasado", Colors.redAccent),
                      ("pendente", "Pendente", Colors.amber),
                      ("pago", "Pago", Colors.greenAccent),
                    ].map((s) {
                      final selected = _statusFilter == s.$1;
                      return ChoiceChip(
                        label: Text(s.$2, style: TextStyle(fontSize: 12, color: selected ? Colors.white : s.$3)),
                        selected: selected,
                        selectedColor: s.$3,
                        onSelected: (_) => setState(() => _statusFilter = s.$1),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(filtered.length.toString() + " registros", style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white24))),
                child: Row(
                  children: [
                    _sortHeader("Nick", "nick", flex: 3),
                    const Expanded(flex: 3, child: Text("Missao", style: TextStyle(color: Colors.white54))),
                    _sortHeader("Prazo", "prazo", flex: 2),
                    _sortHeader("Status", "status", flex: 2),
                    const SizedBox(width: 120),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final a = filtered[index];
                    final status = a.statusInfo;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    if (a.tiktokId != null) Text(a.tiktokId!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Expanded(flex: 3, child: Text(a.missionTitle, style: const TextStyle(color: Colors.white70))),
                              Expanded(flex: 2, child: Text(a.deadline != null ? a.deadline!.toLocal().toString().substring(0, 10) : "-", style: const TextStyle(color: Colors.white70))),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(border: Border.all(color: status.$2), borderRadius: BorderRadius.circular(6)),
                                  child: Text(status.$1, style: TextStyle(color: status.$2, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              SizedBox(
                                width: 120,
                                child: ElevatedButton(
                                  onPressed: () => _openManage(a),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 6)),
                                  child: const Text("Gerenciar", style: TextStyle(fontSize: 11)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: Colors.white12, height: 1),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ManagePaymentDialog extends StatefulWidget {
  final _Assignment assignment;
  const _ManagePaymentDialog({required this.assignment});

  @override
  State<_ManagePaymentDialog> createState() => _ManagePaymentDialogState();
}

class _ManagePaymentDialogState extends State<_ManagePaymentDialog> {
  late String _status;
  final _noteController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _notesFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.assignment.paymentStatus;
    _notesFuture = _loadNotes();
  }

  Future<List<Map<String, dynamic>>> _loadNotes() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("mission_payment_notes")
        .select()
        .eq("streamer_id", widget.assignment.streamerId)
        .eq("mission_id", widget.assignment.missionId)
        .order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    await client
        .from("streamer_missions")
        .update({"payment_status": _status})
        .eq("streamer_id", widget.assignment.streamerId)
        .eq("mission_id", widget.assignment.missionId);

    if (_noteController.text.trim().isNotEmpty) {
      await client.from("mission_payment_notes").insert({
        "streamer_id": widget.assignment.streamerId,
        "mission_id": widget.assignment.missionId,
        "note": _noteController.text.trim(),
        "manager_label": client.auth.currentUser!.email ?? "Gestor",
      });
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.assignment.displayName + " - " + widget.assignment.missionTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("Prazo: " + (widget.assignment.deadline != null ? widget.assignment.deadline!.toLocal().toString().substring(0, 10) : "-"),
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 16),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text("Pendente"),
                    selected: _status == "pendente",
                    selectedColor: Colors.amber,
                    labelStyle: TextStyle(color: _status == "pendente" ? Colors.black : Colors.white70),
                    onSelected: (_) => setState(() => _status = "pendente"),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text("Pago"),
                    selected: _status == "pago",
                    selectedColor: Colors.greenAccent,
                    labelStyle: TextStyle(color: _status == "pago" ? Colors.black : Colors.white70),
                    onSelected: (_) => setState(() => _status = "pago"),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text("Historico de anotacoes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _notesFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.isEmpty) return const Center(child: Text("Nenhuma anotacao ainda.", style: TextStyle(color: Colors.white54)));
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final n = snapshot.data![index];
                        final date = DateTime.parse(n["created_at"] as String).toLocal().toString().substring(0, 16);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((n["manager_label"] ?? "Gestor") + " - " + date, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              Text(n["note"] as String, style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Nova anotacao", labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                    child: Text(_saving ? "Salvando..." : "Salvar"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
