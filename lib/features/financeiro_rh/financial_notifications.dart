import "package:supabase_flutter/supabase_flutter.dart";

/// entry_types that represent a payment made directly to a collaborator
/// (as opposed to despesa/receita, which aren't tied to a person).
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
