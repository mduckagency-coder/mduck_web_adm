import "package:supabase_flutter/supabase_flutter.dart";

/// Notifica o responsavel assim que uma demanda e enviada para ele (mesmo
/// padrao de manager_notifications usado no restante do app -- ver
/// lib/features/calendario/calendar_notifications.dart).
Future<void> notifyNewDemanda({
  required String responsavelId,
  required String demandaTitulo,
  required String criadoPorLabel,
}) async {
  final client = Supabase.instance.client;
  await client.from("manager_notifications").insert({
    "manager_id": responsavelId,
    "subject": "Nova demanda recebida",
    "message": "$criadoPorLabel enviou a demanda \"$demandaTitulo\" para voce.",
  });
}
