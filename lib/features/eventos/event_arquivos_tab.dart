import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:url_launcher/url_launcher.dart";
import "event_history_service.dart";
import "event_upload_helpers.dart";

IconData _fileIcon(String fileName) {
  final ext = fileName.toLowerCase().split(".").last;
  if (["png", "jpg", "jpeg", "gif", "webp"].contains(ext)) return Icons.image_outlined;
  if (ext == "pdf") return Icons.picture_as_pdf_outlined;
  if (["xls", "xlsx", "csv"].contains(ext)) return Icons.table_chart_outlined;
  if (["doc", "docx"].contains(ext)) return Icons.description_outlined;
  return Icons.insert_drive_file_outlined;
}

class EventArquivosTab extends StatefulWidget {
  final String eventId;
  const EventArquivosTab({super.key, required this.eventId});

  @override
  State<EventArquivosTab> createState() => _EventArquivosTabState();
}

class _EventArquivosTabState extends State<EventArquivosTab> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client.from("event_attachments").select("*, managers(login_email)").eq("event_id", widget.eventId).order("uploaded_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
    final file = result.files.first;
    setState(() => _uploading = true);
    try {
      final url = await uploadEventFile(bucket: "event_attachments", prefix: widget.eventId, file: file);
      final client = Supabase.instance.client;
      await client.from("event_attachments").insert({
        "event_id": widget.eventId,
        "file_name": file.name,
        "file_url": url,
        "uploaded_by": client.auth.currentUser!.id,
      });
      await logEventHistory(eventId: widget.eventId, action: "arquivo_anexado", detail: file.name);
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao enviar arquivo: " + e.toString())));
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> file) async {
    final client = Supabase.instance.client;
    try {
      await client.from("event_attachments").delete().eq("id", file["id"]);
      await logEventHistory(eventId: widget.eventId, action: "arquivo_removido", detail: file["file_name"] as String);
      _reload();
    } catch (e) {
      if (mounted) showEventosActionError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Arquivos", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _uploading ? null : _upload,
              icon: const Icon(Icons.upload_file, size: 16),
              label: Text(_uploading ? "Enviando..." : "Anexar arquivo"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 4),
          const Text("PDF, imagens, planilhas, regulamentos e outros documentos do evento.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return buildEventosLoadError(snapshot.error!);
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) return const Center(child: Text("Nenhum arquivo anexado ainda.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final file = list[index];
                    final uploaderData = file["managers"];
                    final date = DateTime.parse(file["uploaded_at"] as String).toLocal().toString().substring(0, 16);
                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(_fileIcon(file["file_name"] as String), color: const Color(0xFF7A0BD4)),
                        title: Text(file["file_name"] as String, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                          date + (uploaderData is Map ? "  -  " + (uploaderData["login_email"] as String? ?? "-") : ""),
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => _delete(file)),
                        onTap: () => launchUrl(Uri.parse(file["file_url"] as String), mode: LaunchMode.externalApplication),
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
