import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

/// Equivalente de buildEventosLoadError/showEventosActionError
/// (event_history_service.dart), para o modulo Programas de Desenvolvimento.
Widget buildProgramasLoadError(Object error) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text("Erro ao carregar: " + error.toString(), style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
    ),
  );
}

void showProgramasActionError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: " + error.toString()), backgroundColor: Colors.redAccent));
}

/// Grava uma entrada na aba Historico do programa. Reaproveita
/// streamer_phase_history (mesma tabela do Onboarding 0-15 Dias) -- so
/// generaliza o padrao ja usado la, sem tabela nova.
Future<void> logProgramaHistory({
  required String streamerId,
  required String phaseKey,
  required String action,
  String? detail,
}) async {
  final client = Supabase.instance.client;
  await client.from("streamer_phase_history").insert({
    "streamer_id": streamerId,
    "phase_key": phaseKey,
    "action": action,
    "detail": detail,
    "performed_by": client.auth.currentUser?.id,
  });
}

/// Status visual de um programa (card na tela inicial / header do
/// detalhe): "nao configurado" enquanto nao tiver nenhuma etapa de fluxo
/// definida, senao segue o status de 3 estados (ativo/pausado/encerrado).
(String, Color) programStatus({required bool hasStages, required String status}) {
  if (!hasStages) return ("Nao configurado", Colors.white38);
  switch (status) {
    case "pausado":
      return ("Pausado", Colors.amber);
    case "encerrado":
      return ("Encerrado", Colors.white54);
    default:
      return ("Ativo", Colors.greenAccent);
  }
}

/// "Atualizado ha X" -- usado em qualquer tela que recarrega dados sob
/// demanda (Campanhas, Participantes), pra deixar claro pro gestor que esta
/// vendo informacao recente.
String relativeTimeLabel(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return "Atualizado agora mesmo";
  if (diff.inMinutes < 60) return "Atualizado ha " + diff.inMinutes.toString() + " minuto" + (diff.inMinutes == 1 ? "" : "s");
  if (diff.inHours < 24) return "Atualizado ha " + diff.inHours.toString() + " hora" + (diff.inHours == 1 ? "" : "s");
  return "Atualizado ha " + diff.inDays.toString() + " dia" + (diff.inDays == 1 ? "" : "s");
}

/// Paleta padronizada de status do streamer dentro de um programa: azul =
/// em andamento, verde = elegivel, amarelo = atencao/perto da meta, vermelho
/// = atrasado (arquivado/reprovado) ou critico (ainda ativo, mas longe da
/// meta), roxo = premiacao, cinza = concluido.
enum StreamerBadge { emAndamento, eligivel, atencao, atrasado, critico, premiacao, concluido }

(String, IconData, Color) streamerBadgeInfo(StreamerBadge badge) {
  switch (badge) {
    case StreamerBadge.emAndamento:
      return ("Em andamento", Icons.hourglass_bottom, Colors.blueAccent);
    case StreamerBadge.eligivel:
      return ("Elegivel", Icons.check_circle, Colors.greenAccent);
    case StreamerBadge.atencao:
      return ("Atencao", Icons.rate_review, Colors.amber);
    case StreamerBadge.atrasado:
      return ("Atrasado", Icons.error_outline, Colors.redAccent);
    case StreamerBadge.critico:
      return ("Critico", Icons.warning_amber, Colors.redAccent);
    case StreamerBadge.premiacao:
      return ("Premiacao", Icons.card_giftcard, Colors.purpleAccent);
    case StreamerBadge.concluido:
      return ("Concluido", Icons.flag, Colors.white54);
  }
}

/// Dialog de confirmacao padrao antes de acoes importantes (graduar,
/// encerrar parceria, marcar premiacao entregue, mover de programa, acoes
/// em massa) -- pra evitar clique acidental.
Future<bool> confirmAction(BuildContext context, {required String title, required String message, String confirmLabel = "Confirmar", Color confirmColor = const Color(0xFF7A0BD4)}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Text(message, style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
        ElevatedButton(onPressed: () => Navigator.of(context).pop(true), style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white), child: Text(confirmLabel)),
      ],
    ),
  );
  return result == true;
}

/// Editar nome/objetivo/descricao de um programa -- usado tanto pelo lapis
/// na aba Visao Geral quanto pelo menu Editar na listagem de programas
/// (programas_page.dart), pra nao duplicar o mesmo formulario em dois
/// lugares. Atualiza o Map `program` recebido in-place (mesma referencia
/// usada pela tela chamadora) e retorna se algo foi salvo.
Future<bool> showEditProgramDialog(BuildContext context, Map<String, dynamic> program) async {
  final nameController = TextEditingController(text: program["name"] as String? ?? "");
  final objectiveController = TextEditingController(text: program["objective"] as String? ?? "");
  final descriptionController = TextEditingController(text: program["description"] as String? ?? "");

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text("Editar programa", style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: (MediaQuery.of(context).size.width * 0.9).clamp(0.0, 420.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Nome", labelStyle: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: objectiveController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Objetivo", labelStyle: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Descricao", labelStyle: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
          child: const Text("Salvar"),
        ),
      ],
    ),
  );
  if (saved != true) return false;

  final updatePayload = {
    "name": nameController.text.trim().isEmpty ? program["name"] : nameController.text.trim(),
    "objective": objectiveController.text.trim().isEmpty ? null : objectiveController.text.trim(),
    "description": descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
    "updated_at": DateTime.now().toIso8601String(),
  };
  await Supabase.instance.client.from("development_programs").update(updatePayload).eq("id", program["id"]);
  program.addAll(updatePayload);
  return true;
}

/// Pede o valor (R$) da premiacao antes de confirmar um card como "Entregue"
/// no quadro Fluxo -- e esse valor que vira o gasto lancado em Financeiro RH
/// > Entradas e Saidas (ver syncParticipationAwardFinancialEntry). Retorna
/// null se cancelado.
Future<num?> promptPrizeValue(BuildContext context, {String? streamerName}) {
  final controller = TextEditingController();
  return showDialog<num?>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text("Valor da premiacao", style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (streamerName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(streamerName, style: const TextStyle(color: Colors.white70)),
            ),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Valor (R\$)",
              labelStyle: TextStyle(color: Colors.white54),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Vai gerar uma saida em Financeiro RH > Entradas e Saidas.",
            style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
        ElevatedButton(
          onPressed: () {
            final value = double.tryParse(controller.text.trim().replaceAll(",", "."));
            Navigator.of(context).pop(value ?? 0);
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
          child: const Text("Confirmar"),
        ),
      ],
    ),
  );
}
