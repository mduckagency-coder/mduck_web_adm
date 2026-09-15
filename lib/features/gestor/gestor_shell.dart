import "dart:html" as html;
import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../calendario/calendar_board_page.dart";
import "../categorias/categorias_page.dart";
import "../crm/crm_page.dart";
import "../gestao/demandas_page.dart";
import "../metricas/level_maintenance_page.dart";
import "../metricas/metricas_streamers_page.dart";
import "../profile/app_top_bar.dart";
import "../progresso/progresso_streamers_page.dart";
import "../streamers/streamers_page.dart";
import "gestao_streamers_page.dart";
import "gestor_dashboard_page.dart";
import "gestor_my_streamers_page.dart";
import "gestor_proximos_agenciados_page.dart";
import "onboarding_phase_kanban_page.dart";
import "onboarding_phase_service.dart"
    show onboardingPhaseKey, onboardingSecondPhaseKey, onboardingThirdPhaseKey;
import "onboarding_materials_page.dart";

class _MenuGroup {
  final IconData icon;
  final String label;
  final List<(IconData, String)> children;

  const _MenuGroup({
    required this.icon,
    required this.label,
    required this.children,
  });
}

// Movido de Home Central (AdminShell) pra ca -- o gestor e quem realmente
// usa esse grupo no dia a dia, nao fazia sentido ficar so na area do
// Administrador. "Gestao de Streamers" virou "Acao Streamers" dentro do
// grupo (mesma pagina, GestaoStreamersPage, so o nome do menu muda).
const _menuGroupsTop = [
  _MenuGroup(
    icon: Icons.people,
    label: "Criadores",
    children: [
      (Icons.badge, "CRM"),
      (Icons.groups_2, "Ação Streamers"),
      (Icons.person_outline, "Streamers"),
      (Icons.query_stats, "Metricas Streamers"),
      (Icons.military_tech, "Manutencao de Nivel"),
      (Icons.category, "Categorias"),
      (Icons.timeline, "Progressao Inatividade"),
    ],
  ),
];

const _menuItemsTop = [
  (Icons.dashboard, "Dashboard"),
  (Icons.assignment_outlined, "Demandas"),
  (Icons.groups, "Meus Streamers"),
];

const _menuItemsBottom = [
  (Icons.hourglass_bottom, "Proximos Agenciados"),
  (Icons.timelapse, "Onboard 0-15 Dias"),
  (Icons.timelapse, "Acompanhamento 16-31 Dias"),
  (Icons.school, "Graduacao Novatos"),
  (Icons.menu_book, "Material Acompanhamento"),
  (Icons.calendar_month, "Calendario"),
];

class GestorShell extends StatefulWidget {
  const GestorShell({super.key});

  @override
  State<GestorShell> createState() => _GestorShellState();
}

class _GestorShellState extends State<GestorShell> {
  String _selected = "Dashboard";
  final Set<String> _expanded = {"Criadores"};

  void _select(String value) {
    setState(() => _selected = value);
    html.window.localStorage["mduck_gestor_page"] = value;
  }

  @override
  void initState() {
    super.initState();
    final saved = html.window.localStorage["mduck_gestor_page"];
    if (saved != null && saved.isNotEmpty) _selected = saved;
  }

