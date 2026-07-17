import "package:flutter/material.dart";
import "../campaigns/agency_campaigns_page.dart";
import "../app_missions/app_missions_page.dart";

class MissoesHubPage extends StatefulWidget {
  const MissoesHubPage({super.key});

  @override
  State<MissoesHubPage> createState() => _MissoesHubPageState();
}

class _MissoesHubPageState extends State<MissoesHubPage> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    if (_selected == "agencia") {
      return Column(
        children: [
          _BackBar(onBack: () => setState(() => _selected = null), title: "Missao Agencia"),
          Expanded(child: const AgencyCampaignsPage()),
        ],
      );
    }
    if (_selected == "app") {
      return Column(
        children: [
          _BackBar(onBack: () => setState(() => _selected = null), title: "Missoes APP MDuck Lives"),
          Expanded(child: const AppMissionsPage()),
        ],
      );
    }

    return Center(
      child: Wrap(
        spacing: 24,
        runSpacing: 24,
        alignment: WrapAlignment.center,
        children: [
          _MissionCard(
            icon: Icons.campaign,
            title: "Missao Agencia",
            subtitle: "Campanhas e eventos da agencia (mes, semanal, TikTok)",
            onTap: () => setState(() => _selected = "agencia"),
          ),
          _MissionCard(
            icon: Icons.flag,
            title: "Missoes APP MDuck Lives",
            subtitle: "Missoes que aparecem no aplicativo para os streamers",
            onTap: () => setState(() => _selected = "app"),
          ),
        ],
      ),
    );
  }
}

class _BackBar extends StatelessWidget {
  final VoidCallback onBack;
  final String title;

  const _BackBar({required this.onBack, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70), onPressed: onBack),
          Text(title, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MissionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: const Color(0xFF7A0BD4)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
