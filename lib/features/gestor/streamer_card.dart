import "package:flutter/material.dart";
import "../metricas/streamer_metrics_share_card.dart";
import "../recruiter/lead_category_icons.dart";
import "../whatsapp/whatsapp_dialog.dart";
import "gestor_streamer_service.dart";
import "streamer_managers_service.dart";
import "streamer_stage_service.dart";

/// Card visual da tela "Gestao de Streamers" -- mesma estrutura do card do
/// Onboard 15 Dias (_OnboardingCard, onboarding_phase_kanban_page.dart:
/// fundo escuro, cantos arredondados, faixa lateral pela saude do prazo,
/// avatar com selo de categoria + estrela, mini controles de gestores,
/// chip de acao), mas essa classe e privada naquele arquivo -- impossivel
/// importar sem mexer no board de Onboarding. Este widget replica o estilo
/// com dados proprios desta fase (diamantes/crescimento/potencial/etc) e o
/// chip "Registrar Ação" no lugar do "Enviar Material".
class StreamerCard extends StatelessWidget {
  final GestorStreamerRow row;
  final VoidCallback onTap;
  final VoidCallback onRegisterAction;
  final StreamerStageInfo? stageInfo;
  final List<StreamerManager> managers;
  final VoidCallback? onManageManagers;

  const StreamerCard({
    super.key,
    required this.row,
    required this.onTap,
    required this.onRegisterAction,
    this.stageInfo,
    this.managers = const [],
    this.onManageManagers,
  });

  String get _categoriaLabel => row.categoryName ?? "Sem categoria";

