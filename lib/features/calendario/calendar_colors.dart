import "package:flutter/material.dart";

String managerDisplayName(Map<String, dynamic> manager) {
  final fullName = manager["full_name"] as String?;
  if (fullName != null && fullName.trim().isNotEmpty) return fullName;
  return (manager["login_email"] as String?) ?? "Colaborador";
}

Color hexToColor(String hex) {
  final cleaned = hex.replaceFirst("#", "");
  return Color(int.parse("FF" + cleaned, radix: 16));
}

String colorToHex(Color color) {
  return "#" + color.toARGB32().toRadixString(16).substring(2).toUpperCase();
}

/// (key, nome, cor, escopo) — escopo "ambos" quando a categoria serve tanto
/// para eventos de Agencia quanto de Streamer.
const defaultEventCategories = [
  ("batalha_oficial", "Batalha Oficial", "#27AE60", "streamer"),
  ("evento_tiktok", "Evento TikTok", "#2E86DE", "ambos"),
  ("entrega_documentos", "Entrega de Documentos", "#7F8C8D", "agencia"),
  ("treinamento_gamer", "Treinamento Gamer", "#E67E22", "streamer"),
  ("treinamento_plataforma", "Treinamento Plataforma", "#E67E22", "streamer"),
  ("reuniao_interna_equipe", "Reunião Interna Equipe", "#2E86DE", "agencia"),
  ("reuniao_geral", "Reunião Geral", "#2E86DE", "ambos"),
  ("aniversario", "Aniversário", "#FF6FA5", "ambos"),
  ("campanha", "Campanha", "#8E44AD", "ambos"),
  ("feriado", "Feriado", "#7F8C8D", "ambos"),
  ("outro", "Outro", "#7F8C8D", "ambos"),
  // Categorias exclusivas do Calendario APP (Streamers) -- ver
  // appCalendarCategoryKeys logo abaixo, usado pra filtrar o dropdown dessa
  // tela e deixar so estas 5, sem misturar com as categorias acima.
  ("evento_individual", "Evento Individual", "#7A0BD4", "streamer"),
  ("acompanhamento_streamer", "Acompanhamento Streamer", "#2E86DE", "streamer"),
  ("evento_agencia_app", "Eventos da Agência", "#27AE60", "ambos"),
  ("campanha_tiktok_app", "Campanhas TikTok", "#F1C40F", "streamer"),
  ("treinamento_agencia_app", "Treinamentos Agência", "#E67E22", "ambos"),
];

/// Unicas categorias que aparecem no dropdown do Calendario APP
/// (Streamers) -- pedido do usuario pra nao misturar com as categorias
/// antigas/genericas (Treinamento Gamer, Batalha Oficial etc.), que
/// continuam existindo so pra eventos ja criados com elas.
const appCalendarCategoryKeys = {
  "evento_individual",
  "acompanhamento_streamer",
  "evento_agencia_app",
  "campanha_tiktok_app",
  "treinamento_agencia_app",
};

const scopeOptions = ["agencia", "streamer"];
const categoryScopeOptions = ["agencia", "streamer", "ambos"];

String scopeLabel(String scope) {
  switch (scope) {
    case "streamer":
      return "Streamer";
    case "ambos":
      return "Ambos";
    case "agencia":
    default:
      return "Agência";
  }
}

const visibilityOptions = ["todos", "equipe", "selecionados"];

String visibilityLabel(String visibility) {
  switch (visibility) {
    case "todos":
      return "Todos";
    case "selecionados":
      return "Selecionados";
    case "equipe":
    default:
      return "Equipe";
  }
}

const statusOptions = ["agendado", "confirmado", "em_andamento", "finalizado", "cancelado"];
const priorityOptions = ["baixa", "normal", "alta", "urgente"];

String statusLabel(String status) {
  switch (status) {
    case "agendado":
      return "Agendado";
    case "confirmado":
      return "Confirmado";
    case "em_andamento":
      return "Em andamento";
    case "finalizado":
      return "Finalizado";
    case "cancelado":
      return "Cancelado";
    default:
      return status;
  }
}

Color statusColor(String status) {
  switch (status) {
    case "agendado":
      return const Color(0xFF2E86DE);
    case "confirmado":
      return const Color(0xFF16A085);
    case "em_andamento":
      return const Color(0xFFF39C12);
    case "finalizado":
      return const Color(0xFF27AE60);
    case "cancelado":
      return const Color(0xFFE74C3C);
    default:
      return Colors.white54;
  }
}

String priorityLabel(String priority) {
  switch (priority) {
    case "baixa":
      return "Baixa";
    case "normal":
      return "Normal";
    case "alta":
      return "Alta";
    case "urgente":
      return "Urgente";
    default:
      return priority;
  }
}