  Widget _buildContent() {
    switch (_selected) {
      case "Dashboard":
        return const GestorDashboardPage();
      case "Demandas":
        return const DemandasPage();
      case "Meus Streamers":
        return const GestorMyStreamersPage();
      case "Ação Streamers":
        return const GestaoStreamersPage();
      case "Streamers":
        return const StreamersPage();
      case "Metricas Streamers":
        return const MetricasStreamersPage();
      case "Manutencao de Nivel":
        return const LevelMaintenancePage();
      case "Categorias":
        return const CategoriasPage();
      case "Progressao Inatividade":
        return const ProgressoStreamersPage();
      case "Proximos Agenciados":
        return const GestorProximosAgenciadosPage();
      case "Onboard 0-15 Dias":
        return const OnboardingPhaseKanbanPage(
          key: ValueKey(onboardingPhaseKey),
          promoteToPhaseKey: onboardingSecondPhaseKey,
        );
      case "Acompanhamento 16-31 Dias":
        return const OnboardingPhaseKanbanPage(
          key: ValueKey(onboardingSecondPhaseKey),
          phaseKey: onboardingSecondPhaseKey,
          title: "Acompanhamento 16-31 Dias",
          description:
              "Continuacao do Onboard 0-15 Dias -- streamers aprovados entram automaticamente na coluna \"Recebidos\". Quem for marcado com a estrela \"streamer em potencial\" e aprovado segue automaticamente pra Graduacao Novatos.",
          materialsStage: "onboarding_30",
          showManualCreateButton: false,
          deadlineDaysThreshold: 31,
          deadlineWarnDays: 27,
          promoteToPhaseKey: onboardingThirdPhaseKey,
          requirePotentialToPromote: true,
        );
      case "Graduacao Novatos":
        return const OnboardingPhaseKanbanPage(
          key: ValueKey(onboardingThirdPhaseKey),
          phaseKey: onboardingThirdPhaseKey,
          title: "Graduacao Novatos",
          description:
              "Streamers destacados como \"em potencial\" no Acompanhamento 16-31 Dias entram automaticamente aqui -- tambem da pra adicionar alguem direto pelo botao \"Novo Agenciado\".",
          materialsStage: "graduacao_novatos",
          showManualCreateButton: true,
          deadlineDaysThreshold: 90,
          deadlineWarnDays: 80,
        );
      case "Material Acompanhamento":
        return const OnboardingMaterialsPage();
      case "Calendario":
        return const CalendarBoardPage(mode: CalendarBoardMode.mine);
      case "CRM":
        return CrmPage(
          managerId: Supabase.instance.client.auth.currentUser!.id,
        );
      default:
        return Center(
          child: Text(
            _selected + " - em construcao",
            style: const TextStyle(fontSize: 18, color: Colors.white70),
          ),
        );
    }
  }

  Widget _itemTile((IconData, String) item) {
    final selected = _selected == item.$2;
    return ListTile(
      leading: Icon(
        item.$1,
        color: selected ? const Color(0xFF7A0BD4) : Colors.white70,
        size: 20,
      ),
      title: Text(
        item.$2,
        style: TextStyle(
          color: selected ? const Color(0xFF7A0BD4) : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      onTap: () => _select(item.$2),
    );
  }

  Widget _groupTile(_MenuGroup group) {
    final isExpanded = _expanded.contains(group.label);
    return Column(
      children: [
        ListTile(
          leading: Icon(group.icon, color: Colors.white70, size: 20),
          title: Text(
            group.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          trailing: Icon(
            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: Colors.white54,
            size: 18,
          ),
          onTap: () => setState(() {
            if (isExpanded) {
              _expanded.remove(group.label);
            } else {
              _expanded.add(group.label);
            }
          }),
        ),
        if (isExpanded)
          ...group.children.map((child) {
            final selected = _selected == child.$2;
            return Padding(
              padding: const EdgeInsets.only(left: 16),
              child: ListTile(
                dense: true,
                leading: Icon(
                  child.$1,
                  color: selected ? const Color(0xFF7A0BD4) : Colors.white54,
                  size: 18,
                ),
                title: Text(
                  child.$2,
                  style: TextStyle(
                    color: selected ? const Color(0xFF7A0BD4) : Colors.white70,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                onTap: () => _select(child.$2),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 250,
            color: const Color(0xFF1A1A1A),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () {
                      html.window.localStorage.remove("mduck_area");
                      Navigator.of(context).pop();
                    },
                    child: Image.asset(
                      "assets/logo/LogoMduck.png",
                      height: 90,
                      errorBuilder: (context, error, stack) => const Text(
                        "MDuck",
                        style: TextStyle(
                          color: Color(0xFF7A0BD4),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    "Área do Gestor",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        ..._menuItemsTop.map(_itemTile),
                        ..._menuGroupsTop.map(_groupTile),
                        ..._menuItemsBottom.map(_itemTile),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white70),
                    tooltip: "Sair",
                    onPressed: () => Supabase.instance.client.auth.signOut(),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                const AppTopBar(),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
