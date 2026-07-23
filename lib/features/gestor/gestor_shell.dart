import "dart:html" as html;
import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../calendario/calendar_board_page.dart";
import "../crm/crm_page.dart";
import "../profile/app_top_bar.dart";
import "gestor_dashboard_page.dart";
import "gestor_my_streamers_page.dart";
import "gestor_proximos_agenciados_page.dart";
import "onboarding_phase_kanban_page.dart";
import "onboarding_materials_page.dart";

const _menuItems = [
  (Icons.dashboard, "Dashboard"),
  (Icons.groups, "Meus Streamers"),
  (Icons.hourglass_bottom, "Proximos Agenciados"),
  (Icons.timelapse, "Onboarding 0-15 Dias"),
  (Icons.menu_book, "Material Acompanhamento"),
  (Icons.calendar_month, "Calendario"),
  (Icons.badge, "CRM"),
];

class GestorShell extends StatefulWidget {
  const GestorShell({super.key});

  @override
  State<GestorShell> createState() => _GestorShellState();
}

class _GestorShellState extends State<GestorShell> {
  String _selected = "Dashboard";

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
      case "Meus Streamers":
        return const GestorMyStreamersPage();
      case "Proximos Agenciados":
        return const GestorProximosAgenciadosPage();
      case "Onboarding 0-15 Dias":
        return const OnboardingPhaseKanbanPage();
      case "Material Acompanhamento":
        return const OnboardingMaterialsPage();
      case "Calendario":
        return const CalendarBoardPage(mode: CalendarBoardMode.mine);
      case "CRM":
        return CrmPage(managerId: Supabase.instance.client.auth.currentUser!.id);
      default:
        return Center(child: Text(_selected + " - em construcao", style: const TextStyle(fontSize: 18, color: Colors.white70)));
    }
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
                    child: Image.asset("assets/logo/LogoMduck.png", height: 90, errorBuilder: (context, error, stack) => const Text("MDuck", style: TextStyle(color: Color(0xFF7A0BD4), fontSize: 20, fontWeight: FontWeight.bold))),
                  ),
                  const Text("Área do Gestor", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        ..._menuItems.map((item) {
                          final selected = _selected == item.$2;
                          return ListTile(
                            leading: Icon(item.$1, color: selected ? const Color(0xFF7A0BD4) : Colors.white70, size: 20),
                            title: Text(item.$2, style: TextStyle(color: selected ? const Color(0xFF7A0BD4) : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            onTap: () => _select(item.$2),
                          );
                        }),
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
