import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../recruiter/lead_category_icons.dart";
import "onboarding_phase_service.dart";
import "onboarding_new_agenciado_dialog.dart";
import "onboarding_stage_config_dialog.dart";
import "onboarding_card_edit_dialog.dart";
import "onboarding_materials_page.dart";
import "../recruiter/lead_handoff_dialog.dart" show propagateManagerToProfile;

Color _hexToColor(String hex) {
  final cleaned = hex.replaceFirst("#", "");
  return Color(int.parse("FF" + cleaned, radix: 16));
}

const _categoryFilterOptions = [
  ("todos", "Todos"),
  ("batalha", "Batalha"),
  ("musico", "Musica"),
  ("gamer", "Games"),
];

const _movementBucketOptions = [
  ("andamento", "Em andamento", Colors.greenAccent),
  ("parado_3", "Parado 3 dias", Colors.amber),
  ("parado_5", "Parado 5 dias", Colors.orangeAccent),
  ("parado_7", "Parado 7 dias", Colors.deepOrangeAccent),
  ("inativo", "Inativo 7+ dias", Colors.redAccent),
];

/// Bucket de movimentacao a partir de stage_changed_at: 0-2 dias = em
/// andamento, 3-4 = parado 3 dias, 5-6 = parado 5 dias, 7 = parado 7 dias,
/// 8+ = inativo. Ajustavel aqui se as faixas mudarem no futuro.
String _movementBucket(DateTime stageChangedAt) {
  final days = DateTime.now().difference(stageChangedAt).inDays;
  if (days <= 2) return "andamento";
  if (days <= 4) return "parado_3";
  if (days <= 6) return "parado_5";
  if (days == 7) return "parado_7";
  return "inativo";
}

const _readyToAdvanceLabel = "Pronto para avancar de etapa";

/// "Proxima acao" do card: primeiro item obrigatorio ainda nao concluido
/// na etapa atual (na ordem configurada). Se a etapa nao tem checklist
/// (dia_0/avaliacao) ou todos os itens ja estao concluidos, indica que o
/// card esta pronto para avancar. Mostrado tanto no board quanto no
/// detalhe do card -- assim o gestor sabe imediatamente o que fazer, sem
/// precisar conferir o checklist item a item.
String? _nextActionFor(String streamerId, String stageKey, Map<String, List<Map<String, dynamic>>> itemsByStage, Map<String, Map<String, bool>> checklistProgress) {
  final items = itemsByStage[stageKey] ?? [];
  if (items.isEmpty) return null;
  final progress = checklistProgress[streamerId + "|" + stageKey] ?? {};
  for (final it in items) {
    if (progress[it["item_key"]] != true) return it["label"] as String?;
  }
  return _readyToAdvanceLabel;
}

class OnboardingPhaseKanbanPage extends StatefulWidget {
  const OnboardingPhaseKanbanPage({super.key});

  @override
  State<OnboardingPhaseKanbanPage> createState() => _OnboardingPhaseKanbanPageState();
}

class _OnboardingPhaseKanbanPageState extends State<OnboardingPhaseKanbanPage> {
  bool _loading = true;
  String? _errorMessage;
  String _agencyId = "";
  bool _canManage = false;
  List<Map<String, dynamic>> _agencyManagers = [];
  Set<String> _selectedManagerIds = {};

  List<Map<String, dynamic>> _stages = [];
  Map<String, List<Map<String, dynamic>>> _itemsByStage = {};
  List<Map<String, dynamic>> _cards = [];
  Map<String, Map<String, bool>> _checklistProgress = {};
  Map<String, List<Map<String, dynamic>>> _cardManagers = {};

  String _categoryFilter = "todos";
  String _periodFilter = "todos";
  String? _movementFilter;
  bool _showArchived = false;

  final _horizontalController = ScrollController();

  String get _userId => Supabase.instance.client.auth.currentUser!.id;

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
      final userId = _userId;
      final me = await client.from("managers").select("agency_id, role").eq("id", userId).single();
      final agencyId = me["agency_id"] as String;
      final canManage = me["role"] == "coordenador" || me["role"] == "admin";

      final agencyManagers = await client.from("managers").select("id, login_email, photo_url").eq("agency_id", agencyId).order("login_email", ascending: true);

      if (_selectedManagerIds.isEmpty) _selectedManagerIds = {userId};

      await seedOnboardingPhaseStages(agencyId: agencyId);

      final stageRows = await client
          .from("streamer_phase_stages")
          .select()
          .eq("agency_id", agencyId)
          .eq("phase_key", onboardingPhaseKey)
          .eq("is_active", true)
          .order("order_index", ascending: true);
      final stages = (stageRows as List).cast<Map<String, dynamic>>();

      final itemRows = await client
          .from("streamer_phase_checklist_items")
          .select()
          .eq("agency_id", agencyId)
          .eq("phase_key", onboardingPhaseKey)
          .eq("is_active", true)
          .order("order_index", ascending: true);
      final itemsByStage = <String, List<Map<String, dynamic>>>{};
      for (final it in (itemRows as List)) {
        itemsByStage.putIfAbsent(it["stage_key"] as String, () => []).add(it as Map<String, dynamic>);
      }

      final effectiveManagerIds = (canManage && _selectedManagerIds.isNotEmpty) ? _selectedManagerIds.toList() : [userId];

      final linkRows = await client
          .from("streamer_phase_progress_managers")
          .select("progress_id")
          .inFilter("manager_id", effectiveManagerIds);
      final progressIds = (linkRows as List).map((r) => r["progress_id"] as String).toSet().toList();

      var cards = <Map<String, dynamic>>[];
      var checklistProgress = <String, Map<String, bool>>{};
      var cardManagers = <String, List<Map<String, dynamic>>>{};

      if (progressIds.isNotEmpty) {
        final progressRows = await client
            .from("streamer_phase_progress")
            .select()
            .inFilter("id", progressIds)
            .eq("phase_key", onboardingPhaseKey)
            .filter("completed_at", "is", null)
            .filter("archived_at", _showArchived ? "not.is" : "is", null)
            // Ordem deterministica -- sem isso, o Postgres pode devolver as
            // linhas em ordem diferente a cada load, e o ListView (sem key
            // por item) pode reaproveitar o estado interno do Draggable
            // errado ao recompor a lista, corrompendo a renderizacao de um
            // card que nem foi editado.
            .order("id", ascending: true);
        final progressList = (progressRows as List).cast<Map<String, dynamic>>();

        if (progressList.isNotEmpty) {
          final streamerIds = progressList.where((p) => p["streamer_id"] != null).map((p) => p["streamer_id"] as String).toList();
          final leadIds = progressList.where((p) => p["streamer_id"] == null && p["lead_id"] != null).map((p) => p["lead_id"] as String).toList();

          final profiles = streamerIds.isEmpty
              ? []
              : await client
                  .from("profiles")
                  .select("id, display_name, tiktok_creator_id, avatar_url, joined_at, phone, email, category_id, streamer_categories(name, icon_key)")
                  .inFilter("id", streamerIds);
          final profileMap = {for (final p in (profiles as List)) p["id"] as String: p as Map<String, dynamic>};

          final statsRows = streamerIds.isEmpty
              ? []
              : await client.from("streamer_stats").select("streamer_id, days_live, hours_live, diamonds").inFilter("streamer_id", streamerIds);
          final statsMap = {for (final s in (statsRows as List)) s["streamer_id"] as String: s as Map<String, dynamic>};

          final leadsRows = leadIds.isEmpty
              ? []
              : await client.from("leads").select("id, name, tiktok_username, category_interest, phone").inFilter("id", leadIds);
          final leadMap = {for (final l in (leadsRows as List)) l["id"] as String: l as Map<String, dynamic>};

          final progressRowsChecklist = streamerIds.isEmpty
              ? []
              : await client
                  .from("streamer_phase_checklist_progress")
                  .select("streamer_id, stage_key, item_key, done")
                  .eq("phase_key", onboardingPhaseKey)
                  .inFilter("streamer_id", streamerIds);
          for (final r in (progressRowsChecklist as List)) {
            final key = (r["streamer_id"] as String) + "|" + (r["stage_key"] as String);
            checklistProgress.putIfAbsent(key, () => {})[r["item_key"] as String] = r["done"] == true;
          }

          final managerLinkRows = await client
              .from("streamer_phase_progress_managers")
              .select("progress_id, manager_id, managers!streamer_phase_progress_managers_manager_id_fkey(login_email, photo_url)")
              .inFilter("progress_id", progressList.map((p) => p["id"] as String).toList());
          for (final r in (managerLinkRows as List)) {
            final progressId = r["progress_id"] as String;
            final managerData = r["managers"];
            cardManagers.putIfAbsent(progressId, () => []).add({
              "managerId": r["manager_id"],
              "email": managerData is Map ? managerData["login_email"] as String? : null,
              "photoUrl": managerData is Map ? managerData["photo_url"] as String? : null,
            });
          }

          cards = progressList.map((p) {
            final streamerId = p["streamer_id"] as String?;
            final stageKey = p["stage_key"] as String;
            if (streamerId != null) {
              final profile = profileMap[streamerId] ?? {};
              final catData = profile["streamer_categories"];
              return {
                "progressId": p["id"],
                "streamerId": streamerId,
                "leadId": null,
                "isLeadOnly": false,
                "stageKey": stageKey,
                "displayName": profile["display_name"] ?? "-",
                "tiktokId": profile["tiktok_creator_id"],
                "phone": profile["phone"],
                "email": profile["email"],
                "categoryId": profile["category_id"],
                "avatarUrl": profile["avatar_url"],
                "joinedAt": profile["joined_at"],
                "startedAt": p["started_at"],
                "stageChangedAt": p["stage_changed_at"],
                "categoryName": catData is Map ? catData["name"] as String? : null,
                "categoryIconKey": catData is Map ? catData["icon_key"] as String? : null,
                "outcome": p["outcome"],
                "nextAction": _nextActionFor(streamerId, stageKey, itemsByStage, checklistProgress),
                "monthDays": statsMap[streamerId]?["days_live"],
                "monthHours": statsMap[streamerId]?["hours_live"],
                "monthDiamonds": statsMap[streamerId]?["diamonds"],
              };
            }
            final lead = leadMap[p["lead_id"]] ?? {};
            return {
              "progressId": p["id"],
              "streamerId": null,
              "leadId": p["lead_id"],
              "isLeadOnly": true,
              "stageKey": stageKey,
              "displayName": lead["name"] ?? "-",
              "tiktokId": lead["tiktok_username"],
              "phone": lead["phone"],
              "email": null,
              "categoryId": null,
              "avatarUrl": null,
              "joinedAt": null,
              "startedAt": p["started_at"],
              "stageChangedAt": p["stage_changed_at"],
              "categoryName": lead["category_interest"],
              "categoryIconKey": null,
              "outcome": p["outcome"],
              "nextAction": "Vincular streamer oficial (\"Vincular Streamer\" em Streamers Agenciados)",
            };
          }).toList();
        }
      }

