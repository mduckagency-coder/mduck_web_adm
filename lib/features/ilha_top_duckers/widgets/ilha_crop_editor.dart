import "package:flutter/material.dart";

/// Editor de corte/enquadramento (zoom + posicao) calibrado sobre uma
/// imagem estatica de referencia (print do video). O app aplica a MESMA
/// transformacao (Align com alignment = offset/50, dentro de um SizedBox
/// scale x maior que o frame, clipado) sobre o video de verdade, entao o
/// que o admin ve aqui e o que aparece no app.
class IlhaCropEditor extends StatelessWidget {
  const IlhaCropEditor({
    super.key,
    required this.imageUrl,
    required this.aspectRatio,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    required this.onScaleChanged,
    required this.onOffsetChanged,
  });

  final String imageUrl;
  final double aspectRatio;
  final double scale;
  final double offsetX;
  final double offsetY;
  final ValueChanged<double> onScaleChanged;
  final void Function(double x, double y) onOffsetChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Corte / enquadramento", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 4),
        const Text(
          "Baseado no print. Dê zoom e arraste pra corrigir vídeo com área maior do que deveria — o app aplica o mesmo corte no vídeo de verdade.",
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return Container(
                  color: Colors.black26,
                  child: ClipRect(
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        if (scale <= 1.001) return;
                        final travelX = size.width * (scale - 1) / 2;
                        final travelY = size.height * (scale - 1) / 2;
                        final newX = (offsetX + details.delta.dx / travelX * 50).clamp(-50.0, 50.0);
                        final newY = (offsetY + details.delta.dy / travelY * 50).clamp(-50.0, 50.0);
                        onOffsetChanged(newX, newY);
                      },
                      child: Align(
                        alignment: Alignment(offsetX / 50, offsetY / 50),
                        child: SizedBox(
                          width: size.width * scale,
                          height: size.height * scale,
                          child: Image.network(imageUrl, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.zoom_out, color: Colors.white54, size: 16),
          Expanded(
            child: Slider(
              value: scale.clamp(1.0, 3.0),
              min: 1.0,
              max: 3.0,
              activeColor: const Color(0xFF7A0BD4),
              onChanged: (v) {
                onScaleChanged(v);
                if (v <= 1.001) onOffsetChanged(0, 0);
              },
            ),
          ),
          const Icon(Icons.zoom_in, color: Colors.white54, size: 16),
        ]),
      ],
    );
  }
}
