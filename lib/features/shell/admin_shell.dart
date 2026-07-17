import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../import/import_page.dart";
import "../progresso/progresso_streamers_page.dart";
import "../metricas/metricas_streamers_page.dart";
import "../campaigns/agency_campaigns_page.dart";
import "../app_missions/app_missions_page.dart";
import "../financeiro/financeiro_page.dart";
import "../streamers/streamers_page.dart";
import "../dashboard/dashboard_page.dart";
import "../categorias/categorias_page.dart";
import "../ranking/ranking_page.dart";
import "../crm/crm_page.dart";
import "../missoes_atividades/missoes_atividades_page.dart";
import "../ilha_top_duckers/ilha_top_duckers_page.dart";

class _MenuGroup {
  final IconData icon;
  final String label;
  final List<(IconData, String)> children;

  const _MenuGroup({required this.icon, required this.label, required this.children});
}

const _menuGroups = [
  _MenuGroup(icon: Icons.people, label: "Criadores", children: [
    (Icons.badge, "CRM"),
    (Icons.person_outline, "Streamers"),
    (Icons.query_stats, "Metricas Streamers"),
    (Icons.category, "Categorias"),
    (Icons.timeline, "Progressao Inatividade"),
  ]),
  _MenuGroup(icon: Icons.flag, label: "Missoes", children: [
    (Icons.campaign, "Missao Agencia"),
    (Icons.flag_outlined, "Missoes APP"),
    (Icons.playlist_add_check, "Missoes Atividades"),
  ]),
  _MenuGroup(icon: Icons.sports_esports, label: "Operacoes APP", children: [
    (Icons.leaderboard, "Ranking"),
    (Icons.landscape, "Ilha Top Duckers"),
    (Icons.calendar_month, "Calendario"),
    (Icons.backpack, "Inventario"),
    (Icons.emoji_events, "Conquistas"),
    (Icons.military_tech, "Brasoes e Titulos"),
    (Icons.school, "MAX Aulas"),
  ]),
  _MenuGroup(icon: Icons.movie_filter, label: "Configuracao Animacao APP", children: [
    (Icons.image, "Background Home"),
    (Icons.terrain, "Ilha Top Duckers - Config"),
    (Icons.pets, "Max"),
    (Icons.animation, "Animacoes de menus"),
  ]),
];

const _standaloneItems = [
  (Icons.attach_money, "Campanhas Financeiro", "Financeiro"),
  (Icons.settings, "Configuracoes", "Configuracoes"),
];

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  String _selected = "Dashboard";
  final Set<String> _expanded = {"Criadores"};

  Widget _buildContent() {
    switch (_selected) {
      case "Dashboard":
        return const DashboardPage();
      case "Streamers":
        return const StreamersPage();
      case "Importacao TikTok":
        return const ImportPage();
      case "Progressao Inatividade":
        return const ProgressoStreamersPage();
      case "Metricas Streamers":
        return const MetricasStreamersPage();
      case "Missao Agencia":
        return const AgencyCampaignsPage();
      case "Missoes APP":
        return const AppMissionsPage();
      case "Campanhas Financeiro":
        return const FinanceiroPage();
      case "Categorias":
        return const CategoriasPage();
      case "Ranking":
        return const RankingPage();
      case "CRM":
        return const CrmPage();
      case "Missoes Atividades":
        return const MissoesAtividadesPage();
      case "Ilha Top Duckers":
        return const IlhaTopDuckersPage();
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
            child: Column(
              children: [
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => setState(() => _selected = "Dashboard"),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Image.asset("assets/LogoMduck.png", height: 60, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      ListTile(
                        leading: Icon(Icons.dashboard, color: _selected == "Dashboard" ? const Color(0xFF7A0BD4) : Colors.white70, size: 20),
                        title: Text("Dashboard",
                            style: TextStyle(color: _selected == "Dashboard" ? const Color(0xFF7A0BD4) : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        onTap: () => setState(() => _selected = "Dashboard"),
                      ),
                      const Divider(color: Colors.white12, height: 12),
                      ..._menuGroups.map((group) {
                        final isExpanded = _expanded.contains(group.label);
                        return Column(
                          children: [
                            ListTile(
                              leading: Icon(group.icon, color: Colors.white70, size: 20),
                              title: Text(group.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              trailing: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white54, size: 18),
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
                                    leading: Icon(child.$1, color: selected ? const Color(0xFF7A0BD4) : Colors.white54, size: 18),
                                    title: Text(child.$2,
                                        style: TextStyle(color: selected ? const Color(0xFF7A0BD4) : Colors.white70, fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                                    onTap: () => setState(() => _selected = child.$2),
                                  ),
                                );
                              }),
                          ],
                        );
                      }),
                      const Divider(color: Colors.white12, height: 24),
                      ..._standaloneItems.map((item) {
                        final selected = _selected == item.$2;
                        return ListTile(
                          leading: Icon(item.$1, color: selected ? const Color(0xFF7A0BD4) : Colors.white70, size: 20),
                          title: Text(item.$3, style: TextStyle(color: selected ? const Color(0xFF7A0BD4) : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          onTap: () => setState(() => _selected = item.$2),
                        );
                      }),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _selected = "Importacao TikTok"),
                  child: Container(
                    width: double.infinity,
                    color: _selected == "Importacao TikTok" ? const Color(0xFF7A0BD4) : const Color(0xFF7A0BD4).withOpacity(0.6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text("Importacao TikTok", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white70),
                  tooltip: "Sair",
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }
}