      setState(() {
        _agencyId = agencyId;
        _canManage = canManage;
        _agencyManagers = agencyManagers.cast<Map<String, dynamic>>();
        _stages = stages;
        _itemsByStage = itemsByStage;
        _cards = cards;
        _checklistProgress = checklistProgress;
        _cardManagers = cardManagers;
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

  String _stageName(String stageKey) => _stages.firstWhere((s) => s["stage_key"] == stageKey, orElse: () => {"name": stageKey})["name"] as String;

  bool _inPeriod(DateTime startedAt) {
    if (_periodFilter == "todos") return true;
    final now = DateTime.now();
    if (_periodFilter == "semana") {
      final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      return !startedAt.isBefore(startOfWeek);
    }
    if (_periodFilter == "mes") {
      final startOfMonth = DateTime(now.year, now.month, 1);
      return !startedAt.isBefore(startOfMonth);
    }
    return true;
  }

  List<Map<String, dynamic>> get _visibleCards {
    return _cards.where((c) {
      if (_categoryFilter != "todos" && c["categoryIconKey"] != _categoryFilter) return false;
      if (!_showArchived) {
        final startedAt = c["startedAt"] as String?;
        if (startedAt != null && !_inPeriod(DateTime.parse(startedAt))) return false;
        if (_movementFilter != null) {
          final stageChangedAt = c["stageChangedAt"] as String?;
          if (stageChangedAt == null || _movementBucket(DateTime.parse(stageChangedAt)) != _movementFilter) return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _moveCard(Map<String, dynamic> card, String newStageKey) async {
    if (card["isLeadOnly"] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vincule o streamer oficial (\"Vincular Streamer\" em Streamers Agenciados) antes de mover este card.")),
        );
      }
      return;
    }
    final streamerId = card["streamerId"] as String;
    final oldStageKey = card["stageKey"] as String;
    if (oldStageKey == newStageKey) return;

    final progressId = card["progressId"] as String;
    final index = _cards.indexWhere((c) => c["progressId"] == progressId);
    if (index == -1) return;
    setState(() => _cards[index]["stageKey"] = newStageKey);

    final client = Supabase.instance.client;
    final userId = _userId;
    try {
      await client.from("streamer_phase_progress").update({
        "stage_key": newStageKey,
        "stage_changed_at": DateTime.now().toIso8601String(),
      }).eq("id", card["progressId"]);
    } catch (e) {
      setState(() => _cards[index]["stageKey"] = oldStageKey);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao mover: " + e.toString())));
      return;
    }
    // Registro de historico -- best effort: a etapa ja mudou de verdade
    // (acima), nao pode reverter o card na tela so porque o log falhou.
    try {
      await client.from("streamer_phase_history").insert({
        "streamer_id": streamerId,
        "phase_key": onboardingPhaseKey,
        "action": "mudanca_etapa",
        "detail": _stageName(oldStageKey) + " → " + _stageName(newStageKey),
        "performed_by": userId,
      });
    } catch (_) {}
  }

  Future<void> _archivePreviousPeriod() async {
    final toArchive = _cards.where((c) {
      final startedAt = c["startedAt"] as String?;
      return startedAt != null && !_inPeriod(DateTime.parse(startedAt));
    }).toList();
    if (toArchive.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nenhum card fora do periodo selecionado para arquivar.")));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Arquivar cards anteriores", style: TextStyle(color: Colors.white)),
        content: Text(
          "Isso vai arquivar " + toArchive.length.toString() + " card(s) fora do periodo selecionado. Eles saem do board mas continuam consultaveis em \"Arquivados\".",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            child: const Text("Arquivar"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await archiveOnboardingCards(progressIds: toArchive.map((c) => c["progressId"] as String).toList(), performedBy: _userId);
    _load();
  }

  Future<void> _unarchive(Map<String, dynamic> card) async {
    await unarchiveOnboardingCard(progressId: card["progressId"] as String, performedBy: _userId);
    _load();
  }

  static const _outcomeLabels = {
    "aprovado": "Aprovado",
    "revisao": "Revisao",
    "desligado": "Desligado",
  };

  Future<void> _evaluateCard(Map<String, dynamic> card, String outcome) async {
    final label = _outcomeLabels[outcome] ?? outcome;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text("Confirmar: " + label, style: const TextStyle(color: Colors.white)),
        content: Text(
          outcome == "desligado"
              ? (card["displayName"] as String) + " sera marcado como desligado e o streamer sera desativado da agencia. Confirma?"
              : outcome == "aprovado"
                  ? (card["displayName"] as String) + " sera aprovado e o Onboarding 0-15 Dias sera concluido. Confirma?"
                  : (card["displayName"] as String) + " ficara em revisao, com acompanhamento estendido. Confirma?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            child: const Text("Confirmar"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await evaluateOnboardingCard(
      progressId: card["progressId"] as String,
      streamerId: card["streamerId"] as String,
      outcome: outcome,
      performedBy: _userId,
    );
    _load();
  }

  /// Reconfere se o lead ja foi oficialmente vinculado a um streamer
  /// (leads.converted_streamer_id) e, se sim, promove o card na hora --
  /// sem depender do recrutador repetir nenhuma acao. Cobre tanto o caso
  /// de o vinculo ter acontecido enquanto o card ainda nao tinha sido
  /// atualizado quanto casos antigos que ficaram presos como "pre-vinculo".
  Future<void> _checkAndPromoteLink(Map<String, dynamic> card) async {
    final leadId = card["leadId"] as String?;
    if (leadId == null) return;
    final client = Supabase.instance.client;
    try {
      final lead = await client.from("leads").select("converted_streamer_id").eq("id", leadId).maybeSingle();
      var streamerId = lead?["converted_streamer_id"] as String?;
      if (streamerId == null) {
        if (!mounted) return;
        // Recrutador ainda nao vinculou -- deixa o proprio gestor buscar e
        // vincular o streamer oficial, sem depender de mais ninguem.
        streamerId = await showDialog<String>(context: context, builder: (context) => _GestorVincularStreamerDialog(leadId: leadId));
        if (streamerId == null) return;
      }
      await createOnboardingPhaseCardIfNeeded(streamerId: streamerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vinculo atualizado! O card ja mostra o streamer oficial."), backgroundColor: Colors.greenAccent),
        );
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao verificar vinculo: " + e.toString())));
    }
  }

  /// Clique no nome do streamer, no card: em vez de despejar tudo de uma
  /// vez (metricas, materiais, historico, grupo...) num dialog so, abre um
  /// pequeno seletor com acoes focadas -- assim o gestor ve so o que
  /// precisa no momento, sem se perder em informacao demais.
  void _openFichaCompleta(Map<String, dynamic> card) {
    if (card["isLeadOnly"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Streamer ainda nao vinculado oficialmente. Use \"Vincular Streamer\" em Streamers Agenciados (area do Recrutador) para liberar as informacoes completas."),
          action: SnackBarAction(label: "Verificar", onPressed: () => _checkAndPromoteLink(card)),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => _StreamerQuickInfoDialog(
        streamerId: card["streamerId"] as String,
        streamerName: card["displayName"] as String,
        stages: _stages,
        agencyId: _agencyId,
      ),
    );
  }

  void _openDetail(Map<String, dynamic> card) {
    if (card["isLeadOnly"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Streamer ainda nao vinculado oficialmente. Use \"Vincular Streamer\" em Streamers Agenciados (area do Recrutador) para liberar o checklist completo."),
          action: SnackBarAction(label: "Verificar", onPressed: () => _checkAndPromoteLink(card)),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => _OnboardingCardDetailDialog(
        streamerId: card["streamerId"] as String,
        streamerName: card["displayName"] as String,
        categoryName: card["categoryName"] as String?,
        categoryIconKey: card["categoryIconKey"] as String?,
        stages: _stages,
        itemsByStage: _itemsByStage,
        progressId: card["progressId"] as String,
      ),
    ).then((changed) {
      if (changed == true) _load();
    });
  }

  // Seletor de gestores responsaveis aberto direto do card (+ / - ao lado
  // do nick), sem precisar abrir o dialog grande de detalhe -- atualiza
  // so o _cardManagers local pra nao recarregar o board inteiro por causa
  // de 1 toggle.
  void _openManagerPickerForCard(Map<String, dynamic> card) {
    final progressId = card["progressId"] as String;
    final currentIds = (_cardManagers[progressId] ?? []).map((m) => m["managerId"] as String).toSet();
    showDialog(
      context: context,
      builder: (context) => _ManagerPickerDialog(
        agencyManagers: _agencyManagers,
        selectedIds: currentIds,
        canManageAll: _canManage,
        onToggle: (managerId, addNow) async {
          final userId = _userId;
          if (addNow) {
            await addManagersToCard(progressId: progressId, managerIds: [managerId], addedBy: userId);
            final m = _agencyManagers.firstWhere((mgr) => mgr["id"] == managerId, orElse: () => {});
            setState(() {
              _cardManagers.putIfAbsent(progressId, () => []).add({
                "managerId": managerId,
                "email": m["login_email"],
                "photoUrl": m["photo_url"],
              });
            });
          } else {
            await removeManagerFromCard(progressId: progressId, managerId: managerId);
            setState(() {
              _cardManagers[progressId]?.removeWhere((mgr) => mgr["managerId"] == managerId);
            });
          }
        },
      ),
    );
  }

  void _openEditCard(Map<String, dynamic> card) {
    showDialog<bool>(
      context: context,
      builder: (context) => OnboardingCardEditDialog(
        isLeadOnly: card["isLeadOnly"] == true,
        streamerId: card["streamerId"] as String?,
        leadId: card["leadId"] as String?,
        initialName: card["displayName"] as String,
        initialTiktok: card["tiktokId"] as String?,
        initialPhone: card["phone"] as String?,
        initialEmail: card["email"] as String?,
        initialCategoryId: card["categoryId"] as String?,
        initialCategoryInterest: card["isLeadOnly"] == true ? card["categoryName"] as String? : null,
      ),
    ).then((changed) {
      if (changed == true) _load();
    });
  }

  Future<void> _confirmDeleteCard(Map<String, dynamic> card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Excluir card", style: TextStyle(color: Colors.white)),
        content: Text(
          "Isso remove " + (card["displayName"] as String) + " do Onboarding 0-15 Dias. O cadastro do streamer/lead nao e apagado, so o acompanhamento deste card. Confirma?",
          style: const TextStyle(color: Colors.white70),
        ),
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
    await deleteOnboardingCard(progressId: card["progressId"] as String);
    _load();
  }

  void _openNewAgenciado() {
    showDialog(context: context, builder: (context) => const OnboardingNewAgenciadoDialog()).then((created) {
      if (created == true) _load();
    });
  }

  void _openStageConfig() {
    showDialog(context: context, builder: (context) => OnboardingStageConfigDialog(agencyId: _agencyId)).then((changed) {
      if (changed == true) _load();
    });
  }

  Widget _collaboratorSelector() {
    if (!_canManage) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Colaboradores", style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _agencyManagers.map((m) {
              final id = m["id"] as String;
              final selected = _selectedManagerIds.contains(id);
              return FilterChip(
                label: Text(m["login_email"] as String, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 12)),
                selected: selected,
                selectedColor: const Color(0xFF7A0BD4),
                backgroundColor: Colors.white.withOpacity(0.05),
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedManagerIds.add(id);
                    } else {
                      _selectedManagerIds.remove(id);
                    }
                  });
                  _load();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _filtersRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ..._categoryFilterOptions.map((opt) {
          final selected = _categoryFilter == opt.$1;
          return ChoiceChip(
            label: Text(opt.$2, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 12)),
            selected: selected,
            selectedColor: const Color(0xFF7A0BD4),
            backgroundColor: Colors.white.withOpacity(0.05),
            onSelected: (_) => setState(() => _categoryFilter = opt.$1),
          );
        }),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: _periodFilter,
          dropdownColor: const Color(0xFF1A1A1A),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          underline: Container(height: 1, color: Colors.white24),
          items: const [
            DropdownMenuItem(value: "todos", child: Text("Todo periodo")),
            DropdownMenuItem(value: "semana", child: Text("Esta semana")),
            DropdownMenuItem(value: "mes", child: Text("Este mes")),
          ],
          onChanged: (v) => setState(() => _periodFilter = v ?? "todos"),
        ),
        if (_canManage && _periodFilter != "todos" && !_showArchived)
          TextButton.icon(
            onPressed: _archivePreviousPeriod,
            icon: const Icon(Icons.archive_outlined, size: 16, color: Colors.white70),
            label: const Text("Arquivar anteriores", style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _showArchived = !_showArchived;
              _movementFilter = null;
            });
            _load();
          },
          icon: Icon(_showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined, size: 16, color: Colors.white70),
          label: Text(_showArchived ? "Ver board" : "Ver arquivados", style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _movementFilterRow() {
    if (_showArchived) return const SizedBox.shrink();
    final counts = <String, int>{};
    for (final c in _visibleCardsIgnoringMovement) {
      final stageChangedAt = c["stageChangedAt"] as String?;
      if (stageChangedAt == null) continue;
      final bucket = _movementBucket(DateTime.parse(stageChangedAt));
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _movementBucketOptions.map((opt) {
          final key = opt.$1;
          final label = opt.$2;
          final color = opt.$3;
          final count = counts[key] ?? 0;
          final selected = _movementFilter == key;
          return FilterChip(
            label: Text(label + " (" + count.toString() + ")", style: TextStyle(color: selected ? Colors.black : color, fontSize: 11, fontWeight: FontWeight.bold)),
            selected: selected,
            selectedColor: color,
            backgroundColor: color.withOpacity(0.12),
            side: BorderSide(color: color),
            onSelected: (v) => setState(() => _movementFilter = v ? key : null),
          );
        }).toList(),
      ),
    );
  }

  List<Map<String, dynamic>> get _visibleCardsIgnoringMovement {
    return _cards.where((c) {
      if (_categoryFilter != "todos" && c["categoryIconKey"] != _categoryFilter) return false;
      final startedAt = c["startedAt"] as String?;
      if (startedAt != null && !_inPeriod(DateTime.parse(startedAt))) return false;
      return true;
    }).toList();
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

    final visibleCards = _visibleCards;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Onboarding 0-15 Dias", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _load),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _openNewAgenciado,
              icon: const Icon(Icons.person_add_alt_1, size: 16),
              label: const Text("Novo Agenciado"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            ),
            if (_canManage) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white70),
                tooltip: "Configurar colunas",
                onPressed: _openStageConfig,
              ),
            ],
          ]),
          const SizedBox(height: 4),
          const Text(
            "Acompanhamento automatico dos primeiros 15 dias — os cards entram sozinhos quando o recrutador conclui o onboarding.",
            style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          _collaboratorSelector(),
          _filtersRow(),
          _movementFilterRow(),
          const SizedBox(height: 16),
          if (_showArchived)
            Expanded(child: _archivedList(visibleCards))
          else if (_stages.isEmpty)
            const Expanded(child: Center(child: Text("Nenhuma etapa configurada.", style: TextStyle(color: Colors.white54))))
          else
            Expanded(child: _board(visibleCards)),
        ],
      ),
    );
  }

  Widget _archivedList(List<Map<String, dynamic>> cards) {
    if (cards.isEmpty) return const Center(child: Text("Nenhum card arquivado.", style: TextStyle(color: Colors.white54)));
    return ListView.builder(
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return Card(
          color: Colors.white.withOpacity(0.05),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              backgroundImage: card["avatarUrl"] != null ? NetworkImage(card["avatarUrl"] as String) : null,
              child: card["avatarUrl"] == null ? const Icon(Icons.person, color: Colors.white54, size: 16) : null,
            ),
            title: Text(card["displayName"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text("Etapa: " + _stageName(card["stageKey"] as String), style: const TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: TextButton(onPressed: () => _unarchive(card), child: const Text("Reativar")),
          ),
        );
      },
    );
  }

  Widget _board(List<Map<String, dynamic>> visibleCards) {
    return Scrollbar(
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
                final columnCards = visibleCards.where((c) => c["stageKey"] == stageKey).toList();
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
                                  final isLeadOnly = card["isLeadOnly"] == true;
                                  final complete = isLeadOnly ? false : _isStageComplete(card["streamerId"] as String, stageKey);
                                  final cardManagerList = _cardManagers[card["progressId"]] ?? const [];
                                  final isEvaluationStage = stageKey == "avaliacao";

                                  if (isLeadOnly) {
                                    return GestureDetector(
                                      key: ValueKey(card["progressId"]),
                                      onTap: () => _openDetail(card),
                                      child: _OnboardingCard(
                                        card: card,
                                        stageColor: stageColor,
                                        stageComplete: complete,
                                        managers: cardManagerList,
                                        isLeadOnly: true,
                                        onEdit: () => _openEditCard(card),
                                        onDelete: () => _confirmDeleteCard(card),
                                        onOpenFicha: () => _openFichaCompleta(card),
                                        onCheckLink: () => _checkAndPromoteLink(card),
                                        onOpenMaterial: () => _openDetail(card),
                                        onManageManagers: () => _openManagerPickerForCard(card),
                                      ),
                                    );
                                  }

                                  return Draggable<Map<String, dynamic>>(
                                    key: ValueKey(card["progressId"]),
                                    data: card,
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: SizedBox(width: 220, child: _OnboardingCard(card: card, stageColor: stageColor, stageComplete: complete, managers: cardManagerList)),
                                    ),
                                    childWhenDragging: Opacity(opacity: 0.3, child: _OnboardingCard(card: card, stageColor: stageColor, stageComplete: complete, managers: cardManagerList)),
                                    child: GestureDetector(
                                      onTap: () => _openDetail(card),
                                      child: _OnboardingCard(
                                        card: card,
                                        stageColor: stageColor,
                                        stageComplete: complete,
                                        managers: cardManagerList,
                                        isEvaluationStage: isEvaluationStage,
                                        onEvaluate: isEvaluationStage ? (outcome) => _evaluateCard(card, outcome) : null,
                                        onEdit: () => _openEditCard(card),
                                        onDelete: () => _confirmDeleteCard(card),
                                        onOpenFicha: () => _openFichaCompleta(card),
                                        onOpenMaterial: () => _openDetail(card),
                                        onManageManagers: () => _openManagerPickerForCard(card),
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
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final Color stageColor;
  final bool stageComplete;
  final List<Map<String, dynamic>> managers;
  final bool isEvaluationStage;
  final bool isLeadOnly;
  final void Function(String outcome)? onEvaluate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onOpenFicha;
  final VoidCallback? onCheckLink;
  final VoidCallback? onOpenMaterial;
  final VoidCallback? onManageManagers;
  const _OnboardingCard({
    required this.card,
    required this.stageColor,
    required this.stageComplete,
    this.managers = const [],
    this.isEvaluationStage = false,
    this.isLeadOnly = false,
    this.onEvaluate,
    this.onEdit,
    this.onDelete,
    this.onOpenFicha,
    this.onOpenMaterial,
    this.onManageManagers,
    this.onCheckLink,
  });

  /// Barra de "saude do prazo": verde enquanto sobra bastante tempo dos
  /// 15 dias de onboarding, amarela perto do limite, vermelha se ja
  /// passou dos 15 dias sem concluir.
  (Color, String) _deadlineHealth(int daysInAgency) {
    if (daysInAgency > 15) return (Colors.redAccent, "Passou dos 15 dias (" + daysInAgency.toString() + ")");
    if (daysInAgency >= 11) return (Colors.amber, "Perto do limite de 15 dias (dia " + daysInAgency.toString() + ")");
    return (Colors.greenAccent, "Dentro do prazo (dia " + daysInAgency.toString() + " de 15)");
  }

  // Fotos pequenas dos gestores + atalhos de adicionar/remover, direto no
  // topo do card ao lado do nick -- tirado do dialog de detalhe porque a
  // lista completa de gestores (com Chips e email por extenso) tomava
  // espaco demais ali. Aqui + e - abrem o mesmo seletor completo de
  // gestores (marcar/desmarcar), so que com dois pontos de entrada obvios.
  Widget _managerMiniControls() {
    final shown = managers.take(2).toList();
    final extra = managers.length - shown.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...shown.map((m) => Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Tooltip(
                message: (m["email"] as String?) ?? "Gestor",
                child: CircleAvatar(
                  radius: 8,
                  backgroundColor: Colors.white24,
                  backgroundImage: m["photoUrl"] != null ? NetworkImage(m["photoUrl"] as String) : null,
                  child: m["photoUrl"] == null ? const Icon(Icons.person, size: 9, color: Colors.white54) : null,
                ),
              ),
            )),
        if (extra > 0) Padding(padding: const EdgeInsets.only(left: 2), child: Text("+" + extra.toString(), style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold))),
        if (onManageManagers != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Tooltip(
              message: "Adicionar gestor",
              child: InkWell(
                onTap: onManageManagers,
                borderRadius: BorderRadius.circular(10),
                child: const Icon(Icons.add_circle, size: 14, color: Colors.greenAccent),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Tooltip(
              message: "Remover gestor",
              child: InkWell(
                onTap: onManageManagers,
                borderRadius: BorderRadius.circular(10),
                child: const Icon(Icons.remove_circle, size: 14, color: Colors.redAccent),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Envolve a construcao do card num try/catch: se algum dado inesperado
  // fizer o card quebrar, o Flutter por padrao troca por um ErrorWidget
  // quase invisivel no nosso tema escuro (texto pequeno sem fundo) -- daria
  // a impressao de "card sumiu", ainda clicavel (o GestureDetector por
  // fora continua funcionando) mas sem nada visivel. Aqui garante que
  // qualquer falha apareca como um card vermelho com o motivo, nunca em
  // branco.
  @override
  Widget build(BuildContext context) {
    try {
      return _buildContent(context);
    } catch (e) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.redAccent, width: 2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(children: [
              Icon(Icons.error_outline, size: 14, color: Colors.redAccent),
              SizedBox(width: 4),
              Text("Erro ao exibir este card", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            Text(e.toString(), style: const TextStyle(color: Colors.white38, fontSize: 9), maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ),
      );
    }
  }

  Widget _buildContent(BuildContext context) {
    final joinedAt = card["joinedAt"] as String?;
    final daysInAgency = joinedAt != null ? DateTime.now().difference(DateTime.parse(joinedAt)).inDays : null;
    final categoryIconKey = card["categoryIconKey"] as String?;
    final catColor = categoryColor(categoryIconKey);
    final outcome = card["outcome"] as String?;
    final deadline = daysInAgency != null ? _deadlineHealth(daysInAgency) : null;
    final monthDays = card["monthDays"] as num?;
    final monthHours = card["monthHours"] as num?;
    final monthDiamonds = card["monthDiamonds"] as num?;

    final baseBorderColor = stageComplete ? Colors.greenAccent : Colors.white12;
    final baseBorderWidth = stageComplete ? 2.0 : 1.0;

    // A faixa lateral (cor diferente so no lado esquerdo) nao pode fazer
    // parte do Border junto com borderRadius -- o Flutter so aceita
    // BorderRadius em bordas com cor uniforme nos 4 lados, senao a pintura
    // quebra silenciosamente (excecao so em tempo de paint, o card fica em
    // branco mas continua ocupando espaco e recebendo toque). Por isso a
    // faixa e uma camada separada (Positioned), com a borda do Container
    // uniforme e um ClipRRect por fora garantindo os cantos arredondados.
    // A cor da faixa mostra o prazo do onboarding (verde/amarelo/vermelho),
    // nao mais a categoria -- a categoria continua so no selo do avatar.
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: baseBorderColor, width: baseBorderWidth),
          ),
          child: Stack(
            children: [
              if (deadline != null) Positioned(left: 0, top: 0, bottom: 0, child: Tooltip(message: deadline.$2, child: Container(width: 4, color: deadline.$1))),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white24,
                    backgroundImage: card["avatarUrl"] != null ? NetworkImage(card["avatarUrl"] as String) : null,
                    child: card["avatarUrl"] == null ? const Icon(Icons.person, color: Colors.white54, size: 16) : null,
                  ),
                  if (categoryIconKey != null && categoryIconKey.isNotEmpty)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1A1A1A)),
                        child: Icon(categoryIcon(categoryIconKey), size: 12, color: catColor),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onOpenFicha,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              card["displayName"] as String,
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, decoration: onOpenFicha != null ? TextDecoration.underline : null),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (onOpenFicha != null) ...[
                            const SizedBox(width: 3),
                            const Icon(Icons.info_outline, size: 11, color: Color(0xFF7A0BD4)),
                          ],
                        ],
                      ),
                    ),
                    if (daysInAgency != null) Text(daysInAgency.toString() + " dias na agencia", style: const TextStyle(color: Colors.white38, fontSize: 9)),
                    if (monthDays != null || monthHours != null || monthDiamonds != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 2,
                          runSpacing: 2,
                          children: [
                            const Icon(Icons.calendar_today, size: 8, color: Colors.white24),
                            Text(monthDays?.toString() ?? "0", style: const TextStyle(color: Colors.white38, fontSize: 9)),
                            const SizedBox(width: 4),
                            const Icon(Icons.schedule, size: 8, color: Colors.white24),
                            Text((monthHours?.toString() ?? "0") + "h", style: const TextStyle(color: Colors.white38, fontSize: 9)),
                            const SizedBox(width: 4),
                            const Icon(Icons.diamond, size: 8, color: Colors.white24),
                            Text(monthDiamonds?.toString() ?? "0", style: const TextStyle(color: Colors.white38, fontSize: 9)),
                          ],
                        ),
                      ),
                    if (isLeadOnly)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.orangeAccent)),
                          child: const Text("Aguardando vinculo", style: TextStyle(color: Colors.orangeAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
              if (onEdit != null || onDelete != null || onCheckLink != null)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, size: 16, color: Colors.white38),
                  color: const Color(0xFF262626),
                  onSelected: (value) {
                    if (value == "edit") onEdit?.call();
                    if (value == "delete") onDelete?.call();
                    if (value == "checkLink") onCheckLink?.call();
                  },
                  itemBuilder: (context) => [
                    if (onCheckLink != null) const PopupMenuItem(value: "checkLink", child: Text("Verificar vinculo", style: TextStyle(color: Colors.tealAccent, fontSize: 13))),
                    if (onEdit != null) const PopupMenuItem(value: "edit", child: Text("Editar", style: TextStyle(color: Colors.white, fontSize: 13))),
                    if (onDelete != null) const PopupMenuItem(value: "delete", child: Text("Excluir", style: TextStyle(color: Colors.redAccent, fontSize: 13))),
                  ],
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                if (onOpenMaterial != null)
                  InkWell(
                    onTap: onOpenMaterial,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFF7A0BD4).withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF7A0BD4))),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.send, size: 10, color: Color(0xFF7A0BD4)),
                        SizedBox(width: 3),
                        Text("Enviar Material", style: TextStyle(color: Color(0xFF7A0BD4), fontSize: 9, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                if (managers.isNotEmpty || onManageManagers != null) _managerMiniControls(),
              ],
            ),
          ),
          if (isEvaluationStage) ...[
            const SizedBox(height: 8),
            if (outcome != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  "Decisao: " + (outcome == "aprovado" ? "Aprovado" : outcome == "desligado" ? "Desligado" : "Em revisao"),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _evaluateButton(icon: Icons.check_circle, color: Colors.greenAccent, tooltip: "Aprovado", onTap: () => onEvaluate?.call("aprovado")),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _evaluateButton(icon: Icons.hourglass_bottom, color: Colors.amber, tooltip: "Revisao", onTap: () => onEvaluate?.call("revisao")),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _evaluateButton(icon: Icons.cancel, color: Colors.redAccent, tooltip: "Desligado", onTap: () => onEvaluate?.call("desligado")),
                  ),
                ],
              ),
          ],
        ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _evaluateButton({required IconData icon, required Color color, required String tooltip, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: color)),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _OnboardingCardDetailDialog extends StatefulWidget {
  final String streamerId;
  final String streamerName;
  final String? categoryName;
  final String? categoryIconKey;
  final List<Map<String, dynamic>> stages;
  final Map<String, List<Map<String, dynamic>>> itemsByStage;
  final String progressId;
  const _OnboardingCardDetailDialog({
    required this.streamerId,
    required this.streamerName,
    required this.categoryName,
    this.categoryIconKey,
    required this.stages,
    required this.itemsByStage,
    required this.progressId,
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

    final myUserId = client.auth.currentUser!.id;
    final nicheFilter = "niche.is.null" + (widget.categoryIconKey != null && widget.categoryIconKey!.isNotEmpty ? ",niche.eq." + widget.categoryIconKey! : "");
    final materialRows = await client
        .from("training_materials")
        .select("id, title, description, link_url, file_url, image_url, author_id, managers(login_email, role)")
        .eq("scope", "acompanhamento")
        .eq("stage", "onboarding_15")
        .eq("onboarding_stage_key", stageKey)
        .or(nicheFilter)
        .eq("is_archived", false)
        .order("order_index", ascending: true);
    final materials = (materialRows as List).cast<Map<String, dynamic>>().where((m) => isMaterialVisibleTo(m, myUserId)).toList();

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
      "nextAction": _nextActionFor(widget.streamerId, stageKey, widget.itemsByStage, {widget.streamerId + "|" + stageKey: checklistProgress}),
      "history": (history as List).cast<Map<String, dynamic>>(),
    };
  }

  Future<void> _toggleItem(String stageKey, String itemKey, bool current) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final newValue = !current;

    // Atualiza a tela na hora (sem esperar a rede) e so refaz o calculo
    // local da "proxima acao" -- evita reabrir progress+checklist+material+
    // historico inteiros (4+ consultas) so por causa de 1 checkbox.
    final data = await _future;
    final checklistProgress = data["checklistProgress"] as Map<String, bool>;
    setState(() {
      checklistProgress[itemKey] = newValue;
      data["nextAction"] = _nextActionFor(widget.streamerId, stageKey, widget.itemsByStage, {widget.streamerId + "|" + stageKey: checklistProgress});
    });
    _changed = true;

    try {
      await client.from("streamer_phase_checklist_progress").upsert({
        "streamer_id": widget.streamerId,
        "phase_key": onboardingPhaseKey,
        "stage_key": stageKey,
        "item_key": itemKey,
        "done": newValue,
        "done_at": newValue ? DateTime.now().toIso8601String() : null,
        "done_by": newValue ? userId : null,
      }, onConflict: "streamer_id,phase_key,stage_key,item_key");
    } catch (e) {
      setState(() {
        checklistProgress[itemKey] = !newValue;
        data["nextAction"] = _nextActionFor(widget.streamerId, stageKey, widget.itemsByStage, {widget.streamerId + "|" + stageKey: checklistProgress});
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: " + e.toString())));
      return;
    }

    if (newValue) {
      final label = widget.itemsByStage[stageKey]?.firstWhere((it) => it["item_key"] == itemKey, orElse: () => {"label": itemKey})["label"] as String;
      // Registro de historico -- best effort: o checklist ja foi salvo
      // acima, nao pode reverter o check na tela so porque o log falhou.
      try {
        await client.from("streamer_phase_history").insert({
          "streamer_id": widget.streamerId,
          "phase_key": onboardingPhaseKey,
          "action": "checklist_item",
          "detail": label,
          "performed_by": userId,
        });
        final history = data["history"] as List<Map<String, dynamic>>;
        setState(() => history.insert(0, {"created_at": DateTime.now().toIso8601String(), "action": "checklist_item", "detail": label}));
      } catch (_) {}
    }
  }

  Future<void> _saveObservation() async {
    if (_obsController.text.trim().isEmpty) return;
    setState(() => _savingObs = true);
    final client = Supabase.instance.client;
    final detail = _obsController.text.trim();
    await client.from("streamer_phase_history").insert({
      "streamer_id": widget.streamerId,
      "phase_key": onboardingPhaseKey,
      "action": "observacao",
      "detail": detail,
      "performed_by": client.auth.currentUser!.id,
    });
    _obsController.clear();
    _changed = true;
    final data = await _future;
    final history = data["history"] as List<Map<String, dynamic>>;
    setState(() {
      history.insert(0, {"created_at": DateTime.now().toIso8601String(), "action": "observacao", "detail": detail});
      _savingObs = false;
    });
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
              if (snapshot.hasError) {
                return SizedBox(height: 300, child: Center(child: Padding(padding: const EdgeInsets.all(16), child: Text("Erro ao carregar: " + snapshot.error.toString(), style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center))));
              }
              if (!snapshot.hasData) return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
              final data = snapshot.data!;
              final stageKey = data["stageKey"] as String;
              final checklistProgress = data["checklistProgress"] as Map<String, bool>;
              final materials = data["materials"] as List<Map<String, dynamic>>;
              final nextAction = data["nextAction"] as String?;
              final history = data["history"] as List<Map<String, dynamic>>;
              final items = widget.itemsByStage[stageKey] ?? [];
              final stageName = widget.stages.firstWhere((s) => s["stage_key"] == stageKey, orElse: () => {"name": stageKey})["name"] as String;
              final myUserId = Supabase.instance.client.auth.currentUser!.id;
              final officialMaterials = materials.where((m) {
                final authorData = m["managers"];
                final role = authorData is Map ? authorData["role"] as String? : null;
                return m["author_id"] != myUserId && (role == "coordenador" || role == "admin");
              }).toList();
              final myMaterials = materials.where((m) => m["author_id"] == myUserId).toList();

              Widget materialRow(Map<String, dynamic> m) => InkWell(
                    onTap: () => openMaterialLinkOrText(context, m),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        const Icon(Icons.description_outlined, size: 14, color: Colors.tealAccent),
                        const SizedBox(width: 6),
                        Expanded(child: Text(m["title"] as String? ?? "-", style: const TextStyle(color: Colors.tealAccent, fontSize: 12, decoration: TextDecoration.underline))),
                        const Icon(Icons.open_in_new, size: 12, color: Colors.white38),
                      ]),
                    ),
                  );

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.streamerName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    if (widget.categoryName != null) Text(widget.categoryName!, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text("Etapa atual: " + stageName, style: const TextStyle(color: Color(0xFF7A0BD4), fontWeight: FontWeight.bold, fontSize: 13)),
                    if (nextAction != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amberAccent)),
                        child: Row(children: [
                          const Icon(Icons.bolt, color: Colors.amberAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("PROXIMA ACAO", style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                Text(nextAction, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ],
                    if (officialMaterials.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text("Material Oficial da Etapa", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      ...officialMaterials.map(materialRow),
                    ],
                    if (myMaterials.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text("Seu Material", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      ...myMaterials.map(materialRow),
                    ],
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
                    if (stageKey == "avaliacao")
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          "A decisao final (Aprovado / Revisao / Desligado) e feita direto no card, no board.",
                          style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(children: [
                      const Text("Ultima atualizacao", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => showDialog(context: context, builder: (context) => _StreamerHistoryDialog(streamerId: widget.streamerId, streamerName: widget.streamerName)),
                        icon: const Icon(Icons.history, size: 14, color: Color(0xFF7A0BD4)),
                        label: const Text("Ver historico completo", style: TextStyle(color: Color(0xFF7A0BD4), fontSize: 12)),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    if (history.isEmpty)
                      const Text("Sem registros ainda.", style: TextStyle(color: Colors.white38, fontSize: 12))
                    else
                      Builder(builder: (context) {
                        final h = history.first;
                        final date = DateTime.parse(h["created_at"] as String).toLocal().toString().substring(0, 16);
                        return Text("(" + date + ") " + (h["detail"] as String? ?? (h["action"] as String)), style: const TextStyle(color: Colors.white70, fontSize: 12));
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

/// Picker de gestores responsaveis do card, em dialog proprio -- tirado de
/// dentro do card de detalhe porque a lista de todos os gestores da
/// agencia (um CheckboxListTile por gestor, sempre expandida) tomava
/// espaco demais no card. Aqui fica isolado, com busca, so aberto quando
/// o usuario quer editar quem esta responsavel.
class _ManagerPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> agencyManagers;
  final Set<String> selectedIds;
  final bool canManageAll;
  final void Function(String managerId, bool addNow) onToggle;
  const _ManagerPickerDialog({
    required this.agencyManagers,
    required this.selectedIds,
    required this.canManageAll,
    required this.onToggle,
  });

  @override
  State<_ManagerPickerDialog> createState() => _ManagerPickerDialogState();
}

class _ManagerPickerDialogState extends State<_ManagerPickerDialog> {
  String _search = "";

  @override
  Widget build(BuildContext context) {
    final filtered = widget.agencyManagers.where((m) => (m["login_email"] as String).toLowerCase().contains(_search.toLowerCase())).toList();
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Gestores responsaveis", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Text("Qualquer gestor pode adicionar colegas. Remover exige coordenador/admin.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(height: 10),
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.white54), hintText: "Buscar gestor", hintStyle: TextStyle(color: Colors.white38), isDense: true),
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text("Nenhum gestor encontrado.", style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final m = filtered[index];
                          final id = m["id"] as String;
                          final checked = widget.selectedIds.contains(id);
                          final canChange = !checked || widget.canManageAll;
                          return CheckboxListTile(
                            value: checked,
                            onChanged: canChange
                                ? (v) => setState(() => widget.onToggle(id, v == true))
                                : null,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: const Color(0xFF7A0BD4),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(m["login_email"] as String, style: TextStyle(color: checked ? Colors.white : Colors.white54, fontSize: 13)),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar"))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vincular Streamer, direto do lado do Gestor -- mesmo fluxo que existe
/// em Streamers Agenciados (area do Recrutador), pra o gestor nao ficar
/// dependente do recrutador vincular o streamer oficial. Aberto quando o
/// gestor clica "Verificar vinculo" num card pre-vinculo e o lead ainda
/// nao tem streamer oficial associado. Retorna o streamerId escolhido (ou
/// null se cancelado).
class _GestorVincularStreamerDialog extends StatefulWidget {
  final String leadId;
  const _GestorVincularStreamerDialog({required this.leadId});

  @override
  State<_GestorVincularStreamerDialog> createState() => _GestorVincularStreamerDialogState();
}

class _GestorVincularStreamerDialogState extends State<_GestorVincularStreamerDialog> {
  String _search = "";
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  String? _selectedId;
  bool _saving = false;
  String? _errorMessage;

  Future<void> _doSearch(String query) async {
    setState(() {
      _search = query;
      _searching = true;
    });
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    final client = Supabase.instance.client;
    final rows = await client
        .from("profiles")
        .select("id, display_name, tiktok_creator_id, avatar_url")
        .or("display_name.ilike.%" + query + "%,tiktok_creator_id.ilike.%" + query + "%")
        .limit(20);
    if (mounted) setState(() {
      _results = (rows as List).cast<Map<String, dynamic>>();
      _searching = false;
    });
  }

  Future<void> _confirm() async {
    if (_selectedId == null) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    final client = Supabase.instance.client;
    try {
      await client.from("leads").update({"converted_streamer_id": _selectedId}).eq("id", widget.leadId);

      final gestores = await client.from("lead_onboarding_gestores").select("manager_id").eq("lead_id", widget.leadId);
      final currentGestor = (gestores as List).isNotEmpty ? (gestores.first["manager_id"] as String) : null;
      if (currentGestor != null) {
        try {
          await propagateManagerToProfile(leadId: widget.leadId, managerId: currentGestor);
        } catch (_) {}
      }

      if (mounted) Navigator.of(context).pop(_selectedId);
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = "Erro ao vincular: " + e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Vincular Streamer Oficial", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                "O recrutador ainda nao vinculou. Pesquise pelo nome ou @TikTok do cadastro oficial (ja importado da planilha).",
                style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.white54), hintText: "Nome ou @TikTok", hintStyle: TextStyle(color: Colors.white38), isDense: true),
                onChanged: _doSearch,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _searching
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? Center(child: Text(_search.trim().length < 2 ? "Digite ao menos 2 letras para buscar." : "Nenhum streamer oficial encontrado.", style: const TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center))
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final r = _results[index];
                              final selected = _selectedId == r["id"];
                              return ListTile(
                                onTap: () => setState(() => _selectedId = r["id"] as String),
                                selected: selected,
                                selectedTileColor: const Color(0xFF7A0BD4).withOpacity(0.15),
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.white24,
                                  backgroundImage: r["avatar_url"] != null ? NetworkImage(r["avatar_url"] as String) : null,
                                  child: r["avatar_url"] == null ? const Icon(Icons.person, color: Colors.white70, size: 16) : null,
                                ),
                                title: Text(r["display_name"] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                subtitle: Text("@" + (r["tiktok_creator_id"] as String? ?? "-"), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                trailing: selected ? const Icon(Icons.check_circle, color: Color(0xFF7A0BD4)) : null,
                              );
                            },
                          ),
              ),
              if (_errorMessage != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (_selectedId == null || _saving) ? null : _confirm,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: Text(_saving ? "Vinculando..." : "Confirmar vinculo"),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seletor rapido aberto ao clicar no nome do streamer no card: em vez de
/// um dialog so com tudo junto (metricas, materiais, grupo, historico...),
/// da acesso direto so ao que o gestor costuma precisar na hora --
/// informacoes do recrutamento e historico -- com o perfil completo ainda
/// disponivel a parte pra quem quiser ir mais fundo.
class _StreamerQuickInfoDialog extends StatelessWidget {
  final String streamerId;
  final String streamerName;
  final List<Map<String, dynamic>> stages;
  final String agencyId;
  const _StreamerQuickInfoDialog({required this.streamerId, required this.streamerName, required this.stages, required this.agencyId});

  Widget _actionButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: const Color(0xFF7A0BD4)),
        label: Align(alignment: Alignment.centerLeft, child: Text(label, style: const TextStyle(color: Colors.white))),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), side: const BorderSide(color: Color(0xFF7A0BD4))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(streamerName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text("O que voce quer ver?", style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 16),
              _actionButton(
                context,
                icon: Icons.assignment_ind_outlined,
                label: "Informacoes do Recrutamento",
                onTap: () {
                  Navigator.of(context).pop();
                  showDialog(context: context, builder: (context) => _RecruitmentInfoDialog(streamerId: streamerId, streamerName: streamerName));
                },
              ),
              const SizedBox(height: 8),
              _actionButton(
                context,
                icon: Icons.history,
                label: "Historico Completo",
                onTap: () {
                  Navigator.of(context).pop();
                  showDialog(context: context, builder: (context) => _StreamerHistoryDialog(streamerId: streamerId, streamerName: streamerName));
                },
              ),
              const SizedBox(height: 8),
              _actionButton(
                context,
                icon: Icons.bar_chart,
                label: "Perfil e Metricas",
                onTap: () {
                  Navigator.of(context).pop();
                  showDialog(context: context, builder: (context) => _StreamerMetricsDialog(streamerId: streamerId, streamerName: streamerName));
                },
              ),
              const SizedBox(height: 8),
              _actionButton(
                context,
                icon: Icons.checklist,
                label: "Check Materiais",
                onTap: () {
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    builder: (context) => _MaterialCheckDialog(streamerId: streamerId, streamerName: streamerName, stages: stages, agencyId: agencyId),
                  );
                },
              ),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar"))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Check Materiais: lista configuravel (via engrenagem, dentro da edicao de
/// cada etapa) que o gestor vai marcando conforme revisa os materiais com o
/// streamer. Nao trava avanco de etapa (isso e o "Checklist desta etapa",
/// tabela separada) -- e so um acompanhamento manual.
/// Mostra os itens de TODAS as etapas/dias (agrupados), nao so o da etapa
/// atual do card -- as vezes o material/informacao e passado com
/// antecedencia, e o gestor precisa poder marcar como feito mesmo antes do
/// card chegar naquele dia.
class _MaterialCheckDialog extends StatefulWidget {
  final String streamerId;
  final String streamerName;
  final List<Map<String, dynamic>> stages;
  final String agencyId;
  const _MaterialCheckDialog({required this.streamerId, required this.streamerName, required this.stages, required this.agencyId});

  @override
  State<_MaterialCheckDialog> createState() => _MaterialCheckDialogState();
}

class _MaterialCheckDialogState extends State<_MaterialCheckDialog> {
  bool _loading = true;
  bool _saving = false;
  String? _message;
  List<Map<String, dynamic>> _items = [];
  // "stage_key|item_key" -> done (chave composta pra nao colidir quando duas
  // etapas geram o mesmo item_key a partir de labels iguais).
  final Map<String, bool> _checked = {};
  // "stage_key|item_key" -> (done_at, done_by_email), so preenchido para
  // itens ja salvos.
  final Map<String, (DateTime, String?)> _confirmedInfo = {};

  String _key(Map<String, dynamic> item) => (item["stage_key"] as String) + "|" + (item["item_key"] as String);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final client = Supabase.instance.client;
    final items = await client
        .from("onboarding_material_check_items")
        .select()
        .eq("agency_id", widget.agencyId)
        .eq("phase_key", onboardingPhaseKey)
        .order("order_index", ascending: true);
    final progress = await client
        .from("onboarding_material_check_progress")
        .select("stage_key, item_key, done, done_at, done_by, managers(login_email)")
        .eq("streamer_id", widget.streamerId)
        .eq("phase_key", onboardingPhaseKey);
    _checked.clear();
    _confirmedInfo.clear();
    for (final r in (progress as List)) {
      final key = (r["stage_key"] as String) + "|" + (r["item_key"] as String);
      _checked[key] = r["done"] == true;
      if (r["done"] == true && r["done_at"] != null) {
        final managerData = r["managers"];
        _confirmedInfo[key] = (DateTime.parse(r["done_at"] as String), managerData is Map ? managerData["login_email"] as String? : null);
      }
    }
    if (mounted) {
      setState(() {
        _items = (items as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    try {
      for (final item in _items) {
        final key = _key(item);
        final isChecked = _checked[key] ?? false;
        await client.from("onboarding_material_check_progress").upsert({
          "streamer_id": widget.streamerId,
          "phase_key": onboardingPhaseKey,
          "stage_key": item["stage_key"],
          "item_key": item["item_key"],
          "done": isChecked,
          "done_at": isChecked ? DateTime.now().toIso8601String() : null,
          "done_by": isChecked ? userId : null,
        }, onConflict: "streamer_id,phase_key,stage_key,item_key");
      }
      await _load();
      if (mounted) {
        setState(() {
          _saving = false;
          _message = "Salvo com sucesso.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _message = "Erro: " + e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text("Check Materiais - " + widget.streamerName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.of(context).pop()),
              ]),
              const Text("Marque conforme for revisando materiais e informacoes com o streamer -- de qualquer dia, mesmo antes do card chegar la.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator()))
              else if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text("Nenhum item configurado ainda. Configure na engrenagem (Configurar colunas > editar a etapa > Check Materiais).", style: TextStyle(color: Colors.white38, fontSize: 12)),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.stages.where((s) => _items.any((it) => it["stage_key"] == s["stage_key"])).map((stage) {
                        final stageKey = stage["stage_key"] as String;
                        final stageItems = _items.where((it) => it["stage_key"] == stageKey).toList();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(stage["name"] as String? ?? stageKey, style: const TextStyle(color: Color(0xFF7A0BD4), fontSize: 12, fontWeight: FontWeight.bold)),
                              ...stageItems.map((item) {
                                final key = _key(item);
                                final isChecked = _checked[key] ?? false;
                                final confirmed = _confirmedInfo[key];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CheckboxListTile(
                                        value: isChecked,
                                        onChanged: (v) => setState(() => _checked[key] = v ?? false),
                                        title: Text(item["label"] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                        activeColor: const Color(0xFF7A0BD4),
                                        controlAffinity: ListTileControlAffinity.leading,
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                      ),
                                      if (isChecked && confirmed != null)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 32),
                                          child: Text(
                                            "Confirmado em " + confirmed.$1.day.toString().padLeft(2, "0") + "/" + confirmed.$1.month.toString().padLeft(2, "0") + "/" + confirmed.$1.year.toString() + (confirmed.$2 != null ? " por " + confirmed.$2! : ""),
                                            style: const TextStyle(color: Colors.white24, fontSize: 9),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_message!, style: TextStyle(color: _message!.startsWith("Erro") ? Colors.redAccent : Colors.greenAccent, fontSize: 12)),
                ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar")),
                const SizedBox(width: 8),
                if (_items.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save, size: 16),
                    label: Text(_saving ? "Salvando..." : "Salvar"),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// So as informacoes que o recrutador preencheu (handoff da Transferencia
/// para o Gestor + dados do lead) -- focado, sem misturar com metricas ou
/// historico de onboarding.
class _RecruitmentInfoDialog extends StatefulWidget {
  final String streamerId;
  final String streamerName;
  const _RecruitmentInfoDialog({required this.streamerId, required this.streamerName});

  @override
  State<_RecruitmentInfoDialog> createState() => _RecruitmentInfoDialogState();
}

class _RecruitmentInfoDialogState extends State<_RecruitmentInfoDialog> {
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    final client = Supabase.instance.client;
    final lead = await client.from("leads").select("id, created_at, converted_at, recruiter_id").eq("converted_streamer_id", widget.streamerId).maybeSingle();
    if (lead == null) return null;
    final handoff = await client.from("lead_recruitment_handoff").select().eq("lead_id", lead["id"]).maybeSingle();
    final recruiter = await client.from("managers").select("login_email").eq("id", lead["recruiter_id"] as String).maybeSingle();
    return {"lead": lead, "handoff": handoff, "recruiterEmail": recruiter?["login_email"] as String?};
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 150, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<Map<String, dynamic>?>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return SizedBox(height: 150, child: Center(child: Text("Erro: " + snapshot.error.toString(), style: const TextStyle(color: Colors.redAccent))));
              }
              final data = snapshot.data;
              final lead = data?["lead"] as Map<String, dynamic>?;
              final handoff = data?["handoff"] as Map<String, dynamic>?;
              final recruiterEmail = data?["recruiterEmail"] as String?;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Informacoes do Recrutamento", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(widget.streamerName, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 16),
                    if (lead == null)
                      const Text("Este streamer nao esta vinculado a um lead de recrutamento (cadastro antigo ou manual).", style: TextStyle(color: Colors.white54, fontSize: 13))
                    else ...[
                      _row("Recrutador", recruiterEmail ?? "-"),
                      _row("Lead criado em", DateTime.parse(lead["created_at"] as String).toLocal().toString().substring(0, 16)),
                      if (lead["converted_at"] != null) _row("Agenciado em", DateTime.parse(lead["converted_at"] as String).toLocal().toString().substring(0, 16)),
                      const SizedBox(height: 12),
                      if (handoff == null)
                        const Text("Transferencia para o gestor ainda nao preenchida.", style: TextStyle(color: Colors.white38, fontSize: 12))
                      else ...[
                        _row("Nicho", (handoff["niche"] as String?)?.isNotEmpty == true ? handoff["niche"] as String : "-"),
                        _row("Categoria", (handoff["category"] as String?)?.isNotEmpty == true ? handoff["category"] as String : "-"),
                        _row("Dias disponiveis", (handoff["available_days"] as String?)?.isNotEmpty == true ? handoff["available_days"] as String : "-"),
                        _row("Horarios disponiveis", (handoff["available_hours"] as String?)?.isNotEmpty == true ? handoff["available_hours"] as String : "-"),
                        _row("Experiencia anterior", (handoff["previous_experience"] as String?)?.isNotEmpty == true ? handoff["previous_experience"] as String : "-"),
                        _row("Objetivos", (handoff["objectives"] as String?)?.isNotEmpty == true ? handoff["objectives"] as String : "-"),
                        _row("Pontos de atencao", (handoff["attention_points"] as String?)?.isNotEmpty == true ? handoff["attention_points"] as String : "-"),
                        if ((handoff["recruitment_summary"] as String?)?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          const Text("Resumo do recrutamento", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(handoff["recruitment_summary"] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                        if ((handoff["notes"] as String?)?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          const Text("Observacoes para o gestor", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(handoff["notes"] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ],
                    ],
                    const SizedBox(height: 16),
                    Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar"))),
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

/// Historico completo do streamer em todas as fases do acompanhamento
/// (streamer_phase_history) -- separado do card de detalhe pra nao
/// despejar tudo de uma vez quando o card abre; so quem quer o historico
/// inteiro entra aqui.
class _StreamerHistoryDialog extends StatefulWidget {
  final String streamerId;
  final String streamerName;
  const _StreamerHistoryDialog({required this.streamerId, required this.streamerName});

  @override
  State<_StreamerHistoryDialog> createState() => _StreamerHistoryDialogState();
}

class _StreamerHistoryDialogState extends State<_StreamerHistoryDialog> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client.from("streamer_phase_history").select().eq("streamer_id", widget.streamerId).order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Historico Completo", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(widget.streamerName, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                    if (snapshot.hasError) return Center(child: Text("Erro: " + snapshot.error.toString(), style: const TextStyle(color: Colors.redAccent)));
                    final history = snapshot.data!;
                    if (history.isEmpty) return const Center(child: Text("Sem registros ainda.", style: TextStyle(color: Colors.white38)));
                    return ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final h = history[index];
                        final date = DateTime.parse(h["created_at"] as String).toLocal().toString().substring(0, 16);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text("- (" + date + ") " + (h["detail"] as String? ?? (h["action"] as String)), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar"))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Perfil e metricas do streamer -- leve e proprio (nao reaproveita o
/// StreamerFichaDialog do Nivel/Manutencao, que espera um mapa complexo ja
/// calculado -- month/tier/probabilidades -- que este board nao tem e
/// quebrava ao abrir daqui). Mostra os dados basicos do cadastro e os
/// numeros do mes atual (streamer_stats), que e o que o gestor precisa ao
/// olhar um streamer do Onboarding.
class _StreamerMetricsDialog extends StatefulWidget {
  final String streamerId;
  final String streamerName;
  const _StreamerMetricsDialog({required this.streamerId, required this.streamerName});

  @override
  State<_StreamerMetricsDialog> createState() => _StreamerMetricsDialogState();
}

class _StreamerMetricsDialogState extends State<_StreamerMetricsDialog> {
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
        .select("display_name, tiktok_creator_id, avatar_url, phone, joined_at, is_active, streamer_categories(name), managers!profiles_assigned_manager_id_fkey(login_email)")
        .eq("id", widget.streamerId)
        .single();
    final stats = await client.from("streamer_stats").select("days_live, hours_live, diamonds, battles").eq("streamer_id", widget.streamerId).maybeSingle();
    return {"profile": profile, "stats": stats};
  }

  Widget _statTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: color)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return SizedBox(height: 150, child: Center(child: Text("Erro: " + snapshot.error.toString(), style: const TextStyle(color: Colors.redAccent))));
              }
              final p = snapshot.data!["profile"] as Map<String, dynamic>;
              final stats = snapshot.data!["stats"] as Map<String, dynamic>?;
              final catData = p["streamer_categories"];
              final managerData = p["managers"];
              final joinedAt = DateTime.parse(p["joined_at"] as String);
              final daysInAgency = DateTime.now().difference(joinedAt).inDays;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white24,
                        backgroundImage: p["avatar_url"] != null ? NetworkImage(p["avatar_url"] as String) : null,
                        child: p["avatar_url"] == null ? const Icon(Icons.person, color: Colors.white, size: 22) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.streamerName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            if ((p["tiktok_creator_id"] as String?)?.isNotEmpty == true) Text("@" + (p["tiktok_creator_id"] as String), style: const TextStyle(color: Colors.white54, fontSize: 13)),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _row("Dias na agencia", daysInAgency.toString() + " dias"),
                    _row("Categoria", catData is Map ? catData["name"] as String? ?? "-" : "-"),
                    _row("Telefone", (p["phone"] as String?)?.isNotEmpty == true ? p["phone"] as String : "-"),
                    _row("Gestor responsavel", managerData is Map ? managerData["login_email"] as String? ?? "-" : "-"),
                    const SizedBox(height: 16),
                    const Text("Este mes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (stats == null)
                      const Text("Sem dados de desempenho registrados ainda.", style: TextStyle(color: Colors.white38, fontSize: 12))
                    else
                      Row(children: [
                        _statTile("Dias ao vivo", (stats["days_live"] as num? ?? 0).toString(), Colors.blueAccent),
                        _statTile("Horas ao vivo", (stats["hours_live"] as num? ?? 0).toString(), Colors.purpleAccent),
                        _statTile("Diamantes", (stats["diamonds"] as num? ?? 0).toString(), const Color(0xFF7A0BD4)),
                      ]),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar"))),
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
