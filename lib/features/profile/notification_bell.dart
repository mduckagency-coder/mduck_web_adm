import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class NotificationBell extends StatefulWidget {
  final VoidCallback? onNotificationTap;
  const NotificationBell({super.key, this.onNotificationTap});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final rows = await client.from("manager_notifications").select().eq("manager_id", userId).order("created_at", ascending: false).limit(30);
    if (mounted) setState(() => _notifications = (rows as List).cast<Map<String, dynamic>>());
  }

  Future<void> _markRead(String id) async {
    final client = Supabase.instance.client;
    await client.from("manager_notifications").update({"read_at": DateTime.now().toIso8601String()}).eq("id", id);
    _load();
  }

  Future<void> _markAllRead() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    await client.from("manager_notifications").update({"read_at": DateTime.now().toIso8601String()}).eq("manager_id", userId).isFilter("read_at", null);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n["read_at"] == null).length;

    return PopupMenuButton<String>(
      tooltip: "Notificacoes",
      color: const Color(0xFF1A1A1A),
      constraints: const BoxConstraints(maxWidth: 340, maxHeight: 420),
      onOpened: _load,
      itemBuilder: (context) {
        if (_notifications.isEmpty) {
          return [const PopupMenuItem(enabled: false, child: Text("Nenhuma notificacao ainda.", style: TextStyle(color: Colors.white54)))];
        }
        return [
          PopupMenuItem(
            enabled: false,
            child: Row(children: [
              const Text("Notificacoes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (unreadCount > 0)
                TextButton(onPressed: () { _markAllRead(); Navigator.of(context).pop(); }, child: const Text("Marcar todas como lidas", style: TextStyle(fontSize: 11))),
            ]),
          ),
          const PopupMenuDivider(),
          ..._notifications.map((n) {
            final isUnread = n["read_at"] == null;
            final date = DateTime.parse(n["created_at"] as String).toLocal().toString().substring(0, 16);
            return PopupMenuItem(
              value: n["id"] as String,
              onTap: () {
                _markRead(n["id"] as String);
                widget.onNotificationTap?.call();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(border: Border(left: BorderSide(color: isUnread ? const Color(0xFF7A0BD4) : Colors.transparent, width: 3))),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n["message"] as String, style: TextStyle(color: isUnread ? Colors.white : Colors.white54, fontSize: 12, fontWeight: isUnread ? FontWeight.bold : FontWeight.normal)),
                      Text(date, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ];
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_outlined, color: Colors.white70, size: 24),
            if (unreadCount > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(unreadCount > 9 ? "9+" : unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

