import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";

import "academy_theme.dart";

/// Ponto tocavel de uma simulacao de LIVE. Os textos padrao ficam aqui; o
/// painel pode sobrescrever qualquer um pelo bloco da aula.
class LiveSpot {
  final String key;
  final String emoji;
  final String label;
  final String meaning;
  final String usage;
  final String tip;
  final Rect rect; // em fracoes da cena (0..1)
  const LiveSpot(this.key, this.emoji, this.label, this.rect, {required this.meaning, required this.usage, required this.tip});

  LiveSpot withOverride(Map? o) => o == null
      ? this
      : LiveSpot(key, (o["emoji"] as String?) ?? emoji, (o["label"] as String?) ?? label, rect,
          meaning: (o["meaning"] as String?) ?? meaning, usage: (o["usage"] as String?) ?? usage, tip: (o["tip"] as String?) ?? tip);
}

const liveSceneNames = {
  "batalha": "Batalha",
  "games": "LIVE de Games",
  "musica": "LIVE de Música",
  "conversa": "LIVE de conversa",
};

/// Pontos padrao de cada cena (chave -> texto). Usado tambem pelo editor do
/// painel para listar o que pode ser personalizado.
final Map<String, List<LiveSpot>> liveSceneSpots = {
  "batalha": const [
    LiveSpot("placar", "📊", "Placar", Rect.fromLTWH(0.04, 0.045, 0.92, 0.07),
        meaning: "Mostra os pontos de cada lado durante a partida.",
        usage: "Narre o placar para quem está assistindo acompanhar a disputa.",
        tip: "Avise quando estiver perto de virar: isso cria emoção."),
    LiveSpot("timer", "⏱️", "Tempo", Rect.fromLTWH(0.36, 0.125, 0.28, 0.06),
        meaning: "É o tempo que falta para acabar a partida.",
        usage: "Use para criar momentos: \"faltam 60 segundos!\".",
        tip: "Guarde energia para o último minuto — é o mais emocionante."),
    LiveSpot("adversario", "🆚", "Adversário", Rect.fromLTWH(0.51, 0.2, 0.45, 0.35),
        meaning: "O outro criador da partida, com a audiência dele.",
        usage: "Interaja com respeito e bom humor: a batalha é um show para as duas audiências.",
        tip: "Apresente o adversário de forma positiva antes de começar."),
    LiveSpot("meta", "🎯", "Meta", Rect.fromLTWH(0.04, 0.575, 0.44, 0.075),
        meaning: "Um objetivo combinado que a audiência acompanha.",
        usage: "Dá um motivo claro para torcer junto.",
        tip: "Metas possíveis animam. Metas exageradas desanimam."),
    LiveSpot("presentes", "🎁", "Presentes", Rect.fromLTWH(0.52, 0.575, 0.44, 0.075),
        meaning: "Forma de apoio da audiência. Na Batalha, o valor dos presentes vira pontos.",
        usage: "Agradeça na hora, pelo nome, quem apoia.",
        tip: "Agradecer vale mais do que pedir."),
    LiveSpot("comentarios", "💬", "Comentários", Rect.fromLTWH(0.04, 0.67, 0.62, 0.2),
        meaning: "A conversa da audiência em tempo real.",
        usage: "Leia a torcida em voz alta e chame as pessoas pelo nome.",
        tip: "Quem se sente visto na batalha volta na próxima."),
    LiveSpot("interacao", "❤️", "Curtidas", Rect.fromLTWH(0.72, 0.67, 0.24, 0.2),
        meaning: "Toques na tela. Na Batalha, curtidas também somam pontos.",
        usage: "Lembre quem não pode mandar presente que tocar na tela já ajuda.",
        tip: "Todo mundo pode participar da torcida — não só quem envia presente."),
  ],
  "games": const [
    LiveSpot("objetivo", "🏁", "Objetivo", Rect.fromLTWH(0.04, 0.035, 0.6, 0.065),
        meaning: "O que você quer alcançar nesta sessão.",
        usage: "Ajuda quem chega a entender a LIVE em segundos.",
        tip: "Repita o objetivo a cada 15–20 minutos para quem acabou de chegar."),
    LiveSpot("gameplay", "🎮", "Gameplay", Rect.fromLTWH(0.04, 0.115, 0.92, 0.42),
        meaning: "O jogo em si: o que está acontecendo na partida.",
        usage: "Narre suas decisões para quem assiste jogar junto com você.",
        tip: "Uma LIVE de Games não precisa ser apenas gameplay: a audiência também precisa participar."),
    LiveSpot("facecam", "📷", "Sua câmera", Rect.fromLTWH(0.69, 0.135, 0.24, 0.13),
        meaning: "Seu rosto junto com o jogo.",
        usage: "Suas reações viram parte do conteúdo.",
        tip: "Reação verdadeira cria momentos que dão ótimos vídeos curtos."),
    LiveSpot("evento", "⚡", "Evento", Rect.fromLTWH(0.12, 0.43, 0.76, 0.07),
        meaning: "Algo que aconteceu na experiência por causa da audiência.",
        usage: "Mostra que a participação de quem assiste muda a LIVE.",
        tip: "Explique as regras dos eventos no começo e repita para quem chega."),
    LiveSpot("presente", "🎁", "Presente", Rect.fromLTWH(0.04, 0.555, 0.5, 0.07),
        meaning: "Apoio enviado por alguém da audiência.",
        usage: "Pode ser ligado a um evento combinado, quando você usa ferramentas que permitem isso.",
        tip: "Agradeça pelo nome e mostre a consequência na tela."),
    LiveSpot("votacao", "🗳️", "Votação", Rect.fromLTWH(0.57, 0.555, 0.39, 0.12),
        meaning: "A audiência escolhe algo da partida (mapa, rota, desafio).",
        usage: "Quem decide quer ver o resultado — e fica.",
        tip: "Dê opções simples: \"digite 1 ou 2\"."),
    LiveSpot("chat", "💬", "Chat", Rect.fromLTWH(0.04, 0.68, 0.62, 0.2),
        meaning: "Onde a audiência participa: comandos, palpites, comentários.",
        usage: "Leia nos momentos calmos do jogo (menus, loading).",
        tip: "Responda curto durante a ação e completo nas pausas."),
  ],
  "musica": const [
    LiveSpot("musica_atual", "🎵", "Tocando agora", Rect.fromLTWH(0.04, 0.035, 0.6, 0.065),
        meaning: "Qual música você está tocando.",
        usage: "Quem chega no meio sabe o que está ouvindo.",
        tip: "Conte uma curiosidade da música antes de começar."),
    LiveSpot("audio", "🎚️", "Áudio", Rect.fromLTWH(0.69, 0.035, 0.27, 0.065),
        meaning: "O equilíbrio entre sua voz e o instrumento.",
        usage: "Teste antes de entrar ao vivo.",
        tip: "Som bom segura mais gente do que imagem perfeita."),
    LiveSpot("artista", "🎤", "Você", Rect.fromLTWH(0.18, 0.12, 0.64, 0.38),
        meaning: "Sua presença: voz, expressão e conexão.",
        usage: "Olhe para a câmera nos trechos mais importantes.",
        tip: "Enquadre rosto e instrumento sem cortar as mãos."),
    LiveSpot("meta", "🎯", "Meta", Rect.fromLTWH(0.04, 0.53, 0.54, 0.07),
        meaning: "Um objetivo visível para a audiência acompanhar.",
        usage: "Pode marcar momentos especiais da LIVE.",
        tip: "Cumpra o que combinar quando a meta for batida."),
    LiveSpot("pedidos", "📝", "Pedidos", Rect.fromLTWH(0.62, 0.53, 0.34, 0.16),
        meaning: "A fila de músicas pedidas pela audiência.",
        usage: "Diga a ordem em voz alta: todo mundo sabe quando é a sua vez.",
        tip: "Transparência na fila evita frustração."),
    LiveSpot("presentes", "🎁", "Presentes", Rect.fromLTWH(0.04, 0.615, 0.54, 0.07),
        meaning: "Apoio da audiência durante a música.",
        usage: "Agradeça no intervalo entre as músicas.",
        tip: "O intervalo também é momento de conexão."),
    LiveSpot("comentarios", "💬", "Comentários", Rect.fromLTWH(0.04, 0.7, 0.62, 0.19),
        meaning: "Reações e conversa da audiência.",
        usage: "Leia os comentários entre uma música e outra.",
        tip: "Lembre o nome de quem sempre aparece."),
  ],
  "conversa": const [
    LiveSpot("moderacao", "🛡️", "Moderação", Rect.fromLTWH(0.04, 0.035, 0.34, 0.065),
        meaning: "Pessoas de confiança que ajudam a cuidar do chat.",
        usage: "Deixam você livre para focar em quem está assistindo.",
        tip: "Combine as regras do chat com seus moderadores antes da LIVE."),
    LiveSpot("host", "🎥", "Você", Rect.fromLTWH(0.16, 0.11, 0.68, 0.34),
        meaning: "O centro da LIVE: sua voz, energia e jeito.",
        usage: "Fale com a audiência, não para a audiência.",
        tip: "Comece já falando, como se a conversa estivesse acontecendo."),
    LiveSpot("pergunta", "❓", "Pergunta", Rect.fromLTWH(0.04, 0.47, 0.58, 0.08),
        meaning: "Uma pergunta em destaque para a audiência responder.",
        usage: "Pergunta aberta puxa conversa.",
        tip: "Troque a pergunta quando a conversa esfriar."),
    LiveSpot("convidado", "👥", "Convidado", Rect.fromLTWH(0.66, 0.47, 0.3, 0.17),
        meaning: "Alguém participando da sua LIVE junto com você.",
        usage: "Apresente o convidado e divida o tempo de fala.",
        tip: "Um bom convidado apresenta você para uma audiência nova."),
    LiveSpot("comentarios", "💬", "Comentários", Rect.fromLTWH(0.04, 0.67, 0.64, 0.21),
        meaning: "A conversa em tempo real.",
        usage: "Leia em voz alta, responda pelo nome e devolva com uma pergunta.",
        tip: "Muita gente assiste sem comentar: fale com elas também."),
    LiveSpot("curtidas", "❤️", "Curtidas", Rect.fromLTWH(0.74, 0.67, 0.22, 0.21),
        meaning: "Toques na tela de quem está gostando.",
        usage: "Um sinal rápido de que o assunto está agradando.",
        tip: "Agradeça a energia: \"que chuva de corações!\"."),
  ],
};

