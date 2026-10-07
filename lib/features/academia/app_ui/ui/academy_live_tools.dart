part of "academy_interactive.dart";

// Recursos da LIVE (Baú de Tesouros, Portal, Sacola de Prêmios):
//   live_menu     LIVE simulada → toque em "⋯" → menu de recursos → item destacado
//   tiktok_sheet  tela clara do TikTok montada por elementos (cards, campos,
//                 linhas, opções, níveis, slider, estimativas) + "Enviar" animado
//   compare       cartões "qual usar?" com mini fluxo animado
// Tudo vem do painel (nomes ficticios, valores ilustrativos).

const _tkInk = Color(0xFF161823);
const _tkGrey = Color(0xFF8A8B91);
const _tkCard = Color(0xFFF1F1F2);
const _tkRed = Color(0xFFFE2C55);

const _menuIcons = <String, IconData>{
  "enquete": Icons.poll_outlined,
  "manual": Icons.menu_book_outlined,
  "bau": Icons.inventory_2_outlined,
  "bau_superfa": Icons.card_giftcard_outlined,
  "sacola": Icons.shopping_bag_outlined,
  "papel": Icons.wallpaper_outlined,
  "desejos": Icons.redeem_outlined,
  "musicas": Icons.library_music_outlined,
  "portal": Icons.door_sliding_outlined,
};

/// Moeda do TikTok (círculo dourado com nota musical).
class _Coin extends StatelessWidget {
  final double size;
  const _Coin({this.size = 16});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFFFD25A), Color(0xFFF2A100)])),
        child: Icon(Icons.music_note, size: size * 0.62, color: Colors.white),
      );
}

/// Fundo de LIVE (câmera cinza + barra de cima) usado atrás das telas.
class _LiveBackdrop extends StatelessWidget {
  final Map b;
  final double height;
  const _LiveBackdrop(this.b, {required this.height});

  @override
  Widget build(BuildContext context) {
    final name = _s(b, "host", "Lucas Martins");
    return Container(
      height: height,
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8E8E8E), Color(0xFFB9B9B9)])),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(3, 3, 8, 3),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              FakeAvatar(name, size: 26),
              const SizedBox(width: 6),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(name.length > 10 ? "${name.substring(0, 9)}…" : name, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                const Text("♥ 18", style: TextStyle(color: Colors.white70, fontSize: 9.5)),
              ]),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: const Text("🧡 77", style: TextStyle(color: Color(0xFFFF7A45), fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
            child: const Text("👤 0", style: TextStyle(color: Colors.white, fontSize: 10.5)),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.power_settings_new, color: Colors.white, size: 20),
        ]),
        if (height > 90) ...[
          const SizedBox(height: 6),
          Row(children: [
            _pill(_s(b, "league_chip", "💎 Top 99% da Liga D2")),
            const Spacer(),
            _pill("Galeria 0/9"),
            const SizedBox(width: 4),
            _pill("Super liga"),
          ]),
        ],
      ]),
    );
  }

  static Widget _pill(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700)),
      );
}

Widget _blockHeader(Map b, Color accent) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_s(b, "label").isNotEmpty)
        Text(_s(b, "label").toUpperCase(), style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      if (_s(b, "title").isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 3), child: Text(_s(b, "title"), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.2))),
      if (_s(b, "intro").isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 6), child: Text(_s(b, "intro"), style: const TextStyle(color: Color(0xFFE6E0F5), fontSize: 14.5, height: 1.45))),
      const SizedBox(height: 12),
    ]);

// ---------------------------------------------------------------- menu da LIVE

class LiveMenuBlock extends StatefulWidget {
  final Map block;
  final Color accent;
  const LiveMenuBlock(this.block, {super.key, required this.accent});

  @override
  State<LiveMenuBlock> createState() => _LiveMenuBlockState();
}

class _LiveMenuBlockState extends State<LiveMenuBlock> {
  bool _open = false;
  bool _found = false;

  Map get b => widget.block;

