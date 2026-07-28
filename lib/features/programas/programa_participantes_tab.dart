import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "program_phase_service.dart";
import "program_eligibility_service.dart";
import "program_monthly_stats_service.dart";
import "programa_history_helpers.dart";
import "participant_extras_service.dart";
import "participante_panel.dart";
import "../calendario/widgets/streamer_picker_dialog.dart";

const _activeFilterOptions = [
  ("todos", "Todos"),
  ("em_andamento", "Em andamento"),
  ("elegiveis", "Elegiveis"),
  ("premiacoes_pendentes", "Premiacoes pendentes"),
  ("avaliacao_pendente", "Precisam de avaliacao"),
  ("proximos_meta", "Proximos da meta"),
  ("critico", "Criticos"),
];

const _archivedFilterOptions = [
  ("todos", "Todos arquivados"),
  ("concluidos", "Concluidos"),
  ("atrasados", "Atrasados"),
];

const _sortOptions = [
  ("nome", "Nome"),
  ("dias", "Dias"),
  ("horas", "Horas"),
  ("diamantes", "Diamantes"),
  ("heart_me", "Heart Me"),
  ("progresso", "Progresso"),
  ("data_entrada", "Data de entrada"),
];

const _optionalColumns = [
  ("categoria", "Categoria"),
  ("etiqueta", "Status"),
  ("dias", "Dias"),
  ("horas", "Horas"),
  ("diamantes", "Diamantes"),
  ("heart_me", "Heart Me"),
  ("batalhas", "Batalhas"),
];

const _pageSize = 30;

class ProgramaParticipantesTab extends StatefulWidget {
  final Map<String, dynamic> program;
  final int year;
  final int month;
  const ProgramaParticipantesTab({super.key, required this.program, required this.year, required this.month});

  @override
  State<ProgramaParticipantesTab> createState() => _ProgramaParticipantesTabState();
}

