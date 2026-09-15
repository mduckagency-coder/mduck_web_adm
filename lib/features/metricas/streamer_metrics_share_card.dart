import "package:flutter/material.dart";
import "package:flutter/services.dart";

/// Monta a mensagem pronta para o gestor mandar ao streamer. Precisa ser
/// clara por si so (o streamer nao ve o resto da tela), por isso leva nick,
/// rotulos explicitos e nao so numeros soltos.
String buildStreamerMetricsMessage({
  required String nick,
  required String categoria,
  required int diamonds,
  required int daysLive,
  required double hoursLive,
}) {
  return "Oi " +
      nick +
      "! Aqui esta o resumo do seu desempenho neste mes:\n\n"
          "Categoria: " +
      categoria +
      "\n"
          "Diamantes: " +
      diamonds.toString() +
      "\n"
          "Dias ao vivo: " +
      daysLive.toString() +
      "\n"
          "Horas ao vivo: " +
      hoursLive.toStringAsFixed(0) +
      "h";
}

/// Metas mensais da agencia (definidas pelo gestor): todo streamer deveria
/// bater 22 dias e 100h ao vivo, e 80 mil diamantes no mes. Usadas so pra
/// dar o % de progresso e uma frase de incentivo no comparativo -- nao sao
/// limite de elegibilidade de nenhum programa, so contexto motivacional.
const int metaDiasAoVivo = 22;
const int metaHorasAoVivo = 100;
const int metaDiamantesMes = 80000;

/// Indice estavel que muda a cada 7 dias corridos (nao reinicia por mes,
/// so avanca) -- usado pra girar as frases motivacionais das listas abaixo
/// sem precisar guardar nenhum estado: mesma semana sempre cai no mesmo
/// indice, semana seguinte já cai no proximo.
int _weeklyIndex(DateTime now, int poolLength) {
  final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
  final week = dayOfYear ~/ 7;
  return week % poolLength;
}

/// Mesma ideia do _weeklyIndex, mas somando um "spin" extra (variant) --
/// cada vez que o gestor aperta copiar de novo no mesmo card, o widget
/// incrementa esse numero e a proxima frase mostrada muda, sem esperar uma
/// semana nova. variant=0 sempre reproduz a escolha semanal normal.
int _phraseIndex(DateTime now, int variant, int poolLength) =>
    (_weeklyIndex(now, poolLength) + variant) % poolLength;

const _growthClosings = [
  "Esse mes voce esta em crescimento comparado ao mesmo periodo do mes "
      "passado! Continue nesse ritmo, a constancia e o que mais pesa no "
      "seu resultado. 🚀",
  "Crescimento confirmado em relacao ao mes passado! Isso mostra que o "
      "seu esforco esta valendo a pena -- bora manter a chama acesa ate o "
      "fim do mes. 🔥",
  "Voce esta evoluindo mes a mes, isso e otimo! Segue firme com a mesma "
      "dedicacao que te trouxe ate aqui. 💪",
  "Otimo periodo! Comparado ao mes passado voce ja esta a frente -- o "
      "proximo passo e manter essa consistencia ate o fechamento do mes. ⭐",
];
const _declineClosings = [
  "Esse mes voce esta em queda comparado ao mesmo periodo do mes "
      "passado. Precisa de mais constancia -- isso e muito importante "
      "para o seu crescimento. Vamos juntos melhorar esses numeros! 💪",
  "Os numeros desse mes ainda estao abaixo do mes passado, mas da pra "
      "reverter com mais frequencia nas lives. Foca nos proximos dias, "
      "cada live conta! 🎯",
  "Notei uma queda em relacao ao mes passado. Sem desanimar -- "
      "ajustando a rotina de lives, o resultado volta rapido. Bora com "
      "tudo no restante do mes! 🚀",
  "Comparado ao mes passado, esse mes esta mais fraco. E hora de focar: "
      "define um horario fixo pra ir ao vivo que a constancia traz o "
      "resultado de volta. 💪",
];
const _neutralClosings = [
  "Esse mes esta bem parecido com o mesmo periodo do mes passado. Um "
      "empurrao a mais em dias e horas ao vivo pode destravar o proximo "
      "salto. 💪",
  "Numeros estaveis em relacao ao mes passado. Um pequeno ajuste na "
      "frequencia das lives ja pode te colocar em outro patamar. 🚀",
  "Mes equilibrado comparado ao anterior. Hora de dar aquele empurrao "
      "extra pra sair do lugar e crescer de verdade. ⭐",
  "Performance parecida com o mes passado. Foca em bater as metas do "
      "mes que o crescimento vem naturalmente. 🎯",
];

