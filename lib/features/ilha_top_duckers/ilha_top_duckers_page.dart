import "package:flutter/material.dart";
import "widgets/ilha_avatars_tab.dart";
import "widgets/ilha_backgrounds_tab.dart";
import "widgets/ilha_preview_tab.dart";
import "widgets/ilha_ranking_tab.dart";
import "widgets/ilha_slots_editor_tab.dart";

/// Gestao da Ilha Top: ranking dos elegiveis, banco de videos/imagens de
/// fundo (com regra de horario e modo fixo/aleatorio), banco de avatares
/// (patos) e editor de posicoes de cada slot da ilha.
class IlhaTopDuckersPage extends StatefulWidget {
  const IlhaTopDuckersPage({super.key});

  @override
  State<IlhaTopDuckersPage> createState() => _IlhaTopDuckersPageState();
}

class _IlhaTopDuckersPageState extends State<IlhaTopDuckersPage> {
  String _tab = "ranking";

  static const _tabs = [
    ("ranking", "Ranking"),
    ("fundos", "Vídeos de Fundo"),
    ("avatares", "Avatares (Patos)"),
    ("posicoes", "Posições da Ilha"),
    ("preview", "Pré-visualização"),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Ilha Top Duckers", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text("Streamers com 80k+ diamantes no mês (elegíveis à ilha), fundos, avatares e posições.", style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: _tabs.map((t) {
              final selected = _tab == t.$1;
              return ChoiceChip(
                label: Text(t.$2),
                selected: selected,
                selectedColor: const Color(0xFF7A0BD4),
                labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold),
                onSelected: (_) => setState(() => _tab = t.$1),
              );
            }).toList(),
          ),
          Expanded(
            child: switch (_tab) {
              "fundos" => const IlhaBackgroundsTab(),
              "avatares" => const IlhaAvatarsTab(),
              "posicoes" => const IlhaSlotsEditorTab(),
              "preview" => const IlhaPreviewTab(),
              _ => const IlhaRankingTab(),
            },
          ),
        ],
      ),
    );
  }
}
