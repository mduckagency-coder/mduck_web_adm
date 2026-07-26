import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "campaign_cycle_service.dart";
import "campanha_detail_page.dart";
import "programa_history_helpers.dart";

class ProgramaCampanhasTab extends StatefulWidget {
  final Map<String, dynamic> program;
  const ProgramaCampanhasTab({super.key, required this.program});

  @override
  State<ProgramaCampanhasTab> createState() => _ProgramaCampanhasTabState();
}

class _ProgramaCampanhasTabState extends State<ProgramaCampanhasTab> {
  bool _loading = true;
  bool _starting = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _cycles = [];

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
      final rows = await client.from("campaign_cycles").select().eq("program_id", widget.program["id"]).order("started_at", ascending: false);
      final cycles = (rows as List).cast<Map<String, dynamic>>();

      final cycleIds = cycles.map((c) => c["id"] as String).toList();
      final participantRows = cycleIds.isEmpty ? [] : await client.from("campaign_cycle_participants").select("cycle_id").inFilter("cycle_id", cycleIds);
      final countByCycle = <String, int>{};
      for (final r in (participantRows as List)) {
        final id = r["cycle_id"] as String;
        countByCycle[id] = (countByCycle[id] ?? 0) + 1;
      }
      for (final c in cycles) {
        c["participantCount"] = countByCycle[c["id"]] ?? 0;
      }

      setState(() {
        _cycles = cycles;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _startNewCycle() async {
    setState(() => _starting = true);
    try {
      final cycleId = await startNewCycle(program: widget.program);
      await _load();
      if (mounted) _openCycle({"id": cycleId});
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _openCycle(Map<String, dynamic> cycle) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => CampanhaDetailPage(program: widget.program, cycleId: cycle["id"] as String)))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final hasOpenCycle = _cycles.any((c) => c["status"] == "em_andamento");
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Campanhas Mensais", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _load),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: (_starting || hasOpenCycle) ? null : _startNewCycle,
              icon: const Icon(Icons.play_circle_outline, size: 16),
              label: Text(_starting ? "Iniciando..." : "Iniciar novo ciclo"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            hasOpenCycle ? "Ja existe um ciclo em andamento -- finalize-o para iniciar o proximo." : "Participantes sao buscados automaticamente ao iniciar o ciclo, sem selecao manual.",
            style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? buildProgramasLoadError(_errorMessage!)
                    : _cycles.isEmpty
                        ? const Center(child: Text("Nenhum ciclo iniciado ainda.", style: TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            itemCount: _cycles.length,
                            itemBuilder: (context, index) {
                              final cycle = _cycles[index];
                              final isOpen = cycle["status"] == "em_andamento";
                              final color = isOpen ? Colors.amber : Colors.greenAccent;
                              return Card(
                                color: Colors.white.withOpacity(0.05),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  onTap: () => _openCycle(cycle),
                                  leading: Icon(isOpen ? Icons.hourglass_bottom : Icons.check_circle, color: color),
                                  title: Text(cycle["period_label"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  subtitle: Text((cycle["participantCount"] as int).toString() + " participantes", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(8)),
                                    child: Text(isOpen ? "Em andamento" : "Finalizado", style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
