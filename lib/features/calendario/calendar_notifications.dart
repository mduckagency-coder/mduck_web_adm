import "package:supabase_flutter/supabase_flutter.dart";

/// Regra provisoria de destinatarios (dono + coordenadores), ate existir um
/// grupo de acesso "Home Central" de verdade. Isolada aqui de proposito para
/// ser facil de trocar depois sem mexer nas telas do calendario.
Future<void> notifyNewEventToAdmins({required String eventTitle, required String createdByLabel}) async {
  final client = Supabase.instance.client;
  final recipients = await client.from("managers").select("id").or("financial_role.eq.dono,role.eq.coordenador");
  for (final r in (recipients as List)) {
    await client.from("manager_notifications").insert({
      "manager_id": r["id"],
      "subject": "Novo evento no calendário",
      "message": createdByLabel + " criou o evento \"" + eventTitle + "\".",
    });
  }
}