  void _tapTarget() {
    setState(() => _found = true);
    showAcademyExplain(context, title: _s(b, "target_title", _s(b, "target")), body: _s(b, "target_body"), tip: _s(b, "target_tip"));
  }

  @override
  Widget build(BuildContext context) {
    final items = _maps(b, "items");
    final target = _s(b, "target");
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _blockHeader(b, widget.accent),
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: Colors.black,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open ? _menu(items, target) : _live(),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: Text(
            !_open
                ? _s(b, "hint", "👆 Toque em ⋯ (Mais opções), no canto de baixo.")
                : _found
                    ? _s(b, "done_text", "✨ Achou! Continue ↓")
                    : "👆 Toque em ${target.isEmpty ? "um recurso" : target}",
            style: TextStyle(color: _found ? const Color(0xFF7CF2B0) : acLilac, fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
        ),
        if (_open)
          TextButton.icon(
            onPressed: () => setState(() {
              _open = false;
              _found = false;
            }),
            icon: const Icon(Icons.replay, size: 15, color: Colors.white54),
            label: const Text("De novo", style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
      ]),
    ]);
  }

  Widget _live() {
    final chat = _maps(b, "chat");
    return SizedBox(
      height: 430,
      child: Stack(children: [
        Positioned.fill(child: _LiveBackdrop(b, height: 430)),
        Positioned(
          left: 10,
          right: 60,
          bottom: 62,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final c in chat)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FakeAvatar(_s(c, "user", "?"), size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: "${_s(c, "user")}  ", style: const TextStyle(color: Color(0xFFE0E0E0), fontWeight: FontWeight.w700)),
                        TextSpan(text: _s(c, "text"), style: const TextStyle(color: Colors.white)),
                      ]),
                      style: const TextStyle(fontSize: 11.5, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: Row(children: [
            _round(Icons.link, const Color(0xFFFF3D7F)),
            const SizedBox(width: 8),
            _round(Icons.group_outlined, const Color(0xFFFF3D7F)),
            const Spacer(),
            _round(Icons.shopping_bag_outlined, Colors.white),
            const SizedBox(width: 8),
            _round(Icons.reply, Colors.white, flip: true),
            const SizedBox(width: 8),
            _round(Icons.auto_fix_high, Colors.white),
            const SizedBox(width: 8),
            Column(mainAxisSize: MainAxisSize.min, children: [
              const _TapHint("👇"),
              const SizedBox(height: 4),
              _Hot(
                active: true,
                radius: 22,
                onTap: () => setState(() => _open = true),
                child: _round(Icons.more_horiz, Colors.white),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  static Widget _round(IconData i, Color c, {bool flip = false}) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
        child: Transform.flip(flipX: flip, child: Icon(i, color: c, size: 20)),
      );

  Widget _menu(List<Map> items, String target) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _LiveBackdrop(b, height: 96),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: const BoxDecoration(color: Color(0xFFF5F5F6), borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            for (final i in [Icons.cached, Icons.flip, Icons.mic_none, Icons.pause])
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(i, color: _tkInk, size: 21),
              ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              LayoutBuilder(builder: (context, box) {
                final w = box.maxWidth / 4;
                return Wrap(runSpacing: 10, children: [
                  for (final it in items)
                    SizedBox(
                      width: w,
                      child: _menuItem(it, _s(it, "label") == target),
                    ),
                ]);
              }),
              const SizedBox(height: 8),
              const Text("Exibir menos ⌃", style: TextStyle(color: _tkGrey, fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              for (final (icon, label, extra) in const [
                (Icons.card_giftcard, "Presentes de LIVE", "•"),
                (Icons.chat_bubble_outline, "Comentar", ""),
                (Icons.article_outlined, "Sobre mim", "• Exibido"),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Row(children: [
                    Icon(icon, size: 19, color: _tkInk),
                    const SizedBox(width: 10),
                    Expanded(child: Text(label, style: const TextStyle(color: _tkInk, fontSize: 13.5, fontWeight: FontWeight.w600))),
                    Text(extra, style: const TextStyle(color: _tkRed, fontSize: 12)),
                    const Icon(Icons.chevron_right, size: 18, color: _tkGrey),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _menuItem(Map it, bool isTarget) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: [
        if (_s(it, "icon") == "bau" || _s(it, "icon") == "portal")
          TreasureChest(size: 30, portal: _s(it, "icon") == "portal")
        else
          Icon(_menuIcons[_s(it, "icon")] ?? Icons.apps, size: 26, color: isTarget ? _tkRed : _tkInk),
        const SizedBox(height: 4),
        Text(_s(it, "label"), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            style: TextStyle(color: _tkInk, fontSize: 10.5, fontWeight: isTarget ? FontWeight.w900 : FontWeight.w500)),
      ]),
    );
    if (!isTarget) {
      return Opacity(opacity: _found ? 0.5 : 1, child: content);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: _Hot(active: !_found, radius: 10, onTap: _tapTarget, child: content),
    );
  }
}

// ---------------------------------------------------------------- tela do TikTok

class TikTokSheetBlock extends StatefulWidget {
  final Map block;
  final Color accent;
  const TikTokSheetBlock(this.block, {super.key, required this.accent});

  @override
  State<TikTokSheetBlock> createState() => _TikTokSheetBlockState();
}

class _TikTokSheetBlockState extends State<TikTokSheetBlock> {
  final Map<String, int> _selected = {}; // grupo -> indice escolhido
  double _t = 0; // posicao do slider (0..1)
  int _sent = -1; // -1 nao enviado; >=0 passos mostrados
  Timer? _timer;
  final Set<int> _seen = {};

  Map get b => widget.block;
  List<Map> get els => _maps(b, "elements");

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _explain(int i, Map e) {
    setState(() => _seen.add(i));
    final body = _s(e, "explain");
    if (body.isEmpty) return;
    showAcademyExplain(context, title: _s(e, "explain_title", _s(e, "label", _s(e, "left"))), body: body, tip: _s(e, "tip"));
  }

  void _select(String group, int i, Map e) {
    setState(() => _selected[group] = i);
    _explain(i, e);
  }

  void _send() {
    final steps = _maps(b, "send_steps");
    _timer?.cancel();
    setState(() => _sent = 0);
    _timer = Timer.periodic(const Duration(milliseconds: 850), (t) {
      if (!mounted || _sent >= steps.length + 1) {
        t.cancel();
        return;
      }
      setState(() => _sent++);
    });
  }

  int _initial(String kind) {
    for (var i = 0; i < els.length; i++) {
      if (_s(els[i], "kind") == kind && _yes(els[i]["selected"])) return i;
    }
    return -1;
  }

  bool _isSelected(String kind, int i) => (_selected[kind] ?? _initial(kind)) == i;

  @override
  Widget build(BuildContext context) {
    final steps = _maps(b, "send_steps");
    final tabs = _s(b, "tabs").split("|").where((x) => x.trim().isNotEmpty).toList();
    final activeTab = int.tryParse(_s(b, "tab_active")) ?? 0;
    final explainable = [for (var i = 0; i < els.length; i++) if (_s(els[i], "explain").isNotEmpty) i];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _blockHeader(b, widget.accent),
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: Colors.black,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _LiveBackdrop(b, height: 96),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: const BoxDecoration(color: Color(0xFFF5F5F6), borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // cabecalho: titulo ou abas
                Row(children: [
                  if (_yes(b["back"])) const Icon(Icons.chevron_left, color: _tkInk, size: 26),
                  if (tabs.isNotEmpty)
                    for (var k = 0; k < tabs.length; k++)
                      GestureDetector(
                        onTap: k == activeTab || _s(b, "tab_explain").isEmpty
                            ? null
                            : () => showAcademyExplain(context, title: tabs[k], body: _s(b, "tab_explain")),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: k == activeTab ? Colors.black : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                          child: Text(tabs[k], style: TextStyle(color: k == activeTab ? Colors.white : _tkInk, fontSize: 13, fontWeight: FontWeight.w800)),
                        ),
                      )
                  else
                    Expanded(
                      child: Text(_s(b, "sheet_title"), textAlign: TextAlign.center, style: const TextStyle(color: _tkInk, fontSize: 15.5, fontWeight: FontWeight.w800)),
                    ),
                  if (tabs.isNotEmpty) const Spacer(),
                  if (_s(b, "corner") == "help")
                    const Icon(Icons.help_outline, color: _tkInk, size: 22)
                  else if (_s(b, "corner") == "icons") ...[
                    const Icon(Icons.mark_email_unread_outlined, color: _tkInk, size: 21),
                    const SizedBox(width: 10),
                    const Icon(Icons.article_outlined, color: _tkInk, size: 21),
                  ] else if (_s(b, "corner") == "close")
                    const Icon(Icons.close, color: _tkInk, size: 21),
                ]),
                if (_s(b, "section").isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Text(_s(b, "section"), style: const TextStyle(color: _tkInk, fontSize: 14.5, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    if (_s(b, "section_action").isNotEmpty) Text(_s(b, "section_action"), style: const TextStyle(color: _tkGrey, fontSize: 12)),
                  ]),
                ],
                const SizedBox(height: 10),
                for (var i = 0; i < els.length; i++) _element(i, els[i]),
                const SizedBox(height: 8),
                if (_s(b, "terms").isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_s(b, "terms"), style: const TextStyle(color: _tkGrey, fontSize: 10.5)),
                  ),
                if (_s(b, "button").isNotEmpty)
                  _Hot(
                    active: steps.isNotEmpty && _sent < 0,
                    radius: 24,
                    onTap: steps.isEmpty ? () {} : _send,
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _tkRed, borderRadius: BorderRadius.circular(24)),
                      child: Text(_s(b, "button"), style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      if (explainable.isNotEmpty)
        _Progress(_seen.where(explainable.contains).length, explainable.length),
      if (steps.isNotEmpty && _sent >= 0) ...[
        const SizedBox(height: 12),
        _sendFlow(steps),
      ],
    ]);
  }

  Widget _element(int i, Map e) {
    final kind = _s(e, "kind");
    final hasExplain = _s(e, "explain").isNotEmpty;
    Widget hot(Widget child, {double r = 12, VoidCallback? onTap}) =>
        hasExplain || onTap != null ? _Hot(active: hasExplain && !_seen.contains(i), radius: r, onTap: onTap ?? () => _explain(i, e), child: child) : child;
    Widget gap(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w);

    switch (kind) {
      case "option": // card de escolha (Baú / Portal)
        final sel = _isSelected("option", i);
        return gap(hot(
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? _tkInk : const Color(0xFFE3E3E5), width: sel ? 1.8 : 1)),
            child: Row(children: [
              if (_s(e, "icon") == "people") ...[
                const Icon(Icons.people_alt_rounded, color: Color(0xFF5B8DEF), size: 30),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (_s(e, "coins").isNotEmpty && _s(e, "icon") != "people") ...[const _Coin(), const SizedBox(width: 6)],
                    Text(_s(e, "left", _s(e, "coins")), style: const TextStyle(color: _tkInk, fontSize: 15, fontWeight: FontWeight.w800)),
                  ]),
                  if (_s(e, "sub").isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 3), child: Text(_s(e, "sub"), style: const TextStyle(color: _tkGrey, fontSize: 11, height: 1.3))),
                ]),
              ),
              if (_s(e, "icon") == "people" && _s(e, "coins").isNotEmpty) ...[
                Container(width: 1, height: 36, color: const Color(0xFFE3E3E5)),
                const SizedBox(width: 10),
                const _Coin(),
                const SizedBox(width: 4),
                Text(_s(e, "coins"), style: const TextStyle(color: _tkInk, fontSize: 14, fontWeight: FontWeight.w800)),
              ] else
                Text(_s(e, "right"), style: const TextStyle(color: _tkGrey, fontSize: 12)),
            ]),
          ),
          onTap: () => _select("option", i, e),
        ));
      case "field": // campo de digitar (Personalizar)
        return gap(hot(
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_s(e, "label"), style: const TextStyle(color: _tkInk, fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(color: _tkCard, borderRadius: BorderRadius.circular(8)),
              child: Text(_s(e, "hint"), style: const TextStyle(color: Color(0xFFAAABB0), fontSize: 13)),
            ),
          ]),
          r: 8,
        ));
      case "row": // linha "rotulo ..... valor >"
        return gap(hot(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Expanded(child: Text(_s(e, "label"), style: const TextStyle(color: _tkInk, fontSize: 13.5, fontWeight: FontWeight.w700))),
              Flexible(child: Text(_s(e, "value"), textAlign: TextAlign.right, style: const TextStyle(color: _tkGrey, fontSize: 12))),
              const Icon(Icons.chevron_right, size: 18, color: _tkGrey),
            ]),
          ),
          r: 10,
        ));
      case "radio":
        final sel = _isSelected("radio", i);
        return gap(hot(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(children: [
              Expanded(child: Text(_s(e, "label"), style: const TextStyle(color: _tkInk, fontSize: 13.5, fontWeight: FontWeight.w600))),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: sel ? _tkRed : const Color(0xFFBDBEC2), width: sel ? 6 : 1.5)),
              ),
            ]),
          ),
          r: 8,
          onTap: () => _select("radio", i, e),
        ));
      case "chips": // Nv.1 Nv.3 ...
        final opts = _s(e, "options").split(",").map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
        final cur = _selected["chips$i"] ?? (int.tryParse(_s(e, "selected")) ?? 0);
        return gap(Row(children: [
          for (var k = 0; k < opts.length; k++)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selected["chips$i"] = k);
                  _explain(i, e);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(right: k < opts.length - 1 ? 6 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: k == cur ? const Color(0xFFFFE8EC) : _tkCard, borderRadius: BorderRadius.circular(6)),
                  child: Text(opts[k], style: TextStyle(color: k == cur ? _tkRed : _tkGrey, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ]));
      case "stat": // numero grande (estimativa)
        final lo = int.tryParse(_s(e, "big_min").replaceAll(".", "")) ?? 0;
        final hi = int.tryParse(_s(e, "big_max").replaceAll(".", "")) ?? lo;
        final v = (lo + (hi - lo) * _t).round();
        return gap(hot(
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Text("$v", key: ValueKey(v), style: const TextStyle(color: _tkInk, fontSize: 26, fontWeight: FontWeight.w900)),
              ),
              Text("${_s(e, "label")} ⓘ", style: const TextStyle(color: _tkGrey, fontSize: 12)),
            ]),
          ),
        ));
      case "pair": // "rotulo ......... valor" (pode mudar com o slider)
        final value = _t >= 0.5 && _s(e, "value_max").isNotEmpty ? _s(e, "value_max") : _s(e, "value");
        return gap(hot(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Expanded(child: Text("${_s(e, "label")} ⓘ", style: const TextStyle(color: _tkInk, fontSize: 12.5))),
              Text(value, style: const TextStyle(color: _tkInk, fontSize: 13.5, fontWeight: FontWeight.w800)),
            ]),
          ),
          r: 10,
        ));
      case "slider":
        final lo = double.tryParse(_s(e, "min")) ?? 0;
        final hi = double.tryParse(_s(e, "max")) ?? 100;
        final v = lo + (hi - lo) * _t;
        return gap(Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () => _explain(i, e),
              child: Row(children: [
                Text(_s(e, "label"), style: const TextStyle(color: _tkInk, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                if (hasExplain && !_seen.contains(i)) const Icon(Icons.touch_app, size: 16, color: Color(0xFFB57BFF)),
              ]),
            ),
            const SizedBox(height: 6),
            Row(children: [
              const _Coin(size: 14),
              const SizedBox(width: 4),
              Text("${v.round()}", style: const TextStyle(color: _tkInk, fontSize: 13, fontWeight: FontWeight.w800)),
            ]),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _tkRed,
                inactiveTrackColor: const Color(0xFFE3E3E5),
                thumbColor: Colors.white,
                overlayColor: _tkRed.withValues(alpha: 0.1),
                trackHeight: 3,
              ),
              child: Slider(value: _t, onChanged: (x) => setState(() => _t = x)),
            ),
            if (_s(e, "note").isNotEmpty)
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(_s(e, "note"), style: const TextStyle(color: _tkGrey, fontSize: 10.5))),
          ]),
        ));
      case "link":
        return gap(hot(Text(_s(e, "label"), style: const TextStyle(color: _tkInk, fontSize: 12.5, fontWeight: FontWeight.w600)), r: 6));
      case "note":
        return gap(Text(_s(e, "label"), style: const TextStyle(color: _tkGrey, fontSize: 11, height: 1.35)));
      case "comment": // texto do comentario configurado
        return gap(hot(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(_s(e, "label"), style: const TextStyle(color: _tkInk, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          r: 6,
        ));
    }
    return const SizedBox.shrink();
  }

  Widget _sendFlow(List<Map> steps) {
    final shown = _sent.clamp(0, steps.length);
    final done = _sent > steps.length;
    final rewards = int.tryParse(_s(b, "rewards")) ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: widget.accent.withValues(alpha: 0.08),
        border: Border.all(color: widget.accent.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_s(b, "send_title", "O que acontece depois de enviar"), style: TextStyle(color: widget.accent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 10),
        for (var k = 0; k < shown; k++) ...[
          TweenAnimationBuilder<double>(
            key: ValueKey("s$k"),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Opacity(opacity: v.clamp(0, 1), child: Transform.scale(scale: 0.85 + 0.15 * v, child: child)),
            child: Row(children: [
              SizedBox(width: 32, child: Center(child: chestOrEmoji(steps[k], size: 30, fallback: "•"))),
              const SizedBox(width: 10),
              Expanded(child: Text(_s(steps[k], "label"), style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800))),
            ]),
          ),
          if (k < steps.length - 1 && k < shown - 1)
            const Padding(padding: EdgeInsets.only(left: 8, top: 2, bottom: 2), child: Icon(Icons.arrow_downward_rounded, color: Colors.white38, size: 18)),
        ],
        if (done && rewards > 0) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var k = 0; k < rewards; k++)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 350 + 120 * k),
                curve: Curves.easeOutBack,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: Stack(clipBehavior: Clip.none, children: [
                  FakeAvatar(["@ana_live", "@bruno_live", "@camila_s", "@theo.games", "@joaopedro", "@mari.oficial"][k % 6], size: 36),
                  const Positioned(right: -4, bottom: -4, child: _Coin(size: 17)),
                ]),
              ),
          ]),
        ],
        if (done && _s(b, "send_body").isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_s(b, "send_body"), style: const TextStyle(color: Color(0xFFE6E0F5), fontSize: 14, height: 1.45)),
        ],
        if (done)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _send,
              icon: const Icon(Icons.replay, size: 15, color: Colors.white54),
              label: const Text("Ver de novo", style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- qual usar?

class CompareBlock extends StatefulWidget {
  final Map block;
  final Color accent;
  const CompareBlock(this.block, {super.key, required this.accent});

  @override
  State<CompareBlock> createState() => _CompareBlockState();
}

class _CompareBlockState extends State<CompareBlock> {
  int? _open;

  static const _palette = [Color(0xFFFFC94D), Color(0xFF5CE1E6), Color(0xFFFF7EB3), Color(0xFFA78BFA)];

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    final items = _maps(b, "items");
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _blockHeader(b, widget.accent),
      for (var i = 0; i < items.length; i++) ...[
        _card(i, items[i], _palette[i % _palette.length]),
        const SizedBox(height: 10),
      ],
      if (_s(b, "footer").isNotEmpty)
        Center(
          child: Text(_s(b, "footer"), textAlign: TextAlign.center, style: const TextStyle(color: acGold, fontSize: 15, fontWeight: FontWeight.w900)),
        ),
    ]);
  }

  Widget _card(int i, Map it, Color color) {
    final open = _open == i;
    final steps = _s(it, "steps").split("|").map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    return GestureDetector(
      onTap: () => setState(() => _open = open ? null : i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: open ? color.withValues(alpha: 0.12) : acCard,
          border: Border.all(color: open ? color : Colors.white12, width: open ? 1.6 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
              child: chestOrEmoji(it, size: 34),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_s(it, "title").toUpperCase(), style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(_s(it, "goal"), style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35, fontWeight: FontWeight.w600)),
              ]),
            ),
            Icon(open ? Icons.remove_circle_outline : Icons.play_circle_outline, color: color, size: 20),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            child: !open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 6, children: [
                        for (var k = 0; k < steps.length; k++) ...[
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(milliseconds: 300 + 350 * k),
                            curve: Curves.easeOut,
                            builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                              child: Text(steps[k], style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          if (k < steps.length - 1)
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward_rounded, size: 16, color: color)),
                        ],
                      ]),
                      if (_s(it, "question").isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text("“${_s(it, "question")}”", style: TextStyle(color: color, fontSize: 13.5, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
                      ],
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- visão do espectador

/// Como o espectador vê: ícones (Baú, Portal, Sacola) no canto de cima,
/// logo abaixo da foto do streamer.
class ViewerViewBlock extends StatefulWidget {
  final Map block;
  final Color accent;
  const ViewerViewBlock(this.block, {super.key, required this.accent});

  @override
  State<ViewerViewBlock> createState() => _ViewerViewBlockState();
}

class _ViewerViewBlockState extends State<ViewerViewBlock> {
  final Set<int> _seen = {};

  Map get b => widget.block;

  @override
  Widget build(BuildContext context) {
    final icons = _maps(b, "icons");
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _blockHeader(b, widget.accent),
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 330,
          child: Stack(children: [
            Positioned.fill(child: _LiveBackdrop(b, height: 330)),
            Positioned(
              left: 12,
              top: 88,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < icons.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Hot(
                      active: !_seen.contains(i),
                      radius: 12,
                      onTap: () {
                        setState(() => _seen.add(i));
                        showAcademyExplain(context, title: _s(icons[i], "title"), body: _s(icons[i], "body"), tip: _s(icons[i], "tip"));
                      },
                      child: _icon(icons[i]),
                    ),
                  ),
              ]),
            ),
            const Positioned(left: 92, top: 112, child: _TapHint("👈 Toque")),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      if (icons.isNotEmpty) _Progress(_seen.length, icons.length),
    ]);
  }

  Widget _icon(Map it) => Container(
        width: 68,
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF8A65), Color(0xFFE53958)]),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          chestOrEmoji(it, size: 48, fallback: "🎁"),
          if (_s(it, "badge").isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
              child: Text(_s(it, "badge"), style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
            ),
        ]),
      );
}

