import "dart:html" as html;
import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "recruiter_dashboard_page.dart";
import "recruiter_leads_page.dart";
import "recruiter_onboarding_central_page.dart";
import "recruiter_metrics_page.dart";
import "recruiter_feedbacks_page.dart";
import "recruiter_materials_page.dart";
import "recruiter_templates_page.dart";
import "recruiter_funnel_page.dart";
import "recruiter_historico_page.dart";
import "recruiter_profile_page.dart";
import "../profile/profile_avatar_menu.dart";
import "../profile/app_top_bar.dart";
import "team/team_dashboard_page.dart";
import "team/team_recruiters_page.dart";
import "team/team_targets_page.dart";
import "team/team_ranking_page.dart";
import "team/team_feedbacks_page.dart";
import "team/team_sla_page.dart";
import "team/team_missions_page.dart";
import "team/team_materials_admin_page.dart";
import "recruiter_settings_page.dart";

const _menuItems = [
  (Icons.dashboard, "Dashboard"),
  (Icons.person_search, "Leads"),
  (Icons.groups, "Streamers Agenciados"),
  (Icons.query_stats, "Metricas"),
  (Icons.feedback_outlined, "Feedbacks"),
  (Icons.menu_book, "Materiais"),
  (Icons.chat_bubble_outline, "Modelos de Mensagens"),
  (Icons.call_split, "Funil de Mensagens"),
  (Icons.history, "Historico"),
];

const _teamMenuItems = [
  (Icons.dashboard_customize, "Dashboard da Equipe"),
  (Icons.groups_2, "Recrutadores"),
  (Icons.flag, "Metas"),
  (Icons.leaderboard, "Ranking da Equipe"),
  (Icons.feedback, "Gerenciar Feedbacks"),
  (Icons.flag_circle, "Missoes"),
  (Icons.upload_file, "Cadastrar Materiais"),
  (Icons.timer, "Prazos (SLA)"),
  (Icons.settings, "Configuracoes"),
];

class RecruiterShell extends StatefulWidget {
  const RecruiterShell({super.key});

  @override
  State<RecruiterShell> createState() => _RecruiterShellState();
}

class _RecruiterShellState extends State<RecruiterShell> {
  String _selected = "Dashboard";
  bool _isCoordenadorOrAdmin = false;
  bool _loadingRole = true;

  void _select(String value) {
    setState(() => _selected = value);
    html.window.location.hash = Uri.encodeComponent(value);
  }

  @override
  void initState() {
    super.initState();
    final hash = html.window.location.hash.replaceFirst("#", "");
    if (hash.isNotEmpty) _selected = Uri.decodeComponent(hash);
    _checkRole();
  }

  Future<void> _checkRole() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("role").eq("id", userId).single();
    setState(() {
      _isCoordenadorOrAdmin = manager["role"] == "coordenador" || manager["role"] == "admin";
      _loadingRole = false;
    });
  }

  Widget _buildContent() {
    switch (_selected) {
      case "Dashboard":
        return RecruiterDashboardPage(onNavigateToFeedbacks: () => _select("Feedbacks"));
      case "Leads":
        return const RecruiterLeadsPage();
      case "Streamers Agenciados":
        return const RecruiterOnboardingCentralPage();
      case "Metricas":
        return const RecruiterMetricsPage();
      case "Feedbacks":
        return const RecruiterFeedbacksPage();
      case "Materiais":
        return const RecruiterMaterialsPage();
      case "Modelos de Mensagens":
        return const RecruiterTemplatesPage();
      case "Funil de Mensagens":
        return const RecruiterFunnelPage();
      case "Historico":
        return const RecruiterHistoricoPage();
      
      case "Dashboard da Equipe":
        return const TeamDashboardPage();
      case "Recrutadores":
        return const TeamRecruitersPage();
      case "Metas":
        return const TeamTargetsPage();
      case "Ranking da Equipe":
        return const TeamRankingPage();
      case "Gerenciar Feedbacks":
        return const TeamFeedbacksPage();
      case "Missoes":
        return const TeamMissionsPage();
      case "Cadastrar Materiais":
        return const TeamMaterialsAdminPage();
      case "Prazos (SLA)":
        return const TeamSlaPage();
      case "Configuracoes":
        return const RecruiterSettingsPage();
      default:
        return Center(child: Text(_selected + " - em construcao", style: const TextStyle(fontSize: 18, color: Colors.white70)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingRole) return const Scaffold(backgroundColor: Color(0xFF121212), body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 250,
            color: const Color(0xFF1A1A1A),
            child: Column(
              children: [
                const SizedBox(height: 20),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: Image.asset("assets/logo/LogoMduck.png", height: 90, errorBuilder: (context, error, stack) => const Text("MDuck", style: TextStyle(color: Color(0xFF7A0BD4), fontSize: 20, fontWeight: FontWeight.bold))),
                ),
                const Text("Area do Recrutador", style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                      if (_isCoordenadorOrAdmin) ...[
                        const Divider(color: Colors.white12, height: 24),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Text("GESTAO DA EQUIPE", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        ..._teamMenuItems.map((item) {
                          final selected = _selected == item.$2;
                          return ListTile(
                            leading: Icon(item.$1, color: selected ? Colors.amber : Colors.white70, size: 20),
                            title: Text(item.$2, style: TextStyle(color: selected ? Colors.amber : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            onTap: () => _select(item.$2),
                          );
                        }),
                      ],
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









