/// Parses a currency value typed by the user, accepting both the Brazilian
/// format ("1.500,00") and the plain format ("1500.00" / "1500,00").
/// `double.tryParse` alone fails on comma decimals, which silently saved 0
/// for any amount typed the natural Brazilian way.
double? parseAmountOrNull(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  if (text.contains(",")) {
    text = text.replaceAll(".", "").replaceAll(",", ".");
  }
  return double.tryParse(text);
}

double parseAmount(String raw) => parseAmountOrNull(raw) ?? 0;
