import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../notify/notify_dialog.dart";

class _StreamerActivity {
  final String id;
  final String displayName;
  final String? tiktokId;
  final DateTime? lastLiveAt;
  final int? daysSince;
  final int daysLive;
  final double hoursLive;
  final int diamonds;

  _StreamerActivity({
    required this.id,
    required this.displayName,
    required this.tiktokId,
    required this.lastLiveAt,
    required this.daysSince,
    required this.daysLive,
    required this.hoursLive,
    required this.diamonds,
  });
}

class ProgressoStreamersPage extends StatefulWidget {
  const ProgressoStreamersPage({super.key});

  @override
  State<ProgressoStreamersPage> createState() => _ProgressoStreamersPageState();
}

class _ProgressoStreamersPageState extends State<ProgressoStreamersPage> {
  late Future<List<_StreamerActivity>> _future;
  String _tab = "3";
  bool _ascending = false;
  String _sortKey = "diamonds";

  static const _tabs = [
    ("3", "Inativos ate 3 dias", "Streamers de 1 a 3 dias sem live.", Colors.orangeAccent),
    ("7", "Inativos ate 7 dias", "Streamers de 4 a 7 dias sem live.", Colors.yellowAccent),
    ("15", "Inativos 15 dias", "Streamers de 8 a 15 dias sem live.", Colors.deepOrangeAccent),
    ("15+", "Inativos 15 dias +", "Streamers de 16 a 30 dias sem live.", Colors.redAccent),
    ("30+", "Inativos", "Streamers ha mais de 30 dias sem live.", Colors.red),
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_StreamerActivity>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("profiles")
        .select("id, display_name, tiktok_creator_id, last_live_at, streamer_stats(days_live, hours_live, diamonds)")
        .eq("is_active", true);

    final now = DateTime.now().toUtc();
    return (rows as List).map((r) {
      final lastLiveText = r["last_live_at"] as String?;
      final lastLive = lastLiveText != null ? DateTime.parse(lastLiveText) : null;
      final days = lastLive != null ? now.difference(lastLive).inDays : null;

      final statsData = r["streamer_stats"];
      Map<String, dynamic>? stats;
      if (statsData is List && statsData.isNotEmpty) {
        stats = statsData.first as Map<String, dynamic>;
      } else if (statsData is Map) {
        stats = statsData as Map<String, dynamic>;
      }

      return _StreamerActivity(
        id: r["id"] as String,
        displayName: r["display_name"] as String,
        tiktokId: r["tiktok_creator_id"] as String?,
        lastLiveAt: lastLive,
        daysSince: days,
        daysLive: stats?["days_live"] as int? ?? 0,
        hoursLive: (stats?["hours_live"] as num?)?.toDouble() ?? 0,
        diamonds: stats?["diamonds"] as int? ?? 0,
      );
    }).toList();
  }

  List<_StreamerActivity> _filter(List<_StreamerActivity> all) {
    List<_StreamerActivity> result;
    switch (_tab) {
      case "3":
        result = all.where((s) => s.daysSince != null && s.daysSince! >= 1 && s.daysSince! <= 3).toList();
        break;
      case "7":
        result = all.where((s) => s.daysSince != null && s.daysSince! >= 4 && s.daysSince! <= 7).toList();
        break;
      case "15":
        result = all.where((s) => s.daysSince != null && s.daysSince! >= 8 && s.daysSince! <= 15).toList();
        break;
      case "15+":
        result = all.where((s) => s.daysSince != null && s.daysSince! >= 16 && s.daysSince! <= 30).toList();
        break;
      case "30+":
        result = all.where((s) => s.daysSince != null && s.daysSince! > 30).toList();
        break;
      default:
        result = all;
    }
    return result;
  }

  int _compare(_StreamerActivity a, _StreamerActivity b) {
    int result;
    switch (_sortKey) {
      case "nick":
        result = a.displayName.compareTo(b.displayName);
        break;
      case "lastLive":
        result = (a.lastLiveAt ?? DateTime(1970)).compareTo(b.lastLiveAt ?? DateTime(1970));
        break;
      case "daysSince":
        result = (a.daysSince ?? -1).compareTo(b.daysSince ?? -1);
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
            Flexible(child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.white54, fontWeight: active ? FontWeight.bold : FontWeight.normal))),
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

  void _openProfile(_StreamerActivity s) {
    showDialog(context: context, builder: (context) => _StreamerProfileDialog(streamerId: s.id));
  }

  void _openNote(_StreamerActivity s) {
    showDialog(context: context, builder: (context) => _ContactLogDialog(streamerId: s.id, displayName: s.displayName, logContext: "atividade"));
  }

  void _notifyOne(_StreamerActivity s) {
    showDialog(context: context, builder: (context) => NotifyDialog(streamerIds: [s.id], targetLabel: s.displayName));
  }

