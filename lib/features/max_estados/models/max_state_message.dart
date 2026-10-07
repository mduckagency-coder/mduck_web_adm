import "max_state.dart";

/// geral | inicio_mes | meio_mes | final_mes | frequencia | retorno | inatividade
enum MaxMessageCategory { geral, inicioMes, meioMes, finalMes, frequencia, retorno, inatividade }

MaxMessageCategory maxMessageCategoryFromDb(String value) {
  switch (value) {
    case "inicio_mes":
      return MaxMessageCategory.inicioMes;
    case "meio_mes":
      return MaxMessageCategory.meioMes;
    case "final_mes":
      return MaxMessageCategory.finalMes;
    case "frequencia":
      return MaxMessageCategory.frequencia;
    case "retorno":
      return MaxMessageCategory.retorno;
    case "inatividade":
      return MaxMessageCategory.inatividade;
    default:
      return MaxMessageCategory.geral;
  }
}

String maxMessageCategoryToDb(MaxMessageCategory category) {
  switch (category) {
    case MaxMessageCategory.inicioMes:
      return "inicio_mes";
    case MaxMessageCategory.meioMes:
      return "meio_mes";
    case MaxMessageCategory.finalMes:
      return "final_mes";
    case MaxMessageCategory.frequencia:
      return "frequencia";
    case MaxMessageCategory.retorno:
      return "retorno";
    case MaxMessageCategory.inatividade:
      return "inatividade";
    case MaxMessageCategory.geral:
      return "geral";
  }
}

String maxMessageCategoryLabel(MaxMessageCategory category) {
  switch (category) {
    case MaxMessageCategory.geral:
      return "Geral";
    case MaxMessageCategory.inicioMes:
      return "Início do mês";
    case MaxMessageCategory.meioMes:
      return "Meio do mês";
    case MaxMessageCategory.finalMes:
      return "Final do mês";
    case MaxMessageCategory.frequencia:
      return "Frequência";
    case MaxMessageCategory.retorno:
      return "Retorno";
    case MaxMessageCategory.inatividade:
      return "Inatividade";
  }
}

class MaxStateMessage {
  final String id;
  final MaxStateKey stateKey;
  final MaxMessageCategory category;
  final String message;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;

  const MaxStateMessage({
    required this.id,
    required this.stateKey,
    required this.category,
    required this.message,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
  });

  factory MaxStateMessage.fromMap(Map<String, dynamic> map) {
    return MaxStateMessage(
      id: map["id"] as String,
      stateKey: maxStateKeyFromDb(map["state_key"] as String),
      category: maxMessageCategoryFromDb(map["category"] as String),
      message: map["message"] as String,
      isActive: map["is_active"] as bool? ?? true,
      sortOrder: (map["sort_order"] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map["created_at"] as String),
    );
  }
}
