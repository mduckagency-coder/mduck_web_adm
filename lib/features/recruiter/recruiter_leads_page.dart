import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "lead_category_icons.dart";

Color hexToColor(String hex) {
  final cleaned = hex.replaceFirst("#", "");
  return Color(int.parse("FF" + cleaned, radix: 16));
}

class RecruiterLeadsPage extends StatefulWidget {
  const RecruiterLeadsPage({super.key});

  @override
  State<RecruiterLeadsPage> createState() => _RecruiterLeadsPageState();
}

class _RecruiterLeadsPageState extends State<RecruiterLeadsPage> {
  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _stages = [];
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;
  String? _errorMessage;
  String _search = "";
  DateTime? _dateStart;
  DateTime? _dateEnd;
  final Set<String> _selectedCategories = {};
  Set<String> _visibleStages = {};
  Map<String, dynamic>? _metaData;
  final Set<String> _selectedIds = {};
  final _horizontalController = ScrollController();

  bool _isCoordOrAdmin = false;
  String _scope = "mine";
  Map<String, String> _recruiterEmails = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final me = await client.from("managers").select("role").eq("id", userId).maybeSingle();
      _isCoordOrAdmin = me != null && (me["role"] == "coordenador" || me["role"] == "admin");
      if (!_isCoordOrAdmin) _scope = "mine";

      final stagesRows = await client.from("lead_kanban_stages").select().eq("is_active", true).order("order_index");
      final categoriesRows = await client.from("lead_categories").select().eq("is_active", true).order("order_index");

      List<Map<String, dynamic>> leadsList;
      if (_isCoordOrAdmin) {
        final allManagers = await client.from("managers").select("id, login_email");
        _recruiterEmails = {for (final m in (allManagers as List)) m["id"] as String: m["login_email"] as String? ?? "-"};
      } else {
        _recruiterEmails = {};
      }

      if (_scope == "mine") {
        final rows = await client.from("leads").select().eq("recruiter_id", userId).order("created_at", ascending: false);
        leadsList = (rows as List).cast<Map<String, dynamic>>();
      } else if (_scope == "team") {
        final team = await client.from("managers").select("id").eq("coordinator_id", userId);
        final teamIds = (team as List).map((m) => m["id"] as String).toList();
        if (teamIds.isEmpty) {
          leadsList = [];
        } else {
          final rows = await client.from("leads").select().inFilter("recruiter_id", teamIds).order("created_at", ascending: false);
          leadsList = (rows as List).cast<Map<String, dynamic>>();
        }
      } else {
        final rows = await client.from("leads").select().order("created_at", ascending: false);
        leadsList = (rows as List).cast<Map<String, dynamic>>();
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Painel de meta e sempre pessoal, mesmo com escopo Equipe/Todos selecionado.
      Map<String, dynamic>? metaData;
      if (_scope == "mine") {
        final myLeads = leadsList;
        final dailyTargets = await client.from("recruiter_targets").select().or("recruiter_id.eq." + userId + ",recruiter_id.is.null").eq("metric", "leads").eq("period_type", "diario");
        double metaDiaria = 0;
        for (final t in (dailyTargets as List)) {
          final start = DateTime.parse(t["starts_at"]);
          final end = DateTime.parse(t["ends_at"]);
          if (!now.isBefore(start) && !now.isAfter(end)) metaDiaria = (t["target_value"] as num).toDouble();
        }
        final leadsHoje = myLeads.where((l) => DateTime.parse(l["created_at"]).isAfter(today)).length;

        final monthlyTargets = await client.from("recruiter_targets").select().or("recruiter_id.eq." + userId + ",recruiter_id.is.null").eq("metric", "agenciamentos").eq("period_type", "mensal");
        double metaMensal = 0;
        for (final t in (monthlyTargets as List)) {
          final start = DateTime.parse(t["starts_at"]);
          final end = DateTime.parse(t["ends_at"]);
          if (!now.isBefore(start) && !now.isAfter(end)) metaMensal = (t["target_value"] as num).toDouble();
        }
        final agenciadosMes = myLeads.where((l) {
          if (l["status"] != "agenciado" || l["converted_at"] == null) return false;
          final d = DateTime.parse(l["converted_at"]);
          return d.year == now.year && d.month == now.month;
        }).length;
        metaData = {"metaDiaria": metaDiaria, "leadsHoje": leadsHoje, "metaMensal": metaMensal, "agenciadosMes": agenciadosMes};
      }

      setState(() {
        _stages = (stagesRows as List).cast<Map<String, dynamic>>();
        _categories = (categoriesRows as List).cast<Map<String, dynamic>>();
        _leads = leadsList;
        if (_visibleStages.isEmpty) _visibleStages = _stages.map((s) => s["stage_key"] as String).toSet();
        _metaData = metaData;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> all) {
    return all.where((l) {
      if (_search.isNotEmpty) {
        final name = (l["name"] as String).toLowerCase();
        final tiktok = (l["tiktok_username"] as String? ?? "").toLowerCase();
        if (!name.contains(_search.toLowerCase()) && !tiktok.contains(_search.toLowerCase())) return false;
      }
      if (_selectedCategories.isNotEmpty && !_selectedCategories.contains(l["category_interest"])) return false;
      if (_dateStart != null || _dateEnd != null) {
        final created = DateTime.parse(l["created_at"]);
        final createdDay = DateTime(created.year, created.month, created.day);
        if (_dateStart != null && createdDay.isBefore(_dateStart!)) return false;
        if (_dateEnd != null && createdDay.isAfter(_dateEnd!)) return false;
      }
      return true;
    }).toList();
  }

  void _selectToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _dateStart = today;
      _dateEnd = today;
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _dateStart != null && _dateEnd != null ? DateTimeRange(start: _dateStart!, end: _dateEnd!) : null,
    );
    if (picked != null) {
      setState(() {
        _dateStart = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _dateEnd = DateTime(picked.end.year, picked.end.month, picked.end.day);
      });
    }
  }

