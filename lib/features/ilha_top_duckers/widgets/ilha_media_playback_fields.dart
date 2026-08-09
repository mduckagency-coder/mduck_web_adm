import "package:flutter/material.dart";

/// Controles de audio/loop reutilizados em todo formulario de video da Ilha
/// Top (fundo e avatar). Quando loop=true, o video precisa tocar em loop
/// infinito no app SEM ser pausado por outro video tocando em outra tela
/// (ex: uma aula do MAX) - isso e responsabilidade do player do app, aqui so
/// guardamos a intencao.
class IlhaMediaPlaybackFields extends StatelessWidget {
  const IlhaMediaPlaybackFields({
    super.key,
    required this.muted,
    required this.volume,
    required this.loop,
    required this.onMutedChanged,
    required this.onVolumeChanged,
    required this.onLoopChanged,
  });

  final bool muted;
  final double volume;
  final bool loop;
  final ValueChanged<bool> onMutedChanged;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<bool> onLoopChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Áudio e reprodução", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        SwitchListTile(
          value: muted,
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: const Color(0xFF7A0BD4),
          title: const Text("Sem som", style: TextStyle(color: Colors.white70, fontSize: 13)),
          onChanged: onMutedChanged,
        ),
        if (!muted)
          Row(children: [
            const Text("Volume", style: TextStyle(color: Colors.white54, fontSize: 12)),
            Expanded(
              child: Slider(
                value: volume.clamp(0.0, 1.0),
                min: 0,
                max: 1,
                activeColor: const Color(0xFF7A0BD4),
                onChanged: onVolumeChanged,
              ),
            ),
            SizedBox(width: 36, child: Text((volume * 100).round().toString() + "%", style: const TextStyle(color: Colors.white54, fontSize: 12))),
          ]),
        SwitchListTile(
          value: loop,
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: const Color(0xFF7A0BD4),
          title: const Text("Loop infinito", style: TextStyle(color: Colors.white70, fontSize: 13)),
          subtitle: loop
              ? const Text("Enquanto tocar, nenhum outro vídeo do app pode pausar/interromper este.", style: TextStyle(color: Colors.amberAccent, fontSize: 11))
              : null,
          onChanged: onLoopChanged,
        ),
      ],
    );
  }
}
