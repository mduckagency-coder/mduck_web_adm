import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../calendario/widgets/streamer_picker_dialog.dart";
import "program_eligibility_service.dart";
import "program_monthly_stats_service.dart";
import "program_participation_service.dart" show syncParticipationAwardFinancialEntry;
import "programa_history_helpers.dart";

String _periodKeyFor(int year, int month) =>
    year.toString() + "-" + month.toString().padLeft(2, "0");

List<Map<String, dynamic>> _parseItems(dynamic raw) {
  if (raw is List) return raw.cast<Map<String, dynamic>>();
  return const [];
}

String _itemsSummary(List<Map<String, dynamic>> items) {
  if (items.isEmpty) return "-";
  return items
      .map((it) {
        final qty = it["quantity"] ?? 1;
        final name = (it["name"] as String?) ?? "-";
        return qty.toString() + "x " + name;
      })
      .join(", ");
}

num _itemsTotal(List<Map<String, dynamic>> items) {
  var total = 0.0;
  for (final it in items) {
    final value = it["value"] as num?;
    if (value != null) total += value.toDouble();
  }
  return total;
}

const _awardStatusOptions = ["pendente", "agendado", "entregue"];

Color _awardStatusColor(String status) {
  switch (status) {
    case "agendado":
      return Colors.amber;
    case "entregue":
      return Colors.greenAccent;
    default:
      return Colors.orangeAccent;
  }
}

String _awardStatusLabel(String status) {
  switch (status) {
    case "agendado":
      return "Agendado";
    case "entregue":
      return "Entregue";
    default:
      return "Pendente";
  }
}

class ProgramaPremiacoesTab extends StatefulWidget {
  final Map<String, dynamic> program;
  final int year;
  final int month;
  const ProgramaPremiacoesTab({
    super.key,
    required this.program,
    required this.year,
    required this.month,
  });

  @override
  State<ProgramaPremiacoesTab> createState() => _ProgramaPremiacoesTabState();
}

class _ProgramaPremiacoesTabState extends State<ProgramaPremiacoesTab> {
  late Future<List<Map<String, dynamic>>> _future;
  String _filter = "pendentes";
  bool _showAllMonths = false;

  // "Quem concluiu este mes": ou a lista de aprovados/graduados no mes (modo
  // metas), ou o topo do ranking do mes (modo pontos) -- so um dos dois fica
  // preenchido, conforme criteria.trackingMode.
  late Future<void> _concludedFuture;
  List<Map<String, dynamic>> _concludedThisMonth = [];
  List<StreamerSnapshot> _rankingTop = [];
  String _trackingMode = "metas";

  @override
  void initState() {
    super.initState();
    _future = _load();
    _concludedFuture = _loadConcluded();
  }

  @override
  void didUpdateWidget(ProgramaPremiacoesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year || oldWidget.month != widget.month) {
      setState(() => _concludedFuture = _loadConcluded());
    }
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("program_awards")
        .select(
          "*, streamer:profiles(display_name, avatar_url, tiktok_username, tiktok_creator_id)",
        )
        .eq("program_id", widget.program["id"])
        .order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _loadConcluded() async {
    final criteria = ProgramCriteria.fromMap(
      widget.program["criteria"] as Map<String, dynamic>?,
    );
    final phaseKey = widget.program["program_key"] as String;
    final agencyId = widget.program["agency_id"] as String;

    if (criteria.trackingMode == "pontos") {
      final rawSnapshots = await fetchActiveStreamerSnapshots(
        agencyId: agencyId,
      );
      final snapshots = await resolveMonthlySnapshots(
        snapshots: rawSnapshots,
        criteria: criteria,
        agencyId: agencyId,
        year: widget.year,
        month: widget.month,
      );
      final ranked = rankByPoints(snapshots, criteria).take(10).toList();
      if (mounted) {
        setState(() {
          _trackingMode = "pontos";
          _rankingTop = ranked;
        });
      }
      return;
    }

    final client = Supabase.instance.client;
    final rows = await client
        .from("streamer_phase_progress")
        .select(
          "streamer_id, outcome, completed_at, streamer:profiles(display_name, avatar_url)",
        )
        .eq("phase_key", phaseKey)
        .inFilter("outcome", ["aprovado", "graduado"]);
    final list = (rows as List).cast<Map<String, dynamic>>().where((r) {
      if (r["completed_at"] == null) return false;
      final completedAt = DateTime.parse(r["completed_at"] as String);
      return completedAt.year == widget.year &&
          completedAt.month == widget.month;
    }).toList();
    if (mounted) {
      setState(() {
        _trackingMode = "metas";
        _concludedThisMonth = list;
      });
    }
  }