  String _stageName(String stageKey) {
    final stage = _stages.firstWhere((s) => s["stage_key"] == stageKey, orElse: () => {"name": stageKey});
    return stage["name"] as String? ?? stageKey;
  }

  Future<void> _updateStatus(String leadId, String newStatus) async {
    final index = _leads.indexWhere((l) => l["id"] == leadId);
    if (index == -1) return;
    final oldStatus = _leads[index]["status"] as String;
    if (oldStatus == newStatus) return;
    setState(() => _leads[index]["status"] = newStatus);
    final client = Supabase.instance.client;
    try {
      await client.from("leads").update({"status": newStatus}).eq("id", leadId);
      await client.from("lead_history").insert({
        "lead_id": leadId,
        "action": "mudanca_etapa",
        "detail": _stageName(oldStatus) + " → " + _stageName(newStatus),
        "performed_by": client.auth.currentUser!.id,
      });
    } catch (e) {
      setState(() => _leads[index]["status"] = oldStatus);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao mover: " + e.toString())));
    }
  }

  Future<void> _moveSelected(String newStatus) async {
    final ids = List<String>.from(_selectedIds);
    for (final id in ids) {
      await _updateStatus(id, newStatus);
    }
    setState(() => _selectedIds.clear());
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Excluir leads selecionados?", style: TextStyle(color: Colors.white)),
        content: Text("Isso vai excluir " + _selectedIds.length.toString() + " lead(s) permanentemente. Nao pode ser desfeito.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final client = Supabase.instance.client;
    for (final id in List<String>.from(_selectedIds)) {
      await client.from("leads").delete().eq("id", id);
    }
    setState(() => _selectedIds.clear());
    _load();
  }

  void _selectAllInColumn(String stageKey, List<Map<String, dynamic>> filtered) {
    setState(() {
      final idsInColumn = filtered.where((l) => l["status"] == stageKey).map((l) => l["id"] as String);
      _selectedIds.addAll(idsInColumn);
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _openAdd() {
    showDialog(context: context, builder: (context) => LeadFormDialog(isCoordOrAdmin: _isCoordOrAdmin)).then((saved) {
      if (saved == true) _load();
    });
  }

  void _openDetail(Map<String, dynamic> lead) {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final canTransfer = _isCoordOrAdmin || lead["recruiter_id"] == userId;
    showDialog(context: context, builder: (context) => LeadDetailDialog(lead: lead, canTransfer: canTransfer)).then((changed) {
      if (changed == true) _load();
    });
  }

  Widget _buildMetaPanel() {
    final metaDiaria = _metaData!["metaDiaria"] as double;
    final leadsHoje = _metaData!["leadsHoje"] as int;
    final metaMensal = _metaData!["metaMensal"] as double;
    final agenciadosMes = _metaData!["agenciadosMes"] as int;

    String emoji;
    String motivational;
    if (metaDiaria == 0) {
      emoji = "\u{1F642}";
      motivational = "Nenhuma meta diaria de leads definida pelo gestor ainda.";
    } else if (leadsHoje >= metaDiaria) {
      emoji = "\u{1F604}";
      motivational = "Meta diaria concluida! Parabens pelo foco hoje.";
    } else if (leadsHoje > 0) {
      emoji = "\u{1F642}";
      motivational = "Faltam " + (metaDiaria - leadsHoje).toStringAsFixed(0) + " leads para bater a meta de hoje. Continue!";
    } else {
      emoji = "\u{1F622}";
      motivational = "Voce ainda nao cadastrou leads hoje. Foque em bater sua meta diaria!";
    }

    return Container(
      width: 190,
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      child: Tooltip(
        message: motivational,
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              const Expanded(child: Text("Meta diaria de leads", style: TextStyle(color: Colors.white70, fontSize: 11))),
            ]),
            const SizedBox(height: 4),
            Text(leadsHoje.toString() + " / " + metaDiaria.toStringAsFixed(0), style: const TextStyle(color: Color(0xFF7A0BD4), fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(color: Colors.white12, height: 16),
            const Text("Meta mensal de agenciamentos", style: TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 4),
            Text(agenciadosMes.toString() + " / " + metaMensal.toStringAsFixed(0), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text("Erro ao carregar: " + _errorMessage!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
        ),
      );
    }

    final categories = _leads.map((l) => l["category_interest"]).whereType<String>().where((c) => c.isNotEmpty).toSet().toList()..sort();
    final filtered = _filter(_leads);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("Leads", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(width: 12),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _load),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _openAdd,
                icon: const Icon(Icons.add),
                label: const Text("Novo Lead"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(context: context, builder: (context) => const BulkImportDialog()).then((saved) {
                    if (saved == true) _load();
                  });
                },
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text("Importacao em Massa"),
              ),
            ],
          ),
          if (_isCoordOrAdmin) ...[
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: "mine", label: Text("Meus Leads")),
                ButtonSegment(value: "team", label: Text("Leads da Equipe")),
                ButtonSegment(value: "all", label: Text("Todos os Leads")),
              ],
              selected: {_scope},
              onSelectionChanged: (s) {
                setState(() => _scope = s.first);
                _load();
              },
            ),
          ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          child: TextField(
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.white54), hintText: "Buscar nome ou @TikTok", hintStyle: TextStyle(color: Colors.white38), isDense: true),
                            onChanged: (v) => setState(() => _search = v),
                          ),
                        ),
                        OutlinedButton.icon(onPressed: _selectToday, icon: const Icon(Icons.today, size: 16), label: const Text("Hoje")),
                        OutlinedButton.icon(
                          onPressed: _pickDateRange,
                          icon: const Icon(Icons.date_range, size: 16),
                          label: Text(_dateStart != null && _dateEnd != null
                              ? _dateStart!.toIso8601String().substring(0, 10) + " a " + _dateEnd!.toIso8601String().substring(0, 10)
                              : "Escolher periodo"),
                        ),
                        if (_dateStart != null || _dateEnd != null)
                          TextButton(onPressed: () => setState(() { _dateStart = null; _dateEnd = null; }), child: const Text("Limpar datas")),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (categories.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        children: categories.map((c) {
                          final selected = _selectedCategories.contains(c);
                          return FilterChip(
                            label: Text(c, style: const TextStyle(fontSize: 11)),
                            selected: selected,
                            selectedColor: const Color(0xFF7A0BD4),
                            labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
                            onSelected: (v) => setState(() {
                              if (v) { _selectedCategories.add(c); } else { _selectedCategories.remove(c); }
                            }),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 8),
                    const Text("Etapas visiveis:", style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: _stages.map((s) {
                        final key = s["stage_key"] as String;
                        final selected = _visibleStages.contains(key);
                        final color = hexToColor(s["color"] as String);
                        return FilterChip(
                          label: Text(s["name"] as String, style: TextStyle(fontSize: 11, color: selected ? Colors.white : color)),
                          selected: selected,
                          selectedColor: color,
                          checkmarkColor: Colors.white,
                          onSelected: (v) => setState(() {
                            if (v) { _visibleStages.add(key); } else { _visibleStages.remove(key); }
                          }),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              if (_metaData != null) _buildMetaPanel(),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedIds.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12, top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFF7A0BD4).withOpacity(0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF7A0BD4))),
              child: Row(
                children: [
                  Text(_selectedIds.length.toString() + " selecionados", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  const Text("Mover para:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    hint: const Text("Escolha a etapa", style: TextStyle(color: Colors.white54)),
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(color: Colors.white),
                    items: _stages.map((s) => DropdownMenuItem(value: s["stage_key"] as String, child: Text(s["name"] as String))).toList(),
                    onChanged: (v) {
                      if (v != null) _moveSelected(v);
                    },
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _deleteSelected,
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                    label: const Text("Excluir selecionados", style: TextStyle(color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () => setState(() => _selectedIds.clear()), child: const Text("Cancelar")),
                ],
              ),
            ),
          if (_stages.isEmpty)
            const Expanded(child: Center(child: Text("Nenhuma etapa configurada. Va em Configuracoes > Funil de Leads.", style: TextStyle(color: Colors.white54))))
          else
            Expanded(
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final stage in _stages.where((s) => _visibleStages.contains(s["stage_key"])))
                        Builder(builder: (context) {
                          final stageKey = stage["stage_key"] as String;
                          final stageColor = hexToColor(stage["color"] as String);
                          final columnLeads = filtered.where((l) => l["status"] == stageKey).toList();
                          return Container(
                            width: 240,
                            height: 560,
                            margin: const EdgeInsets.only(right: 12),
                            child: DragTarget<Map<String, dynamic>>(
                              onWillAcceptWithDetails: (details) => details.data["status"] != stageKey,
                              onAcceptWithDetails: (details) => _updateStatus(details.data["id"] as String, stageKey),
                              builder: (context, candidateData, rejectedData) {
                                final highlighting = candidateData.isNotEmpty;
                                return Container(
                                  decoration: BoxDecoration(
                                    color: highlighting ? stageColor.withOpacity(0.15) : Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: highlighting ? stageColor : Colors.white12),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [stageColor.withOpacity(0.35), stageColor.withOpacity(0.12)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                          border: Border(bottom: BorderSide(color: stageColor, width: 2)),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(stage["name"] as String? ?? stageKey, style: TextStyle(color: stageColor, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(color: stageColor.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
                                                  child: Text(columnLeads.length.toString(), style: TextStyle(color: stageColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                                ),
                                                if (columnLeads.isNotEmpty)
                                                  IconButton(
                                                    icon: const Icon(Icons.select_all, size: 16, color: Colors.white70),
                                                    tooltip: "Selecionar todos desta coluna",
                                                    onPressed: () => _selectAllInColumn(stageKey, filtered),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: ListView.builder(
                                          padding: const EdgeInsets.all(8),
                                          itemCount: columnLeads.length,
                                          itemBuilder: (context, index) {
                                            final lead = columnLeads[index];
                                            final leadId = lead["id"] as String;
                                            final isSelected = _selectedIds.contains(leadId);
                                            final responsibleEmail = _scope != "mine" ? _recruiterEmails[lead["recruiter_id"]] : null;
                                            return Draggable<Map<String, dynamic>>(
                                              data: lead,
                                              feedback: Material(color: Colors.transparent, child: SizedBox(width: 220, child: LeadCard(lead: lead, statusColor: stageColor, categories: _categories, responsibleEmail: responsibleEmail))),
                                              childWhenDragging: Opacity(opacity: 0.3, child: LeadCard(lead: lead, statusColor: stageColor, categories: _categories, responsibleEmail: responsibleEmail)),
                                              child: GestureDetector(
                                                onTap: () => _openDetail(lead),
                                                onLongPress: () => _toggleSelect(leadId),
                                                child: Stack(
                                                  children: [
                                                    LeadCard(lead: lead, statusColor: stageColor, categories: _categories, selected: isSelected, responsibleEmail: responsibleEmail),
                                                    Positioned(
                                                      top: 4,
                                                      left: 4,
                                                      child: GestureDetector(
                                                        onTap: () => _toggleSelect(leadId),
                                                        child: Container(
                                                          width: 18,
                                                          height: 18,
                                                          decoration: BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            color: isSelected ? const Color(0xFF7A0BD4) : Colors.black45,
                                                            border: Border.all(color: Colors.white38, width: 1),
                                                          ),
                                                          child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LeadCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  final Color statusColor;
  final List<Map<String, dynamic>> categories;
  final bool selected;
  final String? responsibleEmail;
  const LeadCard({super.key, required this.lead, required this.statusColor, this.categories = const [], this.selected = false, this.responsibleEmail});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? const Color(0xFF7A0BD4) : Colors.white12, width: selected ? 2 : 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white24,
                backgroundImage: lead["photo_url"] != null ? NetworkImage(lead["photo_url"] as String) : null,
                child: lead["photo_url"] == null ? const Icon(Icons.person, color: Colors.white54, size: 16) : null,
              ),
              if (lead["category_interest"] != null && (lead["category_interest"] as String).isNotEmpty)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1A1A1A)),
                    child: Icon(
                      categoryIcon(categories.firstWhere((c) => c["name"] == lead["category_interest"], orElse: () => {"icon_key": "outro"})["icon_key"] as String?),
                      size: 12,
                      color: statusColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lead["name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                if (lead["tiktok_username"] != null && (lead["tiktok_username"] as String).isNotEmpty) Text("@" + lead["tiktok_username"], style: const TextStyle(color: Colors.white54, fontSize: 10)),
                if (lead["category_interest"] != null && (lead["category_interest"] as String).isNotEmpty) Text(lead["category_interest"], style: TextStyle(color: statusColor, fontSize: 10)),
                if (responsibleEmail != null) Text(responsibleEmail!, style: const TextStyle(color: Colors.white38, fontSize: 9, fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LeadFormDialog extends StatefulWidget {
  final bool isCoordOrAdmin;
  const LeadFormDialog({super.key, this.isCoordOrAdmin = false});

  @override
  State<LeadFormDialog> createState() => _LeadFormDialogState();
}

class _LeadFormDialogState extends State<LeadFormDialog> {
  final _nameController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedOrigin;
  final _originDetailController = TextEditingController();
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategory;
  bool _saving = false;

  // So carregada/exibida para coordenador ou admin -- permite cadastrar o
  // lead ja em nome de outro recrutador, pro dia a dia em que o proprio
  // recrutador nao coloca o card e o gestor acaba fazendo por ele. Null
  // mantem o comportamento padrao (lead fica com quem esta cadastrando).
  List<Map<String, dynamic>> _recruiters = [];
  String? _selectedRecruiterId;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.isCoordOrAdmin) _loadRecruiters();
  }

  Future<void> _loadCategories() async {
    final client = Supabase.instance.client;
    final rows = await client.from("lead_categories").select().eq("is_active", true).order("order_index");
    setState(() => _categories = (rows as List).cast<Map<String, dynamic>>());
  }

  Future<void> _loadRecruiters() async {
    final client = Supabase.instance.client;
    final rows = await client.from("managers").select("id, login_email").order("login_email");
    setState(() => _recruiters = (rows as List).cast<Map<String, dynamic>>());
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final recruiterId = _selectedRecruiterId ?? userId;
    final manager = await client.from("managers").select("agency_id").eq("id", userId).single();
    var initialStage = await client.from("lead_kanban_stages").select("stage_key").eq("agency_id", manager["agency_id"]).eq("is_initial", true).eq("is_active", true).maybeSingle();
    initialStage ??= await client.from("lead_kanban_stages").select("stage_key").eq("agency_id", manager["agency_id"]).eq("is_active", true).order("order_index").limit(1).maybeSingle();

    final inserted = await client.from("leads").insert({
      "agency_id": manager["agency_id"],
      "recruiter_id": recruiterId,
      "name": _nameController.text.trim(),
      "tiktok_username": _tiktokController.text.trim(),
      "phone": _phoneController.text.trim(),
      "category_interest": _selectedCategory,
      "origin": _selectedOrigin,
      "origin_detail": _originDetailController.text.trim(),
      "status": initialStage != null ? initialStage["stage_key"] : "novo",
    }).select("id").single();

    // performed_by fica com quem de fato cadastrou (o gestor, quando for o
    // caso) -- recruiter_id fica com o dono do lead. Isso preserva no
    // historico que o cadastro foi feito em nome de outra pessoa.
    final onBehalf = _selectedRecruiterId != null && _selectedRecruiterId != userId;
    await client.from("lead_history").insert({
      "lead_id": inserted["id"],
      "action": "criacao",
      "detail": onBehalf
          ? "Lead cadastrado pelo gestor em nome do recrutador " + (_recruiters.firstWhere((m) => m["id"] == recruiterId)["login_email"] as String)
          : "Lead cadastrado",
      "performed_by": userId,
    });

    if (_selectedOrigin == "Indicacao") {
      try {
        final donos = await client.from("managers").select("id").eq("financial_role", "dono");
        for (final d in (donos as List)) {
          await client.from("manager_notifications").insert({
            "manager_id": d["id"],
            "subject": "Novo lead por indicacao",
            "message": (_nameController.text.trim()) + " - indicado por: " + (_originDetailController.text.trim().isEmpty ? "nao informado" : _originDetailController.text.trim()),
          });
        }
      } catch (_) {}
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Novo Lead", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              if (widget.isCoordOrAdmin) ...[
                const SizedBox(height: 12),
                const Text("Cadastrar em nome de", style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                DropdownButton<String?>(
                  value: _selectedRecruiterId,
                  isExpanded: true,
                  hint: const Text("Eu mesmo", style: TextStyle(color: Colors.white54)),
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text("Eu mesmo")),
                    ..._recruiters.map((m) => DropdownMenuItem<String?>(value: m["id"] as String, child: Text(m["login_email"] as String? ?? "-"))),
                  ],
                  onChanged: (v) => setState(() => _selectedRecruiterId = v),
                ),
              ],
              const SizedBox(height: 16),
              TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _tiktokController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "@TikTok", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _phoneController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "WhatsApp", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              DropdownButton<String?>(
                value: _selectedCategory,
                hint: const Text("Categoria de interesse", style: TextStyle(color: Colors.white54)),
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white),
                items: _categories.map((c) => DropdownMenuItem<String?>(
                  value: c["name"] as String,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(categoryIcon(c["icon_key"] as String?), size: 16), const SizedBox(width: 6), Text(c["name"] as String)]),
                )).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
              const SizedBox(height: 8),
              DropdownButton<String?>(
                value: _selectedOrigin,
                hint: const Text("Origem do lead", style: TextStyle(color: Colors.white54)),
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white),
                items: leadOrigins.map((o) => DropdownMenuItem<String?>(value: o, child: Text(o))).toList(),
                onChanged: (v) => setState(() => _selectedOrigin = v),
              ),
              if (_selectedOrigin == "Indicacao" || _selectedOrigin == "Outros") ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _originDetailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: _selectedOrigin == "Indicacao" ? "Quem indicou?" : "Descreva a origem",
                    labelStyle: const TextStyle(color: Colors.white54),
                  ),
                ),
              ],
              const SizedBox(height: 16),
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

class LeadDetailDialog extends StatefulWidget {
  final Map<String, dynamic> lead;
  final bool canTransfer;
  const LeadDetailDialog({super.key, required this.lead, this.canTransfer = false});

  @override
  State<LeadDetailDialog> createState() => _LeadDetailDialogState();
}

class _LeadDetailDialogState extends State<LeadDetailDialog> {
  final _obsController = TextEditingController();
  late TextEditingController _nameController;
  late TextEditingController _tiktokController;
  late TextEditingController _phoneController;
  List<Map<String, dynamic>> _editCategories = [];
  String? _selectedEditCategory;
  String? _selectedEditOrigin;
  late Future<List<Map<String, dynamic>>> _historyFuture;
  late Future<String?> _responsibleFuture;
  bool _savingObs = false;
  bool _savingEdit = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
    _responsibleFuture = _loadResponsible();
    _nameController = TextEditingController(text: widget.lead["name"] as String? ?? "");
    _tiktokController = TextEditingController(text: widget.lead["tiktok_username"] as String? ?? "");
    _phoneController = TextEditingController(text: widget.lead["phone"] as String? ?? "");
    _selectedEditCategory = widget.lead["category_interest"] as String?;
    _selectedEditOrigin = widget.lead["origin"] as String?;
    _loadEditCategories();
  }

  Future<void> _loadEditCategories() async {
    final client = Supabase.instance.client;
    final rows = await client.from("lead_categories").select().eq("is_active", true).order("order_index");
    setState(() => _editCategories = (rows as List).cast<Map<String, dynamic>>());
  }

  Future<List<Map<String, dynamic>>> _loadHistory() async {
    final client = Supabase.instance.client;
    final rows = await client.from("lead_history").select().eq("lead_id", widget.lead["id"]).order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<String?> _loadResponsible() async {
    final recruiterId = widget.lead["recruiter_id"] as String?;
    if (recruiterId == null) return null;
    final client = Supabase.instance.client;
    final row = await client.from("managers").select("login_email").eq("id", recruiterId).maybeSingle();
    return row?["login_email"] as String?;
  }

  void _openTransfer() {
    showDialog<bool>(context: context, builder: (context) => LeadTransferDialog(lead: widget.lead)).then((done) {
      // Fecha tambem o dialogo de detalhe: o responsavel mudou, entao a
      // lista (e o proprio dialogo, se reaberto) refletem o novo dono.
      if (done == true && mounted) Navigator.of(context).pop(true);
    });
  }

  Future<void> _saveObservation() async {
    if (_obsController.text.trim().isEmpty) return;
    setState(() => _savingObs = true);
    final client = Supabase.instance.client;
    await client.from("lead_history").insert({
      "lead_id": widget.lead["id"],
      "action": "observacao",
      "detail": _obsController.text.trim(),
      "performed_by": client.auth.currentUser!.id,
    });
    _obsController.clear();
    setState(() {
      _savingObs = false;
      _historyFuture = _loadHistory();
    });
  }

  Future<void> _saveEdit() async {
    setState(() => _savingEdit = true);
    final client = Supabase.instance.client;
    await client.from("leads").update({
      "name": _nameController.text.trim(),
      "tiktok_username": _tiktokController.text.trim(),
      "phone": _phoneController.text.trim(),
      "category_interest": _selectedEditCategory,
      "origin": _selectedEditOrigin,
    }).eq("id", widget.lead["id"]);
    await client.from("lead_history").insert({
      "lead_id": widget.lead["id"],
      "action": "informacoes_atualizadas",
      "detail": "Dados do lead editados",
      "performed_by": client.auth.currentUser!.id,
    });
    setState(() {
      _savingEdit = false;
      _editing = false;
    });
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Excluir lead?", style: TextStyle(color: Colors.white)),
        content: const Text("Isso remove o lead e seu historico permanentemente. Nao pode ser desfeito.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final client = Supabase.instance.client;
      await client.from("leads").delete().eq("id", widget.lead["id"]);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(lead["name"] as String, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                if (widget.canTransfer)
                  IconButton(icon: const Icon(Icons.swap_horiz, color: Colors.white54, size: 18), tooltip: "Transferir Lead", onPressed: _openTransfer),
                IconButton(icon: Icon(_editing ? Icons.close : Icons.edit, color: Colors.white54, size: 18), onPressed: () => setState(() => _editing = !_editing)),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: _confirmDelete),
              ]),
              FutureBuilder<String?>(
                future: _responsibleFuture,
                builder: (context, snapshot) {
                  final email = snapshot.data;
                  if (email == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text("Responsavel: " + email, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  );
                },
              ),
              if (_editing) ...[
                const SizedBox(height: 8),
                TextField(controller: _nameController, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(labelText: "Nome", labelStyle: TextStyle(color: Colors.white54, fontSize: 12))),
                const SizedBox(height: 6),
                TextField(controller: _tiktokController, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(labelText: "@TikTok", labelStyle: TextStyle(color: Colors.white54, fontSize: 12))),
                const SizedBox(height: 6),
                TextField(controller: _phoneController, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(labelText: "WhatsApp", labelStyle: TextStyle(color: Colors.white54, fontSize: 12))),
                const SizedBox(height: 6),
                DropdownButton<String?>(
                  value: _selectedEditCategory,
                  hint: const Text("Categoria", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: _editCategories.map((c) => DropdownMenuItem<String?>(
                    value: c["name"] as String,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(categoryIcon(c["icon_key"] as String?), size: 14), const SizedBox(width: 6), Text(c["name"] as String)]),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedEditCategory = v),
                ),
                const SizedBox(height: 6),
                DropdownButton<String?>(
                  value: _selectedEditOrigin,
                  hint: const Text("Origem", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: leadOrigins.map((o) => DropdownMenuItem<String?>(value: o, child: Text(o))).toList(),
                  onChanged: (v) => setState(() => _selectedEditOrigin = v),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _savingEdit ? null : _saveEdit,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                    child: Text(_savingEdit ? "Salvando..." : "Salvar alteracoes"),
                  ),
                ),
              ] else ...[
                if (lead["tiktok_username"] != null && (lead["tiktok_username"] as String).isNotEmpty) Text("@" + lead["tiktok_username"], style: const TextStyle(color: Colors.white54)),
                if (lead["phone"] != null && (lead["phone"] as String).isNotEmpty) Text("WhatsApp: " + (lead["phone"] as String), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                if (lead["category_interest"] != null && (lead["category_interest"] as String).isNotEmpty) Text("Categoria: " + (lead["category_interest"] as String), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                if (lead["origin"] != null) Text("Origem: " + (lead["origin"] as String), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                Text("Cadastrado em: " + DateTime.parse(lead["created_at"] as String).toLocal().toString().substring(0, 16), style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              const Text("Historico (nunca apagado)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.isEmpty) return const Center(child: Text("Sem historico ainda.", style: TextStyle(color: Colors.white54)));
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final h = snapshot.data![index];
                        final date = DateTime.parse(h["created_at"] as String).toLocal().toString().substring(0, 16);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("[" + (h["action"] as String) + "] " + date, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              Text((h["detail"] as String?) ?? "", style: const TextStyle(color: Colors.white)),
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
                controller: _obsController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Adicionar observacao", labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Fechar")),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _savingObs ? null : _saveObservation,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                    child: Text(_savingObs ? "..." : "Salvar observacao"),
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

class BulkImportDialog extends StatefulWidget {
  const BulkImportDialog({super.key});

  @override
  State<BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState extends State<BulkImportDialog> {
  final _textController = TextEditingController();
  bool _saving = false;
  String? _resultMessage;

  String? _extractHandle(String line) {
    var text = line.trim();
    if (text.isEmpty) return null;
    if (text.contains("tiktok.com")) {
      final match = RegExp(r"@([a-zA-Z0-9_.]+)").firstMatch(text);
      if (match != null) return match.group(1);
      return null;
    }
    if (text.startsWith("@")) text = text.substring(1);
    return text.isEmpty ? null : text;
  }

  Future<void> _import() async {
    final lines = _textController.text.split("\n");
    final handles = <String>{};
    for (final line in lines) {
      final handle = _extractHandle(line);
      if (handle != null) handles.add(handle);
    }
    if (handles.isEmpty) return;

    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", userId).single();
    var initialStage = await client.from("lead_kanban_stages").select("stage_key").eq("agency_id", manager["agency_id"]).eq("is_initial", true).eq("is_active", true).maybeSingle();
    initialStage ??= await client.from("lead_kanban_stages").select("stage_key").eq("agency_id", manager["agency_id"]).eq("is_active", true).order("order_index").limit(1).maybeSingle();
    final statusKey = initialStage != null ? initialStage["stage_key"] as String : "novo";

    var created = 0;
    for (final handle in handles) {
      final inserted = await client.from("leads").insert({
        "agency_id": manager["agency_id"],
        "recruiter_id": userId,
        "name": handle,
        "tiktok_username": handle,
        "status": statusKey,
      }).select("id").single();
      await client.from("lead_history").insert({
        "lead_id": inserted["id"],
        "action": "criacao",
        "detail": "Lead cadastrado",
        "performed_by": userId,
      });
      created++;
    }

    setState(() {
      _saving = false;
      _resultMessage = created.toString() + " leads criados.";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Importacao em Massa", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text("Cole um @usuario ou link do TikTok por linha.", style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: _textController,
                maxLines: 8,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "@streamer1 @streamer2 https://www.tiktok.com/@streamer3",
                  hintStyle: TextStyle(color: Colors.white24),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_resultMessage != null) Text(_resultMessage!, style: const TextStyle(color: Colors.greenAccent)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(_resultMessage != null), child: Text(_resultMessage != null ? "Fechar" : "Cancelar")),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _import,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                    child: Text(_saving ? "Importando..." : "Importar"),
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

/// Retorna true quando o lead foi transferido, para a tela chamadora recarregar.
class LeadTransferDialog extends StatefulWidget {
  final Map<String, dynamic> lead;
  const LeadTransferDialog({super.key, required this.lead});

  @override
  State<LeadTransferDialog> createState() => _LeadTransferDialogState();
}

class _LeadTransferDialogState extends State<LeadTransferDialog> {
  List<Map<String, dynamic>> _recruiters = [];
  String? _currentResponsibleEmail;
  String? _selectedId;
  final _reasonController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final currentId = widget.lead["recruiter_id"] as String?;
    final rows = await client.from("managers").select("id, login_email").order("login_email");
    final all = (rows as List).cast<Map<String, dynamic>>();
    setState(() {
      _recruiters = all.where((m) => m["id"] != currentId).toList();
      _currentResponsibleEmail = all.firstWhere((m) => m["id"] == currentId, orElse: () => {"login_email": "-"})["login_email"] as String?;
      _loading = false;
    });
  }

  bool get _canConfirm => _selectedId != null && _reasonController.text.trim().isNotEmpty;

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final leadId = widget.lead["id"] as String;
    final previousRecruiterId = widget.lead["recruiter_id"] as String?;
    final newRecruiterId = _selectedId!;
    final newEmail = _recruiters.firstWhere((m) => m["id"] == newRecruiterId)["login_email"] as String;
    final reason = _reasonController.text.trim();

    await client.from("leads").update({"recruiter_id": newRecruiterId}).eq("id", leadId);

    await client.from("lead_transfers").insert({
      "lead_id": leadId,
      "previous_recruiter_id": previousRecruiterId,
      "new_recruiter_id": newRecruiterId,
      "performed_by": userId,
      "reason": reason,
    });

    await client.from("lead_history").insert({
      "lead_id": leadId,
      "action": "transferencia",
      "detail": "De " + (_currentResponsibleEmail ?? "-") + " para " + newEmail + ". Motivo: " + reason,
      "performed_by": userId,
    });

    try {
      await client.from("manager_notifications").insert({
        "manager_id": newRecruiterId,
        "subject": "Lead transferido para voce",
        "message": (widget.lead["name"] as String? ?? "Lead") + " foi transferido para voce. Motivo: " + reason,
      });
    } catch (_) {}

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Transferir Lead", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.lead["name"] as String? ?? "", style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 16),
                    Text("Responsavel atual: " + (_currentResponsibleEmail ?? "-"), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 12),
                    DropdownButton<String>(
                      value: _selectedId,
                      isExpanded: true,
                      hint: const Text("Novo responsavel", style: TextStyle(color: Colors.white54)),
                      dropdownColor: const Color(0xFF1A1A1A),
                      style: const TextStyle(color: Colors.white),
                      items: _recruiters.map((m) => DropdownMenuItem(value: m["id"] as String, child: Text(m["login_email"] as String))).toList(),
                      onChanged: (v) => setState(() => _selectedId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reasonController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Motivo da transferencia", labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: (_canConfirm && !_saving) ? _confirm : null,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                          child: Text(_saving ? "Transferindo..." : "Confirmar transferencia"),
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



