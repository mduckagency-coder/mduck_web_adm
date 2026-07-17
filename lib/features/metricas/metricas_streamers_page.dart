import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../whatsapp/whatsapp_dialog.dart";

class _StreamerMetric {
  final String id;
  final String displayName;
  final String? tiktokId;
  final String? phone;
  final int diamonds;
  final int daysLive;
  final double hoursLive;
  final DateTime joinedAt;

  _StreamerMetric({
    required this.id,
    required this.displayName,
    required this.tiktokId,
    required this.phone,
    required this.diamonds,
    required this.daysLive,
    required this.hoursLive,
    required this.joinedAt,
  });
}

class MetricasStreamersPage extends StatefulWidget {
  const MetricasStreamersPage({super.key});

  @override
  State<MetricasStreamersPage> createState() => _MetricasStreamersPageState();
}

class _MetricasStreamersPageState extends State<MetricasStreamersPage> {
  late Future<List<_StreamerMetric>> _future;
  String _selectedTab = "Novatos";
  bool _ascending = false;
  String _sortKey = "diamonds";
  bool _pastMonth = false;

  static const _tabs = [
    "Novatos",
    "Streamers 10k",
    "Streamers 20k",
    "Streamers 40k",
    "Streamers 79k",
    "Top Duckers",
    "Elite",
  ];

  static const _tabRules = {
    "Novatos": "Streamers com ate 3 meses (90 dias) de agencia.",
    "Streamers 10k": "Diamantes: ate 10.000.",
    "Streamers 20k": "Diamantes: de 10.001 ate 20.000.",
    "Streamers 40k": "Diamantes: de 20.001 ate 40.000.",
    "Streamers 79k": "Diamantes: de 40.001 ate 79.000.",
    "Top Duckers": "Diamantes: de 80.000 ate 149.999.",
    "Elite": "Diamantes: acima de 250.000.",
  };

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_StreamerMetric>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("profiles")
        .select("id, display_name, tiktok_creator_id, phone, joined_at, streamer_stats(diamonds, days_live, hours_live)")
        .eq("is_active", true);

    Map<String, Map<String, dynamic>> pastMonthMap = {};
    if (_pastMonth) {
      final monthlyRows = await client
          .from("monthly_stats")
          .select("streamer_id, period_key, diamonds, days_live, hours_live")
          .order("period_key", ascending: false);
      for (final row in (monthlyRows as List)) {
        final sid = row["streamer_id"] as String;
        if (!pastMonthMap.containsKey(sid)) {
          pastMonthMap[sid] = row as Map<String, dynamic>;
        }
      }
    }