class _ProgramaParticipantesTabState extends State<ProgramaParticipantesTab> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _rows = [];
  String _filter = "todos";
  String _sort = "nome";
  String _search = "";
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  bool _showArchived = false;
  String _viewMode = "cards";
  List<Map<String, dynamic>> _savedFilters = [];
  List<String>? _visibleColumns;
  int _visibleCount = _pageSize;
  DateTime? _lastLoadedAt;

  String get _phaseKey => widget.program["program_key"] as String;
  String get _agencyId => widget.program["agency_id"] as String;

  @override
  void initState() {
    super.initState();
    _load();
    _loadSavedFilters();
    fetchVisibleColumns().then((columns) {
      if (mounted) setState(() => _visibleColumns = columns);
    });
  }

  @override
  void didUpdateWidget(ProgramaParticipantesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year || oldWidget.month != widget.month) _load();
  }

  Future<void> _loadSavedFilters() async {
    final filters = await fetchSavedFilters();
    if (mounted) setState(() => _savedFilters = filters);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final client = Supabase.instance.client;
      final criteria = ProgramCriteria.fromMap(widget.program["criteria"] as Map<String, dynamic>?);

      await runProgramSync(
        programId: widget.program["id"] as String,
        phaseKey: _phaseKey,
        agencyId: _agencyId,
        criteria: criteria,
        year: widget.year,
        month: widget.month,
      );

      // A sincronizacao acima pode ter criado/reativado/arquivado cards --
      // busca a lista atualizada pra exibir.
      final progressRows = await client
          .from("streamer_phase_progress")
          .select("id, streamer_id, stage_key, outcome, completed_at, started_at, tags, pinned_note, archived_at, manual_override")
          .eq("phase_key", _phaseKey);
      final progressList = (progressRows as List).cast<Map<String, dynamic>>();
      final streamerIds = progressList.map((r) => r["streamer_id"] as String).toList();

      final snapshotsRaw = await fetchStreamerSnapshotsByIds(streamerIds: streamerIds);
      final snapshotsResolved = await resolveMonthlySnapshots(
        snapshots: snapshotsRaw,
        criteria: criteria,
        agencyId: _agencyId,
        year: widget.year,
        month: widget.month,
      );
      final snapshotById = {for (final s in snapshotsResolved) s.id: s};

      final stageRows = await client.from("streamer_phase_stages").select("stage_key, is_evaluation_stage").eq("agency_id", _agencyId).eq("phase_key", _phaseKey);
      final evalStages = (stageRows as List).where((r) => r["is_evaluation_stage"] == true).map((r) => r["stage_key"] as String).toSet();

      final awardRows = streamerIds.isEmpty
          ? []
          : await client.from("program_awards").select("streamer_id, status").eq("program_id", widget.program["id"]).inFilter("streamer_id", streamerIds);
      final pendingAwardsByStreamer = <String, int>{};
      for (final a in (awardRows as List)) {
        if (a["status"] == "pendente") {
          final id = a["streamer_id"] as String;
          pendingAwardsByStreamer[id] = (pendingAwardsByStreamer[id] ?? 0) + 1;
        }
      }

      for (final p in progressList) {
        final streamerId = p["streamer_id"] as String;
        final snapshot = snapshotById[streamerId];
        p["snapshot"] = snapshot;
        p["isEvaluationStage"] = evalStages.contains(p["stage_key"]);
        p["pendingAwards"] = pendingAwardsByStreamer[streamerId] ?? 0;
        p["eligibility"] = snapshot != null ? evaluateEligibility(snapshot, criteria) : null;
        p["progress"] = snapshot != null ? progressFraction(snapshot, criteria) : 0.0;
      }

      await Future.wait(progressList.map((p) async {
        final streamerId = p["streamer_id"] as String;
        try {
          p["_delta"] = await fetchWeekOverWeekDelta(streamerId: streamerId);
        } catch (_) {
          p["_delta"] = const WeekDelta();
        }
      }));

      setState(() {
        _rows = progressList;
        _loading = false;
        _lastLoadedAt = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  /// Categoria usada tanto pra filtrar quanto pra escolher a etiqueta do
  /// card. Um participante pode "bater" varias (ex: elegivel e proximo da
  /// meta ao mesmo tempo nao acontece -- elegivel so quando ja bateu tudo),
  /// entao a ordem abaixo e a prioridade de exibicao.
  /// Faixas de proximidade da meta pra quem ainda nao e elegivel: perto
  /// (>=70% do progresso medio) fica amarelo "Proximos da meta", longe
  /// (<40%) fica vermelho "Critico", o meio-termo continua azul "Em
  /// andamento" (neutro, ainda nao e urgente).
  static const _proximosMetaThreshold = 0.7;
  static const _criticoThreshold = 0.4;

  String _category(Map<String, dynamic> row) {
    if (row["completed_at"] != null) {
      final outcome = row["outcome"] as String?;
      return (outcome == "aprovado" || outcome == "graduado") ? "concluidos" : "atrasados";
    }
    if ((row["pendingAwards"] as int) > 0) return "premiacoes_pendentes";
    if (row["isEvaluationStage"] == true && row["outcome"] == null) return "avaliacao_pendente";
    final eligibility = row["eligibility"] as EligibilityResult?;
    if (eligibility != null && eligibility.eligible) return "elegiveis";
    final progress = row["progress"] as double? ?? 0.0;
    if (progress >= _proximosMetaThreshold) return "proximos_meta";
    if (progress < _criticoThreshold) return "critico";
    return "em_andamento";
  }

  /// Quantos dias sem live pra quem ja bateu a meta (categoria "elegiveis")
  /// -- alerta que o streamer parou de streamar depois de ja ter conseguido
  /// o objetivo. So retorna a partir de 3 dias; null significa "sem alerta".
  int? _inactiveDaysIfStale(String category, StreamerSnapshot? snapshot) {
    if (category != "elegiveis") return null;
    final lastLive = snapshot?.lastLiveAt;
    if (lastLive == null) return null;
    final days = DateTime.now().difference(lastLive).inDays;
    return days >= 3 ? days : null;
  }

  /// Paleta simplificada em 3 niveis: verde = conseguiu (elegivel, ou ja
  /// chegou na avaliacao final -- chegar ali ja e um sucesso, so falta a
  /// decisao do gestor), amarelo = em andamento (perto ou nao da meta,
  /// ainda tem chance), vermelho = critico (distante, dificilmente vai
  /// bater a tempo). Premiacao pendente e concluido/atrasado (arquivados)
  /// continuam com suas cores proprias, por serem estados operacionais, nao
  /// de progresso.
  StreamerBadge _badgeFor(String category) {
    switch (category) {
      case "concluidos":
        return StreamerBadge.concluido;
      case "premiacoes_pendentes":
        return StreamerBadge.premiacao;
      case "avaliacao_pendente":
        return StreamerBadge.eligivel;
      case "elegiveis":
        return StreamerBadge.eligivel;
      case "proximos_meta":
        return StreamerBadge.atencao;
      case "critico":
        return StreamerBadge.critico;
      case "atrasados":
        return StreamerBadge.atrasado;
      default:
        return StreamerBadge.atencao;
    }
  }

  String _nextAction(Map<String, dynamic> row, String category) {
    switch (category) {
      case "concluidos":
        return "Concluiu o programa";
      case "premiacoes_pendentes":
        return "Premiacao pendente";
      case "avaliacao_pendente":
        return "Pronto para avaliacao";
      case "elegiveis":
        return "Elegivel";
      case "atrasados":
        return "Encerrado";
      case "critico":
        final eligibility = row["eligibility"] as EligibilityResult?;
        final gap = eligibility != null && eligibility.gaps.isNotEmpty ? eligibility.gaps.first : "distante da meta";
        return "Critico: " + gap;
      default:
        final eligibility = row["eligibility"] as EligibilityResult?;
        if (eligibility != null && eligibility.gaps.isNotEmpty) return eligibility.gaps.first;
        return "Em andamento";
    }
  }

  List<Map<String, dynamic>> get _filteredSorted {
    var list = _rows.map((r) => {...r, "_category": _category(r)}).toList();

    list = list.where((r) => _showArchived ? r["archived_at"] != null : r["archived_at"] == null).toList();
    if (_filter != "todos") list = list.where((r) => r["_category"] == _filter).toList();
    if (_search.trim().isNotEmpty) {
      final term = _search.trim().toLowerCase();
      list = list.where((r) {
        final snapshot = r["snapshot"] as StreamerSnapshot?;
        return (snapshot?.displayName.toLowerCase() ?? "").contains(term);
      }).toList();
    }

    bool isFavorite(Map<String, dynamic> r) => ((r["tags"] as List?)?.cast<String>() ?? const <String>[]).contains(tagInfo(ParticipantTag.destaque).$1);

    list.sort((a, b) {
      // Favoritos (marcador Destaque) sempre primeiro, independente do
      // criterio de ordenacao escolhido.
      final favoriteCompare = (isFavorite(a) ? 0 : 1).compareTo(isFavorite(b) ? 0 : 1);
      if (favoriteCompare != 0) return favoriteCompare;
      final sa = a["snapshot"] as StreamerSnapshot?;
      final sb = b["snapshot"] as StreamerSnapshot?;
      switch (_sort) {
        case "dias":
          return (sb?.daysInAgency ?? 0).compareTo(sa?.daysInAgency ?? 0);
        case "horas":
          return (sb?.hoursLive ?? 0).compareTo(sa?.hoursLive ?? 0);
        case "diamantes":
          return (sb?.diamonds ?? 0).compareTo(sa?.diamonds ?? 0);
        case "heart_me":
          return (sb?.heartMe ?? 0).compareTo(sa?.heartMe ?? 0);
        case "progresso":
          return (b["progress"] as double? ?? 0).compareTo(a["progress"] as double? ?? 0);
        case "data_entrada":
          return ((b["started_at"] as String?) ?? "").compareTo((a["started_at"] as String?) ?? "");
        default:
          return (sa?.displayName ?? "").toLowerCase().compareTo((sb?.displayName ?? "").toLowerCase());
      }
    });
    return list;
  }

  Future<String?> _promptText(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: controller, maxLines: 3, autofocus: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Texto", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(controller.text.trim()),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: const Text("Salvar"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendNote(Map<String, dynamic> row, {required bool isMessage}) async {
    final text = await _promptText(isMessage ? "Enviar mensagem" : "Registrar observacao");
    if (text == null || text.isEmpty) return;
    final client = Supabase.instance.client;
    try {
      await client.from("streamer_contact_logs").insert({
        "streamer_id": row["streamer_id"],
        "manager_id": client.auth.currentUser!.id,
        "manager_label": client.auth.currentUser!.email ?? "Gestor",
        "message_sent": text,
        "context": "programa",
      });
      if (!isMessage) {
        await logProgramaHistory(streamerId: row["streamer_id"] as String, phaseKey: _phaseKey, action: "observacao", detail: text);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Salvo! Fica visivel no CRM e no Historico do programa.")));
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  Future<void> _moveToNextProgram(Map<String, dynamic> row) async {
    final nextKey = widget.program["next_program_key"] as String?;
    if (nextKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Este programa nao tem um proximo programa configurado.")));
      return;
    }
    final snapshot = row["snapshot"] as StreamerSnapshot?;
    final ok = await confirmAction(
      context,
      title: "Mover de programa",
      message: "Mover " + (snapshot?.displayName ?? "este streamer") + " para o proximo programa?",
      confirmLabel: "Mover",
    );
    if (!ok) return;
    try {
      await createProgramCardIfNeeded(phaseKey: nextKey, streamerId: row["streamer_id"] as String);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Movido para o proximo programa.")));
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  /// Adiciona streamer(s) manualmente ao programa, independente de bater
  /// (ou nao) os criterios automaticos. Em modo faixa, reaproveita
  /// reactivateOrCreateCard (mesma linha, nunca duplica) e grava
  /// manual_override='add' -- assim a sincronizacao automatica nunca desfaz
  /// essa adicao manual. Em modo fluxo, createProgramCardIfNeeded (sem
  /// override, ja idempotente, ja usado no encadeamento automatico).
  Future<void> _addStreamerManually() async {
    final selected = await showDialog<List<Map<String, dynamic>>>(context: context, builder: (context) => const StreamerPickerDialog());
    if (selected == null || selected.isEmpty) return;
    final criteria = ProgramCriteria.fromMap(widget.program["criteria"] as Map<String, dynamic>?);
    final client = Supabase.instance.client;
    var added = 0;
    for (final s in selected) {
      try {
        final streamerId = s["id"] as String;
        if (criteria.membershipMode == "faixa") {
          await reactivateOrCreateCard(phaseKey: _phaseKey, streamerId: streamerId);
          await client.from("streamer_phase_progress").update({"manual_override": "add"}).eq("streamer_id", streamerId).eq("phase_key", _phaseKey);
        } else {
          await createProgramCardIfNeeded(phaseKey: _phaseKey, streamerId: streamerId);
        }
        added++;
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(added.toString() + " streamer(s) adicionado(s) ao programa.")));
      _load();
    }
  }

  /// Em modo faixa, nao apaga a linha -- arquiva e grava manual_override=
  /// 'remove', pra sincronizacao automatica nunca trazer o streamer de
  /// volta sozinha. Em modo fluxo, comportamento de sempre (apaga a linha).
  Future<void> _removeFromProgram(Map<String, dynamic> row) async {
    final snapshot = row["snapshot"] as StreamerSnapshot?;
    final ok = await confirmAction(
      context,
      title: "Remover do programa",
      message: "Remover " + (snapshot?.displayName ?? "este streamer") + " deste programa?",
      confirmLabel: "Remover",
      confirmColor: Colors.redAccent,
    );
    if (!ok) return;
    try {
      final criteria = ProgramCriteria.fromMap(widget.program["criteria"] as Map<String, dynamic>?);
      if (criteria.membershipMode == "faixa") {
        await Supabase.instance.client.from("streamer_phase_progress").update({
          "completed_at": DateTime.now().toIso8601String(),
          "archived_at": DateTime.now().toIso8601String(),
          "outcome": "removido_manual",
          "manual_override": "remove",
        }).eq("id", row["id"]);
      } else {
        await deleteProgramCard(progressId: row["id"] as String);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Removido do programa.")));
      _load();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  Future<void> _addTag(Map<String, dynamic> row, ParticipantTag tag) async {
    final current = ((row["tags"] as List?)?.cast<String>() ?? <String>[]).toList();
    final key = tagInfo(tag).$1;
    if (current.contains(key)) return;
    current.add(key);
    try {
      await setParticipantTags(progressId: row["id"] as String, tags: current);
      setState(() => row["tags"] = current);
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  Future<void> _removeTag(Map<String, dynamic> row, String key) async {
    final current = ((row["tags"] as List?)?.cast<String>() ?? <String>[]).toList();
    current.remove(key);
    try {
      await setParticipantTags(progressId: row["id"] as String, tags: current);
      setState(() => row["tags"] = current);
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  Future<void> _pickTagToAdd(Map<String, dynamic> row) async {
    final current = ((row["tags"] as List?)?.cast<String>() ?? <String>[]).toSet();
    final available = ParticipantTag.values.where((t) => !current.contains(tagInfo(t).$1)).toList();
    if (available.isEmpty) return;
    final picked = await showDialog<ParticipantTag>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Adicionar marcador", style: TextStyle(color: Colors.white)),
        children: available.map((t) {
          final info = tagInfo(t);
          return SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(t),
            child: Text(info.$2 + "  " + info.$3, style: const TextStyle(color: Colors.white70)),
          );
        }).toList(),
      ),
    );
    if (picked != null) await _addTag(row, picked);
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelectAll(List<Map<String, dynamic>> list) {
    setState(() {
      if (_selectedIds.length == list.length && list.isNotEmpty) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(list.map((r) => r["id"] as String));
      }
    });
  }

  List<Map<String, dynamic>> get _selectedRows => _rows.where((r) => _selectedIds.contains(r["id"])).toList();

  Future<void> _bulkNote({required bool isMessage}) async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final ok = await confirmAction(
      context,
      title: isMessage ? "Mensagem em massa" : "Observacao em massa",
      message: "Aplicar para " + count.toString() + " participante(s) selecionado(s)?",
    );
    if (!ok) return;
    final text = await _promptText(isMessage ? "Enviar mensagem" : "Registrar observacao");
    if (text == null || text.isEmpty) return;
    final client = Supabase.instance.client;
    var success = 0;
    for (final row in _selectedRows) {
      try {
        await client.from("streamer_contact_logs").insert({
          "streamer_id": row["streamer_id"],
          "manager_id": client.auth.currentUser!.id,
          "manager_label": client.auth.currentUser!.email ?? "Gestor",
          "message_sent": text,
          "context": "programa",
        });
        if (!isMessage) {
          await logProgramaHistory(streamerId: row["streamer_id"] as String, phaseKey: _phaseKey, action: "observacao", detail: text);
        }
        success++;
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Aplicado para " + success.toString() + " participante(s).")));
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
    }
  }

  Future<void> _bulkMarkAwardsDelivered() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final ok = await confirmAction(
      context,
      title: "Marcar premiacoes como entregues",
      message: "Marcar todas as premiacoes pendentes de " + count.toString() + " participante(s) como entregues?",
      confirmLabel: "Marcar entregues",
    );
    if (!ok) return;
    final client = Supabase.instance.client;
    var delivered = 0;
    for (final row in _selectedRows) {
      try {
        final res = await client
            .from("program_awards")
            .update({"status": "entregue", "delivered_at": DateTime.now().toIso8601String()})
            .eq("program_id", widget.program["id"])
            .eq("streamer_id", row["streamer_id"])
            .eq("status", "pendente")
            .select();
        delivered += (res as List).length;
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(delivered.toString() + " premiacao(oes) marcada(s) como entregue(s).")));
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
      _load();
    }
  }

  Future<void> _bulkExport() async {
    if (_selectedIds.isEmpty) return;
    final buffer = StringBuffer();
    for (final row in _selectedRows) {
      final snapshot = row["snapshot"] as StreamerSnapshot?;
      buffer.writeln(snapshot?.displayName ?? "-");
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lista copiada para a area de transferencia.")));
  }

  Future<void> _saveCurrentFilter() async {
    final name = await _promptText("Nome do filtro");
    if (name == null || name.isEmpty) return;
    try {
      await saveFilterPreset(name: name, filterKey: _filter, sortKey: _sort, searchTerm: _search);
      await _loadSavedFilters();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  void _applySavedFilter(Map<String, dynamic> preset) {
    setState(() {
      _filter = preset["filter_key"] as String? ?? "todos";
      _sort = preset["sort_key"] as String? ?? "nome";
      _search = preset["search_term"] as String? ?? "";
      _visibleCount = _pageSize;
    });
  }

  Future<void> _removeSavedFilter(String id) async {
    try {
      await deleteSavedFilter(id);
      await _loadSavedFilters();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  Future<void> _pickColumns() async {
    final current = (_visibleColumns ?? _optionalColumns.map((c) => c.$1).toList()).toSet();
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text("Colunas visiveis", style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _optionalColumns.map((c) {
                return CheckboxListTile(
                  value: current.contains(c.$1),
                  onChanged: (v) => setDialogState(() => v == true ? current.add(c.$1) : current.remove(c.$1)),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF7A0BD4),
                  title: Text(c.$2, style: const TextStyle(color: Colors.white, fontSize: 13)),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(current),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
              child: const Text("Salvar"),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final columns = _optionalColumns.map((c) => c.$1).where(result.contains).toList();
    setState(() => _visibleColumns = columns);
    try {
      await setVisibleColumns(columns);
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  Widget _statChip(String label, String value, num? delta, {bool isDouble = false}) {
    Widget? arrow;
    if (delta != null && delta != 0) {
      final up = delta > 0;
      final deltaText = isDouble ? delta.toStringAsFixed(1) : delta.toStringAsFixed(0);
      arrow = Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 3),
        Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 10, color: up ? Colors.greenAccent : Colors.redAccent),
        Text(deltaText, style: TextStyle(color: up ? Colors.greenAccent : Colors.redAccent, fontSize: 10)),
      ]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label + ": " + value, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      if (arrow != null) arrow,
    ]);
  }

  /// Visualizacao em tabela (alternativa aos cards) -- mesmas colunas de
  /// dados e as mesmas acoes, so num layout mais compacto. Rola na
  /// horizontal em telas estreitas, pra continuar responsiva.
  Widget _buildParticipantsTable(List<Map<String, dynamic>> list) {
    final visible = _visibleColumns ?? _optionalColumns.map((c) => c.$1).toList();
    final columnKeys = _optionalColumns.map((c) => c.$1).where(visible.contains).toList();
    const columnLabels = {
      "categoria": "Categoria",
      "etiqueta": "Status",
      "dias": "Dias",
      "horas": "Horas",
      "diamantes": "Diamantes",
      "heart_me": "Heart Me",
      "batalhas": "Batalhas",
    };

    Widget textCell(String text) => Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12));

    Widget cellFor(String key, Map<String, dynamic> row, StreamerSnapshot? snapshot, String category) {
      switch (key) {
        case "categoria":
          return textCell(snapshot?.categoryName ?? "-");
        case "etiqueta":
          final badgeInfo = streamerBadgeInfo(_badgeFor(category));
          final inactiveDays = _inactiveDaysIfStale(category, snapshot);
          return Wrap(spacing: 4, runSpacing: 2, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: badgeInfo.$3.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: badgeInfo.$3)),
              child: Text(badgeInfo.$1, style: TextStyle(color: badgeInfo.$3, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            if (inactiveDays != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.redAccent)),
                child: Text(inactiveDays.toString() + " dias +inativo", style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
          ]);
        case "dias":
          return textCell(snapshot?.daysInAgency.toString() ?? "-");
        case "horas":
          return textCell(snapshot?.hoursLive.toStringAsFixed(1) ?? "-");
        case "diamantes":
          return textCell(snapshot?.diamonds.toString() ?? "-");
        case "heart_me":
          return textCell(snapshot?.heartMe?.toString() ?? "-");
        case "batalhas":
          return textCell(snapshot?.battles.toString() ?? "-");
        default:
          return textCell("-");
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 48),
        child: DataTable(
          columnSpacing: 18,
          headingRowHeight: 32,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 40,
          headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
          columns: [
            const DataColumn(label: Text("Nome", style: TextStyle(color: Colors.white70, fontSize: 12))),
            ...columnKeys.map((k) => DataColumn(label: Text(columnLabels[k] ?? k, style: const TextStyle(color: Colors.white70, fontSize: 12)))),
            const DataColumn(label: Text("Progresso", style: TextStyle(color: Colors.white70, fontSize: 12))),
            const DataColumn(label: Text("Proxima acao", style: TextStyle(color: Colors.white70, fontSize: 12))),
            const DataColumn(label: Text("Acoes", style: TextStyle(color: Colors.white70, fontSize: 12))),
          ],
          rows: list.map((row) {
            final category = row["_category"] as String;
            final snapshot = row["snapshot"] as StreamerSnapshot?;
            final progress = (row["progress"] as double? ?? 0).clamp(0.0, 1.0);

            return DataRow(cells: [
              DataCell(Text(snapshot?.displayName ?? "-", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              ...columnKeys.map((k) => DataCell(cellFor(k, row, snapshot, category))),
              DataCell(textCell((progress * 100).toStringAsFixed(0) + "%")),
              DataCell(SizedBox(width: 160, child: Text(_nextAction(row, category), style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))),
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                if (!_showArchived) IconButton(iconSize: 16, icon: const Icon(Icons.message, color: Colors.white54), tooltip: "Mensagem", onPressed: () => _sendNote(row, isMessage: true)),
                IconButton(iconSize: 16, icon: const Icon(Icons.person_search, color: Colors.white54), tooltip: "Abrir perfil", onPressed: () => openParticipantPanel(context, program: widget.program, row: row, nextAction: _nextAction(row, category))),
                IconButton(iconSize: 16, icon: const Icon(Icons.edit_note, color: Colors.white54), tooltip: "Observacao", onPressed: () => _sendNote(row, isMessage: false)),
                if (!_showArchived) IconButton(iconSize: 16, icon: const Icon(Icons.arrow_forward, color: Colors.white54), tooltip: "Mover", onPressed: () => _moveToNextProgram(row)),
                if (!_showArchived) IconButton(iconSize: 16, icon: const Icon(Icons.person_remove, color: Colors.redAccent), tooltip: "Remover do programa", onPressed: () => _removeFromProgram(row)),
              ])),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatsFooter() {
    final snapshots = _rows.map((r) => r["snapshot"] as StreamerSnapshot?).whereType<StreamerSnapshot>().toList();
    final totalHours = snapshots.fold<double>(0, (sum, s) => sum + s.hoursLive);
    final totalDiamonds = snapshots.fold<num>(0, (sum, s) => sum + s.diamonds);
    final heartMeValues = snapshots.map((s) => s.heartMe).whereType<num>().toList();
    final avgHeartMe = heartMeValues.isEmpty ? 0.0 : heartMeValues.reduce((a, b) => a + b) / heartMeValues.length;
    final avgHours = snapshots.isEmpty ? 0.0 : totalHours / snapshots.length;
    final activeCount = _rows.where((r) => r["archived_at"] == null).length;
    final completedCount = _rows.where((r) => r["archived_at"] != null && (r["outcome"] == "aprovado" || r["outcome"] == "graduado")).length;

    Widget stat(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ]);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(8)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          dense: true,
          collapsedIconColor: Colors.white54,
          iconColor: Colors.white54,
          title: const Text("Estatisticas do programa", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          children: [
            Wrap(spacing: 24, runSpacing: 10, alignment: WrapAlignment.start, children: [
              stat("Horas totais", totalHours.toStringAsFixed(0)),
              stat("Diamantes totais", totalDiamonds.toStringAsFixed(0)),
              stat("Media de Heart Me", avgHeartMe.toStringAsFixed(1)),
              stat("Media de horas", avgHours.toStringAsFixed(1)),
              stat("Participantes ativos", activeCount.toString()),
              stat("Participantes concluidos", completedCount.toString()),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _loading || _errorMessage != null ? const <Map<String, dynamic>>[] : _filteredSorted;
    final pagedList = list.take(_visibleCount).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Participantes", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _load),
            if (_lastLoadedAt != null) Text(relativeTimeLabel(_lastLoadedAt!), style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
            const SizedBox(width: 16),
            if (!_showArchived)
              TextButton.icon(
                onPressed: _addStreamerManually,
                icon: const Icon(Icons.person_add_alt, size: 16, color: Colors.white70),
                label: const Text("Adicionar streamer", style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            const Spacer(),
            IconButton(
              tooltip: "Visualizacao em cards",
              onPressed: () => setState(() => _viewMode = "cards"),
              icon: Icon(Icons.view_agenda, size: 18, color: _viewMode == "cards" ? const Color(0xFF7A0BD4) : Colors.white38),
            ),
            IconButton(
              tooltip: "Visualizacao em tabela",
              onPressed: () => setState(() => _viewMode = "tabela"),
              icon: Icon(Icons.table_view, size: 18, color: _viewMode == "tabela" ? const Color(0xFF7A0BD4) : Colors.white38),
            ),
            if (_viewMode == "tabela")
              IconButton(tooltip: "Colunas visiveis", onPressed: _pickColumns, icon: const Icon(Icons.view_column, size: 18, color: Colors.white38)),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => setState(() {
                _showArchived = !_showArchived;
                _filter = "todos";
                _selectionMode = false;
                _selectedIds.clear();
                _visibleCount = _pageSize;
              }),
              icon: Icon(_showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined, size: 16, color: Colors.white70),
              label: Text(_showArchived ? "Voltar aos ativos" : "Ver arquivados", style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
            if (!_showArchived)
              TextButton.icon(
                onPressed: _toggleSelectionMode,
                icon: Icon(_selectionMode ? Icons.close : Icons.checklist, size: 16, color: Colors.white70),
                label: Text(_selectionMode ? "Cancelar selecao" : "Selecionar", style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
          ]),
          const SizedBox(height: 2),
          Text(
            _showArchived
                ? "Participantes que ja concluiram ou foram desligados deste programa -- so consulta, o historico continua disponivel."
                : "Detectado automaticamente a partir do fluxo deste programa.",
            style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(
              width: 260,
              height: 36,
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.white54, size: 18), hintText: "Buscar por nome", hintStyle: TextStyle(color: Colors.white38), isDense: true),
                onChanged: (v) => setState(() {
                  _search = v;
                  _visibleCount = _pageSize;
                }),
              ),
            ),
            const SizedBox(width: 16),
            const Text("Ordenar: ", style: TextStyle(color: Colors.white54, fontSize: 12)),
            DropdownButton<String>(
              value: _sort,
              isDense: true,
              dropdownColor: const Color(0xFF232323),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              underline: Container(height: 1, color: Colors.white24),
              items: _sortOptions.map((s) => DropdownMenuItem(value: s.$1, child: Text(s.$2))).toList(),
              onChanged: (v) => setState(() {
                _sort = v ?? _sort;
                _visibleCount = _pageSize;
              }),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            ...(_showArchived ? _archivedFilterOptions : _activeFilterOptions).map((f) {
              final selected = _filter == f.$1;
              return ChoiceChip(
                label: Text(f.$2, style: TextStyle(fontSize: 11, color: selected ? Colors.white : Colors.white70)),
                selected: selected,
                selectedColor: const Color(0xFF7A0BD4),
                backgroundColor: Colors.white.withOpacity(0.05),
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() {
                  _filter = f.$1;
                  _visibleCount = _pageSize;
                }),
              );
            }),
            Container(width: 1, height: 18, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 4)),
            ..._savedFilters.map((f) => InputChip(
                  label: Text(f["name"] as String, style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.white.withOpacity(0.05),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _applySavedFilter(f),
                  onDeleted: () => _removeSavedFilter(f["id"] as String),
                )),
            ActionChip(
              avatar: const Icon(Icons.add, size: 12),
              label: const Text("Salvar filtro atual", style: TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              onPressed: _saveCurrentFilter,
            ),
          ]),
          if (_selectionMode && !_showArchived) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
              child: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                TextButton.icon(
                  onPressed: () => _toggleSelectAll(list),
                  icon: Icon(_selectedIds.length == list.length && list.isNotEmpty ? Icons.check_box : Icons.check_box_outline_blank, size: 16, color: Colors.white70),
                  label: Text("Selecionar todos (" + _selectedIds.length.toString() + "/" + list.length.toString() + ")", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
                ElevatedButton.icon(onPressed: _selectedIds.isEmpty ? null : () => _bulkNote(isMessage: true), icon: const Icon(Icons.message, size: 14), label: const Text("Mensagem em massa", style: TextStyle(fontSize: 12))),
                ElevatedButton.icon(onPressed: _selectedIds.isEmpty ? null : () => _bulkNote(isMessage: false), icon: const Icon(Icons.edit_note, size: 14), label: const Text("Observacao em massa", style: TextStyle(fontSize: 12))),
                ElevatedButton.icon(onPressed: _selectedIds.isEmpty ? null : _bulkMarkAwardsDelivered, icon: const Icon(Icons.card_giftcard, size: 14), label: const Text("Marcar premiacao entregue", style: TextStyle(fontSize: 12))),
                ElevatedButton.icon(onPressed: _selectedIds.isEmpty ? null : _bulkExport, icon: const Icon(Icons.copy, size: 14), label: const Text("Exportar lista", style: TextStyle(fontSize: 12))),
              ]),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? buildProgramasLoadError(_errorMessage!)
                    : list.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                "Nenhum participante encontrado. Quando novos streamers atenderem aos criterios deste programa, eles aparecerao automaticamente aqui.",
                                style: TextStyle(color: Colors.white54),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : _viewMode == "tabela"
                            ? _buildParticipantsTable(pagedList)
                            : ListView.builder(
                            itemCount: pagedList.length,
                            itemBuilder: (context, index) {
                              final row = pagedList[index];
                              final id = row["id"] as String;
                              final category = row["_category"] as String;
                              final snapshot = row["snapshot"] as StreamerSnapshot?;
                              final badgeInfo = streamerBadgeInfo(_badgeFor(category));
                              final progress = (row["progress"] as double? ?? 0).clamp(0.0, 1.0);
                              final delta = row["_delta"] as WeekDelta?;
                              final tags = (row["tags"] as List?)?.cast<String>() ?? const <String>[];
                              final pinnedNote = row["pinned_note"] as String?;
                              final inactiveDays = _inactiveDaysIfStale(category, snapshot);

                              return Card(
                                color: Colors.white.withOpacity(0.05),
                                margin: const EdgeInsets.only(bottom: 6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                                        if (_selectionMode)
                                          Checkbox(
                                            value: _selectedIds.contains(id),
                                            visualDensity: VisualDensity.compact,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            onChanged: (v) => setState(() {
                                              if (v == true) {
                                                _selectedIds.add(id);
                                              } else {
                                                _selectedIds.remove(id);
                                              }
                                            }),
                                          ),
                                        const CircleAvatar(radius: 14, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white54, size: 14)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                                            Flexible(child: Text(snapshot?.displayName ?? "-", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                            const SizedBox(width: 6),
                                            Flexible(child: Text(snapshot?.categoryName ?? "Sem categoria", style: const TextStyle(color: Colors.white54, fontSize: 11), overflow: TextOverflow.ellipsis)),
                                          ]),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: badgeInfo.$3.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: badgeInfo.$3)),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            Icon(badgeInfo.$2, size: 10, color: badgeInfo.$3),
                                            const SizedBox(width: 3),
                                            Text(badgeInfo.$1, style: TextStyle(color: badgeInfo.$3, fontSize: 9, fontWeight: FontWeight.bold)),
                                          ]),
                                        ),
                                        if (inactiveDays != null) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.redAccent)),
                                            child: Text(inactiveDays.toString() + " dias +inativo", style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ]),
                                      if (pinnedNote != null && pinnedNote.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.withOpacity(0.4))),
                                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            const Icon(Icons.push_pin, size: 11, color: Colors.amber),
                                            const SizedBox(width: 6),
                                            Expanded(child: Text(pinnedNote, style: const TextStyle(color: Colors.amber, fontSize: 11))),
                                          ]),
                                        ),
                                      ],
                                      const SizedBox(height: 5),
                                      Wrap(spacing: 14, runSpacing: 2, children: [
                                        Text("Dias: " + (snapshot?.daysInAgency.toString() ?? "-"), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                        _statChip("Horas", snapshot?.hoursLive.toStringAsFixed(1) ?? "-", delta?.hoursDelta, isDouble: true),
                                        _statChip("Diamantes", snapshot?.diamonds.toString() ?? "-", delta?.diamondsDelta),
                                        _statChip("Heart Me", snapshot?.heartMe?.toString() ?? "-", delta?.heartMeDelta),
                                      ]),
                                      const SizedBox(height: 5),
                                      Row(children: [
                                        SizedBox(
                                          width: 70,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(3),
                                            child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Color(0xFF7A0BD4))),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text((progress * 100).toStringAsFixed(0) + "%", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(_nextAction(row, category), style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                      ]),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        Expanded(
                                          child: Wrap(spacing: 4, runSpacing: 2, children: [
                                            ...tags.map((key) {
                                              final tag = tagFromKey(key);
                                              if (tag == null) return const SizedBox.shrink();
                                              final info = tagInfo(tag);
                                              return Chip(
                                                label: Text(info.$2 + " " + info.$3, style: const TextStyle(fontSize: 9)),
                                                visualDensity: VisualDensity.compact,
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                padding: EdgeInsets.zero,
                                                backgroundColor: Colors.white.withOpacity(0.08),
                                                onDeleted: () => _removeTag(row, key),
                                              );
                                            }),
                                            ActionChip(
                                              avatar: const Icon(Icons.add, size: 11),
                                              label: const Text("Marcador", style: TextStyle(fontSize: 9)),
                                              visualDensity: VisualDensity.compact,
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              padding: EdgeInsets.zero,
                                              onPressed: () => _pickTagToAdd(row),
                                            ),
                                          ]),
                                        ),
                                        if (!_showArchived)
                                          IconButton(iconSize: 16, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28), visualDensity: VisualDensity.compact, tooltip: "Mensagem", icon: const Icon(Icons.message, color: Colors.white54), onPressed: () => _sendNote(row, isMessage: true)),
                                        IconButton(
                                          iconSize: 16,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          visualDensity: VisualDensity.compact,
                                          tooltip: "Abrir perfil",
                                          icon: const Icon(Icons.person_search, color: Colors.white54),
                                          onPressed: () => openParticipantPanel(context, program: widget.program, row: row, nextAction: _nextAction(row, category)),
                                        ),
                                        IconButton(iconSize: 16, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28), visualDensity: VisualDensity.compact, tooltip: "Observacao", icon: const Icon(Icons.edit_note, color: Colors.white54), onPressed: () => _sendNote(row, isMessage: false)),
                                        if (!_showArchived)
                                          IconButton(iconSize: 16, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28), visualDensity: VisualDensity.compact, tooltip: "Mover", icon: const Icon(Icons.arrow_forward, color: Colors.white54), onPressed: () => _moveToNextProgram(row)),
                                        if (!_showArchived)
                                          IconButton(iconSize: 16, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28), visualDensity: VisualDensity.compact, tooltip: "Remover do programa", icon: const Icon(Icons.person_remove, color: Colors.redAccent), onPressed: () => _removeFromProgram(row)),
                                      ]),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          if (!_loading && _errorMessage == null && list.length > _visibleCount)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton(
                  onPressed: () => setState(() => _visibleCount += _pageSize),
                  child: Text("Carregar mais (" + (list.length - _visibleCount).toString() + " restantes)"),
                ),
              ),
            ),
          if (!_loading && _errorMessage == null && _rows.isNotEmpty) _buildStatsFooter(),
        ],
      ),
    );
  }
}
