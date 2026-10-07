import "package:flutter/material.dart";

import "app_config_service.dart";

const _card = Color(0xFF1B1626);
const _purple = Color(0xFF7A0BD4);

const _statusColors = {
  "novo": Color(0xFF5BA8FF),
  "em_analise": Color(0xFFFFC94D),
  "resolvido": Color(0xFF3DDC97),
  "ignorado": Color(0xFF8E9AB8),
  "duplicado": Color(0xFFC77DFF),
};

/// Reportes enviados pelos streamers no APP (Configurações > Reportar um
/// problema). Separado de "Reportes de Bugs" (bugs do painel).
class AppReportsPage extends StatefulWidget {
  const AppReportsPage({super.key});

  @override
  State<AppReportsPage> createState() => _AppReportsPageState();
}

class _AppReportsPageState extends State<AppReportsPage> {
  final _service = AppConfigService();
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String? _error;

  String? _status;
  String? _type;
  String? _version;
  String? _streamer;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _service.fetchReports();
      if (mounted) setState(() => _all = rows);
    } catch (e) {
      if (mounted) setState(() => _error = "Não foi possível carregar os reportes. Rodou a migração 0099? ($e)");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _who(Map r) {
    final name = (r["streamer_name"] ?? "").toString();
    final user = (r["streamer_username"] ?? "").toString();
    final who = [if (name.isNotEmpty) name, if (user.isNotEmpty) "@$user"].join(" · ");
    return who.isEmpty ? "—" : who;
  }

  static String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? "")?.toLocal();
    if (d == null) return "—";
    String two(int n) => n.toString().padLeft(2, "0");
    return "${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}";
  }

  List<Map<String, dynamic>> get _filtered => _all.where((r) {
        if (_status != null && r["status"] != _status) return false;
        if (_type != null && r["type"] != _type) return false;
        if (_version != null && r["app_version"] != _version) return false;
        if (_streamer != null && _who(r) != _streamer) return false;
        if (_range != null) {
          final d = DateTime.tryParse(r["created_at"]?.toString() ?? "")?.toLocal();
          if (d == null) return false;
          if (d.isBefore(_range!.start) || d.isAfter(_range!.end.add(const Duration(days: 1)))) return false;
        }
        return true;
      }).toList();

  Widget _dropdown(String label, String? value, Map<String, String> options, ValueChanged<String?> onChanged) => SizedBox(
        width: 210,
        child: DropdownButtonFormField<String?>(
          initialValue: value,
          isExpanded: true,
          dropdownColor: _card,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54), border: const OutlineInputBorder(), isDense: true),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text("Todos")),
            for (final e in options.entries) DropdownMenuItem<String?>(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: onChanged,
        ),
      );

  Widget _statusChip(String status) {
    final c = _statusColors[status] ?? Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withValues(alpha: 0.6))),
      child: Text(appReportStatuses[status] ?? status, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: const TextStyle(color: Colors.white70)),
          TextButton(onPressed: _load, child: const Text("Tentar de novo")),
        ]),
      );
    }
    final versions = {for (final r in _all) if ((r["app_version"] ?? "").toString().isNotEmpty) r["app_version"].toString(): r["app_version"].toString()};
    final streamers = {for (final r in _all) _who(r): _who(r)};
    final rows = _filtered;
    final counts = <String, int>{for (final s in appReportStatuses.keys) s: _all.where((r) => r["status"] == s).length};

    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(children: [
        const Expanded(
          child: Text("Reportes do Aplicativo", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        IconButton(onPressed: _load, tooltip: "Atualizar", icon: const Icon(Icons.refresh, color: Colors.white70)),
      ]),
      const Text("Enviados pelos streamers em Configurações > Reportar um problema. (Bugs do painel ficam em Reportes de Bugs.)",
          style: TextStyle(color: Colors.white54, fontSize: 13)),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in appReportStatuses.entries)
          ActionChip(
            backgroundColor: _status == e.key ? _purple : _card,
            label: Text("${e.value}: ${counts[e.key]}", style: const TextStyle(color: Colors.white, fontSize: 12)),
            onPressed: () => setState(() => _status = _status == e.key ? null : e.key),
          ),
      ]),
      const SizedBox(height: 14),
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        _dropdown("Status", _status, appReportStatuses, (v) => setState(() => _status = v)),
        _dropdown("Tipo", _type, appReportTypes, (v) => setState(() => _type = v)),
        _dropdown("Versão", _version, versions, (v) => setState(() => _version = v)),
        _dropdown("Streamer", _streamer, streamers, (v) => setState(() => _streamer = v)),
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range, size: 16),
          label: Text(_range == null
              ? "Período"
              : "${_range!.start.day}/${_range!.start.month} – ${_range!.end.day}/${_range!.end.month}"),
          onPressed: () async {
            final r = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now().add(const Duration(days: 1)));
            setState(() => _range = r);
          },
        ),
        if (_status != null || _type != null || _version != null || _streamer != null || _range != null)
          TextButton(
            onPressed: () => setState(() {
              _status = _type = _version = _streamer = null;
              _range = null;
            }),
            child: const Text("Limpar filtros"),
          ),
      ]),
      const SizedBox(height: 16),
      if (rows.isEmpty)
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: Text("Nenhum reporte por aqui.", style: TextStyle(color: Colors.white38))),
        )
      else
        for (final r in rows)
          Card(
            color: _card,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              onTap: () async {
                final changed = await showDialog<bool>(context: context, builder: (_) => _ReportDetail(report: r, service: _service));
                if (changed == true) _load();
              },
              leading: Icon(r["screenshot_path"] != null ? Icons.image_outlined : Icons.description_outlined, color: Colors.white54),
              title: Text("${_who(r)} — ${appReportTypes[r["type"]] ?? r["type"]}${r["area"] != null ? " · ${r["area"]}" : ""}${r["reply"] != null ? "  💬" : ""}",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text(
                "${_date(r["created_at"] as String?)} · v${r["app_version"] ?? "?"}\n${r["description"]}",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 12.5),
              ),
              isThreeLine: true,
              trailing: _statusChip((r["status"] ?? "novo").toString()),
            ),
          ),
    ]);
  }
}