/// Baú do tesouro no estilo do TikTok: rosa com moldura creme, tampa
/// arredondada, faixa central e fechadura dourada redonda.
/// [portal] = mesmo baú com um brilho (versão do Portal).
class TreasureChest extends StatelessWidget {
  final double size;
  final bool portal;
  const TreasureChest({super.key, this.size = 40, this.portal = false});

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _ChestPainter(portal)));
}

/// Desenho do baú/portal no lugar do emoji quando o item tem "art".
Widget chestOrEmoji(Map m, {required double size, String fallback = "✨"}) {
  final art = _s(m, "art");
  if (art == "bau" || art == "portal") return TreasureChest(size: size, portal: art == "portal");
  return Text(_s(m, "emoji", fallback), style: TextStyle(fontSize: size * 0.72));
}

class _ChestPainter extends CustomPainter {
  final bool portal;
  _ChestPainter(this.portal);

  static const _cream = Color(0xFFF7DFAE);
  static const _creamDark = Color(0xFFE2BC78);

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    Rect r(double l, double t, double rr, double b) => Rect.fromLTRB(w * l, h * t, w * rr, h * b);

    if (portal) {
      c.drawCircle(Offset(w * 0.5, h * 0.52), w * 0.5,
          Paint()..shader = RadialGradient(colors: [const Color(0x8869E6FF), const Color(0x0069E6FF)]).createShader(Offset.zero & s));
    }

