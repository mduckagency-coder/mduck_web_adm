import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

const _months = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];

String _monthLabel(String key) {
  final p = key.split("-");
  return "${_months[int.parse(p[1]) - 1]}/${p[0]}";
}

String _key(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, "0")}";
String _iso(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";
const _metrics = {
  "todos": "Todos os rankings",
  "diamonds": "Diamantes (inclui Top Games e Top Músicos)",
  "hours": "Horas",
  "battles": "Batalhas",
};

String _br(DateTime d) => "${d.day.toString().padLeft(2, "0")}/${d.month.toString().padLeft(2, "0")}";

/// Painel > Ranking > "Período do ranking".
/// Padrão: mês inteiro. Aqui define-se, só para um mês, o dia em que o
/// ranking começa e termina (ex.: de 02/10 a 31/10). Vale para o Ranking do
/// app, "Meu ranking" e a posição na Home. Métricas da Home (dias/horas/
/// diamantes do mês) continuam o mês inteiro.
Future<void> showRankingPeriodDialog(BuildContext context) =>
    showDialog(context: context, builder: (_) => const _RankingPeriodDialog());

class _RankingPeriodDialog extends StatefulWidget {
  const _RankingPeriodDialog();

  @override
  State<_RankingPeriodDialog> createState() => _RankingPeriodDialogState();
}

class _RankingPeriodDialogState extends State<_RankingPeriodDialog> {
  final _db = Supabase.instance.client;
  String? _agency;
  List<Map<String, dynamic>> _windows = [];
  Map<String, bool> _baseOk = {};
  bool _loading = true;

  late String _period = _key(DateTime.now());
  String _metric = "todos";
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _agency ??= (await _db.from("managers").select("agency_id").eq("id", _db.auth.currentUser!.id).single())["agency_id"] as String;
    final rows = List<Map<String, dynamic>>.from(
        await _db.from("ranking_windows").select().eq("agency_id", _agency!).order("period_key", ascending: false) as List);
    final ok = <String, bool>{};
    for (final w in rows) {
      final start = DateTime.parse(w["start_date"] as String);
      if (start.day == 1) {
        ok[w["id"] as String] = true;
        continue;
      }
      final base = start.subtract(const Duration(days: 1));
      final r = await _db
          .from("metric_snapshots")
          .select("streamer_id")
          .eq("agency_id", _agency!)
          .eq("period_key", w["period_key"] as String)
          .eq("data_until", _iso(base))
          .limit(1);
      ok[w["id"] as String] = (r as List).isNotEmpty;
    }
    if (!mounted) return;
    setState(() {
      _windows = rows;
      _baseOk = ok;
      _loading = false;
    });
    _fillFromPeriod();
  }

  DateTime get _monthStart => DateTime.parse("$_period-01");
  DateTime get _monthEnd => DateTime(_monthStart.year, _monthStart.month + 1, 0);

  void _fillFromPeriod() {
    final w = _windows.where((x) => x["period_key"] == _period && (x["metric"] ?? "todos") == _metric).firstOrNull;
    setState(() {
      _start = w == null ? _monthStart : DateTime.parse(w["start_date"] as String);
      _end = w == null ? _monthEnd : DateTime.parse(w["end_date"] as String);
    });
  }

  Future<void> _pick(bool start) async {
    final d = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? _monthStart,
      firstDate: _monthStart,
      lastDate: _monthEnd,
    );
    if (d != null) setState(() => start ? _start = d : _end = d);
  }

  Future<void> _save() async {
    if (_start == null || _end == null || _end!.isBefore(_start!)) return;
    setState(() => _saving = true);
    try {
      final isDefault = _start!.day == 1 && _end!.day == _monthEnd.day;
      if (isDefault) {
        // voltou ao mes inteiro: remove a excecao
        await _db.from("ranking_windows").delete().eq("agency_id", _agency!).eq("period_key", _period).eq("metric", _metric);
      } else {
        await _db.from("ranking_windows").upsert({
          "agency_id": _agency,
          "period_key": _period,
          "metric": _metric,
          "start_date": _iso(_start!),
          "end_date": _iso(_end!),
          "updated_by": _db.auth.currentUser?.id,
          "updated_at": DateTime.now().toUtc().toIso8601String(),
        }, onConflict: "agency_id,period_key,metric");
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isDefault ? "${_monthLabel(_period)} · ${_metrics[_metric]}: volta a contar o mês inteiro." : "Período salvo: ${_monthLabel(_period)} · ${_metrics[_metric]}."),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> w) async {
    await _db.from("ranking_windows").delete().eq("id", w["id"]);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final options = [for (var i = -3; i <= 3; i++) _key(DateTime(now.year, now.month + i, 1))];
    final custom = _start != null && _end != null && !(_start!.day == 1 && _end!.day == _monthEnd.day);
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1626),
      title: const Text("Período do ranking", style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 560,
        child: _loading
            ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                    "Por padrão o ranking conta o mês inteiro. Aqui você muda só um mês específico: por exemplo, contar de 02 até o último dia. "
                    "Vale para o Ranking do app, \"Meu ranking\" e a posição na Home. Os números do mês na Home continuam o mês inteiro.",
                    style: TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _period,
                    dropdownColor: const Color(0xFF1B1626),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Mês", border: OutlineInputBorder(), isDense: true),
                    items: [for (final o in options) DropdownMenuItem(value: o, child: Text(_monthLabel(o)))],
                    onChanged: (v) {
                      if (v == null) return;
                      _period = v;
                      _fillFromPeriod();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _metric,
                    dropdownColor: const Color(0xFF1B1626),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Aplicar a", border: OutlineInputBorder(), isDense: true),
                    items: [for (final e in _metrics.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: (v) {
                      if (v == null) return;
                      _metric = v;
                      _fillFromPeriod();
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      "O período de um ranking específico (ex.: só Horas) vale mais que o de \"Todos os rankings\".",
                      style: TextStyle(color: Colors.white38, fontSize: 11.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pick(true),
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: Text("Começa: ${_start == null ? "—" : _br(_start!)}"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pick(false),
                        icon: const Icon(Icons.stop, size: 16),
                        label: Text("Termina: ${_end == null ? "—" : _br(_end!)}"),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    custom ? "Período personalizado: ${_monthLabel(_period)} · ${_metrics[_metric]}." : "${_monthLabel(_period)} · ${_metrics[_metric]}: mês inteiro (padrão).",
                    style: TextStyle(color: custom ? const Color(0xFFFFC94D) : Colors.white54, fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  if (custom && _start!.day > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        "Para começar no dia ${_br(_start!)}, o sistema desconta automaticamente o que cada um fez até "
                        "${_br(_start!.subtract(const Duration(days: 1)))}, usando a importação normal que tem os dados até esse dia (cada importação fica guardada). "
                        "Se essa importação ainda não existir, o ranking conta desde o dia 01 até ela entrar.",
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, height: 1.35),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                      child: Text(_saving ? "Salvando..." : "Salvar"),
                    ),
                  ),
                  if (_windows.isNotEmpty) ...[
                    const Divider(color: Colors.white12, height: 28),
                    const Text("MESES COM PERÍODO PERSONALIZADO",
                        style: TextStyle(color: Color(0xFFFFC94D), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    const SizedBox(height: 6),
                    for (final w in _windows)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          "${_monthLabel(w["period_key"] as String)} · ${_metrics[w["metric"] ?? "todos"]}: ${_br(DateTime.parse(w["start_date"] as String))} a ${_br(DateTime.parse(w["end_date"] as String))}",
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          _baseOk[w["id"]] == true
                              ? "✅ Pronto"
                              : "⏳ Aguardando a importação com os dados até ${_br(DateTime.parse(w["start_date"] as String).subtract(const Duration(days: 1)))} — até lá conta desde o dia 01",
                          style: TextStyle(color: _baseOk[w["id"]] == true ? Colors.white54 : Colors.orangeAccent, fontSize: 12),
                        ),
                        trailing: TextButton(onPressed: () => _remove(w), child: const Text("Voltar ao mês inteiro")),
                      ),
                  ],
                ]),
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fechar"))],
    );
  }
}
