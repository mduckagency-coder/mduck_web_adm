import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "program_eligibility_service.dart" show ProgramCriteria;
import "program_participation_service.dart";
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

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final program = widget.program;
    final agencyId = program["agency_id"] as String;
    final programId = program["id"] as String;

    final participations = await fetchParticipations(programId: programId);
    final active = participations.where((p) => p.status == "ativo").toList();
    final emProcesso = active
        .where((p) => p.goals.any((g) => g.outcome == "pendente"))
        .length;
    final concluidos = participations.where((p) => p.status == "concluido").length;

    final awardRows = await client
        .from("program_awards")
        .select("status")
        .eq("program_id", programId);
    final pendingAwards = (awardRows as List)
        .where((a) => a["status"] == "pendente")
        .length;

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
      "participations": participations,
      "activeCount": active.length,
      "emProcesso": emProcesso,
      "concluidos": concluidos,
      "pendingAwards": pendingAwards,
      "nextProgramName": nextProgramName,
    };
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _editProgram() async {
    try {
      final saved = await showEditProgramDialog(context, widget.program);
      if (!saved) return;
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

  /// So exibicao informativa -- criterios de programas antigos (modo
  /// "faixa"/critérios automaticos) continuam gravados no banco mesmo sem
  /// mais serem usados pra decidir entrada/saida (isso agora e manual, via
  /// aba Participantes). Mostrar aqui ajuda o gestor a saber que configuracao
  /// legada ainda existe, sem rodar nenhuma consulta pesada.
  List<String> _criteriaLines(ProgramCriteria c) {
    final lines = <String>[];
    if (c.isEmpty) return lines;
    lines.add(
      c.membershipMode == "faixa"
          ? "Modo legado: faixa automatica (nao usado mais pela aba Participantes)"
          : "Modo legado: fluxo manual (nao usado mais pela aba Participantes)",
    );
    if (c.minDays != null || c.maxDaysInAgency != null) {
      final from = c.minDays?.toString() ?? "0";
      final to = c.maxDaysInAgency != null ? " ate " + c.maxDaysInAgency.toString() : "+";
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
      final to = c.maxDiamonds != null ? " ate " + c.maxDiamonds.toString() : "+";
      lines.add(
        "Diamantes: a partir de " +
            from +
            to +
            " (" +
            (_periodLabels[c.diamondsPeriod] ?? c.diamondsPeriod) +
            ")",
      );
    }
    if (c.minHeartMe != null) lines.add("Heart Me minimo: " + c.minHeartMe.toString());
    if (c.minBattles != null) lines.add("Batalhas minimas: " + c.minBattles.toString());
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
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
          ),
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
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
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
    final criteriaLines = _criteriaLines(
      ProgramCriteria.fromMap(program["criteria"] as Map<String, dynamic>?),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Visao Geral",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
              if (snapshot.hasError) return buildProgramasLoadError(snapshot.error!);
              if (!snapshot.hasData)
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              final data = snapshot.data!;
              final participations = (data["participations"] as List)
                  .cast<ProgramParticipation>();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _summaryCard(
                        "Participantes ativos",
                        (data["activeCount"] as int).toString(),
                        const Color(0xFF7A0BD4),
                      ),
                      _summaryCard(
                        "Em processo",
                        (data["emProcesso"] as int).toString(),
                        Colors.amber,
                      ),
                      _summaryCard(
                        "Concluidos",
                        (data["concluidos"] as int).toString(),
                        Colors.greenAccent,
                      ),
                      _summaryCard(
                        "Premiacoes pendentes",
                        (data["pendingAwards"] as int).toString(),
                        Colors.pinkAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Participantes",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Quem esta no programa agora. Pra incluir, remover ou confirmar metas, use a aba Participantes.",
                    style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 8),
                  if (participations.isEmpty)
                    const Text(
                      "Nenhum participante incluido ainda.",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: participations.map((p) {
                        final color = p.status == "concluido"
                            ? Colors.greenAccent
                            : p.status == "removido"
                            ? Colors.white38
                            : Colors.blueAccent;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                p.streamerName ?? "-",
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                p.statusLabel,
                                style: TextStyle(color: color.withOpacity(0.7), fontSize: 10),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _section("Descricao", program["description"] as String?),
          _section("Objetivo", program["objective"] as String?),
          if (criteriaLines.isNotEmpty)
            _section("Configuracao legada (nao usada pela aba Participantes)", criteriaLines.join("\n")),
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