  void _notifyAll(List<_StreamerActivity> list) {
    showDialog(
      context: context,
      builder: (context) => NotifyDialog(
        streamerIds: list.map((s) => s.id).toList(),
        targetLabel: "Todos desta aba (" + list.length.toString() + " streamers)",
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_StreamerActivity>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final filtered = _filter(snapshot.data!)..sort(_compare);
        final activeTab = _tabs.firstWhere((t) => t.$1 == _tab);

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text("Progressao Inatividade",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    tooltip: "Atualizar",
                    onPressed: () => setState(() => _future = _load()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: _tabs.map((t) {
                  final selected = t.$1 == _tab;
                  return ChoiceChip(
                    label: Text(t.$2, style: TextStyle(color: t.$4)),
                    selected: selected,
                    selectedColor: t.$4.withOpacity(0.25),
                    side: BorderSide(color: t.$4),
                    onSelected: (_) => setState(() => _tab = t.$1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              Text(activeTab.$3, style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(filtered.length.toString() + " streamers", style: const TextStyle(color: Colors.white54)),
                  const SizedBox(width: 12),
                  if (filtered.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _notifyAll(filtered),
                      icon: const Icon(Icons.notifications_active, size: 16, color: Colors.amber),
                      label: const Text("Notificar todos desta lista", style: TextStyle(color: Colors.amber, fontSize: 12)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amber)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white24))),
                child: Row(
                  children: [
                    const SizedBox(width: 44),
                    _sortHeader("Nick", "nick", flex: 3),
                    _sortHeader("Ultima LIVE", "lastLive", flex: 2),
                    _sortHeader("Dias sem Live", "daysSince", flex: 2),
                    _sortHeader("Dias", "dias", flex: 1),
                    _sortHeader("Horas", "horas", flex: 1),
                    _sortHeader("Diamantes", "diamonds", flex: 2),
                    const SizedBox(width: 190),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final s = filtered[index];
                    final lastLiveText = s.lastLiveAt != null
                        ? s.lastLiveAt!.toLocal().toString().substring(0, 16)
                        : "sem registro";
                    final daysSinceText = s.daysSince != null ? "ha " + s.daysSince.toString() + " dias" : "-";
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              const CircleAvatar(radius: 18, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white54, size: 18)),
                              const SizedBox(width: 8),
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
                              Expanded(flex: 2, child: Text(lastLiveText, style: const TextStyle(color: Colors.white70))),
                              Expanded(flex: 2, child: Text(daysSinceText, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))),
                              Expanded(flex: 1, child: Text(s.daysLive.toString(), style: const TextStyle(color: Colors.white70))),
                              Expanded(flex: 1, child: Text(s.hoursLive.toStringAsFixed(0), style: const TextStyle(color: Colors.white70))),
                              Expanded(flex: 2, child: Text(s.diamonds.toString(), style: const TextStyle(color: Colors.white))),
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
                                      icon: const Icon(Icons.notifications_active, size: 18, color: Colors.amber),
                                      tooltip: "Notificar",
                                      onPressed: () => _notifyOne(s),
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

class _StreamerProfileDialog extends StatefulWidget {
  final String streamerId;
  const _StreamerProfileDialog({required this.streamerId});

  @override
  State<_StreamerProfileDialog> createState() => _StreamerProfileDialogState();
}

class _StreamerProfileDialogState extends State<_StreamerProfileDialog> {
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
        .select("display_name, tiktok_username, tiktok_creator_id, joined_at, last_live_at, graduation_status, streamer_stats(days_live, hours_live, diamonds, battles)")
        .eq("id", widget.streamerId)
        .single();
    return profile;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
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
              final p = snapshot.data!;
              final statsData = p["streamer_stats"];
              Map<String, dynamic>? stats;
              if (statsData is List && statsData.isNotEmpty) {
                stats = statsData.first as Map<String, dynamic>;
              } else if (statsData is Map) {
                stats = statsData as Map<String, dynamic>;
              }

              Widget row(String label, String value) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Colors.white54))),
                        Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
                      ],
                    ),
                  );

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p["display_name"] as String, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  row("ID TikTok", (p["tiktok_creator_id"] as String?) ?? "-"),
                  row("Nick TikTok", (p["tiktok_username"] as String?) ?? "-"),
                  row("Entrada na agencia", DateTime.parse(p["joined_at"] as String).toLocal().toString().substring(0, 16)),
                  row("Ultima LIVE", p["last_live_at"] != null ? DateTime.parse(p["last_live_at"] as String).toLocal().toString().substring(0, 16) : "sem registro"),
                  row("Dias validos (mes)", (stats?["days_live"] ?? 0).toString()),
                  row("Horas validas (mes)", ((stats?["hours_live"] as num?)?.toStringAsFixed(0) ?? "0")),
                  row("Diamantes (mes)", (stats?["diamonds"] ?? 0).toString()),
                  row("Batalhas (mes)", (stats?["battles"] ?? 0).toString()),
                  row("Status graduacao", (p["graduation_status"] as String?) ?? "-"),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar")),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ContactLogDialog extends StatefulWidget {
  final String streamerId;
  final String displayName;
  final String logContext;

  const _ContactLogDialog({required this.streamerId, required this.displayName, required this.logContext});

  @override
  State<_ContactLogDialog> createState() => _ContactLogDialogState();
}

class _ContactLogDialogState extends State<_ContactLogDialog> {
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
        .eq("context", widget.logContext)
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
      "context": widget.logContext,
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
              Text("Historico - " + widget.displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                "Anote a ultima conversa ou o que foi feito de tentativa para recuperar esse streamer.",
                style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
              ),
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