const _metaBatidaFrases = [
  "Meta do mes batida! Isso mostra o tamanho do seu potencial -- "
      "continue assim. 🏆",
  "Parabens, meta alcancada! Voce prova que da pra ir ainda mais "
      "longe. 🎉",
  "Meta cumprida com sobra! Esse e o padrao que te leva pro proximo "
      "nivel. 🚀",
  "Mandou muito bem, meta do mes no bolso! Bora manter esse padrao ate "
      "o fim do mes. ⭐",
];
const _metaPertoFrases = [
  "Voce esta quase batendo a meta do mes -- faltam so os ultimos "
      "ajustes pra chegar la. 💪",
  "Perto da meta! Um empurrao extra nos proximos dias fecha essa "
      "conta. 🎯",
  "Quase la! Mantem o ritmo que a meta do mes esta ao seu alcance. ⭐",
  "Reta final pra bater a meta -- com mais um pouco de constancia voce "
      "chega la. 🚀",
];
const _metaAbaixoFrases = [
  "Ainda esta abaixo da meta do mes, mas isso nao define o seu "
      "potencial -- toda streamer grande comecou pequena. Foca em subir "
      "aos poucos que o resultado vem. 💪",
  "Sei que os numeros ainda estao longe da meta, mas voce pode chegar "
      "la com constancia. Um passo de cada vez! 🚀",
  "Numeros abaixo da meta por enquanto, mas isso e so o comeco -- com "
      "foco e presenca, voce vira esse jogo. Acredite no seu "
      "crescimento! ⭐",
  "Ainda longe da meta, mas o potencial esta ai -- vamos juntos "
      "aumentar a frequencia nas lives pra destravar esse resultado. 🎯",
];

