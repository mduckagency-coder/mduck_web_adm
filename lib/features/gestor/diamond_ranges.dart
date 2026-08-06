/// Faixas de diamante da tela "Gestão de Streamers" -- 6a taxonomia de
/// faixa que ja existe no app (Metricas Streamers, Programas de
/// Desenvolvimento, Missoes do App, Ilha Top Duckers e a tela Streamers ja
/// tem cada uma a sua propria, com numeros diferentes). Aqui cada faixa
/// carrega tambem a frequencia de acompanhamento esperada (em dias) --
/// numeros pedidos explicitamente pelo usuario, provisorios/ajustaveis na
/// pratica assim como os limiares de streamer_alerts.dart.
class DiamondRange {
  final String key;
  final String label;
  final num min;
  final num? max;
  final int followUpDays;
  const DiamondRange(this.key, this.label, this.min, this.max, this.followUpDays);
}

const diamondRanges = [
  DiamondRange("r0_3k", "0 - 3K", 0, 3000, 5),
  DiamondRange("r3_10k", "3K - 10K", 3000, 10000, 7),
  DiamondRange("r10_20k", "10K - 20K", 10000, 20000, 7),
  DiamondRange("r20_40k", "20K - 40K", 20000, 40000, 5),
  DiamondRange("r40_80k", "40K - 80K", 40000, 80000, 5),
  DiamondRange("r80_150k", "80K - 150K", 80000, 150000, 7),
  DiamondRange("r150_250k", "150K - 250K", 150000, 250000, 10),
  DiamondRange("r250k_mais", "250K+", 250000, null, 15),
];

DiamondRange rangeFor(num diamonds) {
  for (final r in diamondRanges) {
    if (diamonds >= r.min && (r.max == null || diamonds < r.max!)) return r;
  }
  return diamondRanges.last;
}

int followUpDaysFor(num diamonds) => rangeFor(diamonds).followUpDays;

/// Marcos importantes citados explicitamente no pedido (40K/80K/150K) --
/// diferente da lista completa de tetos de diamondRanges, so os 3 que o
/// usuario destacou como "marco importante".
const importantMilestones = [40000, 80000, 150000];

/// "Perto de um marco importante": dentro dos ultimos 10% antes de um dos
/// marcos acima -- mesma regra provisoria de isNearNextTier()
/// (diamond_tiers.dart), so aplicada a uma lista fixa de marcos em vez do
/// teto da faixa atual.
bool isNearMilestone(num diamonds) {
  for (final m in importantMilestones) {
    final gap = m - diamonds;
    if (gap > 0 && gap <= m * 0.10) return true;
  }
  return false;
}
