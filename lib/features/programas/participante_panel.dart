import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "program_eligibility_service.dart";
import "participant_extras_service.dart";
import "programa_history_helpers.dart";

/// Resumo individual do participante, aberto como um painel lateral
/// (docked a direita) -- sem sair da tela do programa. Largura responsiva
/// via MediaQuery (nunca passa de 420, nunca estoura telas estreitas).
Future<void> openParticipantPanel(
  BuildContext context, {
  required Map<String, dynamic> program,
  required Map<String, dynamic> row,
  required String nextAction,
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
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: Material(
            color: const Color(0xFF1A1A1A),
            elevation: 8,
            child: SizedBox(
              width: width,
              height: double.infinity,
              child: _ParticipantPanelContent(program: program, row: row, nextAction: nextAction),
            ),
          ),
        ),
      );
    },
  );
}

class _ParticipantPanelContent extends StatefulWidget {
  final Map<String, dynamic> program;
  final Map<String, dynamic> row;
  final String nextAction;
  const _ParticipantPanelContent({required this.program, required this.row, required this.nextAction});

  @override
  State<_ParticipantPanelContent> createState() => _ParticipantPanelContentState();
}

class _ParticipantPanelContentState extends State<_ParticipantPanelContent> {
  bool _loading = true;
  List<Map<String, dynamic>> _awards = [];
  List<Map<String, dynamic>> _observations = [];
  WeekDelta _delta = const WeekDelta();
  late final _noteController = TextEditingController(text: widget.row["pinned_note"] as String? ?? "");
  bool _savingNote = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final streamerId = widget.row["streamer_id"] as String;
    final programId = widget.program["id"] as String;
    final phaseKey = widget.program["program_key"] as String;

    await ensureTodaySnapshot(streamerId: streamerId, agencyId: widget.program["agency_id"] as String);

    final awards = await client
        .from("program_awards")
        .select("title, status, created_at")
        .eq("program_id", programId)
        .eq("streamer_id", streamerId)
        .order("created_at", ascending: false);
    final obs = await client
        .from("streamer_phase_history")
        .select("detail, created_at, manager:managers(login_email)")
        .eq("streamer_id", streamerId)
        .eq("phase_key", phaseKey)
        .eq("action", "observacao")
        .order("created_at", ascending: false)
        .limit(5);
    final delta = await fetchWeekOverWeekDelta(streamerId: streamerId);

    if (mounted) {
      setState(() {
        _awards = (awards as List).cast<Map<String, dynamic>>();
        _observations = (obs as List).cast<Map<String, dynamic>>();
        _delta = delta;
        _loading = false;
      });
    }
  }

  Future<void> _savePinnedNote() async {
    setState(() => _savingNote = true);
    try {
      final text = _noteController.text.trim();
      await setPinnedNote(progressId: widget.row["id"] as String, note: text.isEmpty ? null : text);
      widget.row["pinned_note"] = text.isEmpty ? null : text;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Observacao fixada salva.")));
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  Widget _deltaText(String label, num? delta, {bool isDouble = false}) {
    if (delta == null || delta == 0) return const SizedBox.shrink();
    final up = delta > 0;
    final text = isDouble ? delta.toStringAsFixed(1) : delta.toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 11, color: up ? Colors.greenAccent : Colors.redAccent),
        const SizedBox(width: 2),
        Text((up ? "+" : "") + text + " " + label + " essa semana", style: TextStyle(color: up ? Colors.greenAccent : Colors.redAccent, fontSize: 10)),
      ]),
    );
  }

  Widget _statRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.row["snapshot"] as StreamerSnapshot?;
    final progress = (widget.row["progress"] as double? ?? 0.0).clamp(0.0, 1.0);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white24,
                backgroundImage: snapshot?.avatarUrl != null ? NetworkImage(snapshot!.avatarUrl!) : null,
                child: snapshot?.avatarUrl == null ? const Icon(Icons.person, color: Colors.white54) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(snapshot?.displayName ?? "-", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  Text((widget.program["name"] as String?) ?? "-", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
              ),
              IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.of(context).pop()),
            ]),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _noteController,
                          maxLines: 2,
                          style: const TextStyle(color: Colors.amber, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: "Observacao fixada",
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.amber.withOpacity(0.08),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _savingNote ? null : _savePinnedNote, child: Text(_savingNote ? "Salvando..." : "Salvar"))),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Color(0xFF7A0BD4))),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text((progress * 100).toStringAsFixed(0) + "%", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ]),
                        const SizedBox(height: 4),
                        Text("Proxima etapa: " + widget.nextAction, style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _deltaText("horas", _delta.hoursDelta, isDouble: true),
                        _statRow("Dias na agencia", snapshot?.daysInAgency.toString() ?? "-"),
                        _statRow("Horas", snapshot?.hoursLive.toStringAsFixed(1) ?? "-"),
                        _deltaText("diamantes", _delta.diamondsDelta),
                        _statRow("Diamantes", snapshot?.diamonds.toString() ?? "-"),
                        _deltaText("Heart Me", _delta.heartMeDelta),
                        _statRow("Heart Me", snapshot?.heartMe?.toString() ?? "-"),
                        const SizedBox(height: 20),
                        const Text("Premiacoes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        if (_awards.isEmpty)
                          const Text("Nenhuma ainda.", style: TextStyle(color: Colors.white38, fontSize: 12))
                        else
                          ..._awards.map((a) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text((a["title"] as String) + " - " + (a["status"] == "entregue" ? "Entregue" : "Pendente"), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              )),
                        const SizedBox(height: 20),
                        const Text("Ultimas observacoes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        if (_observations.isEmpty)
                          const Text("Nenhuma ainda.", style: TextStyle(color: Colors.white38, fontSize: 12))
                        else
                          ..._observations.map((o) {
                            final manager = o["manager"];
                            final email = manager is Map ? manager["login_email"] as String? : null;
                            final date = o["created_at"] != null ? DateTime.parse(o["created_at"] as String).toLocal().toString().substring(0, 16) : "-";
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text((o["detail"] as String?) ?? "-", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                Text(date + (email != null ? "  -  " + email : ""), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                              ]),
                            );
                          }),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
