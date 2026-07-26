import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "program_eligibility_service.dart";
import "programa_history_helpers.dart";

class ProgramaVisaoGeralTab extends StatefulWidget {
  final Map<String, dynamic> program;
  final VoidCallback onChanged;
  const ProgramaVisaoGeralTab({super.key, required this.program, required this.onChanged});

  @override
  State<ProgramaVisaoGeralTab> createState() => _ProgramaVisaoGeralTabState();
}

class _ProgramaVisaoGeralTabState extends State<ProgramaVisaoGeralTab> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<String?> _findPreviousProgramKey(String agencyId, String programKey) async {
    final client = Supabase.instance.client;
    final row = await client
        .from("development_programs")
        .select("program_key")
        .eq("agency_id", agencyId)
        .or("next_program_key.eq." + programKey + ",graduate_program_key.eq." + programKey)
        .maybeSingle();
    return row?["program_key"] as String?;
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final program = widget.program;
    final agencyId = program["agency_id"] as String;
    final phaseKey = program["program_key"] as String;
    final criteria = ProgramCriteria.fromMap(program["criteria"] as Map<String, dynamic>?);

    final snapshots = await fetchActiveStreamerSnapshots(agencyId: agencyId);
    final enrolled = await fetchEnrolledStreamerIds(phaseKey: phaseKey);
    final previousKey = await _findPreviousProgramKey(agencyId, phaseKey);
    final completedPrev = previousKey != null ? await fetchCompletedStreamerIds(phaseKey: previousKey) : null;

    var eligibleCount = 0;
    for (final s in snapshots) {
      if (enrolled.contains(s.id)) continue;
      if (completedPrev != null && !completedPrev.contains(s.id)) continue;
      if (evaluateEligibility(s, criteria).eligible) eligibleCount++;
    }

    final progressRows = await client.from("streamer_phase_progress").select("streamer_id, stage_key, outcome, completed_at, stage_changed_at").eq("phase_key", phaseKey);
    final activeRows = (progressRows as List).cast<Map<String, dynamic>>().where((r) => r["completed_at"] == null).toList();

    final stageRows = await client.from("streamer_phase_stages").select("stage_key, is_evaluation_stage").eq("agency_id", agencyId).eq("phase_key", phaseKey);
    final evalStages = (stageRows as List).where((r) => r["is_evaluation_stage"] == true).map((r) => r["stage_key"] as String).toSet();
    final pendingEvaluations = activeRows.where((r) => evalStages.contains(r["stage_key"]) && r["outcome"] == null).length;

    final awardRowsAll = await client.from("program_awards").select("streamer_id, status").eq("program_id", program["id"]);
    final pendingAwardsByStreamer = <String, int>{};
    for (final a in (awardRowsAll as List)) {
      if (a["status"] == "pendente") {
        final id = a["streamer_id"] as String;
        pendingAwardsByStreamer[id] = (pendingAwardsByStreamer[id] ?? 0) + 1;
      }
    }
    final pendingAwards = pendingAwardsByStreamer.values.fold(0, (a, b) => a + b);

    final activeStreamerIds = activeRows.map((r) => r["streamer_id"] as String).toList();
    final activeSnapshots = await fetchStreamerSnapshotsByIds(streamerIds: activeStreamerIds);
    final snapshotById = {for (final s in activeSnapshots) s.id: s};

    // "Precisam de Atencao": um motivo por streamer, na ordem de
    // prioridade abaixo -- premiacao pendente e avaliacao pendente exigem
    // acao imediata do gestor, entao vem primeiro.
    final attention = <Map<String, dynamic>>[];
    for (final r in activeRows) {
      final streamerId = r["streamer_id"] as String;
      final snapshot = snapshotById[streamerId];
      final name = snapshot?.displayName ?? "-";
      final pending = pendingAwardsByStreamer[streamerId] ?? 0;
      final isEval = evalStages.contains(r["stage_key"]) && r["outcome"] == null;
      final eligibility = snapshot != null ? evaluateEligibility(snapshot, criteria) : null;
      final stageChangedAt = r["stage_changed_at"] != null ? DateTime.parse(r["stage_changed_at"] as String) : null;
      final daysStalled = stageChangedAt != null ? DateTime.now().difference(stageChangedAt).inDays : 0;

      if (pending > 0) {
        attention.add({"name": name, "reason": "Premiacao pendente"});
      } else if (isEval) {
        attention.add({"name": name, "reason": "Avaliacao pendente"});
      } else if (eligibility != null && eligibility.gaps.isNotEmpty) {
        attention.add({"name": name, "reason": eligibility.gaps.first});
      } else if (daysStalled >= 10) {
        attention.add({"name": name, "reason": daysStalled.toString() + " dias sem evolucao"});
      }
    }

