import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "activity_types.dart";
import "gestor_streamer_service.dart";
import "streamer_stage_service.dart";
import "streamer_tasks_service.dart";

/// Painel lateral unico do CRM -- usado pelas telas novas (Novatos, e
/// depois Streamers/Agenda). So precisa do streamerId (igual ao dialog mais
/// generico que ja existia, o do CRM) -- tudo mais e buscado aqui dentro.
///
/// Mesmo mecanismo de animacao de openParticipantPanel
/// (lib/features/programas/participante_panel.dart), o unico painel
/// deslizante de verdade que ja existia no app -- so generalizado pra
/// aceitar qualquer streamer, nao so participante de um programa.
///
/// De proposito NAO reaproveita nem substitui _OnboardingCardDetailDialog
/// (onboarding_phase_kanban_page.dart) -- o board de Onboarding continua
/// com a tela de detalhe que ja funciona. Um desenvolvedor ja tentou
/// reaproveitar uma dialog "ficha" ali dentro e reverteu por conflito de
/// dados (comentario perto da linha 4135 daquele arquivo); este painel novo
/// e o lugar certo pras telas novas, nao uma substituicao do que ja existe.
Future<void> openStreamerSidePanel(
  BuildContext context, {
  required String streamerId,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Fechar",
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, secondaryAnim, child) {
      final width = (MediaQuery.of(context).size.width * 0.9).clamp(0.0, 420.0);
      return Align(
        alignment: Alignment.centerRight,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: Material(
            color: const Color(0xFF1A1A1A),
            elevation: 8,
            child: SizedBox(
              width: width,
              height: double.infinity,
              child: _StreamerSidePanelContent(streamerId: streamerId),
            ),
          ),
        ),
      );
    },
  );
}

class _StreamerSidePanelContent extends StatefulWidget {
  final String streamerId;
  const _StreamerSidePanelContent({required this.streamerId});

  @override
  State<_StreamerSidePanelContent> createState() =>
      _StreamerSidePanelContentState();
}

class _StreamerSidePanelContentState extends State<_StreamerSidePanelContent> {
  late Future<Map<String, dynamic>> _future;
  final _obsController = TextEditingController();
  final _nextActionController = TextEditingController();
  DateTime? _nextActionDate;
  String? _nextActionType;
  bool _saving = false;

  final _actionNoteController = TextEditingController();
  String _actionStageKey = streamerStages.first.key;
  int _actionRevisarEmDias = 5;
  String? _actionPerformedById;
  bool _actionSaving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final me = await client
        .from("managers")
        .select("agency_id")
        .eq("id", userId)
        .single();
    final agencyId = me["agency_id"] as String;

    final profile = await client
        .from("profiles")
        .select(
          "id, display_name, tiktok_username, tiktok_creator_id, avatar_url, joined_at, last_live_at, assigned_manager_id, potential_level, streamer_categories(name), managers!profiles_assigned_manager_id_fkey(login_email), streamer_stats(days_live, hours_live, diamonds)",
        )
        .eq("id", widget.streamerId)
        .single();

    // Card ativo em QUALQUER fase (Onboarding 0-15/16-31 ou outra) --
    // determina se mostra checklist/materiais, sem depender de qual modulo
    // trouxe o gestor ate aqui.
    final activeProgress = await client
        .from("streamer_phase_progress")
        .select("id, phase_key, stage_key")
        .eq("streamer_id", widget.streamerId)
        .filter("completed_at", "is", null)
        .order("started_at", ascending: false)
        .limit(1)
        .maybeSingle();

