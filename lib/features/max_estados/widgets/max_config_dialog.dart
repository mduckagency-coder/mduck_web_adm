import "package:flutter/material.dart";
import "../max_estados_service.dart";

const _purple = Color(0xFF7A0BD4);

/// Engrenagem da pagina Max Entrada: liga/desliga da tela do Max ao abrir o
/// app e os dias que definem cada estado.
class MaxConfigDialog extends StatefulWidget {
  const MaxConfigDialog({super.key});

  @override
  State<MaxConfigDialog> createState() => _MaxConfigDialogState();
}

class _MaxConfigDialogState extends State<MaxConfigDialog> {
  final _service = MaxEstadosService();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _enabled = true;
  int _constanteLives = 3;
  int _constanteStreak = 3;
  int _inativo = 3;
  int _caveira = 10;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_service.fetchEnabled(), _service.fetchRules()]);
      final rules = results[1] as MaxStateRules;
      if (!mounted) return;
      setState(() {
        _enabled = results[0] as bool;
        _constanteLives = rules.constanteMinLivesThisMonth;
        _constanteStreak = rules.constanteMinStreakDays;
        _inativo = rules.inativoMinDaysWithoutLive;
        _caveira = rules.caveiraMinDaysWithoutLive;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Erro ao carregar: $e";
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_caveira <= _inativo) {
      setState(() => _error = "O Caveira precisa de mais dias sem live do que o Inativo.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.saveEnabled(_enabled);
      await _service.saveRules(MaxStateRules(
        constanteMinLivesThisMonth: _constanteLives,
        constanteMinStreakDays: _constanteStreak,
        inativoMinDaysWithoutLive: _inativo,
        caveiraMinDaysWithoutLive: _caveira,
      ));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = "Erro ao salvar: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _stepper({required String emoji, required String title, required String help, required int value, required int min, required ValueChanged<int> onChanged, String unit = "dias"}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(help, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.white54),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 56,
          child: Text("$value $unit", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
          onPressed: value < 60 ? () => onChanged(value + 1) : null,
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: _loading
            ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.settings, color: Colors.white70),
                    SizedBox(width: 8),
                    Text("Configuração do Max Entrada", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _enabled,
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: Colors.greenAccent,
                    title: Text(_enabled ? "Habilitado" : "Desabilitado",
                        style: TextStyle(color: _enabled ? Colors.greenAccent : Colors.white54, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      _enabled
                          ? "A tela do Max (vídeo + mensagem + Avançar) aparece toda vez que o streamer abre o app."
                          : "O app vai direto do carregamento para a Home, sem a tela do Max.",
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  const Text("Quando cada estado aparece", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text(
                    "A contagem usa a data da última live da Importação TikTok. Ordem de prioridade: Caveira → Inativo → Constante → Regular.",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  _stepper(
                    emoji: "💀",
                    title: "Caveira",
                    help: "A partir de quantos dias SEM live.",
                    value: _caveira,
                    min: 2,
                    onChanged: (v) => setState(() => _caveira = v),
                  ),
                  _stepper(
                    emoji: "😴",
                    title: "Inativo",
                    help: "A partir de quantos dias SEM live (e menos que o Caveira).",
                    value: _inativo,
                    min: 1,
                    onChanged: (v) => setState(() => _inativo = v),
                  ),
                  _stepper(
                    emoji: "🔥",
                    title: "Constante — dias de live no mês",
                    help: "Mínimo de dias com live no mês, tendo feito live ontem ou hoje.",
                    value: _constanteLives,
                    min: 1,
                    onChanged: (v) => setState(() => _constanteLives = v),
                  ),
                  _stepper(
                    emoji: "📆",
                    title: "Constante — dias seguidos",
                    help: "Usado quando o sistema tiver o dado de sequência de dias. Hoje a importação só traz a última live.",
                    value: _constanteStreak,
                    min: 2,
                    onChanged: (v) => setState(() => _constanteStreak = v),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text("🙂 Regular: quem não se encaixa em nenhum dos estados acima.",
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
                      child: Text(_saving ? "Salvando..." : "Salvar"),
                    ),
                  ]),
                ]),
              ),
      ),
    );
  }
}
