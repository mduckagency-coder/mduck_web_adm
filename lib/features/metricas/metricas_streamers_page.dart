import "dart:html" as html;
import "package:excel/excel.dart" hide Border;
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../whatsapp/whatsapp_dialog.dart";
import "streamer_metrics_share_card.dart";

class _StreamerMetric {
  final String id;
  final String displayName;
  final String? tiktokId;
  final String? tiktokUsername;
  final String? phone;
  final String categoria;
  final int diamonds;
  final int daysLive;
  final double hoursLive;
  final DateTime joinedAt;

  _StreamerMetric({
    required this.id,
    required this.displayName,
    required this.tiktokId,
    required this.tiktokUsername,
    required this.phone,
    required this.categoria,
    required this.diamonds,
    required this.daysLive,
    required this.hoursLive,
    required this.joinedAt,
  });

  /// Usado pela busca -- compara nick, @ e id (tanto o numerico do TikTok
  /// quanto o id interno do cadastro), sem diferenciar maiusculas/minusculas.
  bool matchesSearch(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return displayName.toLowerCase().contains(q) ||
        (tiktokUsername?.toLowerCase().contains(q) ?? false) ||
        (tiktokId?.toLowerCase().contains(q) ?? false) ||
        id.toLowerCase().contains(q);
  }
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
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  final _searchController = TextEditingController();
  String _search = "";

  static const _tabs = [
    "15 dias",
    "Novatos",
    "0 a 5k",
    "Streamers 10k",
    "Streamers 20k",
    "Streamers 40k",
    "Streamers 79k",
    "Top Duckers",
    "Streamers 150k",
    "Elite",
  ];

  static const _tabRules = {
    "15 dias":
        "Streamers com ate 15 dias de agencia (a partir da data de entrada). Sai automaticamente ao completar 16 dias.",
    "Novatos": "Streamers com ate 3 meses (90 dias) de agencia.",
    "0 a 5k": "Diamantes no mes: de 0 ate 5.000.",
    "Streamers 10k": "Diamantes: de 5.001 ate 10.000.",
    "Streamers 20k": "Diamantes: de 10.001 ate 20.000.",
    "Streamers 40k": "Diamantes: de 20.001 ate 40.000.",
    "Streamers 79k": "Diamantes: de 40.001 ate 79.999.",
    "Top Duckers": "Diamantes: de 80.000 ate 149.999.",
    "Streamers 150k": "Diamantes: de 150.000 ate 249.999.",
    "Elite": "Diamantes: a partir de 250.000.",
  };

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<_StreamerMetric>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("profiles")
        .select(
          "id, display_name, tiktok_creator_id, tiktok_username, phone, joined_at, streamer_stats(diamonds, days_live, hours_live), streamer_categories(name)",
        )
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

      final catData = r["streamer_categories"];
      final categoria = catData is Map
          ? (catData["name"] as String? ?? "Sem categoria")
          : "Sem categoria";

      return _StreamerMetric(
        id: id,
        displayName: r["display_name"] as String,
        tiktokId: r["tiktok_creator_id"] as String?,
        tiktokUsername: r["tiktok_username"] as String?,
        phone: r["phone"] as String?,
        categoria: categoria,
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
      case "15 dias":
        return all
            .where((s) => now.difference(s.joinedAt).inDays <= 15)
            .toList();
      case "Novatos":
        return all
            .where((s) => now.difference(s.joinedAt).inDays <= 90)
            .toList();
      case "0 a 5k":
        return all.where((s) => s.diamonds >= 0 && s.diamonds <= 5000).toList();
      case "Streamers 10k":
        return all
            .where((s) => s.diamonds > 5000 && s.diamonds <= 10000)
            .toList();
      case "Streamers 20k":
        return all
            .where((s) => s.diamonds > 10000 && s.diamonds <= 20000)
            .toList();
      case "Streamers 40k":
        return all
            .where((s) => s.diamonds > 20000 && s.diamonds <= 40000)
            .toList();
      case "Streamers 79k":
        return all
            .where((s) => s.diamonds > 40000 && s.diamonds <= 79999)
            .toList();
      case "Top Duckers":
        return all
            .where((s) => s.diamonds >= 80000 && s.diamonds <= 149999)
            .toList();
      case "Streamers 150k":
        return all
            .where((s) => s.diamonds >= 150000 && s.diamonds <= 249999)
            .toList();
      case "Elite":
        return all.where((s) => s.diamonds >= 250000).toList();
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
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white54,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              active
                  ? (_ascending ? Icons.arrow_upward : Icons.arrow_downward)
                  : Icons.unfold_more,
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
    showDialog(
      context: context,
      builder: (context) => _MetricStreamerProfileDialog(
        streamerId: s.id,
        nick: s.displayName,
        categoria: s.categoria,
        diamonds: s.diamonds,
        daysLive: s.daysLive,
        hoursLive: s.hoursLive,
      ),
    );
  }

