import "package:supabase_flutter/supabase_flutter.dart";

/// Generates pending "salario"/"ajuda_custo" financial_entries for the current
/// month for every active collaborator (system or external, no login) with a
/// base_salary/cost_assistance set on their financial profile, if one doesn't
/// already exist for that month. Commission and goal bonuses are intentionally
/// not auto-generated here since they depend on performance data confirmed
/// manually in the Equipe tab.
Future<void> generateMonthlyPayrollEntries() async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser!.id;
  final manager = await client.from("managers").select("agency_id").eq("id", userId).single();
  final agencyId = manager["agency_id"];
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEndExclusive = DateTime(now.year, now.month + 1, 1);

  Future<void> ensureEntry({String? managerId, String? externalCollaboratorId, required String entryType, required num? amount, required int paymentDay}) async {
    if (amount == null || amount == 0) return;
    final dueDate = DateTime(now.year, now.month, paymentDay.clamp(1, 28));
    var query = client.from("financial_entries").select("id").eq("entry_type", entryType).gte("due_date", monthStart.toIso8601String().substring(0, 10)).lt("due_date", monthEndExclusive.toIso8601String().substring(0, 10));
    query = managerId != null ? query.eq("manager_id", managerId) : query.eq("external_collaborator_id", externalCollaboratorId!);
    final existing = await query.maybeSingle();
    if (existing != null) return;
    await client.from("financial_entries").insert({
      "agency_id": agencyId,
      "entry_type": entryType,
      "manager_id": managerId,
      "external_collaborator_id": externalCollaboratorId,
      "description": entryType == "salario" ? "Salario mensal" : "Ajuda de custo mensal",
      "amount": amount,
      "due_date": dueDate.toIso8601String().substring(0, 10),
      "status": "pendente",
      "created_by": userId,
    });
  }

  final profiles = await client
      .from("collaborator_financial_profile")
      .select("manager_id, base_salary, cost_assistance, payment_day, managers!collaborator_financial_profile_manager_id_fkey!inner(employment_status)")
      .eq("managers.employment_status", "ativo");
  for (final p in (profiles as List).cast<Map<String, dynamic>>()) {
    final paymentDay = (p["payment_day"] as int?) ?? 5;
    await ensureEntry(managerId: p["manager_id"] as String, entryType: "salario", amount: p["base_salary"] as num?, paymentDay: paymentDay);
    await ensureEntry(managerId: p["manager_id"] as String, entryType: "ajuda_custo", amount: p["cost_assistance"] as num?, paymentDay: paymentDay);
  }

  final externals = await client.from("external_collaborators").select("id, base_salary, cost_assistance, payment_day").eq("employment_status", "ativo");
  for (final e in (externals as List).cast<Map<String, dynamic>>()) {
    final paymentDay = (e["payment_day"] as int?) ?? 5;
    await ensureEntry(externalCollaboratorId: e["id"] as String, entryType: "salario", amount: e["base_salary"] as num?, paymentDay: paymentDay);
    await ensureEntry(externalCollaboratorId: e["id"] as String, entryType: "ajuda_custo", amount: e["cost_assistance"] as num?, paymentDay: paymentDay);
  }
}