class _ReportDetail extends StatefulWidget {
  final Map<String, dynamic> report;
  final AppConfigService service;
  const _ReportDetail({required this.report, required this.service});

  @override
  State<_ReportDetail> createState() => _ReportDetailState();
}

class _ReportDetailState extends State<_ReportDetail> {
  late String _status = (widget.report["status"] ?? "novo").toString();
  late final _note = TextEditingController(text: (widget.report["admin_note"] ?? "").toString());
  late final _reply = TextEditingController(text: (widget.report["reply"] ?? "").toString());
  String? _shotUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final path = widget.report["screenshot_path"] as String?;
    if (path != null) {
      widget.service.screenshotUrl(path).then((u) {
        if (mounted) setState(() => _shotUrl = u);
      });
    }
  }

  @override
  void dispose() {
    _note.dispose();
    _reply.dispose();
    super.dispose();
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(k, style: const TextStyle(color: Colors.white54))),
          Expanded(child: SelectableText(v, style: const TextStyle(color: Colors.white))),
        ]),
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.service.updateReport(widget.report["id"] as String, status: _status, adminNote: _note.text.trim(), reply: _reply.text, replyChanged: _reply.text.trim() != (widget.report["reply"] ?? "").toString().trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return AlertDialog(
      backgroundColor: _card,
      title: Text(appReportTypes[r["type"]] ?? r["type"].toString(), style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _row("Streamer", (r["streamer_name"] ?? "—").toString()),
            _row("@", (r["streamer_username"] ?? "—").toString()),
            _row("ID da conta", (r["streamer_id"] ?? r["auth_user_id"] ?? "—").toString()),
            _row("Data/hora", _AppReportsPageState._date(r["created_at"] as String?)),
            _row("Versão do app", (r["app_version"] ?? "—").toString()),
            _row("Plataforma", (r["platform"] ?? "—").toString()),
            if (r["area"] != null) _row("Parte do app", r["area"].toString()),
            if (r["title"] != null) _row("Ideia", r["title"].toString()),
            const SizedBox(height: 8),
            const Text("Descrição", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 4),
            SelectableText((r["description"] ?? "").toString(), style: const TextStyle(color: Colors.white, height: 1.4)),
            if (r["screenshot_path"] != null) ...[
              const SizedBox(height: 14),
              const Text("Print", style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 6),
              _shotUrl == null
                  ? const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(_shotUrl!, fit: BoxFit.contain, height: 420,
                          errorBuilder: (_, _, _) => const Text("Não foi possível abrir a imagem.", style: TextStyle(color: Colors.white54))),
                    ),
            ],
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _status,
              dropdownColor: _card,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Status", labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder(), isDense: true),
              items: [for (final e in appReportStatuses.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reply,
              minLines: 2,
              maxLines: 6,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Resposta para o streamer (aparece no app, em Meus envios)",
                labelStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 6,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Anotação interna (não aparece no app)", labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder()),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Fechar")),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
          child: Text(_saving ? "Salvando..." : "Salvar"),
        ),
      ],
    );
  }
}