  void _openNote(_StreamerMetric s) {
    showDialog(
      context: context,
      builder: (context) => _MetricsContactLogDialog(
        streamerId: s.id,
        displayName: s.displayName,
      ),
    );
  }

  void _openWhatsAppOne(_StreamerMetric s) {
    showDialog(
      context: context,
      builder: (context) => WhatsAppDialog(
        targets: [
          WhatsAppTarget(id: s.id, displayName: s.displayName, phone: s.phone),
        ],
        targetLabel: s.displayName,
      ),
    );
  }

  void _openWhatsAppAll(List<_StreamerMetric> list) {
    showDialog(
      context: context,
      builder: (context) => WhatsAppDialog(
        targets: list
            .map(
              (s) => WhatsAppTarget(
                id: s.id,
                displayName: s.displayName,
                phone: s.phone,
              ),
            )
            .toList(),
        targetLabel:
            "Todos desta aba (" + list.length.toString() + " streamers)",
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelectAll(List<_StreamerMetric> list) {
    setState(() {
      if (_selectedIds.length == list.length && list.isNotEmpty) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(list.map((s) => s.id));
      }
    });
  }

  Future<void> _copySelected(List<_StreamerMetric> list) async {
    final selected = list.where((s) => _selectedIds.contains(s.id)).toList();
    if (selected.isEmpty) return;
    final buffer = StringBuffer();
    for (final s in selected) {
      buffer.writeln(
        s.displayName +
            (s.tiktokId != null ? " (" + s.tiktokId! + ")" : "") +
            " - Diamantes: " +
            s.diamonds.toString() +
            " - Dias: " +
            s.daysLive.toString() +
            " - Horas: " +
            s.hoursLive.toStringAsFixed(0),
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selected.length.toString() +
                " streamer(s) copiado(s) para a area de transferencia.",
          ),
        ),
      );
    }
  }

