import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "program_eligibility_service.dart";
import "program_monthly_stats_service.dart";
import "programa_history_helpers.dart";

class ProgramaVisaoGeralTab extends StatefulWidget {
  final Map<String, dynamic> program;
  final VoidCallback onChanged;
  final int year;
  final int month;
  const ProgramaVisaoGeralTab({
    super.key,
    required this.program,
    required this.onChanged,
    required this.year,
    required this.month,
  });

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

  @override
  void didUpdateWidget(ProgramaVisaoGeralTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year || oldWidget.month != widget.month)
      _reload();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final program = widget.program;
    final agencyId = program["agency_id"] as String;
    final phaseKey = program["program_key"] as String;
    final programId = program["id"] as String;
    final criteria = ProgramCriteria.fromMap(
      program["criteria"] as Map<String, dynamic>?,
    );

    await runProgramSync(
      programId: programId,
      phaseKey: phaseKey,
      agencyId: agencyId,
      criteria: criteria,
      year: widget.year,
      month: widget.month,
    );

    final snapshotsRaw = await fetchActiveStreamerSnapshots(agencyId: agencyId);
    final snapshots = await resolveMonthlySnapshots(
      snapshots: snapshotsRaw,
      criteria: criteria,
      agencyId: agencyId,
      year: widget.year,
      month: widget.month,
    );
    final enrolled = await fetchEnrolledStreamerIds(phaseKey: phaseKey);
    final previousKey = await findPreviousProgramKey(
      agencyId: agencyId,
      phaseKey: phaseKey,
    );
    final completedPrev = previousKey != null
        ? await fetchCompletedStreamerIds(phaseKey: previousKey)
        : null;

    var eligibleCount = 0;
    final eligibleNames = <String>[];
    for (final s in criteria.isEmpty ? const <StreamerSnapshot>[] : snapshots) {
      if (enrolled.contains(s.id)) continue;
      if (completedPrev != null && !completedPrev.contains(s.id)) continue;
      if (evaluateEligibility(s, criteria).eligible) {
        eligibleCount++;
        eligibleNames.add(s.displayName);
      }
    }

    // Modo pontos: sem aprovar/reprovar, so exibe o ranking de quem passa nos
    // filtros duros (categoria/faixa/novato/inativo) -- rankByPoints so
    // ordena, nao decide entrada/saida (isso continua fora do escopo aqui).
    final rankingPool = criteria.trackingMode == "pontos"
        ? rankByPoints(
            snapshots
                .where((s) => evaluateEligibility(s, criteria).eligible)
                .toList(),
            criteria,
          )
        : const <StreamerSnapshot>[];

    final progressRows = await client
        .from("streamer_phase_progress")
        .select(
          "streamer_id, stage_key, outcome, completed_at, stage_changed_at",
        )
        .eq("phase_key", phaseKey);
    final activeRows = (progressRows as List)
        .cast<Map<String, dynamic>>()
        .where((r) => r["completed_at"] == null)
        .toList();

    final stageRows = await client
        .from("streamer_phase_stages")
        .select("stage_key, is_evaluation_stage")
        .eq("agency_id", agencyId)
        .eq("phase_key", phaseKey);
    final evalStages = (stageRows as List)
        .where((r) => r["is_evaluation_stage"] == true)
        .map((r) => r["stage_key"] as String)
        .toSet();
    final pendingEvaluations = activeRows
        .where(
          (r) => evalStages.contains(r["stage_key"]) && r["outcome"] == null,
        )
        .length;

    final awardRowsAll = await client
        .from("program_awards")
        .select("streamer_id, status")
        .eq("program_id", program["id"]);
    final pendingAwardsByStreamer = <String, int>{};
    for (final a in (awardRowsAll as List)) {
      if (a["status"] == "pendente") {
        final id = a["streamer_id"] as String;
        pendingAwardsByStreamer[id] = (pendingAwardsByStreamer[id] ?? 0) + 1;
      }
    }
    final pendingAwards = pendingAwardsByStreamer.values.fold(
      0,
      (a, b) => a + b,
    );

