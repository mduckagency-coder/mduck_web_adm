import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class RecruiterOnboardingSection extends StatefulWidget {
  const RecruiterOnboardingSection({super.key});

  @override
  State<RecruiterOnboardingSection> createState() => _RecruiterOnboardingSectionState();
}

class _RecruiterOnboardingSectionState extends State<RecruiterOnboardingSection> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final leads = await client.from("leads").select("id, name, tiktok_username, converted_at").eq("recruiter_id", userId).eq("status", "agenciado").order("converted_at", ascending: false);
    final leadsList = (leads as List).cast<Map<String, dynamic>>();

    for (final l in leadsList) {
      var checklist = await client.from("lead_onboarding_checklist").select().eq("lead_id", l["id"]).maybeSingle();
      checklist ??= await client.from("lead_onboarding_checklist").insert({"lead_id": l["id"]}).select().single();
      l["checklist"] = checklist;

      final gestores = await client.from("lead_onboarding_gestores").select("manager_id, managers(login_email)").eq("lead_id", l["id"]);
      l["gestores"] = (gestores as List).cast<Map<String, dynamic>>();
    }
    return leadsList;
  }

  Future<void> _toggleField(String leadId, String field, bool current) async {
    final client = Supabase.instance.client;
    await client.from("lead_onboarding_checklist").update({field: !current, "updated_at": DateTime.now().toIso8601String()}).eq("lead_id", leadId);
    setState(() => _future = _load());
  }

  void _openGestorSelector(Map<String, dynamic> lead) {
    showDialog(context: context, builder: (context) => _GestorSelectorDialog(leadId: lead["id"] as String, leadName: lead["name"] as String)).then((_) {
      setState(() => _future = _load());
    });
  }

  Widget _stepChip(String label, bool checked, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: checked ? Colors.greenAccent.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: checked ? Colors.greenAccent : Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(checked ? Icons.check_circle : Icons.radio_button_unchecked, color: checked ? Colors.greenAccent : Colors.white38, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: checked ? Colors.greenAccent : Colors.white70, fontSize: 11, fontWeight: checked ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()));
        final list = snapshot.data!;
        if (list.isEmpty) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF7A0BD4).withOpacity(0.3))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.rocket_launch, color: Color(0xFF7A0BD4), size: 18),
                const SizedBox(width: 8),
                Text("Onboarding de Novos Agenciados (" + list.length.toString() + ")", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
              const SizedBox(height: 4),
              const Text("Assim que um lead vira Agenciado no Kanban, ele aparece aqui automaticamente para voce acompanhar o processo de entrada.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              ...list.map((l) {
                final checklist = l["checklist"] as Map<String, dynamic>;
                final gestores = (l["gestores"] as List).cast<Map<String, dynamic>>();
                final fields = ["convite_enviado", "convite_aceito", "entrou_agencia", "grupo_individual_criado", "material_boas_vindas", "apresentacao_gestores", "concluido"];
                final doneCount = fields.where((f) => checklist[f] == true).length + (gestores.isNotEmpty ? 1 : 0);
                final totalSteps = fields.length + 1;
                final fraction = doneCount / totalSteps;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(l["name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        Text(doneCount.toString() + "/" + totalSteps.toString(), style: const TextStyle(color: Color(0xFF7A0BD4), fontSize: 12, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: fraction, minHeight: 5, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Color(0xFF7A0BD4)))),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _stepChip("Convite Enviado", checklist["convite_enviado"] == true, () => _toggleField(l["id"] as String, "convite_enviado", checklist["convite_enviado"] == true)),
                        _stepChip("Convite Aceito", checklist["convite_aceito"] == true, () => _toggleField(l["id"] as String, "convite_aceito", checklist["convite_aceito"] == true)),
                        _stepChip("Entrou p/ Agencia", checklist["entrou_agencia"] == true, () => _toggleField(l["id"] as String, "entrou_agencia", checklist["entrou_agencia"] == true)),
                        InkWell(
                          onTap: () => _openGestorSelector(l),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: gestores.isNotEmpty ? Colors.amber.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: gestores.isNotEmpty ? Colors.amber : Colors.white24),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.supervisor_account, color: gestores.isNotEmpty ? Colors.amber : Colors.white38, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                gestores.isEmpty ? "Selecionar Gestor" : gestores.length.toString() + " gestor(es)",
                                style: TextStyle(color: gestores.isNotEmpty ? Colors.amber : Colors.white70, fontSize: 11, fontWeight: gestores.isNotEmpty ? FontWeight.bold : FontWeight.normal),
                              ),
                            ]),
                          ),
                        ),
                        _stepChip("Grupo Individual", checklist["grupo_individual_criado"] == true, () => _toggleField(l["id"] as String, "grupo_individual_criado", checklist["grupo_individual_criado"] == true)),
                        _stepChip("Material Boas-vindas", checklist["material_boas_vindas"] == true, () => _toggleField(l["id"] as String, "material_boas_vindas", checklist["material_boas_vindas"] == true)),
                        _stepChip("Apresentacao Gestores", checklist["apresentacao_gestores"] == true, () => _toggleField(l["id"] as String, "apresentacao_gestores", checklist["apresentacao_gestores"] == true)),
                        _stepChip("Concluido", checklist["concluido"] == true, () => _toggleField(l["id"] as String, "concluido", checklist["concluido"] == true)),
                      ]),
                      if (gestores.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text("Acompanhando: " + gestores.map((g) => (g["managers"] as Map)["login_email"] as String? ?? "-").join(", "), style: const TextStyle(color: Colors.amber, fontSize: 11)),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _GestorSelectorDialog extends StatefulWidget {
  final String leadId;
  final String leadName;
  const _GestorSelectorDialog({required this.leadId, required this.leadName});

  @override
  State<_GestorSelectorDialog> createState() => _GestorSelectorDialogState();
}

class _GestorSelectorDialogState extends State<_GestorSelectorDialog> {
  List<Map<String, dynamic>> _gestores = [];
  final Set<String> _selected = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final rows = await client.from("managers").select("id, login_email").eq("role", "gestor");
    final current = await client.from("lead_onboarding_gestores").select("manager_id").eq("lead_id", widget.leadId);
    setState(() {
      _gestores = (rows as List).cast<Map<String, dynamic>>();
      _selected.addAll((current as List).map((c) => c["manager_id"] as String));
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final existing = await client.from("lead_onboarding_gestores").select("manager_id").eq("lead_id", widget.leadId);
    final existingIds = (existing as List).map((e) => e["manager_id"] as String).toSet();

    final toAdd = _selected.difference(existingIds);
    final toRemove = existingIds.difference(_selected);

    for (final id in toAdd) {
      await client.from("lead_onboarding_gestores").insert({"lead_id": widget.leadId, "manager_id": id});
      await client.from("manager_notifications").insert({
        "manager_id": id,
        "message": "Voce foi selecionado para acompanhar o onboarding de: " + widget.leadName,
      });
    }
    for (final id in toRemove) {
      await client.from("lead_onboarding_gestores").delete().eq("lead_id", widget.leadId).eq("manager_id", id);
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Gestor(es) para " + widget.leadName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text("Pode selecionar mais de um. Cada um recebe uma notificacao.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              if (_gestores.isEmpty)
                const Text("Nenhum gestor cadastrado ainda.", style: TextStyle(color: Colors.white54, fontSize: 12))
              else
                ..._gestores.map((g) {
                  final id = g["id"] as String;
                  return CheckboxListTile(
                    value: _selected.contains(id),
                    onChanged: (v) => setState(() {
                      if (v == true) { _selected.add(id); } else { _selected.remove(id); }
                    }),
                    title: Text(g["login_email"] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    activeColor: Colors.amber,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  );
                }),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: Text(_saving ? "Salvando..." : "Salvar"),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