  void _exportSelected(List<_StreamerMetric> list) {
    final selected = list.where((s) => _selectedIds.contains(s.id)).toList();
    if (selected.isEmpty) return;

    final workbook = Excel.createExcel();
    final sheet = workbook["Streamers"];
    workbook.delete("Sheet1");

    sheet.appendRow([
      TextCellValue("Nick"),
      TextCellValue("TikTok ID"),
      TextCellValue("Telefone"),
      TextCellValue("Diamantes"),
      TextCellValue("Dias ao vivo"),
      TextCellValue("Horas ao vivo"),
      TextCellValue("Entrada na agencia"),
    ]);

    for (final s in selected) {
      sheet.appendRow([
        TextCellValue(s.displayName),
        TextCellValue(s.tiktokId ?? "-"),
        TextCellValue(s.phone ?? "-"),
        IntCellValue(s.diamonds),
        IntCellValue(s.daysLive),
        DoubleCellValue(s.hoursLive),
        TextCellValue(s.joinedAt.toLocal().toString().substring(0, 10)),
      ]);
    }

    final bytes = workbook.encode();
    if (bytes == null) return;

    final fileName = "streamers_" + _selectedTab.replaceAll(" ", "_") + ".xlsx";
    final blob = html.Blob([
      bytes,
    ], "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_StreamerMetric>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final filtered = _filter(snapshot.data!)
          ..retainWhere((s) => s.matchesSearch(_search))
          ..sort(_compare);

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    "Metricas Streamers",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    tooltip: "Atualizar",
                    onPressed: () => setState(() => _future = _load()),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _togglePastMonth,
                    icon: Icon(
                      _pastMonth ? Icons.calendar_month : Icons.history,
                      size: 16,
                      color: _pastMonth ? Colors.amber : Colors.white70,
                    ),
                    label: Text(
                      _pastMonth ? "Vendo mes passado" : "Ver mes passado",
                      style: TextStyle(
                        color: _pastMonth ? Colors.amber : Colors.white70,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _pastMonth ? Colors.amber : Colors.white24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _toggleSelectionMode,
                    icon: Icon(
                      _selectionMode ? Icons.close : Icons.checklist,
                      size: 16,
                      color: _selectionMode ? Colors.amber : Colors.white70,
                    ),
                    label: Text(
                      _selectionMode ? "Cancelar selecao" : "Selecionar",
                      style: TextStyle(
                        color: _selectionMode ? Colors.amber : Colors.white70,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _selectionMode ? Colors.amber : Colors.white24,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white54,
                      size: 18,
                    ),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white54,
                              size: 18,
                            ),
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _search = "";
                            }),
                          ),
                    hintText: "Pesquisar por nick, @ ou ID",
                    hintStyle: const TextStyle(color: Colors.white38),
                  ),
                  onChanged: (v) => setState(() => _search = v.trim()),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: _tabs.map((tab) {
                  final selected = tab == _selectedTab;
                  return ChoiceChip(
                    label: Text(tab),
                    selected: selected,
                    selectedColor: const Color(0xFF7A0BD4),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                    ),
                    onSelected: (_) => setState(() => _selectedTab = tab),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                _tabRules[_selectedTab] ?? "",
                style: const TextStyle(
                  color: Colors.white54,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    filtered.length.toString() +
                        " streamers" +
                        (_pastMonth ? " (mes passado)" : ""),
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(width: 12),
                  if (_selectionMode) ...[
                    InkWell(
                      onTap: () => _toggleSelectAll(filtered),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value:
                                filtered.isNotEmpty &&
                                _selectedIds.length == filtered.length,
                            onChanged: (_) => _toggleSelectAll(filtered),
                            activeColor: const Color(0xFF7A0BD4),
                          ),
                          Text(
                            "Selecionar todos (" +
                                _selectedIds.length.toString() +
                                ")",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _selectedIds.isEmpty
                          ? null
                          : () => _copySelected(filtered),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text(
                        "Copiar",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _selectedIds.isEmpty
                          ? null
                          : () => _exportSelected(filtered),
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text(
                        "Exportar",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ] else if (filtered.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _openWhatsAppAll(filtered),
                      icon: const Icon(
                        Icons.chat,
                        size: 16,
                        color: Color(0xFF25D366),
                      ),
                      label: const Text(
                        "WhatsApp para todos desta lista",
                        style: TextStyle(
                          color: Color(0xFF25D366),
                          fontSize: 12,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF25D366)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white24)),
                ),
                child: Row(
                  children: [
                    SizedBox(width: _selectionMode ? 108 : 76),
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
                                width: _selectionMode ? 108 : 76,
                                child: Row(
                                  children: [
                                    if (_selectionMode)
                                      Checkbox(
                                        value: _selectedIds.contains(s.id),
                                        activeColor: const Color(0xFF7A0BD4),
                                        onChanged: (checked) => setState(() {
                                          if (checked == true) {
                                            _selectedIds.add(s.id);
                                          } else {
                                            _selectedIds.remove(s.id);
                                          }
                                        }),
                                      )
                                    else
                                      Text(
                                        "#" + (index + 1).toString(),
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                    const SizedBox(width: 6),
                                    const CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.white24,
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.white54,
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: InkWell(
                                  onTap: () => _openProfile(s),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.displayName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (s.tiktokId != null)
                                        Text(
                                          s.tiktokId!,
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  s.diamonds.toString(),
                                  style: const TextStyle(
                                    color: Color(0xFF7A0BD4),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  s.daysLive.toString(),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  s.hoursLive.toStringAsFixed(0),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                              SizedBox(
                                width: 190,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _openNote(s),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFB026FF,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                          ),
                                        ),
                                        child: const Text(
                                          "Nota",
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.chat,
                                        size: 18,
                                        color: Color(0xFF25D366),
                                      ),
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
  final String nick;
  final String categoria;
  final int diamonds;
  final int daysLive;
  final double hoursLive;

  const _MetricStreamerProfileDialog({
    required this.streamerId,
    required this.nick,
    required this.categoria,
    required this.diamonds,
    required this.daysLive,
    required this.hoursLive,
  });

  @override
  State<_MetricStreamerProfileDialog> createState() =>
      _MetricStreamerProfileDialogState();
}

class _MetricStreamerProfileDialogState
    extends State<_MetricStreamerProfileDialog> {
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
        .select(
          "display_name, tiktok_username, tiktok_creator_id, joined_at, graduation_status, groups!profiles_group_id_fkey(name)",
        )
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
                  child: Center(
                    child: Text(
                      "Erro: " + snapshot.error.toString(),
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData)
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              final p = snapshot.data!["profile"] as Map<String, dynamic>;
              final monthly = (snapshot.data!["monthly"] as List)
                  .cast<Map<String, dynamic>>();
              final joinedAt = DateTime.parse(p["joined_at"] as String);
              final deadline = joinedAt.add(const Duration(days: 90));
              final groupData = p["groups"];
              final groupName = groupData is Map
                  ? groupData["name"] as String?
                  : null;

              Widget row(String label, String value) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 170,
                      child: Text(
                        label,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p["display_name"] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamerMetricsShareCard(
                      nick: widget.nick,
                      categoria: widget.categoria,
                      diamonds: widget.diamonds,
                      daysLive: widget.daysLive,
                      hoursLive: widget.hoursLive,
                    ),
                    const SizedBox(height: 16),
                    row("Grupo", groupName ?? "Sem grupo"),
                    row(
                      "Entrada na agencia",
                      joinedAt.toLocal().toString().substring(0, 16),
                    ),
                    row(
                      "Fim dos 3 meses (novato)",
                      deadline.toLocal().toString().substring(0, 10),
                    ),
                    row(
                      "Status graduacao",
                      (p["graduation_status"] as String?) ?? "-",
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Historico mensal",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (monthly.isEmpty)
                      const Text(
                        "Nenhum mes fechado ainda.",
                        style: TextStyle(color: Colors.white54),
                      )
                    else
                      for (var i = 0; i < monthly.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            (i + 1).toString() +
                                "o mes (" +
                                monthly[i]["period_key"].toString() +
                                "): " +
                                monthly[i]["days_live"].toString() +
                                " dias, " +
                                (monthly[i]["hours_live"] as num)
                                    .toStringAsFixed(0) +
                                "h, " +
                                monthly[i]["diamonds"].toString() +
                                " diamantes",
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
                              builder: (context) => _MetricsContactLogDialog(
                                streamerId: widget.streamerId,
                                displayName: p["display_name"] as String,
                              ),
                            );
                          },
                          child: const Text("Adicionar Nota"),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("Fechar"),
                        ),
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

  const _MetricsContactLogDialog({
    required this.streamerId,
    required this.displayName,
  });

  @override
  State<_MetricsContactLogDialog> createState() =>
      _MetricsContactLogDialogState();
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
              Text(
                "Notas - " + widget.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _logsFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          "Nenhum registro ainda.",
                          style: TextStyle(color: Colors.white54),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final log = snapshot.data![index];
                        final date = DateTime.parse(
                          log["created_at"] as String,
                        ).toLocal().toString().substring(0, 16);
                        final managerLabel =
                            (log["manager_label"] as String?) ?? "Gestor";
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                managerLabel + " - " + date,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (log["message_sent"] as String?) ?? "",
                                style: const TextStyle(color: Colors.white),
                              ),
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
                decoration: const InputDecoration(
                  labelText: "Adicione informacoes aqui",
                  labelStyle: TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Fechar"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB026FF),
                      foregroundColor: Colors.white,
                    ),
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
