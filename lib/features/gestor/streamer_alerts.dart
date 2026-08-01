import "package:flutter/material.dart";
import "gestor_streamer_service.dart";

/// Limiar de "sem acompanhamento" usado tanto pelo alerta 🔴 quanto pelo KPI
/// do dashboard -- um numero so, pra nao ter dois valores diferentes pro
/// mesmo conceito espalhados pela tela.
const semAcompanhamentoDiasLimite = 7;

class StreamerAlert {
  final String emoji;
  final Color color;
  final String label;
  const StreamerAlert(this.emoji, this.color, this.label);
}

/// Media de crescimento da agencia (so entre quem tem mes anterior fechado
/// -- sem isso nao da pra calcular growth de verdade, ver
/// GestorStreamerRow.growth). Usada pelo alerta 🟢 "crescimento acima da
/// media". Sem ninguem com mes fechado ainda, retorna 0 (ninguem fica
/// marcado, mas nao quebra o calculo).
num averageGrowth(List<GestorStreamerRow> allRows) {
  final withMonth = allRows.where((r) => r.diamondsLastMonth != null).toList();
  if (withMonth.isEmpty) return 0;
  final sum = withMonth.fold<num>(0, (acc, r) => acc + r.growth);
  return sum / withMonth.length;
}

/// Alertas provisorios (limiares ajustaveis se o gestor achar errado na
/// pratica) -- um streamer pode ter mais de um ao mesmo tempo. Calculado
/// uma vez por tela (Lista/Cards/Calendario todas usam o mesmo resultado,
/// nao recalculam cada uma do seu jeito).
List<StreamerAlert> computeAlerts(
  GestorStreamerRow row,
  List<GestorStreamerRow> allRows,
) {
  final alerts = <StreamerAlert>[];

  if (row.daysSinceLastContact > semAcompanhamentoDiasLimite) {
    alerts.add(
      StreamerAlert(
        "🔴",
        Colors.redAccent,
        "Mais de " +
            semAcompanhamentoDiasLimite.toString() +
            " dias sem acompanhamento",
      ),
    );
  }

  if (row.nextAction == null) {
    alerts.add(
      const StreamerAlert("🔴", Colors.redAccent, "Sem próxima ação agendada"),
    );
  }

  if (row.diamondsLastMonth != null &&
      row.growth < 0 &&
      row.growth.abs() >= row.diamondsLastMonth! * 0.2) {
    alerts.add(
      const StreamerAlert(
        "🟡",
        Colors.amber,
        "Queda significativa nos diamantes",
      ),
    );
  }

  final avg = averageGrowth(allRows);
  if (row.diamondsLastMonth != null && avg > 0 && row.growth > avg) {
    alerts.add(
      const StreamerAlert(
        "🟢",
        Colors.greenAccent,
        "Crescimento acima da média",
      ),
    );
  }

  return alerts;
}

/// A cor mais grave dentre os alertas do streamer (vermelho > amarelo >
/// verde > cinza quando nao ha nenhum) -- usada pra faixa lateral do card e
/// destaque no calendario.
Color mostSevereAlertColor(List<StreamerAlert> alerts) {
  if (alerts.any((a) => a.color == Colors.redAccent)) return Colors.redAccent;
  if (alerts.any((a) => a.color == Colors.amber)) return Colors.amber;
  if (alerts.any((a) => a.color == Colors.greenAccent)) {
    return Colors.greenAccent;
  }
  return Colors.white12;
}
