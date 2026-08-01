import "demanda_model.dart";

/// Atividade de um cronograma de planejamento, com os dados da demanda de
/// origem, usada para plotar as atividades (com sua propria prioridade) na
/// visao Mes/Semana/Dia da pagina de Demandas -- ao lado das demandas por
/// prazo, mas identificaveis pelo icone/estilo proprio.
class AtividadeAgendaItem {
  final String id;
  final String descricao;
  final DateTime data;
  final String? hora;
  final bool concluida;
  final DemandaPrioridade prioridade;
  final String demandaId;
  final String demandaTitulo;

  const AtividadeAgendaItem({
    required this.id,
    required this.descricao,
    required this.data,
    required this.hora,
    required this.concluida,
    required this.prioridade,
    required this.demandaId,
    required this.demandaTitulo,
  });

  factory AtividadeAgendaItem.fromRow(Map<String, dynamic> row) {
    final planejamento = row["planejamento"] as Map<String, dynamic>;
    final demanda = planejamento["demanda"] as Map<String, dynamic>;
    return AtividadeAgendaItem(
      id: row["id"] as String,
      descricao: row["descricao"] as String,
      data: DateTime.parse(row["data"] as String),
      hora: row["hora"] as String?,
      concluida: row["concluida"] as bool,
      prioridade: DemandaPrioridadeX.fromValue(row["prioridade"] as String),
      demandaId: demanda["id"] as String,
      demandaTitulo: demanda["titulo"] as String,
    );
  }
}
