import "max_state_media.dart";

/// regular | constante | inativo | caveira
enum MaxStateKey { regular, constante, inativo, caveira }

MaxStateKey maxStateKeyFromDb(String value) {
  return MaxStateKey.values.firstWhere((s) => s.name == value, orElse: () => MaxStateKey.regular);
}

String maxStateKeyToDb(MaxStateKey key) => key.name;

String maxStateKeyLabel(MaxStateKey key) {
  switch (key) {
    case MaxStateKey.regular:
      return "Max Regular";
    case MaxStateKey.constante:
      return "Max Constante";
    case MaxStateKey.inativo:
      return "Max Inativo";
    case MaxStateKey.caveira:
      return "Max Caveira";
  }
}

String maxStateKeyDescription(MaxStateKey key) {
  switch (key) {
    case MaxStateKey.regular:
      return "Estado padrão do Max.";
    case MaxStateKey.constante:
      return "Max quando o streamer mantém constância nas lives.";
    case MaxStateKey.inativo:
      return "Max quando o streamer passa um tempo sem transmitir.";
    case MaxStateKey.caveira:
      return "Max quando o streamer fica muito tempo sem transmitir.";
  }
}

/// Resumo usado nos cards da tela principal do Max.
class MaxStateSummary {
  final MaxStateKey stateKey;
  final MaxStateMedia? media;
  final int messageCount;

  const MaxStateSummary({
    required this.stateKey,
    this.media,
    required this.messageCount,
  });
}