List<LiveSpot> spotsFor(String scene, Map? overrides) =>
    [for (final s in liveSceneSpots[scene] ?? const <LiveSpot>[]) s.withOverride(overrides?[s.key] as Map?)];

/// Simulacao visual de uma LIVE.
///   explore  -> pontos pulsando; tocar mostra "Isso significa / Isso pode
///               ser usado para / Dica MDuck".
///   identify -> pede para tocar na parte certa da tela (prompts).
class LiveScene extends StatefulWidget {
  final String scene;
  final Map? overrides;
  final bool identify;
  final List<Map> prompts;
  final Color accent;
  final void Function(int explored, int total)? onProgress;

  const LiveScene({super.key, required this.scene, this.overrides, this.identify = false, this.prompts = const [], this.accent = acLilac, this.onProgress});

  @override
  State<LiveScene> createState() => _LiveSceneState();
}

class _LiveSceneState extends State<LiveScene> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  Timer? _chatTimer;
  int _chatTick = 0;
  LiveSpot? _selected;
  final Set<String> _visited = {};
  int _prompt = 0;
  String? _feedback;
  bool _feedbackOk = false;

  late List<LiveSpot> _spots = spotsFor(widget.scene, widget.overrides);

  @override
  void initState() {
    super.initState();
    _chatTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (mounted) setState(() => _chatTick++);
    });
  }

  @override
  void didUpdateWidget(covariant LiveScene old) {
    super.didUpdateWidget(old);
    if (old.scene != widget.scene || old.overrides != widget.overrides) _spots = spotsFor(widget.scene, widget.overrides);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _float.dispose();
    _chatTimer?.cancel();
    super.dispose();
  }

  void _tap(LiveSpot s) {
    if (widget.identify) {
      if (_prompt >= widget.prompts.length) return;
      final p = widget.prompts[_prompt];
      final ok = p["key"] == s.key;
      setState(() {
        _feedbackOk = ok;
        _feedback = ok ? (p["ok"] as String? ?? "Isso!") : "Ainda não. Tente outra parte da tela.";
        if (ok) _prompt++;
      });
      return;
    }
    setState(() {
      _selected = s;
      _visited.add(s.key);
    });
    widget.onProgress?.call(_visited.length, _spots.length);
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.identify && _prompt >= widget.prompts.length && widget.prompts.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.identify)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Container(
            key: ValueKey("$_prompt-$done"),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: widget.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Text(done ? "🎉" : "👆", style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  done ? "Mandou bem! Você identificou todas as partes." : "${_prompt + 1}/${widget.prompts.length} · ${widget.prompts[_prompt]["ask"]}",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ]),
          ),
        ),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: AspectRatio(
            aspectRatio: 9 / 13,
            child: LayoutBuilder(builder: (context, box) {
              final size = box.biggest;
              Rect r(Rect f) => Rect.fromLTWH(f.left * size.width, f.top * size.height, f.width * size.width, f.height * size.height);
              return ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(children: [
                  Positioned.fill(child: _background()),
                  for (final s in _spots) Positioned.fromRect(rect: r(s.rect), child: _element(s.key, r(s.rect).size)),
                  // areas de toque (por cima de tudo, na ordem: as menores por ultimo)
                  for (final s in [..._spots]..sort((a, b) => (b.rect.width * b.rect.height).compareTo(a.rect.width * a.rect.height)))
                    Positioned.fromRect(
                      rect: r(s.rect),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _tap(s),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: _selected?.key == s.key && !widget.identify ? Border.all(color: widget.accent, width: 2) : null,
                          ),
                        ),
                      ),
                    ),
                  if (!widget.identify)
                    for (final s in _spots)
                      Positioned(
                        left: (r(s.rect).right - 16).clamp(2.0, size.width - 26),
                        top: (r(s.rect).top - 8).clamp(2.0, size.height - 26),
                        child: IgnorePointer(child: _dot(_visited.contains(s.key))),
                      ),
                ]),
              );
            }),
          ),
        ),
      ),
      const SizedBox(height: 10),
      if (widget.identify && _feedback != null)
        Text(_feedback!,
            textAlign: TextAlign.center,
            style: TextStyle(color: _feedbackOk ? const Color(0xFF7CF2B0) : const Color(0xFFFFB4C2), fontWeight: FontWeight.w800)),
      if (widget.identify && done)
        TextButton(
          onPressed: () => setState(() {
            _prompt = 0;
            _feedback = null;
          }),
          child: const Text("Fazer de novo"),
        ),
      if (!widget.identify) ...[
        Text("Você explorou ${_visited.length} de ${_spots.length}",
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: _selected == null
              ? Container(
                  key: const ValueKey("vazio"),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
                  child: const Text("👆 Toque nos pontos que brilham para descobrir o que cada parte faz.",
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13)),
                )
              : _SpotInfo(key: ValueKey(_selected!.key), spot: _selected!, accent: widget.accent),
        ),
      ],
    ]);
  }

  Widget _dot(bool visited) => AnimatedBuilder(
        animation: _pulse,
        builder: (_, _) {
          final t = _pulse.value;
          return SizedBox(
            width: 24,
            height: 24,
            child: Stack(alignment: Alignment.center, children: [
              if (!visited)
                Container(
                  width: 10 + 14 * t,
                  height: 10 + 14 * t,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: widget.accent.withValues(alpha: 0.5 * (1 - t))),
                ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: visited ? const Color(0xFF3DDC97) : widget.accent,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: visited ? const Icon(Icons.check, size: 9, color: Colors.white) : null,
              ),
            ]),
          );
        },
      );

  // ------------------------------------------------------------------ cenas

  Widget _background() {
    final colors = switch (widget.scene) {
      "batalha" => const [Color(0xFF2A0B2E), Color(0xFF14061F)],
      "games" => const [Color(0xFF071A33), Color(0xFF0B0820)],
      "musica" => const [Color(0xFF2B0B3A), Color(0xFF10061E)],
      _ => const [Color(0xFF1B1240), Color(0xFF0C0820)],
    };
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors)),
      child: Align(
        alignment: const Alignment(0, 0.97),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          height: 26,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
          child: const Row(children: [
            SizedBox(width: 12),
            Expanded(child: Text("Comente...", style: TextStyle(color: Colors.white38, fontSize: 10))),
            Text("🎁  ❤️  ", style: TextStyle(fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  static const _names = ["ana_live", "leo.games", "bia💜", "duda", "rafa_br", "ju.music", "tom"];

  List<String> get _chat => switch (widget.scene) {
        "batalha" => ["Vamos virar!! 🔥", "tô aqui na torcida", "faltam 2 min!!", "manda ver 💜", "boa noite gente"],
        "games" => ["vai pela esquerda", "1", "2", "quase!!", "que jogada 😱", "faz o desafio!"],
        "musica" => ["canta aquela de novo 🥹", "pedido: Evidências", "que voz!", "boa noite 🎶", "arrepiei"],
        _ => ["de São Paulo!", "oi oi 💜", "cheguei agora", "boa pergunta", "Recife aqui"],
      };

  Widget _chatList(Size s) {
    final lines = _chat;
    return ClipRect(
      child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text.rich(
                key: ValueKey("${_chatTick + i}"),
                TextSpan(children: [
                  TextSpan(text: "${_names[(_chatTick + i) % _names.length]}  ", style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700)),
                  TextSpan(text: lines[(_chatTick + i) % lines.length], style: const TextStyle(color: Colors.white)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: math.max(9, s.height * 0.12)),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _chip(String text, {Color bg = const Color(0x55000000), Color fg = Colors.white, double fs = 10}) => Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, style: TextStyle(color: fg, fontSize: fs, fontWeight: FontWeight.w800))),
      );

  Widget _person(Color c1, Color c2, String label, Size s) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c1, c2]),
        ),
        child: Stack(children: [
          Align(
            alignment: const Alignment(0, 0.35),
            child: Icon(Icons.person, size: s.height * 0.62, color: Colors.white.withValues(alpha: 0.85)),
          ),
          Positioned(left: 6, bottom: 6, child: _chip(label, fs: 9)),
        ]),
      );

  Widget _hearts(Size s) => AnimatedBuilder(
        animation: _float,
        builder: (_, _) => Stack(children: [
          for (var i = 0; i < 5; i++)
            Positioned(
              left: s.width * (0.15 + (i * 0.17) % 0.7),
              top: s.height * (1 - ((_float.value + i / 5) % 1)) - 10,
              child: Opacity(
                opacity: 1 - ((_float.value + i / 5) % 1),
                child: Text(["❤️", "💜", "💖", "❤️", "💗"][i], style: TextStyle(fontSize: 12 + (i % 2) * 4)),
              ),
            ),
        ]),
      );

  Widget _element(String key, Size s) {
    switch ("${widget.scene}.$key") {
      // ------------------------------------------------------------ batalha
      case "batalha.placar":
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Row(children: [
            Expanded(flex: 58, child: Container(color: const Color(0xFF8B3DFF), alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 8), child: const Text("1.240", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)))),
            Expanded(flex: 42, child: Container(color: const Color(0xFFFF3D6E), alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 8), child: const Text("890", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)))),
          ]),
        );
      case "batalha.timer":
        return _chip("⏱ 04:12", bg: Colors.black.withValues(alpha: 0.6), fs: 11);
      case "batalha.adversario":
        return Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: _person(const Color(0xFFFF3D6E), const Color(0xFF5A0F2E), "adversário", s)),
          Positioned(
            left: -s.width * 1.02,
            top: 0,
            width: s.width * 0.98,
            height: s.height,
            child: IgnorePointer(child: _person(const Color(0xFF8B3DFF), const Color(0xFF2D0E66), "você", s)),
          ),
          Positioned(
            left: -22,
            top: s.height * 0.42,
            child: IgnorePointer(
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [acGold, Color(0xFFFF8A00)])),
                child: const Text("VS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ),
          ),
        ]);
      case "batalha.meta":
        return _goal("🌹 Meta 34/50", 0.68);
      case "batalha.presentes":
        return _giftBanner("bia💜 enviou 🌹 x5");
      case "batalha.comentarios":
      case "musica.comentarios":
      case "conversa.comentarios":
      case "games.chat":
        return _chatList(s);
      case "batalha.interacao":
      case "conversa.curtidas":
        return _hearts(s);
      // -------------------------------------------------------------- games
      case "games.objetivo":
        return _chip("🏁 Objetivo: vencer 3 partidas · 1/3", bg: const Color(0xCC0E7C9E), fs: 10);
      case "games.gameplay":
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CustomPaint(painter: _GamePainter(_float), child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: SizedBox(width: s.width * 0.35, height: 8, child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(value: 0.7, backgroundColor: Colors.black38, color: Color(0xFF3DDC97)),
              )),
            ),
          )),
        );
      case "games.facecam":
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF5CF2FF), width: 1.5),
            gradient: const LinearGradient(colors: [Color(0xFF3B1E8C), Color(0xFF14104A)]),
          ),
          child: Icon(Icons.person, color: Colors.white70, size: s.height * 0.7),
        );
      case "games.evento":
        return AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Transform.scale(scale: 1 + 0.03 * math.sin(_pulse.value * math.pi * 2), child: child),
          child: _chip("⚡ Evento ativado: chuva de obstáculos!", bg: const Color(0xDDFFB020), fg: Colors.black, fs: 10),
        );
      case "games.presente":
        return _giftBanner("leo.games enviou 🎁");
      case "games.votacao":
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text("🗳️ Próximo mapa", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            _bar("1 · Deserto", 0.62),
            const SizedBox(height: 2),
            _bar("2 · Gelo", 0.38),
          ]),
        );
      // ------------------------------------------------------------- musica
      case "musica.musica_atual":
        return _chip("🎵 Tocando agora: Evidências", bg: const Color(0xCCB0379F), fs: 10);
      case "musica.audio":
        return AnimatedBuilder(
          animation: _float,
          builder: (_, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text("🎙️", style: TextStyle(fontSize: 10)),
              const SizedBox(width: 4),
              for (var i = 0; i < 6; i++)
                Container(
                  width: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  height: 4 + 10 * (0.5 + 0.5 * math.sin(_float.value * math.pi * 8 + i)).abs(),
                  color: i < 4 ? const Color(0xFF3DDC97) : acGold,
                ),
            ]),
          ),
        );
      case "musica.artista":
        return Stack(children: [
          Positioned.fill(child: _person(const Color(0xFF7A2BE2), const Color(0xFF2B0B3A), "você", s)),
          Align(alignment: const Alignment(0.55, 0.45), child: Text("🎤", style: TextStyle(fontSize: s.height * 0.18))),
          Align(alignment: const Alignment(-0.7, -0.6), child: Text("🎶", style: TextStyle(fontSize: s.height * 0.1))),
        ]);
      case "musica.meta":
        return _goal("🎯 Meta: 20/30 💜", 0.66);
      case "musica.presentes":
        return _giftBanner("ju.music enviou 🌹");
      case "musica.pedidos":
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(10)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text("📝 Pedidos", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
            SizedBox(height: 2),
            Text("1. Evidências", style: TextStyle(color: Colors.white70, fontSize: 8.5)),
            Text("2. Garota de Ipanema", style: TextStyle(color: Colors.white70, fontSize: 8.5), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text("3. Trem-Bala", style: TextStyle(color: Colors.white70, fontSize: 8.5)),
          ]),
        );
      // ----------------------------------------------------------- conversa
      case "conversa.moderacao":
        return _chip("🛡️ 2 moderadores", bg: const Color(0x8814204A), fs: 10);
      case "conversa.host":
        return _person(const Color(0xFF5B2BC9), const Color(0xFF1B1240), "você", s);
      case "conversa.pergunta":
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text("❓ De onde você está assistindo?", style: TextStyle(color: Color(0xFF2B1470), fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        );
      case "conversa.convidado":
        return _person(const Color(0xFF0F766E), const Color(0xFF14204A), "convidada", s);
    }
    return const SizedBox.shrink();
  }

  Widget _goal(String text, double value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(12)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
          const SizedBox(height: 3),
          ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: value, minHeight: 4, backgroundColor: Colors.white12, color: acGold)),
        ]),
      );

  Widget _giftBanner(String text) => AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Opacity(opacity: 0.75 + 0.25 * math.sin(_pulse.value * math.pi), child: child),
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xCCFF7A9C), Color(0x33FF7A9C)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
        ),
      );

  Widget _bar(String label, double v) => Stack(children: [
        Container(height: 13, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
        FractionallySizedBox(
          widthFactor: v,
          child: Container(height: 13, decoration: BoxDecoration(color: const Color(0x995CF2FF), borderRadius: BorderRadius.circular(4))),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 8), overflow: TextOverflow.ellipsis)),
              Text("${(v * 100).round()}%", style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ]);
}