  void _openWhatsAppFree(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => WhatsAppDialog(
        targets: [
          WhatsAppTarget(id: row.id, displayName: row.displayName, phone: row.phone),
        ],
        targetLabel: row.displayName,
      ),
    );
  }

  void _openWhatsAppWithMetrics(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => WhatsAppDialog(
        targets: [
          WhatsAppTarget(id: row.id, displayName: row.displayName, phone: row.phone),
        ],
        targetLabel: row.displayName,
        initialMessage: buildStreamerMetricsMessage(
          nick: row.nick,
          categoria: _categoriaLabel,
          diamonds: row.diamonds.toInt(),
          daysLive: row.daysLive,
          hoursLive: row.hoursLive,
        ),
      ),
    );
  }

  /// Opcao de mensagem -- oferece as metricas do mes prontas (copiar ou
  /// mandar por WhatsApp ja preenchido, StreamerMetricsShareCard reusado de
  /// Metricas Streamers) ou uma mensagem livre.
  void _openWhatsApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                StreamerMetricsShareCard(
                  nick: row.nick,
                  categoria: _categoriaLabel,
                  diamonds: row.diamonds.toInt(),
                  daysLive: row.daysLive,
                  hoursLive: row.hoursLive,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _openWhatsAppWithMetrics(context);
                    },
                    icon: const Icon(Icons.chat, size: 16),
                    label: const Text("Enviar por WhatsApp com essas métricas"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _openWhatsAppFree(context);
                    },
                    child: const Text("Mensagem livre"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Nick clicavel -- mesmo espirito do "O que voce quer ver?" do Onboard
  /// 15 Dias (_StreamerQuickInfoDialog, onboarding_phase_kanban_page.dart):
  /// um menu curto em vez de abrir a ficha completa direto, pra nao
  /// competir com o chip "Registrar Ação" (que so deve abrir clicando nele
  /// mesmo).
  void _openQuickInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "O que você quer ver?",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onTap();
                    },
                    icon: const Icon(
                      Icons.badge_outlined,
                      size: 18,
                      color: Color(0xFF7A0BD4),
                    ),
                    label: const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Ficha completa",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      side: const BorderSide(color: Color(0xFF7A0BD4)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          backgroundColor: const Color(0xFF1A1A1A),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 380),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row.displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  StreamerMetricsShareCard(
                                    nick: row.nick,
                                    categoria: _categoriaLabel,
                                    diamonds: row.diamonds.toInt(),
                                    daysLive: row.daysLive,
                                    hoursLive: row.hoursLive,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.bar_chart,
                      size: 18,
                      color: Color(0xFF7A0BD4),
                    ),
                    label: const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Métricas do mês",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      side: const BorderSide(color: Color(0xFF7A0BD4)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Saude do prazo da acao atual -- mesma ideia de _deadlineHealth do
  /// Onboard, so que baseada em due_at (streamer_stage) em vez de dias
  /// desde a entrada na agencia.
  (Color, String) _dueHealth() {
    final dueAt = stageInfo?.dueAt;
    if (dueAt == null) return (Colors.white12, "Sem prazo definido");
    final daysLeft = dueAt.difference(DateTime.now()).inDays;
    if (daysLeft < 0) {
      return (
        Colors.redAccent,
        "Prazo vencido há " + (-daysLeft).toString() + " dia(s)",
      );
    }
    if (daysLeft <= 1) {
      return (Colors.amber, "Vence em breve (revisar em até 1 dia)");
    }
    return (Colors.greenAccent, "Dentro do prazo (" + daysLeft.toString() + " dia(s))");
  }

  // Mesmo padrao visual/UX do _managerMiniControls do Onboard 15 Dias
  // (onboarding_phase_kanban_page.dart) -- fotos pequenas + atalhos de
  // adicionar/remover, so que apontando pro streamer_managers_service.dart
  // (N:N generico por streamerId) em vez do vinculo preso a um progressId
  // de onboarding.
  Widget _managerMiniControls() {
    final shown = managers.take(2).toList();
    final extra = managers.length - shown.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...shown.map(
          (m) => Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Tooltip(
              message: m.loginEmail ?? "Gestor",
              child: CircleAvatar(
                radius: 8,
                backgroundColor: Colors.white24,
                backgroundImage: m.photoUrl != null
                    ? NetworkImage(m.photoUrl!)
                    : null,
                child: m.photoUrl == null
                    ? const Icon(Icons.person, size: 9, color: Colors.white54)
                    : null,
              ),
            ),
          ),
        ),
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Text(
              "+" + extra.toString(),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (onManageManagers != null)
          Tooltip(
            message: "Gestores responsáveis",
            child: InkWell(
              onTap: onManageManagers,
              borderRadius: BorderRadius.circular(10),
              child: const Icon(
                Icons.add_circle,
                size: 13,
                color: Colors.greenAccent,
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final health = _dueHealth();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Tooltip(
                  message: health.$2,
                  child: Container(width: 4, color: health.$1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white24,
                              backgroundImage: row.avatarUrl != null
                                  ? NetworkImage(row.avatarUrl!)
                                  : null,
                              child: row.avatarUrl == null
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white54,
                                      size: 16,
                                    )
                                  : null,
                            ),
                            if (row.categoryIconKey != null &&
                                row.categoryIconKey!.isNotEmpty)
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  child: Icon(
                                    categoryIcon(row.categoryIconKey),
                                    size: 11,
                                    color: categoryColor(row.categoryIconKey),
                                  ),
                                ),
                              ),
                            if (row.potentialLevel == "alto")
                              Positioned(
                                bottom: -2,
                                left: -2,
                                child: Tooltip(
                                  message: "Potencial alto",
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                    child: const Icon(
                                      Icons.star,
                                      size: 11,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _openQuickInfo(context),
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "@" + row.nick,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  row.displayName,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _openWhatsApp(context),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.chat,
                              size: 15,
                              color: Color(0xFF25D366),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.diamond,
                              size: 11,
                              color: Color(0xFF7A0BD4),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              row.diamonds.toString(),
                              style: const TextStyle(
                                color: Color(0xFF7A0BD4),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        if (row.diamondsLastMonth != null)
                          Text(
                            (row.growth >= 0 ? "▲ +" : "▼ ") +
                                row.growth.toString(),
                            style: TextStyle(
                              color: row.growth >= 0
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: potentialColor(
                              row.potentialLevel,
                            ).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            potentialLabel(row.potentialLevel),
                            style: TextStyle(
                              color: potentialColor(row.potentialLevel),
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _infoLine("Dias agência", row.daysInAgency.toString()),
                    _infoLine(
                      "Últ. acomp.",
                      row.lastContactAt != null
                          ? row.lastContactAt!.toLocal().toString().substring(
                              0,
                              10,
                            )
                          : "-",
                    ),
                    if (stageInfo?.note != null)
                      _infoLine("Nota", stageInfo!.note!),
                    _infoLine("Gestor", row.assignedManagerEmail ?? "-"),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        InkWell(
                          onTap: onRegisterAction,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7A0BD4).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF7A0BD4),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_note,
                                  size: 10,
                                  color: Color(0xFF7A0BD4),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  "Registrar Ação",
                                  style: TextStyle(
                                    color: Color(0xFF7A0BD4),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (managers.isNotEmpty || onManageManagers != null)
                          _managerMiniControls(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }
}

