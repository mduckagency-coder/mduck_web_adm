import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../ilha_top_service.dart";

/// Ranking dos elegiveis a Ilha Top (80k+ diamantes no mes). O slot (Top
/// 1..Top 10 ou Area 11+) e calculado automaticamente pela posicao no
/// ranking - nao e atribuicao manual. Tem um "modo teste" que ignora o
/// minimo de 80k, so pra visualizacao (ninguem e desbloqueado de verdade
/// nesse modo) -- util quando ainda ninguem bateu a meta no mes.
class IlhaRankingTab extends StatefulWidget {
  const IlhaRankingTab({super.key});

  @override
  State<IlhaRankingTab> createState() => _IlhaRankingTabState();
}

class _IlhaRankingTabState extends State<IlhaRankingTab> {
  final _service = IlhaTopService();
  late Future<List<Map<String, dynamic>>> _future = Future.value(const []);
  late Future<Map<String, dynamic>?> _lastMonthTop1Future;
  bool _testMode = false;
  bool _loadingTestMode = true;
  Map<String, dynamic> _testConfig = const {};

  @override
  void initState() {
    super.initState();
    _lastMonthTop1Future = _service.fetchLastMonthTop1();
    _initTestMode();
  }

  Future<void> _initTestMode() async {
    final results = await Future.wait([_service.fetchTestMode(), _service.fetchTestConfig()]);
    if (mounted) {
      setState(() {
        _testMode = results[0] as bool;
        _testConfig = results[1] as Map<String, dynamic>;
        _loadingTestMode = false;
        _future = _fetchRanking();
      });
    }
  }

  Future<void> _setTestMode(bool value) async {
    setState(() {
      _testMode = value;
      _future = _fetchRanking();
    });
    try {
      await _service.saveTestMode(value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar modo teste: " + e.toString()), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRanking() => _service.fetchRanking(
        testMode: _testMode,
        threshold: _testMode ? (_testConfig["diamond_threshold"] as int? ?? 0) : 80000,
        pinnedIds: _testMode
            ? [_testConfig["pinned_top1"] as String?, _testConfig["pinned_top2"] as String?, _testConfig["pinned_top3"] as String?]
            : const [],
      );

  void _reload() => setState(() => _future = _fetchRanking());

  Future<void> _unlock(String streamerId) async {
    final client = Supabase.instance.client;
    await client.from("streamer_islands").upsert({"streamer_id": streamerId, "unlocked_at": DateTime.now().toIso8601String()});
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _testMode ? Colors.amber.withOpacity(0.1) : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: _testMode ? Border.all(color: Colors.amber) : null,
                ),
                child: Row(children: [
                  Icon(Icons.science_outlined, color: _testMode ? Colors.amber : Colors.white38, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Modo teste (vale pra agência toda, inclusive no app) — ignora o mínimo de 80k e mostra todo mundo no ranking (não desbloqueia ninguém de verdade aqui). Lembre de desligar depois de testar.",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  if (_loadingTestMode)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Switch(
                      value: _testMode,
                      activeThumbColor: Colors.amber,
                      onChanged: _setTestMode,
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, dynamic>?>(
                future: _lastMonthTop1Future,
                builder: (context, top1Snapshot) {
                  final top1 = top1Snapshot.data;
                  if (top1Snapshot.connectionState != ConnectionState.done || top1 == null) return const SizedBox.shrink();
                  return Card(
                    color: Colors.amber.withOpacity(0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.amber)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.amber.withOpacity(0.2),
                        backgroundImage: top1["avatar_url"] != null ? NetworkImage(top1["avatar_url"] as String) : null,
                        child: top1["avatar_url"] == null ? const Icon(Icons.emoji_events, color: Colors.amber) : null,
                      ),
                      title: Text("Top 1 do mês passado (" + (top1["period_key"] as String) + "): " + (top1["display_name"] as String),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        (top1["diamonds"] as int).toString() + " diamantes  -  posiciona no slot \"Top 1 do mes passado\" no editor de posições",
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  );
                },
              ),
              Row(
                children: [
                  Text(
                    list.length.toString() + (_testMode ? " no ranking (modo teste)" : " elegiveis (80k+ diamantes no mes)"),
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _reload),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text(
                          _testMode ? "Nenhum streamer ativo cadastrado ainda." : "Nenhum streamer atingiu 80k diamantes ainda.",
                          style: const TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final s = list[index];
                          final rank = index + 1;
                          final slotKey = slotKeyForRank(rank);
                          final slotLabel = slotKey == "top_11_plus" ? "Area 11+" : "Top " + rank.toString();
                          final unlocked = s["unlocked_at"] != null;
                          final avatarLabel = s["avatar_label"] as String?;
                          return Card(
                            color: Colors.white.withOpacity(0.05),
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: rank == 1 ? const Color(0xFF7A0BD4) : Colors.white24,
                                child: Text(rank.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              title: Text(s["display_name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                (s["tiktok_creator_id"] ?? "-") +
                                    "  -  " +
                                    s["diamonds"].toString() +
                                    " diamantes  -  " +
                                    s["decorations"].toString() +
                                    " decoracoes  -  " +
                                    slotLabel +
                                    (avatarLabel != null ? "  -  avatar: " + avatarLabel : "  -  sem avatar escolhido"),
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              trailing: _testMode
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(border: Border.all(color: Colors.amber), borderRadius: BorderRadius.circular(8)),
                                      child: const Text("Pré-visualização", style: TextStyle(color: Colors.amber, fontSize: 11)),
                                    )
                                  : unlocked
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(border: Border.all(color: Colors.greenAccent), borderRadius: BorderRadius.circular(8)),
                                          child: Text("Desbloqueada em " + DateTime.parse(s["unlocked_at"]).toLocal().toString().substring(0, 10),
                                              style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
                                        )
                                      : ElevatedButton(
                                          onPressed: () => _unlock(s["id"] as String),
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                                          child: const Text("Desbloquear ilha"),
                                        ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