  void _reload() {
    setState(() {
      _future = _load();
      _concludedFuture = _loadConcluded();
    });
  }

  Future<void> _markDelivered(Map<String, dynamic> award) async {
    final ok = await confirmAction(
      context,
      title: "Marcar premiacao como entregue",
      message: "Confirmar entrega de \"" + (award["title"] as String) + "\"?",
    );
    if (!ok) return;
    final client = Supabase.instance.client;
    try {
      await client
          .from("program_awards")
          .update({
            "status": "entregue",
            "delivered_at": DateTime.now().toIso8601String(),
          })
          .eq("id", award["id"]);
      final streamer = award["streamer"];
      final streamerName = streamer is Map ? streamer["display_name"] as String? : null;
      await syncParticipationAwardFinancialEntry(
        programId: widget.program["id"] as String,
        awardId: award["id"] as String,
        awardTitle: award["title"] as String,
        streamerName: streamerName,
        amount: _itemsTotal(_parseItems(award["items"])),
        status: "entregue",
      );
      await logProgramaHistory(
        streamerId: award["streamer_id"] as String,
        phaseKey: widget.program["program_key"] as String,
        action: "premiacao_entregue",
        detail:
            (award["title"] as String) +
            (streamer is Map
                ? "  -  " + (streamer["display_name"] as String? ?? "")
                : ""),
      );
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Premiacao entregue.")));
      _reload();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  void _openForm({Map<String, dynamic>? existing}) {
    showDialog(
      context: context,
      builder: (context) => _AwardFormDialog(
        program: widget.program,
        existing: existing,
        defaultYear: widget.year,
        defaultMonth: widget.month,
      ),
    ).then((saved) {
      if (saved == true) _reload();
    });
  }

  /// "Quem concluiu este mes" -- aprovados/graduados no mes (modo metas) ou
  /// topo do ranking do mes (modo pontos), pra dar contexto de quem
  /// provavelmente vai levar a premiacao configurada abaixo.
  Widget _concludedSection() {
    return FutureBuilder<void>(
      future: _concludedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final hasData = _trackingMode == "pontos"
            ? _rankingTop.isNotEmpty
            : _concludedThisMonth.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _trackingMode == "pontos"
                    ? "Topo do ranking -- " +
                          monthLabel(widget.year, widget.month)
                    : "Quem concluiu -- " +
                          monthLabel(widget.year, widget.month),
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              if (!hasData)
                const Text(
                  "Ninguem ainda neste mes.",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                )
              else if (_trackingMode == "pontos")
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _rankingTop.asMap().entries.map((e) {
                    final rank = e.key + 1;
                    final s = e.value;
                    return Chip(
                      avatar: CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.white24,
                        child: Text(
                          rank.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      label: Text(
                        s.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: Colors.white.withOpacity(0.06),
                    );
                  }).toList(),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _concludedThisMonth.map((r) {
                    final streamer = r["streamer"];
                    final name = streamer is Map
                        ? (streamer["display_name"] as String? ?? "-")
                        : "-";
                    return Chip(
                      avatar: const Icon(
                        Icons.emoji_events,
                        size: 14,
                        color: Colors.greenAccent,
                      ),
                      label: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: Colors.white.withOpacity(0.06),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedPeriodKey = _periodKeyFor(widget.year, widget.month);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Premiacoes",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Nova premiacao"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A0BD4),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _concludedSection(),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text("Pendentes"),
                selected: _filter == "pendentes",
                selectedColor: Colors.orangeAccent,
                onSelected: (_) => setState(() => _filter = "pendentes"),
              ),
              ChoiceChip(
                label: const Text("Agendadas"),
                selected: _filter == "agendadas",
                selectedColor: Colors.amber,
                onSelected: (_) => setState(() => _filter = "agendadas"),
              ),
              ChoiceChip(
                label: const Text("Entregues"),
                selected: _filter == "entregues",
                selectedColor: Colors.greenAccent,
                onSelected: (_) => setState(() => _filter = "entregues"),
              ),
              ChoiceChip(
                label: const Text("Todos"),
                selected: _filter == "todos",
                selectedColor: Colors.white24,
                onSelected: (_) => setState(() => _filter = "todos"),
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: Text(
                  _showAllMonths
                      ? "Todos os meses"
                      : "So " + monthLabel(widget.year, widget.month),
                ),
                selected: _showAllMonths,
                selectedColor: const Color(0xFF7A0BD4),
                onSelected: (v) => setState(() => _showAllMonths = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return buildProgramasLoadError(snapshot.error!);
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!.where((a) {
                  if (_filter == "pendentes" && a["status"] != "pendente")
                    return false;
                  if (_filter == "agendadas" && a["status"] != "agendado")
                    return false;
                  if (_filter == "entregues" && a["status"] != "entregue")
                    return false;
                  if (!_showAllMonths) {
                    final periodKey = a["period_key"] as String?;
                    if (periodKey != selectedPeriodKey) return false;
                  }
                  return true;
                }).toList();
                if (list.isEmpty)
                  return const Center(
                    child: Text(
                      "Nenhuma premiacao aqui.",
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final award = list[index];
                    final streamer = award["streamer"];
                    final name = streamer is Map
                        ? (streamer["display_name"] as String? ?? "-")
                        : "Sem streamer (manual)";
                    final nick = streamer is Map
                        ? streamer["tiktok_username"] as String?
                        : null;
                    final avatarUrl = streamer is Map
                        ? streamer["avatar_url"] as String?
                        : null;
                    final status = award["status"] as String? ?? "pendente";
                    final statusColor = _awardStatusColor(status);
                    final items = _parseItems(award["items"]);
                    final scheduledDate =
                        award["scheduled_delivery_date"] as String?;
                    final reason = award["reason"] as String?;
                    final isAutoTicket = award["ticket_period_key"] != null;
                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _openForm(existing: award),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white54,
                                  size: 18,
                                )
                              : null,
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                name +
                                    (nick != null && nick.isNotEmpty
                                        ? " (@" + nick + ")"
                                        : ""),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isAutoTicket) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF7A0BD4,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF7A0BD4),
                                  ),
                                ),
                                child: const Text(
                                  "Automatico",
                                  style: TextStyle(
                                    color: Color(0xFF7A0BD4),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items.isNotEmpty
                                  ? _itemsSummary(items)
                                  : (award["title"] as String? ?? "-"),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            if (scheduledDate != null)
                              Text(
                                "Entrega prevista: " + scheduledDate,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            if (reason != null && reason.isNotEmpty)
                              Text(
                                reason,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: statusColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _awardStatusLabel(status),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (status != "entregue")
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.greenAccent,
                                  size: 20,
                                ),
                                tooltip: "Marcar como entregue",
                                onPressed: () => _markDelivered(award),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow {
  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController valueController;
  _ItemRow({String name = "", int quantity = 1, num? value})
    : nameController = TextEditingController(text: name),
      quantityController = TextEditingController(text: quantity.toString()),
      valueController = TextEditingController(text: value?.toString() ?? "");
}

class _AwardFormDialog extends StatefulWidget {
  final Map<String, dynamic> program;
  final Map<String, dynamic>? existing;
  final int defaultYear;
  final int defaultMonth;
  const _AwardFormDialog({
    required this.program,
    this.existing,
    required this.defaultYear,
    required this.defaultMonth,
  });

  @override
  State<_AwardFormDialog> createState() => _AwardFormDialogState();
}

class _AwardFormDialogState extends State<_AwardFormDialog> {
  late final _reasonController = TextEditingController(
    text: widget.existing?["reason"] as String? ?? "",
  );
  late List<_ItemRow> _items = _initialItems();
  late DateTime? _scheduledDeliveryDate =
      widget.existing?["scheduled_delivery_date"] != null
      ? DateTime.parse(widget.existing!["scheduled_delivery_date"] as String)
      : null;
  late String _status = widget.existing?["status"] as String? ?? "pendente";
  late int _periodYear = _initialPeriodYear();
  late int _periodMonth = _initialPeriodMonth();
  Map<String, dynamic>? _selectedStreamer;
  bool _saving = false;
  String? _error;

  int _initialPeriodYear() {
    final key = widget.existing?["period_key"] as String?;
    if (key != null) return int.parse(key.split("-")[0]);
    return widget.defaultYear;
  }

  int _initialPeriodMonth() {
    final key = widget.existing?["period_key"] as String?;
    if (key != null) return int.parse(key.split("-")[1]);
    return widget.defaultMonth;
  }

  List<_ItemRow> _initialItems() {
    final raw = widget.existing?["items"];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .cast<Map<String, dynamic>>()
          .map(
            (it) => _ItemRow(
              name: (it["name"] as String?) ?? "",
              quantity: (it["quantity"] as num?)?.toInt() ?? 1,
              value: it["value"] as num?,
            ),
          )
          .toList();
    }
    final title = widget.existing?["title"] as String?;
    return [_ItemRow(name: title ?? "")];
  }

  @override
  void initState() {
    super.initState();
    final streamer = widget.existing?["streamer"];
    if (widget.existing != null && streamer is Map) {
      _selectedStreamer = {"id": widget.existing!["streamer_id"], ...streamer};
    }
  }

  Future<void> _pickStreamer() async {
    final selected = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => const StreamerPickerDialog(),
    );
    if (selected == null || selected.isEmpty) return;
    setState(() => _selectedStreamer = selected.first);
  }

  Future<void> _pickDeliveryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDeliveryDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _scheduledDeliveryDate = picked);
  }

  Future<void> _save() async {
    final itemsData = _items
        .where((it) => it.nameController.text.trim().isNotEmpty)
        .map(
          (it) => {
            "name": it.nameController.text.trim(),
            "quantity": int.tryParse(it.quantityController.text.trim()) ?? 1,
            "value": double.tryParse(
              it.valueController.text.trim().replaceAll(",", "."),
            ),
          },
        )
        .toList();

    if (itemsData.isEmpty) {
      setState(() => _error = "Adicione pelo menos um item de premiacao.");
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final streamerId = _selectedStreamer?["id"] as String?;
      final wasEntregue = widget.existing?["status"] == "entregue";
      final data = {
        "program_id": widget.program["id"],
        "streamer_id": streamerId,
        "title": _itemsSummary(itemsData),
        "items": itemsData,
        "status": _status,
        "delivered_at": _status == "entregue"
            ? (wasEntregue
                  ? widget.existing!["delivered_at"]
                  : DateTime.now().toIso8601String())
            : null,
        "scheduled_delivery_date": _scheduledDeliveryDate != null
            ? _scheduledDeliveryDate!.toIso8601String().substring(0, 10)
            : null,
        "reason": _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
        "period_key": _periodKeyFor(_periodYear, _periodMonth),
      };
      String awardId;
      if (widget.existing != null) {
        awardId = widget.existing!["id"] as String;
        await client.from("program_awards").update(data).eq("id", awardId);
      } else {
        final inserted = await client
            .from("program_awards")
            .insert({...data, "created_by": userId})
            .select("id")
            .single();
        awardId = inserted["id"] as String;
      }
      await syncParticipationAwardFinancialEntry(
        programId: widget.program["id"] as String,
        awardId: awardId,
        awardTitle: data["title"] as String,
        streamerName: _selectedStreamer?["display_name"] as String?,
        amount: _itemsTotal(itemsData),
        status: _status,
      );
      if (streamerId != null) {
        await logProgramaHistory(
          streamerId: streamerId,
          phaseKey: widget.program["program_key"] as String,
          action: "premiacao_registrada",
          detail: data["title"] as String,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = "Erro: " + e.toString();
      });
    }
  }

  Future<void> _delete() async {
    try {
      await Supabase.instance.client
          .from("program_awards")
          .delete()
          .eq("id", widget.existing!["id"]);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  Widget _itemRowWidget(int index) {
    final item = _items[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: item.nameController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: "Premiacao",
                labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: item.quantityController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: "Qtd",
                labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: item.valueController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: "Valor R\$",
                labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
                isDense: true,
              ),
            ),
          ),
          if (_items.length > 1)
            IconButton(
              icon: const Icon(
                Icons.remove_circle_outline,
                color: Colors.redAccent,
                size: 18,
              ),
              onPressed: () => setState(() => _items.removeAt(index)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing != null ? "Editar premiacao" : "Nova premiacao",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Streamer vinculado (opcional)",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: _selectedStreamer != null
                                ? Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: Colors.white24,
                                        backgroundImage:
                                            _selectedStreamer!["avatar_url"] !=
                                                null
                                            ? NetworkImage(
                                                _selectedStreamer!["avatar_url"]
                                                    as String,
                                              )
                                            : null,
                                        child:
                                            _selectedStreamer!["avatar_url"] ==
                                                null
                                            ? const Icon(
                                                Icons.person,
                                                size: 14,
                                                color: Colors.white54,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedStreamer!["display_name"]
                                                      as String? ??
                                                  "-",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              "@" +
                                                  ((_selectedStreamer!["tiktok_username"]
                                                          as String?) ??
                                                      "-") +
                                                  "  -  ID: " +
                                                  ((_selectedStreamer!["tiktok_creator_id"]
                                                          as String?) ??
                                                      "-"),
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    "Sem streamer vinculado (manual)",
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                          ),
                          TextButton(
                            onPressed: _pickStreamer,
                            child: Text(
                              _selectedStreamer != null
                                  ? "Trocar"
                                  : "Selecionar",
                            ),
                          ),
                          if (_selectedStreamer != null)
                            IconButton(
                              icon: const Icon(
                                Icons.clear,
                                size: 16,
                                color: Colors.white38,
                              ),
                              onPressed: () =>
                                  setState(() => _selectedStreamer = null),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "Itens premiados",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...List.generate(_items.length, _itemRowWidget),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () =>
                              setState(() => _items.add(_ItemRow())),
                          icon: const Icon(
                            Icons.add,
                            size: 16,
                            color: Color(0xFF7A0BD4),
                          ),
                          label: const Text(
                            "Adicionar item",
                            style: TextStyle(color: Color(0xFF7A0BD4)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        dropdownColor: const Color(0xFF232323),
                        decoration: const InputDecoration(
                          labelText: "Status",
                          labelStyle: TextStyle(color: Colors.white54),
                        ),
                        style: const TextStyle(color: Colors.white),
                        items: _awardStatusOptions
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(_awardStatusLabel(s)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _status = v!),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Referente a: " +
                                  monthLabel(_periodYear, _periodMonth),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_left,
                              size: 18,
                              color: Colors.white54,
                            ),
                            onPressed: () => setState(() {
                              if (_periodMonth == 1) {
                                _periodMonth = 12;
                                _periodYear -= 1;
                              } else {
                                _periodMonth -= 1;
                              }
                            }),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: Colors.white54,
                            ),
                            onPressed: () => setState(() {
                              if (_periodMonth == 12) {
                                _periodMonth = 1;
                                _periodYear += 1;
                              } else {
                                _periodMonth += 1;
                              }
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _scheduledDeliveryDate != null
                                  ? "Entrega prevista: " +
                                        _scheduledDeliveryDate!
                                            .toIso8601String()
                                            .substring(0, 10)
                                  : "Entrega prevista: nao definida",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _pickDeliveryDate,
                            child: const Text("Escolher data"),
                          ),
                          if (_scheduledDeliveryDate != null)
                            IconButton(
                              icon: const Icon(
                                Icons.clear,
                                size: 16,
                                color: Colors.white38,
                              ),
                              onPressed: () =>
                                  setState(() => _scheduledDeliveryDate = null),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _reasonController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Motivo",
                          labelStyle: TextStyle(color: Colors.white54),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.existing != null)
                    TextButton(
                      onPressed: _delete,
                      child: const Text(
                        "Excluir",
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text("Cancelar"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A0BD4),
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
