import "package:flutter/material.dart";

enum DemandaPrioridade { alta, media, baixa }

enum DemandaStatus { naoIniciada, emAndamento, concluida }

extension DemandaPrioridadeX on DemandaPrioridade {
  String get label {
    switch (this) {
      case DemandaPrioridade.alta:
        return "Alta";
      case DemandaPrioridade.media:
        return "Media";
      case DemandaPrioridade.baixa:
        return "Baixa";
    }
  }

  String get value {
    switch (this) {
      case DemandaPrioridade.alta:
        return "alta";
      case DemandaPrioridade.media:
        return "media";
      case DemandaPrioridade.baixa:
        return "baixa";
    }
  }

  static DemandaPrioridade fromValue(String value) =>
      DemandaPrioridade.values.firstWhere(
        (p) => p.value == value,
        orElse: () => DemandaPrioridade.media,
      );
}

extension DemandaStatusX on DemandaStatus {
  String get label {
    switch (this) {
      case DemandaStatus.naoIniciada:
        return "Nao iniciada";
      case DemandaStatus.emAndamento:
        return "Em andamento";
      case DemandaStatus.concluida:
        return "Concluida";
    }
  }

  String get value {
    switch (this) {
      case DemandaStatus.naoIniciada:
        return "nao_iniciada";
      case DemandaStatus.emAndamento:
        return "em_andamento";
      case DemandaStatus.concluida:
        return "concluida";
    }
  }

  static DemandaStatus fromValue(String value) =>
      DemandaStatus.values.firstWhere(
        (s) => s.value == value,
        orElse: () => DemandaStatus.naoIniciada,
      );
}

/// Icones disponiveis para identificar visualmente o tipo da demanda.
/// A chave e o que fica salvo no banco (coluna `icone`); o valor e o
/// IconData usado na interface.
const Map<String, IconData> demandaIconOptions = {
  "flag": Icons.flag,
  "campaign": Icons.campaign,
  "warning": Icons.warning_amber,
  "star": Icons.star,
  "bar_chart": Icons.bar_chart,
  "attach_money": Icons.attach_money,
  "groups": Icons.groups,
  "event": Icons.event,
  "build": Icons.build,
  "school": Icons.school,
  "trending_up": Icons.trending_up,
  "assignment": Icons.assignment,
};

IconData demandaIconFor(String key) => demandaIconOptions[key] ?? Icons.flag;

class Demanda {
  final String id;
  final String titulo;
  final String descricao;
  final DemandaPrioridade prioridade;
  final String categoria;
  final String icone;
  final DateTime? prazo;
  final DemandaStatus status;
  final String criadoPorId;
  final String criadoPorLabel;
  final String responsavelId;
  final String responsavelLabel;
  final DateTime criadoEm;
  final DateTime atualizadoEm;

  const Demanda({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.prioridade,
    required this.categoria,
    required this.icone,
    required this.prazo,
    required this.status,
    required this.criadoPorId,
    required this.criadoPorLabel,
    required this.responsavelId,
    required this.responsavelLabel,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  factory Demanda.fromRow(Map<String, dynamic> row) {
    String managerLabel(dynamic managerRow) {
      if (managerRow is! Map) return "-";
      final fullName = managerRow["full_name"] as String?;
      if (fullName != null && fullName.isNotEmpty) return fullName;
      return (managerRow["login_email"] as String?) ?? "-";
    }

    return Demanda(
      id: row["id"] as String,
      titulo: row["titulo"] as String,
      descricao: (row["descricao"] as String?) ?? "",
      prioridade: DemandaPrioridadeX.fromValue(row["prioridade"] as String),
      categoria: (row["categoria"] as String?) ?? "Geral",
      icone: (row["icone"] as String?) ?? "flag",
      prazo: row["prazo"] != null
          ? DateTime.parse(row["prazo"] as String)
          : null,
      status: DemandaStatusX.fromValue(row["status"] as String),
      criadoPorId: row["criado_por"] as String,
      criadoPorLabel: managerLabel(row["criado_por_manager"]),
      responsavelId: row["responsavel_id"] as String,
      responsavelLabel: managerLabel(row["responsavel_manager"]),
      criadoEm: DateTime.parse(row["created_at"] as String),
      atualizadoEm: DateTime.parse(row["updated_at"] as String),
    );
  }

  Demanda copyWith({DemandaStatus? status}) => Demanda(
    id: id,
    titulo: titulo,
    descricao: descricao,
    prioridade: prioridade,
    categoria: categoria,
    icone: icone,
    prazo: prazo,
    status: status ?? this.status,
    criadoPorId: criadoPorId,
    criadoPorLabel: criadoPorLabel,
    responsavelId: responsavelId,
    responsavelLabel: responsavelLabel,
    criadoEm: criadoEm,
    atualizadoEm: DateTime.now(),
  );
}

/// Cor do card: sem prazo definido sempre aparece em cinza, independente da
/// prioridade. Com prazo, a cor segue a prioridade (alta/media/baixa).
Color demandaCor(Demanda d) {
  if (d.prazo == null) return Colors.grey;
  switch (d.prioridade) {
    case DemandaPrioridade.alta:
      return const Color(0xFFE5484D);
    case DemandaPrioridade.media:
      return const Color(0xFFF5A623);
    case DemandaPrioridade.baixa:
      return const Color(0xFF3DD68C);
  }
}

String demandaCorLabel(Demanda d) =>
    d.prazo == null ? "Sem prazo" : d.prioridade.label;