class _SpotInfo extends StatelessWidget {
  final LiveSpot spot;
  final Color accent;
  const _SpotInfo({super.key, required this.spot, required this.accent});

  Widget _line(String title, String body, {Color? color}) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: color ?? accent, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(body, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35)),
        ]),
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("${spot.emoji}  ${spot.label}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          _line("Isso significa…", spot.meaning),
          _line("Isso pode ser usado para…", spot.usage),
          _line("💡 Dica MDuck", spot.tip, color: acGold),
        ]),
      );
}

/// Cenario de jogo bem simples (plataforma, personagem e moedas).
class _GamePainter extends CustomPainter {
  final Animation<double> t;
  _GamePainter(this.t) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size s) {
    final sky = Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1E5FB8), Color(0xFF6FC3FF)]).createShader(Offset.zero & s);
    canvas.drawRect(Offset.zero & s, sky);
    final hill = Paint()..color = const Color(0xFF2E8B57);
    canvas.drawOval(Rect.fromLTWH(-s.width * 0.2, s.height * 0.62, s.width * 0.8, s.height * 0.6), hill);
    canvas.drawOval(Rect.fromLTWH(s.width * 0.4, s.height * 0.66, s.width * 0.9, s.height * 0.6), Paint()..color = const Color(0xFF3AA76D));
    final ground = Paint()..color = const Color(0xFF6B4423);
    canvas.drawRect(Rect.fromLTWH(0, s.height * 0.86, s.width, s.height * 0.14), ground);
    canvas.drawRect(Rect.fromLTWH(0, s.height * 0.84, s.width, s.height * 0.03), Paint()..color = const Color(0xFF4CAF50));
    // plataforma
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.55, s.height * 0.55, s.width * 0.25, s.height * 0.05), const Radius.circular(4)), ground);
    // moedas
    for (var i = 0; i < 3; i++) {
      final bob = math.sin(t.value * math.pi * 2 + i) * 3;
      canvas.drawCircle(Offset(s.width * (0.6 + i * 0.07), s.height * 0.47 + bob), s.height * 0.025, Paint()..color = acGold);
    }
    // personagem pulando
    final jump = math.max(0.0, math.sin(t.value * math.pi * 2)) * s.height * 0.12;
    final cx = s.width * 0.3, by = s.height * 0.84 - jump;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, by - s.height * 0.07), width: s.width * 0.07, height: s.height * 0.12), const Radius.circular(6)), Paint()..color = const Color(0xFF7A2BE2));
    canvas.drawCircle(Offset(cx, by - s.height * 0.16), s.height * 0.04, Paint()..color = const Color(0xFFFFD7A8));
    // inimigo
    canvas.drawCircle(Offset(s.width * 0.82, s.height * 0.81), s.height * 0.035, Paint()..color = const Color(0xFFE53935));
  }

  @override
  bool shouldRepaint(_GamePainter old) => false;
}
