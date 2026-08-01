/// Faixas de diamante da tela "Streamers" -- 5a taxonomia de faixa que ja
/// existe no app (Metricas Streamers, Programas de Desenvolvimento, Missoes
/// do App e Ilha Top Duckers ja tem cada uma a sua propria, com numeros
/// diferentes). "Elite" aqui (150K-250K) e diferente do "Elite" de Metricas
/// Streamers/Missoes do App (250K+) -- mantido com o nome exato pedido, so
/// registrando a ambiguidade caso vire fonte de confusao no futuro.
class DiamondTier {
  final String key;
  final String label;
  final num min;
  final num? max;
  const DiamondTier(this.key, this.label, this.min, this.max);
}

const diamondTiers = [
  DiamondTier("recuperacao", "Recuperação (0-3K)", 0, 3000),
  DiamondTier("crescimento", "Crescimento (3K-40K)", 3000, 40000),
  DiamondTier("desenvolvimento", "Desenvolvimento (40K-80K)", 40000, 80000),
  DiamondTier("performance", "Performance (80K-150K)", 80000, 150000),
  DiamondTier("elite", "Elite (150K-250K)", 150000, 250000),
  DiamondTier("premium", "Premium (250K+)", 250000, null),
];

DiamondTier? tierFor(num diamonds) {
  for (final t in diamondTiers) {
    if (diamonds >= t.min && (t.max == null || diamonds < t.max!)) return t;
  }
  return null;
}

/// "Proximas graduacoes": streamer dentro dos ultimos 10% da faixa atual
/// (perto o suficiente do teto pra provavelmente subir de faixa no proximo
/// fechamento). Definicao provisoria -- ajustavel se o gestor achar o
/// limiar errado na pratica. Faixa Premium nunca "gradua" (sem teto).
bool isNearNextTier(num diamonds) {
  final tier = tierFor(diamonds);
  if (tier == null || tier.max == null) return false;
  final gap = tier.max! - diamonds;
  return gap > 0 && gap <= tier.max! * 0.10;
}