    String? nextProgramName;
    final nextKey = program["next_program_key"] as String?;
    if (nextKey != null) {
      final next = await client.from("development_programs").select("name").eq("agency_id", agencyId).eq("program_key", nextKey).maybeSingle();
      nextProgramName = next?["name"] as String?;
    }

    return {
      "participantCount": activeRows.length,
      "eligibleCount": eligibleCount,
      "pendingEvaluations": pendingEvaluations,
      "pendingAwards": pendingAwards,
      "nextProgramName": nextProgramName,
      "attention": attention,
    };
  }

  void _reload() => setState(() => _future = _load());

  List<String> _criteriaLines(ProgramCriteria c) {
    final lines = <String>[];
    if (c.minDays != null) lines.add("Dias minimos na agencia: " + c.minDays.toString());
    if (c.minHours != null) lines.add("Horas minimas: " + c.minHours.toString());
    if (c.minDiamonds != null) lines.add("Diamantes minimos: " + c.minDiamonds.toString());
    if (c.minHeartMe != null) lines.add("Heart Me minimo: " + c.minHeartMe.toString());
    if (c.minBattles != null) lines.add("Batalhas minimas: " + c.minBattles.toString());
    if (c.categoryIds.isNotEmpty) lines.add("Restrito a " + c.categoryIds.length.toString() + " categoria(s)");
    if (c.requiredMaterialIds.isNotEmpty) lines.add(c.requiredMaterialIds.length.toString() + " treinamento(s) obrigatorio(s) (informativo)");
    return lines;
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _section(String title, String? content) {
    if (content == null || content.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final program = widget.program;
    final managerData = program["manager"];
    final criteria = ProgramCriteria.fromMap(program["criteria"] as Map<String, dynamic>?);
    final criteriaLines = _criteriaLines(criteria);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) return buildProgramasLoadError(snapshot.error!);
              if (!snapshot.hasData) return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()));
              final data = snapshot.data!;
              final attention = (data["attention"] as List).cast<Map<String, dynamic>>();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    _summaryCard("Participantes", (data["participantCount"] as int).toString(), const Color(0xFF7A0BD4)),
                    _summaryCard("Elegiveis", (data["eligibleCount"] as int).toString(), Colors.greenAccent),
                    _summaryCard("Avaliacoes pendentes", (data["pendingEvaluations"] as int).toString(), Colors.orangeAccent),
                    _summaryCard("Premiacoes pendentes", (data["pendingAwards"] as int).toString(), Colors.pinkAccent),
                  ]),
                  const SizedBox(height: 20),
                  const Text("Precisam de Atencao", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text("Gerado automaticamente -- quem precisa de acompanhamento agora.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 8),
                  if (attention.isEmpty)
                    const Text("Ninguem precisando de atencao no momento.", style: TextStyle(color: Colors.white54, fontSize: 12))
                  else
                    ...attention.map((a) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            const Icon(Icons.priority_high, size: 14, color: Colors.orangeAccent),
                            const SizedBox(width: 6),
                            Text(a["name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 8),
                            Text(a["reason"] as String, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ]),
                        )),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _section("Descricao", program["description"] as String?),
          _section("Objetivo", program["objective"] as String?),
          if (criteriaLines.isNotEmpty) _section("Criterios", criteriaLines.join("\n")),
          _section("Premiacoes", program["awards_description"] as String?),
          _section("Responsavel", managerData is Map ? managerData["login_email"] as String? : null),
          FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              final nextName = snapshot.data?["nextProgramName"] as String?;
              return _section("Proximo programa", nextName);
            },
          ),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh, size: 16), label: const Text("Atualizar"))),
        ],
      ),
    );
  }
}
