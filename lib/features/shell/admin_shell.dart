import "dart:html" as html;
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
import "../metricas/level_maintenance_page.dart";
import "../financeiro_rh/financeiro_rh_shell.dart";
import "../calendario/agenda_agencia_page.dart";
import "../calendario/agenda_streamers_page.dart";
import "../admin/bug_reports_page.dart";
import "../admin/bug_reports_page.dart";
import "../eventos/eventos_page.dart";
import "../programas/programas_page.dart";
import "../profile/profile_avatar_menu.dart";
import "../profile/app_top_bar.dart";

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
    (Icons.military_tech, "Manutencao de Nivel"),
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
    (Icons.backpack, "Inventario"),
    (Icons.emoji_events, "Conquistas"),
    (Icons.military_tech, "Brasoes e Titulos"),
    (Icons.school, "MAX Aulas"),
  ]),
  _MenuGroup(icon: Icons.calendar_month, label: "Calendario", children: [
    (Icons.apartment, "Agenda da Agencia"),
    (Icons.groups, "Agenda dos Streamers"),
    (Icons.inbox, "Solicitacoes"),
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

  void _select(String value) {
    debugPrint("[AdminShell] _select chamado com value=" + value);
    setState(() => _selected = value);
    html.window.localStorage["mduck_admin_page"] = value;
    debugPrint("[AdminShell] localStorage gravado=" + value);
  }

  @override
  bool _isDono = false;

  @override
  void initState() {
    super.initState();
    final saved = html.window.localStorage["mduck_admin_page"];
    if (saved != null && saved.isNotEmpty) _selected = saved;
    debugPrint("[AdminShell] initState() chamado. saved=" + (saved ?? "null") + " _selected=" + _selected);
    _checkDono();
  }

  bool _isAdmin2 = false;

  Future<void> _checkDono() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("financial_role, role").eq("id", userId).maybeSingle();
    if (mounted) {
      setState(() {
        _isDono = manager != null && manager["financial_role"] == "dono";
        _isAdmin2 = manager != null && manager["role"] == "admin";
      });
    }
  }

  Widget _buildContent() {
    debugPrint("[AdminShell] _buildContent() chamado com _selected=" + _selected);
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
      case "Manutencao de Nivel":
        return const LevelMaintenancePage();
      case "Missao Agencia":
        return const AgencyCampaignsPage();
      case "Missoes APP":
        return const AppMissionsPage();
      case "Campanhas Financeiro":
        return const FinanceiroPage();
      case "Reportes de Bugs":
        return const BugReportsPage();
      case "Financeiro & RH":
        return const FinanceiroRhShell();
      case "Reportes de Bugs":
        return const BugReportsPage();
      case "Categorias":
        return const CategoriasPage();
      case "Ranking":
        return const RankingPage();
      case "CRM":
        return const CrmPage();
      case "Eventos":
        return const EventosPage();
      case "Programas de Desenvolvimento":
        return const ProgramasPage();
      case "Missoes Atividades":
        return const MissoesAtividadesPage();
      case "Ilha Top Duckers":
        return const IlhaTopDuckersPage();
      case "Agenda da Agencia":
        return const AgendaAgenciaPage();
      case "Agenda dos Streamers":
        return const AgendaStreamersPage();
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
                  onTap: () {
                    html.window.localStorage.remove("mduck_area");
                    Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Image.asset("assets/logo/LogoMduck.png", height: 96, fit: BoxFit.contain),
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
                        onTap: () => _select("Dashboard"),
                      ),
                      ListTile(
                        leading: Icon(Icons.event, color: _selected == "Eventos" ? const Color(0xFF7A0BD4) : Colors.white70, size: 20),
                        title: Text("Eventos",
                            style: TextStyle(color: _selected == "Eventos" ? const Color(0xFF7A0BD4) : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        onTap: () => _select("Eventos"),
                      ),
                      ListTile(
                        leading: Icon(Icons.trending_up, color: _selected == "Programas de Desenvolvimento" ? const Color(0xFF7A0BD4) : Colors.white70, size: 20),
                        title: Text("Programas de Desenvolvimento",
                            style: TextStyle(color: _selected == "Programas de Desenvolvimento" ? const Color(0xFF7A0BD4) : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        onTap: () => _select("Programas de Desenvolvimento"),
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
                                    onTap: () => _select(child.$2),
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
                          onTap: () => _select(item.$2),
                        );
                      }),
                      if (_isDono) ListTile(leading: Icon(Icons.account_balance, color: _selected == "Financeiro & RH" ? const Color(0xFF7A0BD4) : Colors.amber, size: 20), title: Text("Financeiro & RH", style: TextStyle(color: _selected == "Financeiro & RH" ? const Color(0xFF7A0BD4) : Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)), onTap: () => _select("Financeiro & RH")),
                      if (_isDono || _isAdmin2) ListTile(leading: Icon(Icons.bug_report, color: _selected == "Reportes de Bugs" ? const Color(0xFF7A0BD4) : Colors.redAccent, size: 20), title: Text("Reportes de Bugs", style: TextStyle(color: _selected == "Reportes de Bugs" ? const Color(0xFF7A0BD4) : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)), onTap: () => _select("Reportes de Bugs")),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _select("Importacao TikTok"),
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
                
                const SizedBox(height: 8),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                AppTopBar(onNotificationTap: () => _select("Reportes de Bugs")),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}























