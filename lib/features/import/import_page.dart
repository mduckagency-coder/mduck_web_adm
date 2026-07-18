import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "tiktok_import_repository.dart";
import "activity_import_repository.dart";
import "agent_link_import_repository.dart";

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final _repository = TikTokImportRepository();
  final _activityRepository = ActivityImportRepository();
  final _agentLinkRepository = AgentLinkImportRepository();
  bool _isProcessing = false;
  bool _isProcessingActivity = false;
  bool _isProcessingAgentLink = false;
  ImportSummary? _summary;
  ActivityImportSummary? _activitySummary;
  AgentLinkImportSummary? _agentLinkSummary;
  String? _errorMessage;
  String? _activityErrorMessage;
  String? _agentLinkErrorMessage;
  String? _agencyId;
  DateTime? _lastMetricsUpdate;
  DateTime? _lastActivityUpdate;
  DateTime? _lastAgentLinkUpdate;

  @override
  void initState() {
    super.initState();
    _loadAgencyId();
  }

  Future<void> _loadAgencyId() async {
    final client = Supabase.instance.client;
    final managerId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", managerId).single();
    setState(() {
      _agencyId = manager["agency_id"];
    });
    _loadLastUpdates();
  }

  Future<void> _loadLastUpdates() async {
    final client = Supabase.instance.client;
    final metrics = await client
        .from("tiktok_imports")
        .select("processed_at")
        .eq("import_type", "metricas")
        .order("processed_at", ascending: false)
        .limit(1)
        .maybeSingle();
    final activity = await client
        .from("tiktok_imports")
        .select("processed_at")
        .eq("import_type", "atividade")
        .order("processed_at", ascending: false)
        .limit(1)
        .maybeSingle();
    final agentLink = await client
        .from("tiktok_imports")
        .select("processed_at")
        .eq("import_type", "vinculo_agente")
        .order("processed_at", ascending: false)
        .limit(1)
        .maybeSingle();
    setState(() {
      _lastMetricsUpdate = metrics != null && metrics["processed_at"] != null ? DateTime.parse(metrics["processed_at"]) : null;
      _lastActivityUpdate = activity != null && activity["processed_at"] != null ? DateTime.parse(activity["processed_at"]) : null;
      _lastAgentLinkUpdate = agentLink != null && agentLink["processed_at"] != null ? DateTime.parse(agentLink["processed_at"]) : null;
    });
  }

  Future<void> _pickAndProcessMetrics() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["xlsx"],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _summary = null;
    });

    try {
      final summary = await _repository.processFile(result.files.single.bytes!, agencyId: _agencyId!);
      setState(() {
        _summary = summary;
      });
      _loadLastUpdates();
    } catch (e) {
      setState(() {
        _errorMessage = "Erro ao processar planilha: " + e.toString();
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickAndProcessAgentLink() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["xlsx"],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() {
      _isProcessingAgentLink = true;
      _agentLinkErrorMessage = null;
      _agentLinkSummary = null;
    });

    try {
      final client = Supabase.instance.client;
      final importRecord = await client.from("tiktok_imports").insert({
        "agency_id": _agencyId,
        "uploaded_by": client.auth.currentUser!.id,
        "file_url": "upload_direto",
        "status": "processando",
        "import_type": "vinculo_agente",
      }).select().single();

      final summary = await _agentLinkRepository.processFile(result.files.single.bytes!);

      await client.from("tiktok_imports").update({
        "status": "concluido",
        "rows_processed": summary.rows.length,
        "processed_at": DateTime.now().toIso8601String(),
      }).eq("id", importRecord["id"]);

      setState(() {
        _agentLinkSummary = summary;
      });
      _loadLastUpdates();
    } catch (e) {
      setState(() {
        _agentLinkErrorMessage = "Erro ao processar planilha: " + e.toString();
      });
    } finally {
      setState(() {
        _isProcessingAgentLink = false;
      });
    }
  }

  Future<void> _pickAndProcessActivity() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["xlsx"],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() {
      _isProcessingActivity = true;
      _activityErrorMessage = null;
      _activitySummary = null;
    });

    try {
      final summary = await _activityRepository.processFile(result.files.single.bytes!);
      setState(() {
        _activitySummary = summary;
      });
      _loadLastUpdates();
    } catch (e) {
      setState(() {
        _activityErrorMessage = "Erro ao processar planilha: " + e.toString();
      });
    } finally {
      setState(() {
        _isProcessingActivity = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Importacao TikTok",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 24),

          // Bloco 1: planilha de metricas mensais
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("1. Planilha de Metricas (mes atual/mes passado)",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                const Text(
                  "Atualiza diamantes, horas e dias validos do mes, e fecha o mes anterior.",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  _lastMetricsUpdate != null
                      ? "Ultima atualizacao: " + _lastMetricsUpdate!.toLocal().toString().substring(0, 16)
                      : "Nunca atualizado",
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: (_isProcessing || _agencyId == null) ? null : _pickAndProcessMetrics,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_isProcessing ? "Processando..." : "Selecionar planilha (.xlsx)"),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                if (_summary != null) ...[
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    _SummaryChip(label: "Linhas lidas", value: _summary!.totalRowsRead, color: Colors.white),
                    _SummaryChip(label: "Aplicados", value: _summary!.applied, color: Colors.greenAccent),
                    const SizedBox(width: 12),
                    _SummaryChip(label: "Criados", value: _summary!.created, color: Colors.cyanAccent),
                    _SummaryChip(label: "Nao encontrados", value: _summary!.notFound, color: Colors.orangeAccent),
                    _SummaryChip(label: "Erros", value: _summary!.errors, color: Colors.redAccent),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 240,
                    child: ListView.builder(
                      itemCount: _summary!.rows.length,
                      itemBuilder: (context, index) {
                        final row = _summary!.rows[index];
                        final color = row.status == "aplicado"
                            ? Colors.greenAccent
                            : row.status == "nao_encontrado"
                                ? Colors.orangeAccent
                                : Colors.redAccent;
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.circle, size: 10, color: color),
                          title: Text(row.nick.isEmpty ? row.tiktokId : row.nick, style: const TextStyle(color: Colors.white)),
                          subtitle: row.detail != null ? Text(row.detail!, style: const TextStyle(color: Colors.white54, fontSize: 11)) : null,
                          trailing: Text(row.status, style: TextStyle(color: color)),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Bloco 2: planilha de ultima live
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("2. Planilha de Atividade (Ultima LIVE)",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                const Text(
                  "Atualiza a data/hora da ultima transmissao de cada streamer, usada no Progresso Streamers.",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  _lastActivityUpdate != null
                      ? "Ultima atualizacao: " + _lastActivityUpdate!.toLocal().toString().substring(0, 16)
                      : "Nunca atualizado",
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isProcessingActivity ? null : _pickAndProcessActivity,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_isProcessingActivity ? "Processando..." : "Selecionar planilha (.xlsx)"),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                ),
                const SizedBox(height: 16),
                if (_activityErrorMessage != null)
                  Text(_activityErrorMessage!, style: const TextStyle(color: Colors.redAccent)),
                if (_activitySummary != null)
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    _SummaryChip(label: "Linhas lidas", value: _activitySummary!.totalRowsRead, color: Colors.white),
                    _SummaryChip(label: "Aplicados", value: _activitySummary!.applied, color: Colors.greenAccent),
                    _SummaryChip(label: "Nao encontrados", value: _activitySummary!.notFound, color: Colors.orangeAccent),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(8)),
      child: Text(label + ": " + value.toString(), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}