    return (rows as List).map((r) {
      final id = r["id"] as String;
      int diamonds = 0;
      int daysLive = 0;
      double hoursLive = 0;

      if (_pastMonth) {
        final past = pastMonthMap[id];
        diamonds = past?["diamonds"] as int? ?? 0;
        daysLive = past?["days_live"] as int? ?? 0;
        hoursLive = (past?["hours_live"] as num?)?.toDouble() ?? 0;
      } else {
        final statsData = r["streamer_stats"];
        Map<String, dynamic>? stats;
        if (statsData is List && statsData.isNotEmpty) {
          stats = statsData.first as Map<String, dynamic>;
        } else if (statsData is Map) {
          stats = statsData as Map<String, dynamic>;
        }
        if (stats != null) {
          diamonds = stats["diamonds"] as int? ?? 0;
          daysLive = stats["days_live"] as int? ?? 0;
          hoursLive = (stats["hours_live"] as num?)?.toDouble() ?? 0;
        }
      }

      return _StreamerMetric(
        id: id,
        displayName: r["display_name"] as String,
        tiktokId: r["tiktok_creator_id"] as String?,
        phone: r["phone"] as String?,
        diamonds: diamonds,
        daysLive: daysLive,
        hoursLive: hoursLive,
        joinedAt: DateTime.parse(r["joined_at"] as String),
      );
    }).toList();
  }

  List<_StreamerMetric> _filter(List<_StreamerMetric> all) {
    final now = DateTime.now();
    switch (_selectedTab) {
      case "Novatos":
        return all.where((s) => now.difference(s.joinedAt).inDays <= 90).toList();
      case "Streamers 10k":
        return all.where((s) => s.diamonds <= 10000).toList();
      case "Streamers 20k":
        return all.where((s) => s.diamonds > 10000 && s.diamonds <= 20000).toList();
      case "Streamers 40k":
        return all.where((s) => s.diamonds > 20000 && s.diamonds <= 40000).toList();
      case "Streamers 79k":
        return all.where((s) => s.diamonds > 40000 && s.diamonds <= 79000).toList();
      case "Top Duckers":
        return all.where((s) => s.diamonds >= 80000 && s.diamonds < 150000).toList();
      case "Elite":
        return all.where((s) => s.diamonds > 250000).toList();
      default:
        return all;
    }
  }

  int _compare(_StreamerMetric a, _StreamerMetric b) {
    int result;
    switch (_sortKey) {
      case "nick":
        result = a.displayName.compareTo(b.displayName);
        break;
      case "dias":
        result = a.daysLive.compareTo(b.daysLive);
        break;
      case "horas":
        result = a.hoursLive.compareTo(b.hoursLive);
        break;
      default:
        result = a.diamonds.compareTo(b.diamonds);
    }
    return _ascending ? result : -result;
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
            _ascending = false;
          }
        }),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: active ? Colors.white : Colors.white54, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
            const SizedBox(width: 2),
            Icon(
              active ? (_ascending ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more,
              size: 14,
              color: active ? Colors.white : Colors.white24,
            ),
          ],
        ),
      ),
    );
  }

  void _togglePastMonth() {
    setState(() {
      _pastMonth = !_pastMonth;
      _future = _load();
    });
  }

  void _openProfile(_StreamerMetric s) {
    showDialog(context: context, builder: (context) => _MetricStreamerProfileDialog(streamerId: s.id));
  }

  void _openNote(_StreamerMetric s) {
    showDialog(context: context, builder: (context) => _MetricsContactLogDialog(streamerId: s.id, displayName: s.displayName));
  }

  void _openWhatsAppOne(_StreamerMetric s) {
    showDialog(
      context: context,
      builder: (context) => WhatsAppDialog(
        targets: [WhatsAppTarget(id: s.id, displayName: s.displayName, phone: s.phone)],
        targetLabel: s.displayName,
      ),
    );
  }

  void _openWhatsAppAll(List<_StreamerMetric> list) {
    showDialog(
      context: context,
      builder: (context) => WhatsAppDialog(
        targets: list.map((s) => WhatsAppTarget(id: s.id, displayName: s.displayName, phone: s.phone)).toList(),
        targetLabel: "Todos desta aba (" + list.length.toString() + " streamers)",
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_StreamerMetric>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final filtered = _filter(snapshot.data!)..sort(_compare);

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text("Metricas Streamers",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    tooltip: "Atualizar",
                    onPressed: () => setState(() => _future = _load()),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _togglePastMonth,
                    icon: Icon(_pastMonth ? Icons.calendar_month : Icons.history, size: 16, color: _pastMonth ? Colors.amber : Colors.white70),
                    label: Text(_pastMonth ? "Vendo mes passado" : "Ver mes passado",
                        style: TextStyle(color: _pastMonth ? Colors.amber : Colors.white70)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: _pastMonth ? Colors.amber : Colors.white24)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: _tabs.map((tab) {
                  final selected = tab == _selectedTab;
                  return ChoiceChip(
                    label: Text(tab),
                    selected: selected,
                    selectedColor: const Color(0xFF7A0BD4),
                    labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
                    onSelected: (_) => setState(() => _selectedTab = tab),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(_tabRules[_selectedTab] ?? "", style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(filtered.length.toString() + " streamers" + (_pastMonth ? " (mes passado)" : ""), style: const TextStyle(color: Colors.white54)),
                  const SizedBox(width: 12),
                  if (filtered.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _openWhatsAppAll(filtered),
                      icon: const Icon(Icons.chat, size: 16, color: Color(0xFF25D366)),
                      label: const Text("WhatsApp para todos desta lista", style: TextStyle(color: Color(0xFF25D366), fontSize: 12)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF25D366))),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white24))),
                child: Row(
                  children: [
                    const SizedBox(width: 76),
                    _sortHeader("Nick", "nick", flex: 3),
                    _sortHeader("Diamantes", "diamonds", flex: 2),
                    _sortHeader("Dias", "dias", flex: 1),
                    _sortHeader("Horas", "horas", flex: 1),
                    const SizedBox(width: 190),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final s = filtered[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 76,
                                child: Row(
                                  children: [
                                    Text("#" + (index + 1).toString(), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                    const SizedBox(width: 6),
                                    const CircleAvatar(radius: 16, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white54, size: 16)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: InkWell(
                                  onTap: () => _openProfile(s),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      if (s.tiktokId != null)
                                        Text(s.tiktokId!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(flex: 2, child: Text(s.diamonds.toString(), style: const TextStyle(color: Color(0xFF7A0BD4), fontWeight: FontWeight.bold))),
                              Expanded(flex: 1, child: Text(s.daysLive.toString(), style: const TextStyle(color: Colors.white70))),
                              Expanded(flex: 1, child: Text(s.hoursLive.toStringAsFixed(0), style: const TextStyle(color: Colors.white70))),
                              SizedBox(
                                width: 190,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _openNote(s),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFB026FF),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                        ),
                                        child: const Text("Nota", style: TextStyle(fontSize: 11)),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.chat, size: 18, color: Color(0xFF25D366)),
                                      tooltip: "WhatsApp",
                                      onPressed: () => _openWhatsAppOne(s),
                                    ),
                                  ],
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

class _MetricStreamerProfileDialog extends StatefulWidget {
  final String streamerId;
  const _MetricStreamerProfileDialog({required this.streamerId});

  @override
  State<_MetricStreamerProfileDialog> createState() => _MetricStreamerProfileDialogState();
}

class _MetricStreamerProfileDialogState extends State<_MetricStreamerProfileDialog> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final profile = await client
        .from("profiles")
        .select("display_name, tiktok_username, tiktok_creator_id, joined_at, graduation_status, groups!profiles_group_id_fkey(name)")
        .eq("id", widget.streamerId)
        .single();
    final monthly = await client
        .from("monthly_stats")
        .select("period_key, diamonds, days_live, hours_live")
        .eq("streamer_id", widget.streamerId)
        .order("period_key", ascending: true)
        .limit(3);
    return {"profile": profile, "monthly": monthly};
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SizedBox(
                  height: 150,
                  child: Center(child: Text("Erro: " + snapshot.error.toString(), style: const TextStyle(color: Colors.redAccent))),
                );
              }
              if (!snapshot.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
              final p = snapshot.data!["profile"] as Map<String, dynamic>;
              final monthly = (snapshot.data!["monthly"] as List).cast<Map<String, dynamic>>();
              final joinedAt = DateTime.parse(p["joined_at"] as String);
              final deadline = joinedAt.add(const Duration(days: 90));
              final groupData = p["groups"];
              final groupName = groupData is Map ? groupData["name"] as String? : null;

              Widget row(String label, String value) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(width: 170, child: Text(label, style: const TextStyle(color: Colors.white54))),
                        Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
                      ],
                    ),
                  );

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p["display_name"] as String, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    row("Grupo", groupName ?? "Sem grupo"),
                    row("Entrada na agencia", joinedAt.toLocal().toString().substring(0, 16)),
                    row("Fim dos 3 meses (novato)", deadline.toLocal().toString().substring(0, 10)),
                    row("Status graduacao", (p["graduation_status"] as String?) ?? "-"),
                    const SizedBox(height: 16),
                    const Text("Historico mensal", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (monthly.isEmpty)
                      const Text("Nenhum mes fechado ainda.", style: TextStyle(color: Colors.white54))
                    else
                      for (var i = 0; i < monthly.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            (i + 1).toString() + "o mes (" + monthly[i]["period_key"].toString() + "): " +
                                monthly[i]["days_live"].toString() + " dias, " +
                                (monthly[i]["hours_live"] as num).toStringAsFixed(0) + "h, " +
                                monthly[i]["diamonds"].toString() + " diamantes",
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => _MetricsContactLogDialog(streamerId: widget.streamerId, displayName: p["display_name"] as String),
                            );
                          },
                          child: const Text("Adicionar Nota"),
                        ),
                        const SizedBox(width: 8),
                        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar")),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MetricsContactLogDialog extends StatefulWidget {
  final String streamerId;
  final String displayName;

  const _MetricsContactLogDialog({required this.streamerId, required this.displayName});

  @override
  State<_MetricsContactLogDialog> createState() => _MetricsContactLogDialogState();
}

class _MetricsContactLogDialogState extends State<_MetricsContactLogDialog> {
  final _noteController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _logsFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _logsFuture = _loadLogs();
  }

  Future<List<Map<String, dynamic>>> _loadLogs() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("streamer_contact_logs")
        .select("message_sent, manager_label, created_at")
        .eq("streamer_id", widget.streamerId)
        .eq("context", "metricas")
        .order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _save() async {
    if (_noteController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    await client.from("streamer_contact_logs").insert({
      "streamer_id": widget.streamerId,
      "manager_id": client.auth.currentUser!.id,
      "manager_label": client.auth.currentUser!.email ?? "Gestor",
      "message_sent": _noteController.text.trim(),
      "context": "metricas",
    });
    _noteController.clear();
    setState(() {
      _saving = false;
      _logsFuture = _loadLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Notas - " + widget.displayName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _logsFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.isEmpty) {
                      return const Center(child: Text("Nenhum registro ainda.", style: TextStyle(color: Colors.white54)));
                    }
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final log = snapshot.data![index];
                        final date = DateTime.parse(log["created_at"] as String).toLocal().toString().substring(0, 16);
                        final managerLabel = (log["manager_label"] as String?) ?? "Gestor";
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(managerLabel + " - " + date, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text((log["message_sent"] as String?) ?? "", style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Adicione informacoes aqui", labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar")),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB026FF), foregroundColor: Colors.white),
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

