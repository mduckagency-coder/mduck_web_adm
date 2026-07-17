import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

const _categories = [
  ("mes", "Mes"),
  ("semanal", "Semanal"),
  ("tiktok_streamers", "TikTok Streamers"),
  ("tiktok_agencia", "TikTok Agencia"),
];

const _rewardTypes = [
  ("produto", "Produto"),
  ("placa", "Placa"),
  ("presente", "Presente"),
  ("outros", "Outros"),
];

(String, Color) _computeStatus(Map<String, dynamic> c) {
  if (c["is_cancelled"] == true) return ("Cancelado", Colors.redAccent);
  final now = DateTime.now();
  final start = c["start_date"] != null ? DateTime.parse(c["start_date"]) : null;
  final end = c["end_date"] != null ? DateTime.parse(c["end_date"]) : null;
  if (start == null) return ("A acontecer", Colors.blueAccent);
  if (now.isBefore(start)) return ("A acontecer", Colors.blueAccent);
  if (end != null && now.isAfter(end)) return ("Finalizado", Colors.greenAccent);
  return ("Em andamento", Colors.amber);
}

String _monthLabel(Map<String, dynamic> c) {
  if (c["start_date"] == null) return "Sem data";
  final start = DateTime.parse(c["start_date"]);
  final now = DateTime.now();
  final diff = (start.year - now.year) * 12 + (start.month - now.month);
  if (diff == 0) return "Este mes";
  if (diff == -1) return "Mes passado";
  if (diff == 1) return "Proximo mes";
  return start.month.toString().padLeft(2, "0") + "/" + start.year.toString();
}

double _totalRewards(Map<String, dynamic> c) {
  final rewards = c["campaign_rewards"];
  if (rewards is! List) return 0;
  double total = 0;
  for (final r in rewards) {
    total += (r["value"] as num?)?.toDouble() ?? 0;
  }
  return total;
}

class AgencyCampaignsPage extends StatefulWidget {
  const AgencyCampaignsPage({super.key});

  @override
  State<AgencyCampaignsPage> createState() => _AgencyCampaignsPageState();
}

