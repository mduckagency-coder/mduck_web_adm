import "package:flutter/material.dart";

Color _hexToColor(String hex) {
  final cleaned = hex.replaceFirst("#", "");
  return Color(int.parse("FF" + cleaned, radix: 16));
}

/// Formato de recorte e tamanho do avatar dentro do slot na ilha. Hoje o app
/// forca todo avatar num circulo fixo (equivalente a "Padrao" aqui) -- os
/// outros formatos e o ajuste de tamanho sao opcionais, por cima do que ja
/// existe.
class IlhaAvatarDisplayFields extends StatelessWidget {
  const IlhaAvatarDisplayFields({
    super.key,
    required this.displayShape,
    required this.borderColor,
    required this.sizeMode,
    required this.sizePercent,
    required this.onDisplayShapeChanged,
    required this.onBorderColorChanged,
    required this.onSizeModeChanged,
    required this.onSizePercentChanged,
  });

  final String displayShape;
  final String borderColor;
  final String sizeMode;
  final double sizePercent;
  final ValueChanged<String> onDisplayShapeChanged;
  final ValueChanged<String> onBorderColorChanged;
  final ValueChanged<String> onSizeModeChanged;
  final ValueChanged<double> onSizePercentChanged;

  Color get _previewBorderColor {
    try {
      return _hexToColor(borderColor);
    } catch (_) {
      return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Formato de exibição", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 4),
        const Text("Como esse avatar aparece recortado dentro do slot na ilha.", style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
            label: const Text("Padrão (círculo com borda)"),
            selected: displayShape == "circle_border",
            selectedColor: const Color(0xFF7A0BD4),
            labelStyle: TextStyle(color: displayShape == "circle_border" ? Colors.white : Colors.white70, fontSize: 12),
            onSelected: (_) => onDisplayShapeChanged("circle_border"),
          ),
          ChoiceChip(
            label: const Text("Círculo sem borda visível"),
            selected: displayShape == "circle_plain",
            selectedColor: const Color(0xFF7A0BD4),
            labelStyle: TextStyle(color: displayShape == "circle_plain" ? Colors.white : Colors.white70, fontSize: 12),
            onSelected: (_) => onDisplayShapeChanged("circle_plain"),
          ),
          ChoiceChip(
            label: const Text("Quadrado"),
            selected: displayShape == "square",
            selectedColor: const Color(0xFF7A0BD4),
            labelStyle: TextStyle(color: displayShape == "square" ? Colors.white : Colors.white70, fontSize: 12),
            onSelected: (_) => onDisplayShapeChanged("square"),
          ),
        ]),
        if (displayShape == "circle_border") ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextFormField(
                initialValue: borderColor,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(labelText: "Cor da borda (ex: #FFFFFF)", labelStyle: TextStyle(color: Colors.white54)),
                onChanged: onBorderColorChanged,
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(radius: 14, backgroundColor: _previewBorderColor),
          ]),
        ],
        const SizedBox(height: 20),
        const Text("Tamanho", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 4),
        const Text("Por padrão o tamanho é controlado só pela posição/slot. Pra ajustar manualmente (tamanho real do arquivo, maior ou menor), ligue o ajuste abaixo.",
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          ChoiceChip(
            label: const Text("Padrão"),
            selected: sizeMode == "default",
            selectedColor: const Color(0xFF7A0BD4),
            labelStyle: TextStyle(color: sizeMode == "default" ? Colors.white : Colors.white70, fontSize: 12),
            onSelected: (_) => onSizeModeChanged("default"),
          ),
          ChoiceChip(
            label: const Text("Ajustar por porcentagem"),
            selected: sizeMode == "percent",
            selectedColor: const Color(0xFF7A0BD4),
            labelStyle: TextStyle(color: sizeMode == "percent" ? Colors.white : Colors.white70, fontSize: 12),
            onSelected: (_) => onSizeModeChanged("percent"),
          ),
        ]),
        if (sizeMode == "percent") ...[
          const SizedBox(height: 8),
          Row(children: [
            const Text("Tamanho", style: TextStyle(color: Colors.white54, fontSize: 12)),
            Expanded(
              child: Slider(
                value: sizePercent.clamp(10, 300),
                min: 10,
                max: 300,
                divisions: 58,
                activeColor: const Color(0xFF7A0BD4),
                onChanged: onSizePercentChanged,
              ),
            ),
            SizedBox(width: 48, child: Text(sizePercent.round().toString() + "%", style: const TextStyle(color: Colors.white54, fontSize: 12))),
          ]),
          const Text("100% = tamanho real do arquivo. Menos de 100% diminui, mais de 100% aumenta.", style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ],
    );
  }
}