/// Compara o mes atual (streamer_stats, sempre "ate hoje") com a mesma
/// altura do mes passado. So existe o total FECHADO do mes anterior
/// (monthly_stats, populado pela importacao mensal) -- nao ha granularidade
/// diaria confiavel pra saber exatamente o que o streamer tinha "no dia 14"
/// do mes passado (streamer_stat_snapshots so registra algo quando alguem
/// abre a tela naquele dia, com gaps). Por isso o total fechado do mes
/// passado e proporcionalizado pelos dias corridos deste mes (ex.: hoje dia
/// 14 de um mes anterior com 31 dias -> considera 14/31 do total fechado)
/// -- da uma base de comparacao justa "mesma altura do mes" sem depender de
/// historico diario que o app nao tem.
///
/// Tambem mostra o % de progresso em relacao a meta do mes (22 dias, 100h,
/// 80 mil diamantes) com uma frase de incentivo -- pro streamer que esta
/// bem abaixo entender que da pra melhorar, em vez de so ver um numero
/// baixo sem contexto nenhum. As frases (de crescimento/queda e de meta)
/// giram a cada semana (_weeklyIndex) pra nao virar sempre a mesma mensagem
/// copiada e colada.
String buildStreamerMetricsComparisonMessage({
  required String nick,
  required String categoria,
  required int diamondsThisMonth,
  required int daysLiveThisMonth,
  required double hoursLiveThisMonth,
  required num diamondsLastMonth,
  required num daysLiveLastMonth,
  required num hoursLiveLastMonth,
  int variant = 0,
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final prevMonth = now.month == 1 ? 12 : now.month - 1;
  final prevYear = now.month == 1 ? now.year - 1 : now.year;
  final daysInPrevMonth = DateTime(prevYear, prevMonth + 1, 0).day;
  final referenceDay = now.day > daysInPrevMonth ? daysInPrevMonth : now.day;
  final fraction = referenceDay / daysInPrevMonth;

  final diamondsLastEq = (diamondsLastMonth * fraction).round();
  final daysLastEq = (daysLiveLastMonth * fraction).round();
  final hoursLastEq = hoursLiveLastMonth * fraction;

  final diamondsDelta = diamondsThisMonth - diamondsLastEq;
  final daysDelta = daysLiveThisMonth - daysLastEq;
  final hoursDelta = hoursLiveThisMonth - hoursLastEq;

  String arrow(num delta) => delta > 0 ? "📈" : (delta < 0 ? "📉" : "➡️");
  String signed(num delta, {int decimals = 0}) =>
      (delta > 0 ? "+" : "") + delta.toStringAsFixed(decimals);

  final improved = [
    diamondsDelta,
    daysDelta,
    hoursDelta,
  ].where((d) => d > 0).length;
  final declined = [
    diamondsDelta,
    daysDelta,
    hoursDelta,
  ].where((d) => d < 0).length;

  final List<String> closingPool;
  if (improved > declined) {
    closingPool = _growthClosings;
  } else if (declined > improved) {
    closingPool = _declineClosings;
  } else {
    closingPool = _neutralClosings;
  }
  final closing = closingPool[_phraseIndex(now, variant, closingPool.length)];

  final diasPct = (daysLiveThisMonth / metaDiasAoVivo) * 100;
  final horasPct = (hoursLiveThisMonth / metaHorasAoVivo) * 100;
  final diamantesPct = (diamondsThisMonth / metaDiamantesMes) * 100;
  final metaPctMedia = (diasPct + horasPct + diamantesPct) / 3;

  final List<String> metaPool;
  if (metaPctMedia >= 100) {
    metaPool = _metaBatidaFrases;
  } else if (metaPctMedia >= 70) {
    metaPool = _metaPertoFrases;
  } else {
    metaPool = _metaAbaixoFrases;
  }
  // Indice deslocado (+1) em relacao ao das closings acima pra essas duas
  // frases (crescimento/meta) nao repetirem sempre a mesma combinacao na
  // mesma semana.
  final metaFrase =
      metaPool[_phraseIndex(now, variant + 1, metaPool.length)];

  String pct(double v) => v.clamp(0, 999).toStringAsFixed(0) + "%";

  return "Oi " +
      nick +
      "! Aqui esta a comparacao do seu desempenho deste mes (ate o dia " +
      referenceDay.toString() +
      ") com o mesmo periodo do mes passado:\n\n"
          "Categoria: " +
      categoria +
      "\n\n" +
      arrow(diamondsDelta) +
      " Diamantes: " +
      diamondsThisMonth.toString() +
      " (mes passado ate o dia " +
      referenceDay.toString() +
      ": ~" +
      diamondsLastEq.toString() +
      ", " +
      signed(diamondsDelta) +
      ")\n" +
      arrow(daysDelta) +
      " Dias ao vivo: " +
      daysLiveThisMonth.toString() +
      " (mes passado: ~" +
      daysLastEq.toString() +
      ", " +
      signed(daysDelta) +
      ")\n" +
      arrow(hoursDelta) +
      " Horas ao vivo: " +
      hoursLiveThisMonth.toStringAsFixed(0) +
      "h (mes passado: ~" +
      hoursLastEq.toStringAsFixed(0) +
      "h, " +
      signed(hoursDelta) +
      "h)\n\n" +
      closing +
      "\n\n"
          "🎯 Meta do mes: " +
      metaDiasAoVivo.toString() +
      " dias e " +
      metaHorasAoVivo.toString() +
      "h ao vivo, " +
      (metaDiamantesMes ~/ 1000).toString() +
      "k diamantes.\n"
          "Seu progresso ate agora: " +
      pct(diasPct) +
      " dos dias, " +
      pct(horasPct) +
      " das horas, " +
      pct(diamantesPct) +
      " dos diamantes.\n\n" +
      metaFrase;
}

/// Card clicavel que copia a mensagem de metricas do mes pronta para enviar
/// ao streamer (usado tanto em Metricas Streamers quanto no CRM).
class StreamerMetricsShareCard extends StatelessWidget {
  final String nick;
  final String categoria;
  final int diamonds;
  final int daysLive;
  final double hoursLive;

  const StreamerMetricsShareCard({
    super.key,
    required this.nick,
    required this.categoria,
    required this.diamonds,
    required this.daysLive,
    required this.hoursLive,
  });

  Future<void> _copy(BuildContext context) async {
    final text = buildStreamerMetricsMessage(
      nick: nick,
      categoria: categoria,
      diamonds: diamonds,
      daysLive: daysLive,
      hoursLive: hoursLive,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Mensagem copiada. Pronta para enviar ao streamer."),
        ),
      );
    }
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 6),
          Text(
            label + ": ",
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _copy(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF7A0BD4).withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF7A0BD4).withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.query_stats,
                    size: 16,
                    color: Color(0xFF7A0BD4),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      "Metricas do mes - pronto para enviar",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Icon(Icons.copy, size: 16, color: Colors.white54),
                ],
              ),
              const SizedBox(height: 8),
              _row(Icons.person, "Streamer", nick),
              _row(Icons.category, "Categoria", categoria),
              _row(Icons.diamond, "Diamantes", diamonds.toString()),
              _row(Icons.calendar_month, "Dias ao vivo", daysLive.toString()),
              _row(
                Icons.access_time,
                "Horas ao vivo",
                hoursLive.toStringAsFixed(0) + "h",
              ),
              const SizedBox(height: 6),
              const Text(
                "Toque para copiar a mensagem completa",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card irmao do StreamerMetricsShareCard -- mesma ideia (clicavel, copia
/// mensagem pronta), mas pro comparativo com o mes passado
/// (buildStreamerMetricsComparisonMessage). Widget separado em vez de um
/// botao dentro do card de cima pra nao aninhar dois InkWell/GestureDetector
/// na mesma area (dispara os dois onTap juntos no Flutter) -- assim o card
/// original fica intocado.
///
/// StatefulWidget (nao Stateless) por causa do "_variant": a cada clique em
/// copiar, o texto exibido muda pra outra frase da mesma familia (mesmos
/// dados, incentivo diferente) -- assim o gestor que manda mensagem pra
/// varios streamers na sequencia nao repete sempre a mesma frase, mesmo
/// dentro da mesma semana.
class StreamerMetricsComparisonShareCard extends StatefulWidget {
  final String nick;
  final String categoria;
  final int diamondsThisMonth;
  final int daysLiveThisMonth;
  final double hoursLiveThisMonth;
  final num diamondsLastMonth;
  final num daysLiveLastMonth;
  final num hoursLiveLastMonth;

  const StreamerMetricsComparisonShareCard({
    super.key,
    required this.nick,
    required this.categoria,
    required this.diamondsThisMonth,
    required this.daysLiveThisMonth,
    required this.hoursLiveThisMonth,
    required this.diamondsLastMonth,
    required this.daysLiveLastMonth,
    required this.hoursLiveLastMonth,
  });

  @override
  State<StreamerMetricsComparisonShareCard> createState() =>
      _StreamerMetricsComparisonShareCardState();
}

class _StreamerMetricsComparisonShareCardState
    extends State<StreamerMetricsComparisonShareCard> {
  int _variant = 0;

  String get _message => buildStreamerMetricsComparisonMessage(
    nick: widget.nick,
    categoria: widget.categoria,
    diamondsThisMonth: widget.diamondsThisMonth,
    daysLiveThisMonth: widget.daysLiveThisMonth,
    hoursLiveThisMonth: widget.hoursLiveThisMonth,
    diamondsLastMonth: widget.diamondsLastMonth,
    daysLiveLastMonth: widget.daysLiveLastMonth,
    hoursLiveLastMonth: widget.hoursLiveLastMonth,
    variant: _variant,
  );

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _message));
    if (!context.mounted) return;
    setState(() => _variant++);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Comparativo com o mes passado copiado. Pronto para enviar ao streamer.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.compare_arrows,
                size: 16,
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  "Comparativo com o mes passado",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              _message,
              style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy, size: 15, color: Colors.blueAccent),
              label: const Text(
                "Copiar mensagem",
                style: TextStyle(color: Colors.blueAccent, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _reengagementClosings = [
  "Isso mostra o quanto voce e capaz -- seu potencial continua o mesmo, so "
      "precisa voltar a aparecer. Bora marcar uma live essa semana? 💜",
  "Voce ja provou que consegue entregar numeros assim -- o talento nao "
      "muda, so falta voltar pra frente das cameras. Sentimos sua falta! 🚀",
  "Numeros desse nivel nao vem por acaso -- voce tem talento de sobra. Que "
      "tal retomar aos poucos essa semana e ir pegando o ritmo de novo? 💪",
  "A gente sabe do que voce e capaz -- o potencial continua o mesmo de "
      "sempre. Vamos combinar um horario pra voce voltar as lives? ⭐",
];

const _reengagementNoHistoryClosings = [
  "Toda jornada tem um comeco -- que tal marcarmos um horario pra voce "
      "ir ao vivo essa semana e a gente te ajudar a pegar o ritmo? 💜",
  "Ainda da tempo de comecar com tudo! Bora combinar um dia certo pra sua "
      "proxima live? 🚀",
  "Sem numeros anteriores pra comparar, mas isso e so o inicio da sua "
      "historia por aqui. Vamos marcar sua volta as lives? ⭐",
  "O primeiro passo e o mais importante -- topa a gente combinar um "
      "horario fixo pra voce comecar a aparecer mais? 💪",
];

/// Mensagem de reengajamento pro streamer inativo (sem live ha varios
/// dias). Em vez de so cobrar "volta pra live", contextualiza com o ultimo
/// mes FECHADO em que ele realmente teve atividade (monthly_stats -- nunca
/// o total acumulado, que dilui/esconde o quanto ele ja foi bom): mostra
/// que o gestor lembra do que ele ja entregou, nao so que ele sumiu. Sem
/// nenhum mes fechado com atividade (streamer novo que nunca engatou),
/// cai num texto mais simples de "vamos comecar".
String buildStreamerReengagementMessage({
  required String nick,
  required String categoria,
  required int daysSinceLastLive,
  String? lastActiveMonthLabel,
  int? lastActiveMonthDays,
  double? lastActiveMonthHours,
  int? lastActiveMonthDiamonds,
  int variant = 0,
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final intro =
      "Oi " +
      nick +
      "! Notei que faz " +
      daysSinceLastLive.toString() +
      " dias que voce nao vai ao vivo -- bateu saudade das suas lives por "
          "aqui! 👋\n\n"
          "Categoria: " +
      categoria +
      "\n\n";

  if (lastActiveMonthLabel == null) {
    final pool = _reengagementNoHistoryClosings;
    final closing = pool[_phraseIndex(now, variant, pool.length)];
    return intro + closing;
  }

  final pool = _reengagementClosings;
  final closing = pool[_phraseIndex(now, variant, pool.length)];

  return intro +
      "Sabia que em " +
      lastActiveMonthLabel +
      " voce teve otimos numeros:\n"
          "📅 Dias ao vivo: " +
      (lastActiveMonthDays ?? 0).toString() +
      "\n"
          "⏱️ Horas ao vivo: " +
      (lastActiveMonthHours ?? 0).toStringAsFixed(0) +
      "h\n"
          "💎 Diamantes: " +
      (lastActiveMonthDiamonds ?? 0).toString() +
      "\n\n" +
      closing;
}

/// Card de reengajamento -- so faz sentido mostrar quando o streamer esta
/// inativo (ver computeStreamerStatus/isInactive nas telas que chamam
/// isso). Mesmo padrao visual dos outros dois cards (texto visivel +
/// botao copiar + variant que muda a cada copia), so que em tom
/// laranja/vermelho pra sinalizar "atencao, precisa de acao" -- mesma cor
/// ja usada pro status "Inativo" no resto do app.
class StreamerReengagementShareCard extends StatefulWidget {
  final String nick;
  final String categoria;
  final int daysSinceLastLive;
  final String? lastActiveMonthLabel;
  final int? lastActiveMonthDays;
  final double? lastActiveMonthHours;
  final int? lastActiveMonthDiamonds;

  const StreamerReengagementShareCard({
    super.key,
    required this.nick,
    required this.categoria,
    required this.daysSinceLastLive,
    this.lastActiveMonthLabel,
    this.lastActiveMonthDays,
    this.lastActiveMonthHours,
    this.lastActiveMonthDiamonds,
  });

  @override
  State<StreamerReengagementShareCard> createState() =>
      _StreamerReengagementShareCardState();
}

class _StreamerReengagementShareCardState
    extends State<StreamerReengagementShareCard> {
  int _variant = 0;

  String get _message => buildStreamerReengagementMessage(
    nick: widget.nick,
    categoria: widget.categoria,
    daysSinceLastLive: widget.daysSinceLastLive,
    lastActiveMonthLabel: widget.lastActiveMonthLabel,
    lastActiveMonthDays: widget.lastActiveMonthDays,
    lastActiveMonthHours: widget.lastActiveMonthHours,
    lastActiveMonthDiamonds: widget.lastActiveMonthDiamonds,
    variant: _variant,
  );

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _message));
    if (!context.mounted) return;
    setState(() => _variant++);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Mensagem de reengajamento copiada. Pronta para enviar ao streamer.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                size: 16,
                color: Colors.orangeAccent,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  "Streamer inativo - mensagem de incentivo",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              _message,
              style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _copy(context),
              icon: const Icon(
                Icons.copy,
                size: 15,
                color: Colors.orangeAccent,
              ),
              label: const Text(
                "Copiar mensagem",
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
