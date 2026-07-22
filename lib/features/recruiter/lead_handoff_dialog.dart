import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

/// Leva o gestor ja definido para um lead (via lead_onboarding_gestores) ate
/// o cadastro oficial do streamer, assim que ele existir (leads.converted_streamer_id).
/// Chamada sempre que um gestor e definido/redefinido para um lead, em
/// qualquer ordem em relacao ao vinculo do streamer oficial.
Future<void> propagateManagerToProfile({required String leadId, required String managerId}) async {
  final client = Supabase.instance.client;
  final lead = await client.from("leads").select("converted_streamer_id").eq("id", leadId).maybeSingle();
  final streamerId = lead?["converted_streamer_id"] as String?;
  if (streamerId == null) return;

  await client.from("profiles").update({"assigned_manager_id": managerId}).eq("id", streamerId);
  await client.from("manager_assignment_history").insert({
    "manager_id": managerId,
    "streamer_id": streamerId,
  });
}

/// Modal obrigatorio "Transferencia para o Gestor", preenchido uma unica vez
/// quando o recrutador marca "Convite enviado" em Streamers Agenciados.
/// Retorna true quando confirmado, para a tela chamadora recarregar.
class LeadHandoffDialog extends StatefulWidget {
  final String leadId;
  final String leadName;
  final String? initialCategory;
  const LeadHandoffDialog({super.key, required this.leadId, required this.leadName, this.initialCategory});

  @override
  State<LeadHandoffDialog> createState() => _LeadHandoffDialogState();
}

class _LeadHandoffDialogState extends State<LeadHandoffDialog> {
  List<Map<String, dynamic>> _managers = [];
  final Set<String> _selectedManagerIds = {};
  late final _categoryController = TextEditingController(text: widget.initialCategory ?? "");
  final _nicheController = TextEditingController();
  final _availableDaysController = TextEditingController();
  final _availableHoursController = TextEditingController();
  final _experienceController = TextEditingController();
  final _objectivesController = TextEditingController();
  final _attentionPointsController = TextEditingController();
  final _summaryController = TextEditingController();
  final _notesController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final rows = await client.from("managers").select("id, login_email, photo_url").order("login_email");
    if (mounted) setState(() {
      _managers = (rows as List).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  bool get _canConfirm => _selectedManagerIds.isNotEmpty;

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final managerIds = _selectedManagerIds.toList();
    final managerEmails = managerIds.map((id) => _managers.firstWhere((m) => m["id"] == id)["login_email"] as String).toList();

    try {
      await client.from("lead_onboarding_gestores").delete().eq("lead_id", widget.leadId);
      for (final managerId in managerIds) {
        await client.from("lead_onboarding_gestores").insert({"lead_id": widget.leadId, "manager_id": managerId});
      }

      await client.from("lead_recruitment_handoff").insert({
        "lead_id": widget.leadId,
        "manager_id": managerIds.first,
        "niche": _nicheController.text.trim(),
        "category": _categoryController.text.trim(),
        "available_days": _availableDaysController.text.trim(),
        "available_hours": _availableHoursController.text.trim(),
        "previous_experience": _experienceController.text.trim(),
        "objectives": _objectivesController.text.trim(),
        "attention_points": _attentionPointsController.text.trim(),
        "recruitment_summary": _summaryController.text.trim(),
        "notes": _notesController.text.trim(),
        "performed_by": userId,
      });

      final checklist = await client.from("lead_onboarding_checklist").select().eq("lead_id", widget.leadId).maybeSingle();
      if (checklist == null) {
        await client.from("lead_onboarding_checklist").insert({
          "lead_id": widget.leadId,
          "convite_enviado": true,
          "convite_enviado_at": DateTime.now().toIso8601String(),
          "convite_enviado_by": userId,
        });
      } else {
        await client.from("lead_onboarding_checklist").update({
          "convite_enviado": true,
          "convite_enviado_at": DateTime.now().toIso8601String(),
          "convite_enviado_by": userId,
          "updated_at": DateTime.now().toIso8601String(),
        }).eq("lead_id", widget.leadId);
      }

      await client.from("lead_history").insert({
        "lead_id": widget.leadId,
        "action": "transferencia_gestor",
        "detail": "Transferido para " + managerEmails.join(", ") + (_summaryController.text.trim().isNotEmpty ? ". Resumo: " + _summaryController.text.trim() : ""),
        "performed_by": userId,
      });

      for (final managerId in managerIds) {
        await client.from("manager_notifications").insert({
          "manager_id": managerId,
          "subject": "Novo streamer a caminho",
          "message": widget.leadName + " esta a caminho da agencia. Convite enviado, voce foi definido como gestor responsavel.",
        });
        await propagateManagerToProfile(leadId: widget.leadId, managerId: managerId);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao transferir: " + e.toString())));
    }
  }

  Widget _field(TextEditingController controller, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54, fontSize: 12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Transferencia para o Gestor", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.leadName, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text("Preenchido uma unica vez, no envio do convite.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Gestor(es) responsavel(is)", style: TextStyle(color: Colors.white54, fontSize: 12)),
                            const Text("Pode selecionar mais de um colaborador.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
                            const SizedBox(height: 4),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 180),
                              decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                              child: _managers.isEmpty
                                  ? const Padding(padding: EdgeInsets.all(12), child: Text("Nenhum colaborador cadastrado.", style: TextStyle(color: Colors.white54, fontSize: 12)))
                                  : ListView(
                                      shrinkWrap: true,
                                      children: _managers.map((m) {
                                        final id = m["id"] as String;
                                        return CheckboxListTile(
                                          value: _selectedManagerIds.contains(id),
                                          onChanged: (v) => setState(() {
                                            if (v == true) { _selectedManagerIds.add(id); } else { _selectedManagerIds.remove(id); }
                                          }),
                                          title: Text(m["login_email"] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                          activeColor: const Color(0xFF7A0BD4),
                                          dense: true,
                                          controlAffinity: ListTileControlAffinity.leading,
                                        );
                                      }).toList(),
                                    ),
                            ),
                            const SizedBox(height: 10),
                            _field(_nicheController, "Nicho do streamer"),
                            _field(_categoryController, "Categoria"),
                            _field(_availableDaysController, "Dias disponiveis"),
                            _field(_availableHoursController, "Horarios disponiveis"),
                            _field(_experienceController, "Experiencia anterior", maxLines: 2),
                            _field(_objectivesController, "Objetivos do streamer", maxLines: 2),
                            _field(_attentionPointsController, "Pontos de atencao", maxLines: 2),
                            _field(_summaryController, "Resumo do recrutamento", maxLines: 3),
                            _field(_notesController, "Observacoes importantes para o gestor", maxLines: 2),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: (_canConfirm && !_saving) ? _confirm : null,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                          child: Text(_saving ? "Transferindo..." : "Confirmar transferencia"),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
