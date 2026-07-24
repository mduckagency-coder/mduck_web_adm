import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

/// Mostra o erro de carregamento de forma visivel (em vez de deixar o
/// FutureBuilder girando pra sempre quando a query falha). Usado nas 8
/// abas do modulo Eventos.
Widget buildEventosLoadError(Object error) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text("Erro ao carregar: " + error.toString(), style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
    ),
  );
}

/// Mostra o erro de uma acao (salvar/excluir/etc) num SnackBar, pra nunca
/// deixar um botao preso em "Salvando..." sem feedback nenhum quando algo
/// falha (RLS, coluna invalida, etc).
void showEventosActionError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: " + error.toString()), backgroundColor: Colors.redAccent));
}

/// Grava uma entrada automatica na aba Historico do evento. Usada por todas
/// as abas (Cronograma, Tarefas, Participantes, Premiacoes, Financeiro,
/// Arquivos) sempre que uma acao relevante acontece - o usuario nunca
/// precisa escrever isso manualmente.
Future<void> logEventHistory({
  required String eventId,
  required String action,
  String? detail,
}) async {
  final client = Supabase.instance.client;
  await client.from("event_history").insert({
    "event_id": eventId,
    "action": action,
    "detail": detail,
    "performed_by": client.auth.currentUser!.id,
  });
}

const eventStatusOptions = ["planejado", "em_andamento", "finalizado", "cancelado"];

const eventTaskStatusOptions = ["pendente", "em_andamento", "concluido"];

Color eventTaskStatusColor(String status) {
  switch (status) {
    case "em_andamento":
      return Colors.blueAccent;
    case "concluido":
      return Colors.greenAccent;
    default:
      return Colors.amber;
  }
}

String eventTaskStatusLabel(String status) {
  switch (status) {
    case "em_andamento":
      return "Em andamento";
    case "concluido":
      return "Concluido";
    default:
      return "Pendente";
  }
}

String eventStatusLabel(String status) {
  switch (status) {
    case "em_andamento":
      return "Em andamento";
    case "finalizado":
      return "Finalizado";
    case "cancelado":
      return "Cancelado";
    default:
      return "Planejado";
  }
}
