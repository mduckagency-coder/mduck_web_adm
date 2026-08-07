import "package:flutter/material.dart";
import "models/calendar_request.dart";
import "services/calendar_service.dart";
import "widgets/request_prompt_dialog.dart";
import "widgets/request_review_dialog.dart";

class SolicitacoesPage extends StatefulWidget {
  const SolicitacoesPage({super.key});

  @override
  State<SolicitacoesPage> createState() => _SolicitacoesPageState();
}

class _SolicitacoesPageState extends State<SolicitacoesPage> {
  final _service = CalendarService();

  static const _tabs = [
    (["aguardando_analise"], "Aguardando análise"),
    (["buscando_oponente", "oponente_confirmado"], "Em andamento"),
    (["aprovada", "concluida"], "Aprovadas"),
    (["rejeitada"], "Recusadas"),
  ];

  int _selectedTab = 0;
  List<CalendarRequest> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _service.fetchRequests(statuses: _tabs[_selectedTab].$1);
    if (mounted) {
      setState(() {
        _requests = rows;
        _loading = false;
      });
    }
  }

  Future<void> _openRequest(CalendarRequest request) async {
    final changed = await showDialog<bool>(context: context, builder: (_) => RequestReviewDialog(request: request));
    if (changed == true) _load();
  }

  Future<void> _openPrompt() async {
    final sent = await showDialog<bool>(context: context, builder: (_) => const RequestPromptDialog());
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido enviado ao streamer.")));
    }
  }

  Widget _typeIcon(CalendarRequestType type) {
    return Icon(type == CalendarRequestType.batalhaOficial ? Icons.sports_kabaddi : Icons.event, color: const Color(0xFF7A0BD4), size: 20);
  }

  Widget _requestCard(CalendarRequest request) {
    final dateLabel = request.proposedDate != null
        ? request.proposedDate!.day.toString().padLeft(2, "0") + "/" + request.proposedDate!.month.toString().padLeft(2, "0") + "/" + request.proposedDate!.year.toString()
        : "Data não informada";
    final timeLabel = request.proposedStartTime != null ? " às " + request.proposedStartTime!.format(context) : "";

    final subtitleParts = <String>[calendarRequestTypeLabel(request.requestType), dateLabel + timeLabel];
    if (request.requestType == CalendarRequestType.batalhaOficial) {
      if (request.battleRounds != null) subtitleParts.add(request.battleRounds.toString() + " round" + (request.battleRounds == 3 ? "s" : ""));
      if (request.battleDiamondsEstimate != null) subtitleParts.add("~" + request.battleDiamondsEstimate.toString() + " diamantes");
    }
    if (request.needsBanner) subtitleParts.add("Pediu banner");

    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _openRequest(request),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.white24,
          backgroundImage: request.streamerAvatarUrl != null && request.streamerAvatarUrl!.isNotEmpty ? NetworkImage(request.streamerAvatarUrl!) : null,
          child: request.streamerAvatarUrl == null || request.streamerAvatarUrl!.isEmpty ? const Icon(Icons.person, color: Colors.white70) : null,
        ),
        title: Row(children: [
          _typeIcon(request.requestType),
          const SizedBox(width: 8),
          Expanded(child: Text(request.streamerName ?? "Streamer", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitleParts.join(" • "), style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: calendarRequestStatusColor(request.status).withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
          child: Text(calendarRequestStatusLabel(request.status), style: TextStyle(color: calendarRequestStatusColor(request.status), fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Solicitações", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _openPrompt,
              icon: const Icon(Icons.send),
              label: const Text("Pedir solicitação ao streamer"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            "Batalhas oficiais e eventos solicitados pelos streamers, aguardando aprovação da agência.",
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: List.generate(_tabs.length, (index) {
              final selected = _selectedTab == index;
              return ChoiceChip(
                label: Text(_tabs[index].$2),
                selected: selected,
                onSelected: (_) {
                  setState(() => _selectedTab = index);
                  _load();
                },
                selectedColor: const Color(0xFF7A0BD4),
                backgroundColor: const Color(0xFF1A1A1A),
                labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
              );
            }),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                    ? const Center(child: Text("Nenhuma solicitação por aqui.", style: TextStyle(color: Colors.white54)))
                    : ListView(children: _requests.map(_requestCard).toList()),
          ),
        ],
      ),
    );
  }
}