class _AgencyCampaignsPageState extends State<AgencyCampaignsPage> {
  String _category = "mes";
  String _monthFilter = "todos";
  bool _showHistory = false;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("agency_campaigns")
        .select("*, campaign_rewards(value)")
        .eq("category", _category)
        .order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _loadAll() async {
    final client = Supabase.instance.client;
    final rows = await client.from("agency_campaigns").select("*, campaign_rewards(value)").order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _reload() => setState(() => _future = _showHistory ? _loadAll() : _load());

  void _openCreate() {
    showDialog(context: context, builder: (context) => _CampaignFormDialog(category: _category)).then((saved) {
      if (saved == true) _reload();
    });
  }

  List<Map<String, dynamic>> _filterByMonth(List<Map<String, dynamic>> list) {
    if (_monthFilter == "todos") return list;
    return list.where((c) {
      final label = _monthLabel(c);
      if (_monthFilter == "este") return label == "Este mes";
      if (_monthFilter == "passado") return label == "Mes passado";
      if (_monthFilter == "proximo") return label == "Proximo mes";
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("Missao Agencia", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(width: 12),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _reload),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() {
                  _showHistory = !_showHistory;
                  _future = _showHistory ? _loadAll() : _load();
                }),
                icon: Icon(_showHistory ? Icons.list_alt : Icons.history, color: Colors.white70),
                label: Text(_showHistory ? "Ver por categoria" : "Ver historico completo", style: const TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                onPressed: _openCreate,
                backgroundColor: const Color(0xFF7A0BD4),
                foregroundColor: Colors.white,
                tooltip: "Nova campanha",
                child: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_showHistory)
            Wrap(
              spacing: 8,
              children: _categories.map((c) {
                final selected = c.$1 == _category;
                return ChoiceChip(
                  label: Text(c.$2),
                  selected: selected,
                  selectedColor: const Color(0xFF7A0BD4),
                  labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
                  onSelected: (_) => setState(() {
                    _category = c.$1;
                    _future = _load();
                  }),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          if (!_showHistory)
            Wrap(
              spacing: 8,
              children: [
                ("todos", "Todos os meses"),
                ("passado", "Mes passado"),
                ("este", "Este mes"),
                ("proximo", "Proximo mes"),
              ].map((m) {
                final selected = _monthFilter == m.$1;
                return ChoiceChip(
                  label: Text(m.$2, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.white70)),
                  selected: selected,
                  selectedColor: Colors.white24,
                  onSelected: (_) => setState(() => _monthFilter = m.$1),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final campaigns = _showHistory ? snapshot.data! : _filterByMonth(snapshot.data!);
                if (campaigns.isEmpty) {
                  return const Center(child: Text("Nenhuma campanha encontrada.", style: TextStyle(color: Colors.white54)));
                }
                return ListView.builder(
                  itemCount: campaigns.length,
                  itemBuilder: (context, index) {
                    final c = campaigns[index];
                    final status = _computeStatus(c);
                    final monthLabel = _monthLabel(c);
                    final categoryLabel = _categories.firstWhere((cat) => cat.$1 == c["category"], orElse: () => _categories[0]).$2;
                    final total = _totalRewards(c);
                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(c["title"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          (_showHistory ? categoryLabel + " - " : "") +
                              monthLabel +
                              (c["start_date"] != null ? " (" + c["start_date"].toString() + (c["end_date"] != null ? " a " + c["end_date"].toString() : "") + ")" : "") +
                              (total > 0 ? " - Premiacoes: R\$ " + total.toStringAsFixed(2) : ""),
                          style: const TextStyle(color: Colors.white54),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(border: Border.all(color: status.$2), borderRadius: BorderRadius.circular(8)),
                          child: Text(status.$1, style: TextStyle(color: status.$2, fontSize: 12)),
                        ),
                        onTap: _showHistory
                            ? null
                            : () {
                                showDialog(context: context, builder: (context) => _CampaignFormDialog(category: _category, existing: c)).then((saved) {
                                  if (saved == true) _reload();
                                });
                              },
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

class _CampaignFormDialog extends StatefulWidget {
  final String category;
  final Map<String, dynamic>? existing;

  const _CampaignFormDialog({required this.category, this.existing});

  @override
  State<_CampaignFormDialog> createState() => _CampaignFormDialogState();
}

class _CampaignFormDialogState extends State<_CampaignFormDialog> {
  final _titleController = TextEditingController();
  final _participantsController = TextEditingController();
  final _backstageController = TextEditingController();
  final _linksController = TextEditingController();
  final _videoController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isCancelled = false;
  String? _attachmentUrl;
  String? _attachmentName;
  bool _saving = false;
  bool _uploading = false;

  List<Map<String, dynamic>> _rewards = [];
  List<Map<String, dynamic>> _streamers = [];

  @override
  void initState() {
    super.initState();
    _loadStreamers();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e["title"] ?? "";
      _participantsController.text = e["participants"] ?? "";
      _backstageController.text = e["backstage_campaign"] ?? "";
      _linksController.text = e["links"] ?? "";
      _videoController.text = e["promo_video_url"] ?? "";
      _descriptionController.text = e["description"] ?? "";
      _isCancelled = e["is_cancelled"] == true;
      _attachmentUrl = e["attachment_url"];
      _attachmentName = e["attachment_name"];
      if (e["start_date"] != null) _startDate = DateTime.tryParse(e["start_date"]);
      if (e["end_date"] != null) _endDate = DateTime.tryParse(e["end_date"]);
      _loadExistingRewards(e["id"]);
    }
  }

  Future<void> _loadStreamers() async {
    final client = Supabase.instance.client;
    final rows = await client.from("profiles").select("id, display_name").eq("is_active", true).order("display_name");
    setState(() => _streamers = (rows as List).cast<Map<String, dynamic>>());
  }

  Future<void> _loadExistingRewards(String campaignId) async {
    final client = Supabase.instance.client;
    final rows = await client.from("campaign_rewards").select().eq("campaign_id", campaignId);
    setState(() => _rewards = (rows as List).cast<Map<String, dynamic>>().map((r) => Map<String, dynamic>.from(r)).toList());
  }

  void _addReward() {
    setState(() {
      _rewards.add({"reward_type": "produto", "description": "", "value": 0.0, "streamer_id": null});
    });
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.single.bytes == null) return;
    setState(() => _uploading = true);
    try {
      final client = Supabase.instance.client;
      final fileName = DateTime.now().millisecondsSinceEpoch.toString() + "_" + result.files.single.name;
      await client.storage.from("campaign_attachments").uploadBinary(fileName, result.files.single.bytes!);
      final url = client.storage.from("campaign_attachments").getPublicUrl(fileName);
      setState(() {
        _attachmentUrl = url;
        _attachmentName = result.files.single.name;
      });
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final managerId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", managerId).single();

    final data = {
      "agency_id": manager["agency_id"],
      "category": widget.category,
      "title": _titleController.text.trim(),
      "start_date": _startDate?.toIso8601String().substring(0, 10),
      "end_date": _endDate?.toIso8601String().substring(0, 10),
      "participants": _participantsController.text.trim(),
      "backstage_campaign": _backstageController.text.trim(),
      "attachment_url": _attachmentUrl,
      "attachment_name": _attachmentName,
      "links": _linksController.text.trim(),
      "promo_video_url": _videoController.text.trim(),
      "description": _descriptionController.text.trim(),
      "is_cancelled": _isCancelled,
      "created_by": managerId,
    };

    String campaignId;
    if (widget.existing != null) {
      campaignId = widget.existing!["id"];
      await client.from("agency_campaigns").update(data).eq("id", campaignId);
      await client.from("campaign_rewards").delete().eq("campaign_id", campaignId);
    } else {
      final inserted = await client.from("agency_campaigns").insert(data).select().single();
      campaignId = inserted["id"];
    }

    for (final r in _rewards) {
      if ((r["description"] as String?)?.trim().isEmpty ?? true) continue;
      await client.from("campaign_rewards").insert({
        "campaign_id": campaignId,
        "reward_type": r["reward_type"],
        "description": r["description"],
        "value": r["value"],
        "streamer_id": r["streamer_id"],
      });
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 750),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.existing != null ? "Editar campanha" : "Nova campanha",
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: _titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Titulo", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => _pickDate(true), child: Text(_startDate != null ? "Inicio: " + _startDate!.toIso8601String().substring(0, 10) : "Escolher inicio"))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(onPressed: () => _pickDate(false), child: Text(_endDate != null ? "Fim: " + _endDate!.toIso8601String().substring(0, 10) : "Escolher fim"))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: _participantsController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Participantes", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _backstageController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Campanha Backstage", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _linksController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Links", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _videoController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Video Promocional (URL)", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _descriptionController, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Descricao", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(onPressed: _uploading ? null : _pickAttachment, icon: const Icon(Icons.attach_file, size: 16), label: Text(_uploading ? "Enviando..." : "Anexar documento")),
                    const SizedBox(width: 8),
                    if (_attachmentUrl != null) Expanded(child: Text(_attachmentName ?? "Arquivo anexado", style: const TextStyle(color: Color(0xFF7A0BD4)), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text("Premiacoes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(onPressed: _addReward, icon: const Icon(Icons.add, size: 16), label: const Text("Adicionar item")),
                  ],
                ),
                for (var i = 0; i < _rewards.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            DropdownButton<String>(
                              value: _rewards[i]["reward_type"],
                              dropdownColor: const Color(0xFF1A1A1A),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: _rewardTypes.map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2))).toList(),
                              onChanged: (v) => setState(() => _rewards[i]["reward_type"] = v),
                            ),
                            const SizedBox(width: 8),
                            IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), onPressed: () => setState(() => _rewards.removeAt(i))),
                          ],
                        ),
                        TextFormField(
                          initialValue: _rewards[i]["description"] as String?,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(labelText: "Descricao do item", labelStyle: TextStyle(color: Colors.white54, fontSize: 12)),
                          onChanged: (v) => _rewards[i]["description"] = v,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: (_rewards[i]["value"] as num?)?.toString() ?? "0",
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(labelText: "Valor (R\$)", labelStyle: TextStyle(color: Colors.white54, fontSize: 12)),
                                onChanged: (v) => _rewards[i]["value"] = double.tryParse(v) ?? 0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                value: _rewards[i]["streamer_id"],
                                dropdownColor: const Color(0xFF1A1A1A),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(labelText: "Streamer (opcional)", labelStyle: TextStyle(color: Colors.white54, fontSize: 12)),
                                items: [
                                  const DropdownMenuItem<String?>(value: null, child: Text("Geral (nao vinculado)")),
                                  ..._streamers.map((s) => DropdownMenuItem<String?>(value: s["id"] as String, child: Text(s["display_name"] as String))),
                                ],
                                onChanged: (v) => setState(() => _rewards[i]["streamer_id"] = v),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _isCancelled,
                  onChanged: (v) => setState(() => _isCancelled = v ?? false),
                  title: const Text("Cancelar esta campanha", style: TextStyle(color: Colors.white)),
                  activeColor: Colors.redAccent,
                  contentPadding: EdgeInsets.zero,
                ),
                const Text(
                  "O status (a acontecer / em andamento / finalizado) e calculado automaticamente pelas datas.",
                  style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                      child: Text(_saving ? "Salvando..." : "Salvar"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
