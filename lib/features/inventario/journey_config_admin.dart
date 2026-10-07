import "package:flutter/material.dart";
import "conquistas_admin.dart" show compactValue, parseValue;
import "conquistas_service.dart";

const _purple = Color(0xFF7A0BD4);
const _gold = Color(0xFFFFC94D);
const _card = Color(0xFF1B1626);

/// Inventario > CONFIGURACOES da Jornada (app_settings 'journey_config').
///   diamond_target   meta de diamantes do mes (padrao 80K). Dias e horas usam
///                    as metas padrao/personalizadas que ja existem (22 / 100).
///   onboarding_days  duracao da fase "Primeiros 90 dias" (padrao 90).
/// As metas profissionais NUNCA sao reduzidas pelo historico do streamer.
class JourneyConfigAdmin extends StatefulWidget {
  const JourneyConfigAdmin({super.key});

  @override
  State<JourneyConfigAdmin> createState() => _JourneyConfigAdminState();
}

class _JourneyConfigAdminState extends State<JourneyConfigAdmin> {
  final _service = ConquistasService();
  final _diamondTarget = TextEditingController();
  final _onboardingDays = TextEditingController();
  final _journeyTitle = TextEditingController();
  final _journeySubtitle = TextEditingController();
  Map<String, dynamic> _config = {};
  bool _loaded = false;
  bool _saving = false;
  bool _recalculating = false;

  @override
  void initState() {
    super.initState();
    _service.fetchJourneyConfig().then((c) {
      if (!mounted) return;
      setState(() {
        _config = c;
        _diamondTarget.text = compactValue((c["diamond_target"] as num?) ?? 80000);
        _onboardingDays.text = ((c["onboarding_days"] as num?) ?? 90).toString();
        _journeyTitle.text = c["journey_title"] as String? ?? "Sua jornada na MDuck";
        _journeySubtitle.text = c["journey_subtitle"] as String? ?? "Um registro dos momentos que marcaram sua trajetória.";
        _loaded = true;
      });
    }).catchError((_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _diamondTarget.dispose();
    _onboardingDays.dispose();
    _journeyTitle.dispose();
    _journeySubtitle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final config = Map<String, dynamic>.from(_config)
        ..["diamond_target"] = parseValue(_diamondTarget.text) ?? 80000
        ..["onboarding_days"] = int.tryParse(_onboardingDays.text.trim()) ?? 90
        ..["journey_title"] = _journeyTitle.text.trim().isEmpty ? "Sua jornada na MDuck" : _journeyTitle.text.trim()
        ..["journey_subtitle"] = _journeySubtitle.text.trim();
      await _service.saveJourneyConfig(config);
      _config = config;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Configurações salvas.")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _recalculate() async {
    setState(() => _recalculating = true);
    try {
      final n = await _service.recalculateAll();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Recalculado. $n conquista(s) nova(s).")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      if (mounted) setState(() => _recalculating = false);
    }
  }

  Widget _field(TextEditingController c, String label, String help) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          SizedBox(
            width: 220,
            child: TextField(
              controller: c,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54), border: const OutlineInputBorder(), isDense: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(help, style: const TextStyle(color: Colors.white54, fontSize: 12))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.lightBlueAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.35)),
        ),
        child: const Text(
          "O app mostra sempre a referência profissional do mês: 22 dias de live, 100 horas ao vivo e 80K diamantes "
          "(dias e horas seguem as metas padrão ou personalizadas de cada streamer). A meta nunca é reduzida pelo histórico: "
          "quem está abaixo é incentivado pela Constância e pelas orientações, sem transformar uma meta baixa em meta cumprida. "
          "A Constância é calculada sozinha (dias, horas, ritmo do mês, comparação com o mês anterior e dias sem live).",
          style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
        ),
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("METAS E FASES", style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          _field(_diamondTarget, "Meta de diamantes do mês", "Referência mostrada na Home e na Jornada (padrão 80K)."),
          _field(_onboardingDays, "Duração dos primeiros dias", "Quantos dias após o acesso ao app aparece a área \"Primeiros 90 dias\" (padrão 90)."),
          const SizedBox(height: 8),
          const Text("TEXTOS DA JORNADA NO APP", style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          _field(_journeyTitle, "Título da Jornada", "Aparece no topo da linha do tempo (ex.: Sua jornada na MDuck)."),
          _field(_journeySubtitle, "Descrição da Jornada", "Frase logo abaixo do título."),
        ]),
      ),
      const SizedBox(height: 16),
      Row(children: [
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
          child: Text(_saving ? "Salvando..." : "Salvar"),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _recalculating ? null : _recalculate,
          icon: const Icon(Icons.refresh, size: 16, color: Colors.white70),
          label: Text(_recalculating ? "Recalculando..." : "Recalcular conquistas e marcos agora", style: const TextStyle(color: Colors.white70)),
        ),
      ]),
    ]);
  }
}