    Map<String, dynamic>? checklistData;
    if (activeProgress != null) {
      final phaseKey = activeProgress["phase_key"] as String;
      final stageKey = activeProgress["stage_key"] as String;
      final items = await client
          .from("streamer_phase_checklist_items")
          .select()
          .eq("phase_key", phaseKey)
          .eq("stage_key", stageKey)
          .eq("is_active", true)
          .order("order_index", ascending: true);
      final progressRows = await client
          .from("streamer_phase_checklist_progress")
          .select()
          .eq("streamer_id", widget.streamerId)
          .eq("phase_key", phaseKey)
          .eq("stage_key", stageKey);
      final progress = {
        for (final r in (progressRows as List).cast<Map<String, dynamic>>())
          r["item_key"] as String: r["done"] == true,
      };
      final stageRow = await client
          .from("streamer_phase_stages")
          .select("name")
          .eq("phase_key", phaseKey)
          .eq("stage_key", stageKey)
          .maybeSingle();
      checklistData = {
        "phaseKey": phaseKey,
        "stageKey": stageKey,
        "stageName": stageRow?["name"] as String? ?? stageKey,
        "items": (items as List).cast<Map<String, dynamic>>(),
        "progress": progress,
      };
    }

    // Historico unificado -- junta o historico por fase (Onboarding etc,
    // todas as fases desse streamer) com o log de acompanhamento generico
    // (streamer_contact_logs, ja usado em Progressao/Inatividade), numa
    // timeline so, mais recente primeiro.
    final historyRows = await client
        .from("streamer_phase_history")
        .select()
        .eq("streamer_id", widget.streamerId)
        .order("created_at", ascending: false)
        .limit(30);
    final contactRows = await client
        .from("streamer_contact_logs")
        .select()
        .eq("streamer_id", widget.streamerId)
        .order("created_at", ascending: false)
        .limit(30);

    final combinedHistory =
        [
          ...(historyRows as List).cast<Map<String, dynamic>>().map(
            (r) => {
              "created_at": r["created_at"],
              "label": r["action"] as String,
              "detail": r["detail"] as String?,
            },
          ),
          ...(contactRows as List).cast<Map<String, dynamic>>().map(
            (r) => {
              "created_at": r["created_at"],
              "label": "Acompanhamento",
              "detail": r["message_sent"] as String?,
            },
          ),
        ]..sort(
          (a, b) =>
              (b["created_at"] as String).compareTo(a["created_at"] as String),
        );

    final nextAction = await fetchNextActionFor(widget.streamerId);

    // Mes anterior fechado, mesma fonte (monthly_stats) e mesmo calculo de
    // prevPeriodKey ja usados em gestor_streamer_service.dart -- so pra
    // mostrar a evolucao aqui tambem, sem duplicar a logica de growth.
    final now = DateTime.now();
    final prevMonth = now.month == 1 ? 12 : now.month - 1;
    final prevYear = now.month == 1 ? now.year - 1 : now.year;
    final prevPeriodKey =
        prevYear.toString() + "-" + prevMonth.toString().padLeft(2, "0");
    final monthlyRow = await client
        .from("monthly_stats")
        .select("diamonds")
        .eq("period_key", prevPeriodKey)
        .eq("streamer_id", widget.streamerId)
        .maybeSingle();
    final diamondsLastMonth = monthlyRow?["diamonds"] as num?;

    // Lista de gestores da agencia -- pro dropdown "Realizado por" (quem de
    // fato fez o acompanhamento, pode ser diferente de quem esta logado
    // registrando).
    final agencyManagers = await client
        .from("managers")
        .select("id, login_email")
        .eq("agency_id", agencyId);

