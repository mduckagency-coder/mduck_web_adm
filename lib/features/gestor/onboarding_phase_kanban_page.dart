import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "onboarding_phase_category_icons.dart";
import "onboarding_phase_service.dart";

Color _hexToColor(String hex) {
  final cleaned = hex.replaceFirst("#", "");
  return Color(int.parse("FF" + cleaned, radix: 16));
}

class OnboardingPhaseKanbanPage extends StatefulWidget {
  const OnboardingPhaseKanbanPage({super.key});

  @override
  State<OnboardingPhaseKanbanPage> createState() => _OnboardingPhaseKanbanPageState();
}

class _OnboardingPhaseKanbanPageState extends State<OnboardingPhaseKanbanPage> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _stages = [];
  Map<String, List<Map<String, dynamic>>> _itemsByStage = {};
  List<Map<String, dynamic>> _cards = [];
  Map<String, Map<String, bool>> _checklistProgress = {};
  final _horizontalController = ScrollController();

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
      final me = await client.from("managers").select("agency_id").eq("id", userId).single();
      final agencyId = me["agency_id"] as String;

      await seedOnboardingPhaseStages(agencyId: agencyId);

      final stageRows = await client
          .from("streamer_phase_stages")
          .select()
          .eq("agency_id", agencyId)
          .eq("phase_key", onboardingPhaseKey)
          .eq("is_active", true)
          .order("order_index");
      final stages = (stageRows as List).cast<Map<String, dynamic>>();

      final itemRows = await client
          .from("streamer_phase_checklist_items")
          .select()
          .eq("agency_id", agencyId)
          .eq("phase_key", onboardingPhaseKey)
          .eq("is_active", true)
          .order("order_index");
      final itemsByStage = <String, List<Map<String, dynamic>>>{};
      for (final it in (itemRows as List)) {
        itemsByStage.putIfAbsent(it["stage_key"] as String, () => []).add(it as Map<String, dynamic>);
      }

      final progressRows = await client
          .from("streamer_phase_progress")
          .select()
          .eq("manager_id", userId)
          .eq("phase_key", onboardingPhaseKey)
          .filter("completed_at", "is", null);
      final progressList = (progressRows as List).cast<Map<String, dynamic>>();

      var cards = <Map<String, dynamic>>[];
      var checklistProgress = <String, Map<String, bool>>{};
      if (progressList.isNotEmpty) {
        final streamerIds = progressList.map((p) => p["streamer_id"] as String).toList();
        final profiles = await client
            .from("profiles")
            .select("id, display_name, tiktok_creator_id, avatar_url, joined_at, streamer_categories(name, icon_key)")
            .inFilter("id", streamerIds);
        final profileMap = {for (final p in (profiles as List)) p["id"] as String: p as Map<String, dynamic>};

        final progressRowsChecklist = await client
            .from("streamer_phase_checklist_progress")
            .select("streamer_id, stage_key, item_key, done")
            .eq("phase_key", onboardingPhaseKey)
            .inFilter("streamer_id", streamerIds);
        for (final r in (progressRowsChecklist as List)) {
          final key = (r["streamer_id"] as String) + "|" + (r["stage_key"] as String);
          checklistProgress.putIfAbsent(key, () => {})[r["item_key"] as String] = r["done"] == true;
        }

        cards = progressList.map((p) {
          final profile = profileMap[p["streamer_id"]] ?? {};
          final catData = profile["streamer_categories"];
          return {
            "progressId": p["id"],
            "streamerId": p["streamer_id"],
            "stageKey": p["stage_key"],
            "displayName": profile["display_name"] ?? "-",
            "tiktokId": profile["tiktok_creator_id"],
            "avatarUrl": profile["avatar_url"],
            "joinedAt": profile["joined_at"],
            "categoryName": catData is Map ? catData["name"] as String? : null,
            "categoryIconKey": catData is Map ? catData["icon_key"] as String? : null,
          };
        }).toList();
      }

      setState(() {
        _stages = stages;
        _itemsByStage = itemsByStage;
        _cards = cards;
        _checklistProgress = checklistProgress;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  bool _isStageComplete(String streamerId, String stageKey) {
    final items = _itemsByStage[stageKey] ?? [];
    if (items.isEmpty) return true;
    final progress = _checklistProgress[streamerId + "|" + stageKey] ?? {};
    return items.every((it) => progress[it["item_key"]] == true);
  }

  int _stageOrder(String stageKey) => _stages.firstWhere((s) => s["stage_key"] == stageKey, orElse: () => {"order_index": 0})["order_index"] as int;

  String _stageName(String stageKey) => _stages.firstWhere((s) => s["stage_key"] == stageKey, orElse: () => {"name": stageKey})["name"] as String;

  Future<void> _moveCard(Map<String, dynamic> card, String newStageKey) async {
    final streamerId = card["streamerId"] as String;
    final oldStageKey = card["stageKey"] as String;
    if (oldStageKey == newStageKey) return;

    if (_stageOrder(newStageKey) > _stageOrder(oldStageKey) && !_isStageComplete(streamerId, oldStageKey)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ainda existem tarefas obrigatorias pendentes nesta etapa. Conclua o checklist antes de avancar.")),
        );
      }
      return;
    }

    final index = _cards.indexWhere((c) => c["streamerId"] == streamerId);
    if (index == -1) return;
    setState(() => _cards[index]["stageKey"] = newStageKey);

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    try {
      await client.from("streamer_phase_progress").update({
        "stage_key": newStageKey,
        "stage_changed_at": DateTime.now().toIso8601String(),
      }).eq("id", card["progressId"]);

      await client.from("streamer_phase_history").insert({
        "streamer_id": streamerId,
        "phase_key": onboardingPhaseKey,
        "action": "mudanca_etapa",
        "detail": _stageName(oldStageKey) + " → " + _stageName(newStageKey),
        "performed_by": userId,
      });
    } catch (e) {
      setState(() => _cards[index]["stageKey"] = oldStageKey);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao mover: " + e.toString())));
    }
  }

  void _openDetail(Map<String, dynamic> card) {
    showDialog(
      context: context,
      builder: (context) => _OnboardingCardDetailDialog(
        streamerId: card["streamerId"] as String,
        streamerName: card["displayName"] as String,
        categoryName: card["categoryName"] as String?,
        stages: _stages,
        itemsByStage: _itemsByStage,
      ),
    ).then((changed) {
      if (changed == true) _load();
    });
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Onboarding 0-15 Dias", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _load),
          ]),
          const SizedBox(height: 4),
          const Text(
            "Acompanhamento automatico dos primeiros 15 dias — os cards entram sozinhos quando o recrutador conclui o onboarding.",
            style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          if (_stages.isEmpty)
            const Expanded(child: Center(child: Text("Nenhuma etapa configurada.", style: TextStyle(color: Colors.white54))))
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
                      for (final stage in _stages)
                        Builder(builder: (context) {
                          final stageKey = stage["stage_key"] as String;
                          final stageColor = _hexToColor(stage["color"] as String);
                          final columnCards = _cards.where((c) => c["stageKey"] == stageKey).toList();
                          return Container(
                            width: 240,
                            height: 560,
                            margin: const EdgeInsets.only(right: 12),
                            child: DragTarget<Map<String, dynamic>>(
                              onWillAcceptWithDetails: (details) => details.data["stageKey"] != stageKey,
                              onAcceptWithDetails: (details) => _moveCard(details.data, stageKey),
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
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(color: stageColor.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
                                              child: Text(columnCards.length.toString(), style: TextStyle(color: stageColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: ListView.builder(
                                          padding: const EdgeInsets.all(8),
                                          itemCount: columnCards.length,
                                          itemBuilder: (context, index) {
                                            final card = columnCards[index];
                                            final complete = _isStageComplete(card["streamerId"] as String, stageKey);
                                            return Draggable<Map<String, dynamic>>(
                                              data: card,
                                              feedback: Material(color: Colors.transparent, child: SizedBox(width: 220, child: _OnboardingCard(card: card, stageColor: stageColor, stageComplete: complete))),
                                              childWhenDragging: Opacity(opacity: 0.3, child: _OnboardingCard(card: card, stageColor: stageColor, stageComplete: complete)),
                                              child: GestureDetector(
                                                onTap: () => _openDetail(card),
                                                child: _OnboardingCard(card: card, stageColor: stageColor, stageComplete: complete),
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

class _OnboardingCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final Color stageColor;
  final bool stageComplete;
  const _OnboardingCard({required this.card, required this.stageColor, required this.stageComplete});

  @override
  Widget build(BuildContext context) {
    final joinedAt = card["joinedAt"] as String?;
    final daysInAgency = joinedAt != null ? DateTime.now().difference(DateTime.parse(joinedAt)).inDays : null;
    final tiktokId = card["tiktokId"] as String?;
    final categoryName = card["categoryName"] as String?;
    final emoji = categoryEmoji(iconKey: card["categoryIconKey"] as String?, categoryName: categoryName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: stageComplete ? Colors.greenAccent : Colors.white12, width: stageComplete ? 2 : 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white24,
            backgroundImage: card["avatarUrl"] != null ? NetworkImage(card["avatarUrl"] as String) : null,
            child: card["avatarUrl"] == null ? const Icon(Icons.person, color: Colors.white54, size: 16) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(card["displayName"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                ]),
                if (tiktokId != null && tiktokId.isNotEmpty) Text("@" + tiktokId, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                if (categoryName != null && categoryName.isNotEmpty) Text(categoryName, style: TextStyle(color: stageColor, fontSize: 10)),
                if (daysInAgency != null) Text(daysInAgency.toString() + " dias na agencia", style: const TextStyle(color: Colors.white38, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingCardDetailDialog extends StatefulWidget {
  final String streamerId;
  final String streamerName;
  final String? categoryName;
  final List<Map<String, dynamic>> stages;
  final Map<String, List<Map<String, dynamic>>> itemsByStage;
  const _OnboardingCardDetailDialog({
    required this.streamerId,
    required this.streamerName,
    required this.categoryName,
    required this.stages,
    required this.itemsByStage,
  });

  @override
  State<_OnboardingCardDetailDialog> createState() => _OnboardingCardDetailDialogState();
}

class _OnboardingCardDetailDialogState extends State<_OnboardingCardDetailDialog> {
  late Future<Map<String, dynamic>> _future;
  final _obsController = TextEditingController();
  bool _savingObs = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;

    final progress = await client
        .from("streamer_phase_progress")
        .select()
        .eq("streamer_id", widget.streamerId)
        .eq("phase_key", onboardingPhaseKey)
        .single();
    final stageKey = progress["stage_key"] as String;

    final checklistRows = await client
        .from("streamer_phase_checklist_progress")
        .select()
        .eq("streamer_id", widget.streamerId)
        .eq("phase_key", onboardingPhaseKey)
        .eq("stage_key", stageKey);
    final checklistProgress = {for (final r in (checklistRows as List)) r["item_key"] as String: r["done"] == true};

    List<Map<String, dynamic>> materials = [];
    if (widget.categoryName != null && widget.categoryName!.isNotEmpty) {
      final rows = await client
          .from("training_materials")
          .select("title, link_url, file_url")
          .eq("category", widget.categoryName as Object)
          .eq("is_archived", false)
          .order("order_index");
      materials = (rows as List).cast<Map<String, dynamic>>();
    }

    final history = await client
        .from("streamer_phase_history")
        .select()
        .eq("streamer_id", widget.streamerId)
        .eq("phase_key", onboardingPhaseKey)
        .order("created_at", ascending: false);

    return {
      "progress": progress,
      "stageKey": stageKey,
      "checklistProgress": checklistProgress,
      "materials": materials,
      "history": (history as List).cast<Map<String, dynamic>>(),
    };
  }

  Future<void> _toggleItem(String stageKey, String itemKey, bool current) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final newValue = !current;
    await client.from("streamer_phase_checklist_progress").upsert({
      "streamer_id": widget.streamerId,
      "phase_key": onboardingPhaseKey,
      "stage_key": stageKey,
      "item_key": itemKey,
      "done": newValue,
      "done_at": newValue ? DateTime.now().toIso8601String() : null,
      "done_by": newValue ? userId : null,
    }, onConflict: "streamer_id,phase_key,stage_key,item_key");

    if (newValue) {
      final label = widget.itemsByStage[stageKey]?.firstWhere((it) => it["item_key"] == itemKey, orElse: () => {"label": itemKey})["label"] as String;
      await client.from("streamer_phase_history").insert({
        "streamer_id": widget.streamerId,
        "phase_key": onboardingPhaseKey,
        "action": "checklist_item",
        "detail": label,
        "performed_by": userId,
      });
    }
    _changed = true;
    setState(() => _future = _load());
  }

  Future<void> _saveObservation() async {
    if (_obsController.text.trim().isEmpty) return;
    setState(() => _savingObs = true);
    final client = Supabase.instance.client;
    await client.from("streamer_phase_history").insert({
      "streamer_id": widget.streamerId,
      "phase_key": onboardingPhaseKey,
      "action": "observacao",
      "detail": _obsController.text.trim(),
      "performed_by": client.auth.currentUser!.id,
    });
    _obsController.clear();
    _changed = true;
    setState(() {
      _savingObs = false;
      _future = _load();
    });
  }

  Future<void> _concludePhase() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    await client.from("streamer_phase_progress").update({"completed_at": DateTime.now().toIso8601String()}).eq("streamer_id", widget.streamerId).eq("phase_key", onboardingPhaseKey);
    await client.from("streamer_phase_history").insert({
      "streamer_id": widget.streamerId,
      "phase_key": onboardingPhaseKey,
      "action": "onboarding_concluido",
      "detail": "Onboarding 0-15 Dias concluido",
      "performed_by": userId,
    });
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
              final data = snapshot.data!;
              final stageKey = data["stageKey"] as String;
              final checklistProgress = data["checklistProgress"] as Map<String, bool>;
              final materials = data["materials"] as List<Map<String, dynamic>>;
              final history = data["history"] as List<Map<String, dynamic>>;
              final items = widget.itemsByStage[stageKey] ?? [];
              final allDone = items.isNotEmpty && items.every((it) => checklistProgress[it["item_key"]] == true);
              final maxOrder = widget.stages.isEmpty ? 0 : widget.stages.map((s) => s["order_index"] as int).reduce((a, b) => a > b ? a : b);
              final currentOrder = widget.stages.firstWhere((s) => s["stage_key"] == stageKey, orElse: () => {"order_index": 0})["order_index"] as int;
              final isLastStage = currentOrder == maxOrder;
              final stageName = widget.stages.firstWhere((s) => s["stage_key"] == stageKey, orElse: () => {"name": stageKey})["name"] as String;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.streamerName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    if (widget.categoryName != null) Text(widget.categoryName!, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text("Etapa atual: " + stageName, style: const TextStyle(color: Color(0xFF7A0BD4), fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 16),
                    const Text("Checklist da etapa", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (items.isEmpty)
                      const Text("Nenhum item configurado para esta etapa.", style: TextStyle(color: Colors.white38, fontSize: 12))
                    else
                      ...items.map((it) {
                        final itemKey = it["item_key"] as String;
                        final done = checklistProgress[itemKey] == true;
                        return CheckboxListTile(
                          value: done,
                          onChanged: (_) => _toggleItem(stageKey, itemKey, done),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: Colors.greenAccent,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(it["label"] as String, style: TextStyle(color: done ? Colors.white : Colors.white70, fontSize: 13)),
                        );
                      }),
                    if (isLastStage && allDone) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: _concludePhase,
                          icon: const Icon(Icons.flag, size: 16),
                          label: const Text("Concluir Onboarding 0-15 Dias"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                        ),
                      ),
                    ],
                    if (materials.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text("Materiais da categoria" + (widget.categoryName != null ? " (" + widget.categoryName! + ")" : ""), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      ...materials.map((m) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(children: [
                              const Icon(Icons.description_outlined, size: 14, color: Colors.white54),
                              const SizedBox(width: 6),
                              Expanded(child: Text(m["title"] as String? ?? "-", style: const TextStyle(color: Colors.white70, fontSize: 12))),
                            ]),
                          )),
                    ],
                    const SizedBox(height: 16),
                    const Text("Historico", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (history.isEmpty)
                      const Text("Sem registros ainda.", style: TextStyle(color: Colors.white38, fontSize: 12))
                    else
                      ...history.map((h) {
                        final date = DateTime.parse(h["created_at"] as String).toLocal().toString().substring(0, 16);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text("- (" + date + ") " + (h["detail"] as String? ?? (h["action"] as String)), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        );
                      }),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _obsController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: "Adicionar observacao", labelStyle: TextStyle(color: Colors.white54)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _savingObs ? null : _saveObservation,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                        child: Text(_savingObs ? "..." : "Salvar"),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(context).pop(_changed), child: const Text("Fechar"))),
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
