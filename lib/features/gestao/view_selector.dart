import "package:flutter/material.dart";

enum DemandasViewMode { dia, semana, mes, lista }

extension DemandasViewModeX on DemandasViewMode {
  String get label {
    switch (this) {
      case DemandasViewMode.dia:
        return "Dia";
      case DemandasViewMode.semana:
        return "Semana";
      case DemandasViewMode.mes:
        return "Mes";
      case DemandasViewMode.lista:
        return "Lista";
    }
  }

  IconData get icon {
    switch (this) {
      case DemandasViewMode.dia:
      case DemandasViewMode.semana:
      case DemandasViewMode.mes:
        return Icons.calendar_month;
      case DemandasViewMode.lista:
        return Icons.view_list;
    }
  }
}

/// Alterna somente a forma de visualizar as demandas (Dia/Semana/Mes/Lista).
/// Nao navega para outra pagina - a mesma tela apenas troca de layout.
class ViewSelector extends StatelessWidget {
  final DemandasViewMode selected;
  final ValueChanged<DemandasViewMode> onChanged;

  const ViewSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: DemandasViewMode.values.map((mode) {
        final isSelected = mode == selected;
        return ChoiceChip(
          avatar: Icon(
            mode.icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.white54,
          ),
          label: Text(mode.label),
          selected: isSelected,
          selectedColor: const Color(0xFF7A0BD4),
          backgroundColor: Colors.white.withOpacity(0.05),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          side: BorderSide(
            color: isSelected ? const Color(0xFF7A0BD4) : Colors.white12,
          ),
          onSelected: (_) => onChanged(mode),
        );
      }).toList(),
    );
  }
}
