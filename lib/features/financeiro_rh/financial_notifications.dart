import "package:supabase_flutter/supabase_flutter.dart";

/// entry_types that represent a payment made directly to a collaborator
/// (as opposed to despesa/receita, which aren't tied to a person). Kept for
/// labeling purposes; the notification trigger itself only cares whether a
/// manager_id is set, since a "despesa" linked to a person (ex: categoria
/// Equipe / Colaborador) is just as much a personal payment as a "salario".
const payrollEntryTypes = {"salario", "comissao", "ajuda_custo", "bonificacao", "premiacao"};

/// Only PJ/autonomo collaborators issue a nota fiscal in Brazil; CLT staff
/// don't, so they shouldn't be asked to confirm sending one.
bool isPjContract(String? contractType) {
  if (contractType == null) return false;
  final t = contractType.toLowerCase();
  return t.contains("pj") || t.contains("autonomo") || t.contains("autônomo");
}

Future<void> notifyPaymentSent({required String managerId, required String description, required num amount}) async {
  final client = Supabase.instance.client;
  await client.from("manager_notifications").insert({
    "manager_id": managerId,
    "subject": "Pagamento realizado",
    "message": description + " - R\$ " + amount.toStringAsFixed(2) + ". Confirme o envio da nota fiscal para mduckagency@gmail.com na aba Financeiro do seu perfil.",
  });
}

/// Call right after marking a financial_entries row "pago". Notifies the
/// linked manager (and flags notified_at, which powers the "confirmar nota
/// fiscal" list in their profile) only when the entry is tied to a system
/// collaborator who is PJ/autonomo. No-op otherwise (external collaborators
/// have no login/profile to notify; CLT staff don't send notas fiscais).
Future<void> maybeNotifyPayment({
  required String entryId,
  required String? managerId,
  required String? contractType,
  required String description,
  required num amount,
}) async {
  if (managerId == null || !isPjContract(contractType)) return;
  final client = Supabase.instance.client;
  await notifyPaymentSent(managerId: managerId, description: description, amount: amount);
  await client.from("financial_entries").update({"notified_at": DateTime.now().toIso8601String()}).eq("id", entryId);
}