    // pezinhos
    final feet = Paint()..color = _creamDark;
    c.drawRRect(RRect.fromRectAndRadius(r(0.13, 0.84, 0.25, 0.92), Radius.circular(w * 0.02)), feet);
    c.drawRRect(RRect.fromRectAndRadius(r(0.75, 0.84, 0.87, 0.92), Radius.circular(w * 0.02)), feet);

    // corpo (parte de baixo)
    final body = RRect.fromRectAndCorners(r(0.10, 0.50, 0.90, 0.88), bottomLeft: Radius.circular(w * 0.07), bottomRight: Radius.circular(w * 0.07));
    c.drawRRect(body, Paint()..color = _cream);
    final bodyIn = RRect.fromRectAndCorners(r(0.15, 0.53, 0.85, 0.83), bottomLeft: Radius.circular(w * 0.04), bottomRight: Radius.circular(w * 0.04));
    c.drawRRect(bodyIn, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE5486C), Color(0xFFC72C55)]).createShader(bodyIn.outerRect));

    // tampa arredondada
    final lid = RRect.fromRectAndCorners(r(0.10, 0.08, 0.90, 0.52), topLeft: Radius.circular(w * 0.30), topRight: Radius.circular(w * 0.30));
    c.drawRRect(lid, Paint()..color = _cream);
    final lidIn = RRect.fromRectAndCorners(r(0.15, 0.13, 0.85, 0.49), topLeft: Radius.circular(w * 0.25), topRight: Radius.circular(w * 0.25));
    c.drawRRect(lidIn, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF77C99), Color(0xFFE5486C)]).createShader(lidIn.outerRect));
    // brilho da tampa
    c.drawRRect(RRect.fromRectAndRadius(r(0.22, 0.20, 0.34, 0.40), Radius.circular(w * 0.05)), Paint()..color = const Color(0x55FFFFFF));

    // faixa central (vertical)
    c.drawRect(r(0.43, 0.08, 0.57, 0.88), Paint()..color = _cream);
    // faixa da emenda (horizontal)
    c.drawRRect(RRect.fromRectAndRadius(r(0.08, 0.46, 0.92, 0.56), Radius.circular(w * 0.03)), Paint()..color = _cream);
    c.drawRect(r(0.08, 0.54, 0.92, 0.56), Paint()..color = _creamDark);

    // fechadura redonda dourada
    final center = Offset(w * 0.5, h * 0.51);
    c.drawCircle(center, w * 0.135, Paint()..color = const Color(0xFFC98F2E));
    c.drawCircle(center, w * 0.115,
        Paint()..shader = const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFFFF0B8), Color(0xFFF0C25A)]).createShader(Rect.fromCircle(center: center, radius: w * 0.115)));
    final hole = Paint()..color = const Color(0xFF6B4410);
    c.drawCircle(Offset(w * 0.5, h * 0.495), w * 0.03, hole);
    c.drawPath(
        Path()
          ..moveTo(w * 0.485, h * 0.50)
          ..lineTo(w * 0.515, h * 0.50)
          ..lineTo(w * 0.525, h * 0.565)
          ..lineTo(w * 0.475, h * 0.565)
          ..close(),
        hole);

    if (portal) {
      // brilho de 4 pontas (detalhe do Portal)
      void star(double x, double y, double rad, Color col) {
        final p = Path()
          ..moveTo(w * x, h * (y - rad))
          ..quadraticBezierTo(w * x, h * y, w * (x + rad), h * y)
          ..quadraticBezierTo(w * x, h * y, w * x, h * (y + rad))
          ..quadraticBezierTo(w * x, h * y, w * (x - rad), h * y)
          ..quadraticBezierTo(w * x, h * y, w * x, h * (y - rad))
          ..close();
        c.drawPath(p, Paint()..color = col);
      }

      star(0.86, 0.14, 0.15, const Color(0xFFFFE36B));
      star(0.86, 0.14, 0.07, Colors.white);
      star(0.12, 0.30, 0.07, const Color(0xFF9EF0FF));
    }
  }

  @override
  bool shouldRepaint(_ChestPainter old) => old.portal != portal;
}