    final activeStreamerIds = activeRows
        .map((r) => r["streamer_id"] as String)
        .toList();
    final activeSnapshots = await fetchStreamerSnapshotsByIds(
      streamerIds: activeStreamerIds,
    );
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
      final isEval =
          evalStages.contains(r["stage_key"]) && r["outcome"] == null;
      final eligibility = snapshot != null
          ? evaluateEligibility(snapshot, criteria)
          : null;
      final stageChangedAt = r["stage_changed_at"] != null
          ? DateTime.parse(r["stage_changed_at"] as String)
          : null;
      final daysStalled = stageChangedAt != null
          ? DateTime.now().difference(stageChangedAt).inDays
          : 0;

      if (pending > 0) {
        attention.add({"name": name, "reason": "Premiacao pendente"});
      } else if (isEval) {
        attention.add({"name": name, "reason": "Avaliacao pendente"});
      } else if (eligibility != null && eligibility.gaps.isNotEmpty) {
        attention.add({"name": name, "reason": eligibility.gaps.first});
      } else if (daysStalled >= 10) {
        attention.add({
          "name": name,
          "reason": daysStalled.toString() + " dias sem evolucao",
        });
      }
    }

    String? nextProgramName;
    final nextKey = program["next_program_key"] as String?;
    if (nextKey != null) {
      final next = await client
          .from("development_programs")
          .select("name")
          .eq("agency_id", agencyId)
          .eq("program_key", nextKey)
          .maybeSingle();
      nextProgramName = next?["name"] as String?;
    }

    return {
      "participantCount": activeRows.length,
      "eligibleCount": eligibleCount,
      "eligibleNames": eligibleNames,
      "pendingEvaluations": pendingEvaluations,
      "pendingAwards": pendingAwards,
      "nextProgramName": nextProgramName,
      "attention": attention,
      "rankingPool": rankingPool,
    };
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _editProgram() async {
    final program = widget.program;
    final nameController = TextEditingController(
      text: program["name"] as String? ?? "",
    );
    final objectiveController = TextEditingController(
      text: program["objective"] as String? ?? "",
    );
    final descriptionController = TextEditingController(
      text: program["description"] as String? ?? "",
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          "Editar programa",
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Nome",
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: objectiveController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Objetivo",
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Descricao",
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7A0BD4),
              foregroundColor: Colors.white,
            ),
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
    if (saved != true) return;

    try {
      final updatePayload = {
        "name": nameController.text.trim().isEmpty
            ? program["name"]
            : nameController.text.trim(),
        "objective": objectiveController.text.trim().isEmpty
            ? null
            : objectiveController.text.trim(),
        "description": descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        "updated_at": DateTime.now().toIso8601String(),
      };
      await Supabase.instance.client
          .from("development_programs")
          .update(updatePayload)
          .eq("id", program["id"]);
      program.addAll(updatePayload);
      widget.onChanged();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  static const _periodLabels = {
    "total": "total acumulado",
    "mes_atual": "mes atual",
    "mes_anterior": "mes anterior",
    "mes_atual_ou_anterior": "mes atual ou anterior",
  };

  List<String> _criteriaLines(ProgramCriteria c) {
    final lines = <String>[];
    lines.add(
      c.membershipMode == "faixa"
          ? "Modo: faixa automatica (entra e sai sozinho)"
          : "Modo: fluxo manual (Kanban + avaliacao)",
    );
    if (c.minDays != null || c.maxDaysInAgency != null) {
      final from = c.minDays?.toString() ?? "0";
      final to = c.maxDaysInAgency != null
          ? " ate " + c.maxDaysInAgency.toString()
          : "+";
      lines.add("Dias na agencia: a partir de " + from + to);
    }
    if (c.minHours != null)
      lines.add(
        "Horas minimas: " +
            c.minHours.toString() +
            " (" +
            (_periodLabels[c.hoursPeriod] ?? c.hoursPeriod) +
            ")",
      );
    if (c.minDiamonds != null || c.maxDiamonds != null) {
      final from = c.minDiamonds?.toString() ?? "0";
      final to = c.maxDiamonds != null
          ? " ate " + c.maxDiamonds.toString()
          : "+";
      lines.add(
        "Diamantes: a partir de " +
            from +
            to +
            " (" +
            (_periodLabels[c.diamondsPeriod] ?? c.diamondsPeriod) +
            ")",
      );
    }
    if (c.minHeartMe != null)
      lines.add("Heart Me minimo: " + c.minHeartMe.toString());
    if (c.minBattles != null)
      lines.add("Batalhas minimas: " + c.minBattles.toString());
    if (c.categoryIds.isNotEmpty)
      lines.add(
        "Restrito a " + c.categoryIds.length.toString() + " categoria(s)",
      );
    if (c.categoryOverrides.isNotEmpty)
      lines.add(
        c.categoryOverrides.length.toString() +
            " categoria(s) com meta personalizada",
      );
    if (c.ticketQuantity > 0)
      lines.add(
        "Tickets de sorteio: " + c.ticketQuantity.toString() + " por conclusao",
      );
    return lines;
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, String? content) {
    if (content == null || content.trim().isEmpty)
      return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final program = widget.program;
    final managerData = program["manager"];
    final criteria = ProgramCriteria.fromMap(
      program["criteria"] as Map<String, dynamic>?,
    );
    final criteriaLines = _criteriaLines(criteria);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Visao Geral",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit, size: 16, color: Colors.white54),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                onPressed: _editProgram,
                tooltip: "Editar titulo, objetivo e descricao",
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return buildProgramasLoadError(snapshot.error!);
              if (!snapshot.hasData)
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              final data = snapshot.data!;
              final attention = (data["attention"] as List)
                  .cast<Map<String, dynamic>>();
              final eligibleNames = (data["eligibleNames"] as List)
                  .cast<String>();
              final rankingPool = (data["rankingPool"] as List)
                  .cast<StreamerSnapshot>();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _summaryCard(
                        "Participantes",
                        (data["participantCount"] as int).toString(),
                        const Color(0xFF7A0BD4),
                      ),
                      _summaryCard(
                        "Elegiveis",
                        (data["eligibleCount"] as int).toString(),
                        Colors.greenAccent,
                      ),
                      _summaryCard(
                        "Avaliacoes pendentes",
                        (data["pendingEvaluations"] as int).toString(),
                        Colors.orangeAccent,
                      ),
                      _summaryCard(
                        "Premiacoes pendentes",
                        (data["pendingAwards"] as int).toString(),
                        Colors.pinkAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (criteria.trackingMode == "pontos") ...[
                    const Text(
                      "Ranking do Programa",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Ordenado pela metrica escolhida em Configuracoes -- nao aprova nem reprova ninguem.",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (rankingPool.isEmpty)
                      const Text(
                        "Nenhum streamer no ranking no momento.",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      )
                    else
                      ...rankingPool.take(20).toList().asMap().entries.map((
                        entry,
                      ) {
                        final index = entry.key;
                        final s = entry.value;
                        final isTop3 = index < 3;
                        final medalColor = index == 0
                            ? Colors.amber
                            : index == 1
                            ? Colors.grey.shade300
                            : index == 2
                            ? const Color(0xFFCD7F32)
                            : Colors.white24;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isTop3
                                ? Colors.amber.withOpacity(0.08)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: isTop3
                                ? Border.all(color: medalColor.withOpacity(0.6))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: medalColor.withOpacity(
                                    isTop3 ? 1 : 0.2,
                                  ),
                                ),
                                child: Text(
                                  "#" + (index + 1).toString(),
                                  style: TextStyle(
                                    color: isTop3
                                        ? Colors.black
                                        : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  s.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                pointsValueFor(s, criteria).toString(),
                                style: const TextStyle(
                                  color: Color(0xFF7A0BD4),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ] else ...[
                    const Text(
                      "Streamers Elegiveis",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Ja batem os criterios automaticos deste programa agora.",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (eligibleNames.isEmpty)
                      const Text(
                        "Nenhum streamer elegivel no momento.",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: eligibleNames
                            .map(
                              (name) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.greenAccent),
                                ),
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    "Precisam de Atencao",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Gerado automaticamente -- quem precisa de acompanhamento agora.",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (attention.isEmpty)
                    const Text(
                      "Ninguem precisando de atencao no momento.",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    )
                  else
                    ...attention.map(
                      (a) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.priority_high,
                              size: 14,
                              color: Colors.orangeAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              a["name"] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              a["reason"] as String,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _section("Descricao", program["description"] as String?),
          _section("Objetivo", program["objective"] as String?),
          if (criteriaLines.isNotEmpty)
            _section("Configuracao deste programa", criteriaLines.join("\n")),
          _section("Premiacoes", program["awards_description"] as String?),
          _section(
            "Responsavel",
            managerData is Map ? managerData["login_email"] as String? : null,
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              final nextName = snapshot.data?["nextProgramName"] as String?;
              return _section("Proximo programa", nextName);
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text("Atualizar"),
            ),
          ),
        ],
      ),
    );
  }
}