    return {
      "agencyId": agencyId,
      "profile": profile,
      "checklist": checklistData,
      "history": combinedHistory,
      "nextAction": nextAction,
      "diamondsLastMonth": diamondsLastMonth,
      "agencyManagers": (agencyManagers as List).cast<Map<String, dynamic>>(),
    };
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _toggleChecklistItem(
    String phaseKey,
    String stageKey,
    String itemKey,
    bool current,
  ) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    await client.from("streamer_phase_checklist_progress").upsert({
      "streamer_id": widget.streamerId,
      "phase_key": phaseKey,
      "stage_key": stageKey,
      "item_key": itemKey,
      "done": !current,
      "done_at": !current ? DateTime.now().toIso8601String() : null,
      "done_by": !current ? userId : null,
    }, onConflict: "streamer_id,phase_key,stage_key,item_key");
    _reload();
  }

  Future<void> _setPotential(String? level) async {
    await updateStreamerPotential(streamerId: widget.streamerId, level: level);
    _reload();
  }

  Future<void> _saveObservation() async {
    if (_obsController.text.trim().isEmpty) return;
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    await client.from("streamer_contact_logs").insert({
      "streamer_id": widget.streamerId,
      "manager_id": userId,
      "manager_label": client.auth.currentUser?.email ?? "Gestor",
      "message_sent": _obsController.text.trim(),
      "context": "painel_streamer",
    });
    _obsController.clear();
    _reload();
  }

  Future<void> _saveNextAction(
    String agencyId,
    String? assignedManagerId,
  ) async {
    if (_nextActionController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    await createTask(
      agencyId: agencyId,
      streamerId: widget.streamerId,
      managerId: assignedManagerId ?? userId,
      title: _nextActionController.text.trim(),
      activityType: _nextActionType,
      dueAt: _nextActionDate,
      performedBy: userId,
    );
    _nextActionController.clear();
    _nextActionDate = null;
    _nextActionType = null;
    setState(() => _saving = false);
    _reload();
  }

  Future<void> _completeNextAction(String taskId) async {
    await completeTask(taskId);
    _reload();
  }

  Future<void> _pickNextActionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextActionDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _nextActionDate = picked);
  }

  Future<void> _registerAction(
    String agencyId,
    List<Map<String, dynamic>> agencyManagers,
  ) async {
    setState(() => _actionSaving = true);
    String? performedByLabel;
    if (_actionPerformedById != null) {
      final match = agencyManagers.firstWhere(
        (m) => m["id"] == _actionPerformedById,
        orElse: () => const {},
      );
      performedByLabel = match["login_email"] as String?;
    }
    try {
      await registerStreamerAction(
        streamerId: widget.streamerId,
        agencyId: agencyId,
        stageKey: _actionStageKey,
        note: _actionNoteController.text.trim().isEmpty
            ? null
            : _actionNoteController.text.trim(),
        dueInDays: _actionRevisarEmDias,
        performedByManagerId: _actionPerformedById,
        performedByLabel: performedByLabel,
      );
      _actionNoteController.clear();
      setState(() {
        _actionStageKey = streamerStages.first.key;
        _actionRevisarEmDias = 5;
        _actionPerformedById = null;
        _actionSaving = false;
      });
      _reload();
    } catch (e) {
      if (mounted) {
        setState(() => _actionSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao registrar ação: " + e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "Erro ao carregar: " + snapshot.error.toString(),
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final profile = data["profile"] as Map<String, dynamic>;
          final checklist = data["checklist"] as Map<String, dynamic>?;
          final history = data["history"] as List<Map<String, dynamic>>;
          final nextAction = data["nextAction"] as StreamerTask?;
          final diamondsLastMonth = data["diamondsLastMonth"] as num?;
          final agencyId = data["agencyId"] as String;
          final agencyManagers =
              data["agencyManagers"] as List<Map<String, dynamic>>;
          final assignedManagerId = profile["assigned_manager_id"] as String?;
          final catData = profile["streamer_categories"];
          final managerData = profile["managers"];
          final statsData = profile["streamer_stats"];
          Map<String, dynamic>? stats;
          if (statsData is List && statsData.isNotEmpty) {
            stats = statsData.first as Map<String, dynamic>;
          } else if (statsData is Map) {
            stats = statsData as Map<String, dynamic>;
          }
          final joinedAt = DateTime.parse(profile["joined_at"] as String);
          final lastLiveAt = profile["last_live_at"] != null
              ? DateTime.parse(profile["last_live_at"] as String)
              : null;
          final potentialLevel = profile["potential_level"] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white24,
                      backgroundImage: profile["avatar_url"] != null
                          ? NetworkImage(profile["avatar_url"] as String)
                          : null,
                      child: profile["avatar_url"] == null
                          ? const Icon(Icons.person, color: Colors.white54)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile["display_name"] as String? ?? "-",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "@" +
                                ((profile["tiktok_username"] as String?) ??
                                    (profile["tiktok_creator_id"] as String?) ??
                                    "-"),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          if (catData is Map)
                            Text(
                              catData["name"] as String? ?? "-",
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metricChip(
                      Icons.diamond,
                      (stats?["diamonds"] as num?)?.toString() ?? "0",
                    ),
                    _metricChip(
                      Icons.calendar_today,
                      (stats?["days_live"] as num?)?.toString() ?? "0",
                    ),
                    _metricChip(
                      Icons.schedule,
                      ((stats?["hours_live"] as num?)?.toStringAsFixed(0) ??
                              "0") +
                          "h",
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _actionSection(agencyId, agencyManagers),
                const SizedBox(height: 16),
                _infoRow(
                  "Dias na agência",
                  DateTime.now().difference(joinedAt).inDays.toString(),
                ),
                _infoRow(
                  "Última live",
                  lastLiveAt != null
                      ? lastLiveAt.toLocal().toString().substring(0, 16)
                      : "Nunca",
                ),
                _infoRow(
                  "Gestor responsável",
                  managerData is Map
                      ? (managerData["login_email"] as String? ?? "-")
                      : "Sem gestor",
                ),
                const SizedBox(height: 8),
                _potentialSection(potentialLevel),
                const SizedBox(height: 12),
                _diamondEvolutionSection(
                  (stats?["diamonds"] as num?) ?? 0,
                  diamondsLastMonth,
                ),
                const SizedBox(height: 16),

                const Text(
                  "Próxima ação",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                if (nextAction != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A0BD4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF7A0BD4).withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nextAction.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              if (nextAction.dueAt != null)
                                Text(
                                  nextAction.dueAt!
                                      .toLocal()
                                      .toString()
                                      .substring(0, 16),
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.check_circle_outline,
                            color: Colors.greenAccent,
                          ),
                          tooltip: "Concluir",
                          onPressed: () => _completeNextAction(nextAction.id),
                        ),
                      ],
                    ),
                  )
                else
                  const Text(
                    "Nenhuma ação pendente.",
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nextActionController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Nova ação",
                          labelStyle: TextStyle(color: Colors.white54),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String?>(
                      value: _nextActionType,
                      hint: const Text(
                        "Tipo",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      dropdownColor: const Color(0xFF1A1A1A),
                      underline: const SizedBox.shrink(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      items: activityTypes
                          .map(
                            (t) => DropdownMenuItem<String?>(
                              value: t.key,
                              child: Text(t.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _nextActionType = value),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.event,
                        size: 18,
                        color: _nextActionDate != null
                            ? const Color(0xFF7A0BD4)
                            : Colors.white54,
                      ),
                      tooltip: "Definir data",
                      onPressed: _pickNextActionDate,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: Color(0xFF7A0BD4),
                      ),
                      onPressed: _saving
                          ? null
                          : () => _saveNextAction(agencyId, assignedManagerId),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (checklist != null) ...[
                  Text(
                    "Checklist -- " + (checklist["stageName"] as String),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...(checklist["items"] as List<Map<String, dynamic>>).map((
                    item,
                  ) {
                    final itemKey = item["item_key"] as String;
                    final progress =
                        checklist["progress"] as Map<String, dynamic>;
                    final done = progress[itemKey] == true;
                    return CheckboxListTile(
                      value: done,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: Colors.greenAccent,
                      onChanged: (_) => _toggleChecklistItem(
                        checklist["phaseKey"] as String,
                        checklist["stageKey"] as String,
                        itemKey,
                        done,
                      ),
                      title: Text(
                        item["label"] as String,
                        style: TextStyle(
                          color: done ? Colors.white : Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                const Text(
                  "Histórico",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                if (history.isEmpty)
                  const Text(
                    "Nenhum registro ainda.",
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  )
                else
                  ...history.take(15).map((h) {
                    final date = DateTime.parse(
                      h["created_at"] as String,
                    ).toLocal().toString().substring(0, 16);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h["label"] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if ((h["detail"] as String?)?.isNotEmpty == true)
                            Text(
                              h["detail"] as String,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          Text(
                            date,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                TextField(
                  controller: _obsController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Adicionar observação",
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _saveObservation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A0BD4),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Salvar"),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  static const _revisarEmOptions = [3, 5, 7, 10, 15, 30];

  /// "Registrar Ação" -- mesma acao principal da tela Gestao de Streamers
  /// (streamer_action_dialog.dart), embutida aqui no painel: escolhe o tipo
  /// de acao, escreve o que precisa ser feito, e o streamer ja vai pra
  /// coluna daquele tipo no Kanban (registerStreamerAction,
  /// streamer_stage_service.dart).
  Widget _actionSection(String agencyId, List<Map<String, dynamic>> agencyManagers) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF7A0BD4).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF7A0BD4).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Registrar Ação",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _actionStageKey,
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              isDense: true,
              labelText: "Tipo de ação",
              labelStyle: TextStyle(color: Colors.white54),
            ),
            items: streamerStages
                .map(
                  (s) => DropdownMenuItem(
                    value: s.key,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(s.icon, size: 14, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(s.label),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(
              () => _actionStageKey = v ?? streamerStages.first.key,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _actionNoteController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: "O que precisa ser feito",
              labelStyle: TextStyle(color: Colors.white54),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                "Realizado por",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: _actionPerformedById,
                dropdownColor: const Color(0xFF1A1A1A),
                underline: const SizedBox.shrink(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                hint: const Text(
                  "Eu mesmo",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                items: agencyManagers
                    .map(
                      (m) => DropdownMenuItem<String?>(
                        value: m["id"] as String,
                        child: Text(m["login_email"] as String? ?? "-"),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _actionPerformedById = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                "Revisar em",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _actionRevisarEmDias,
                dropdownColor: const Color(0xFF1A1A1A),
                underline: const SizedBox.shrink(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                items: _revisarEmOptions
                    .map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(d.toString() + " dias"),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _actionRevisarEmDias = v ?? 5),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _actionSaving
                    ? null
                    : () => _registerAction(agencyId, agencyManagers),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A0BD4),
                  foregroundColor: Colors.white,
                ),
                child: Text(_actionSaving ? "Salvando..." : "Registrar"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Texto simples com seta -- de proposito nao e um grafico (fora do
  /// escopo desta fase), so o mesmo numero de crescimento que a lista ja
  /// calcula (GestorStreamerRow.growth), reaproveitado aqui no painel.
  Widget _diamondEvolutionSection(num diamonds, num? diamondsLastMonth) {
    if (diamondsLastMonth == null) {
      return Row(
        children: [
          const SizedBox(
            width: 130,
            child: Text(
              "Evolução diamantes",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          const Expanded(
            child: Text(
              "Sem mês anterior fechado",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      );
    }
    final growth = diamonds - diamondsLastMonth;
    final up = growth >= 0;
    return Row(
      children: [
        const SizedBox(
          width: 130,
          child: Text(
            "Evolução diamantes",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            (up ? "▲ +" : "▼ ") +
                growth.toString() +
                " (mês anterior: " +
                diamondsLastMonth.toString() +
                ")",
            style: TextStyle(
              color: up ? Colors.greenAccent : Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _potentialSection(String? current) {
    Widget option(String? level, String label) {
      final selected = current == level;
      return ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        selectedColor: potentialColor(level).withOpacity(0.3),
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
        onSelected: (_) => _setPotential(level),
      );
    }

    return Row(
      children: [
        const SizedBox(
          width: 130,
          child: Text(
            "Potencial",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            children: [
              option("alto", "Alto"),
              option("medio", "Médio"),
              option("baixo", "Baixo"),
            ],
          ),
        ),
      ],
    );
  }
}
