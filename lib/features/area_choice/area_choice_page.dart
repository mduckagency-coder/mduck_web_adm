import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "dart:html" as html;
import "../shell/admin_shell.dart";
import "../recruiter/recruiter_shell.dart";

class AreaChoicePage extends StatelessWidget {
  const AreaChoicePage({super.key});

  void _goTo(BuildContext context, String area, Widget page) {
    html.window.localStorage["mduck_area"] = area;
    html.window.localStorage.remove(area == "admin" ? "mduck_admin_page" : "mduck_recruiter_page");
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset("assets/logo/LogoMduck.png", height: 110, errorBuilder: (context, error, stack) => const Text("MDuck Admin", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
            const SizedBox(height: 16),
            const Text("Escolha para onde deseja ir", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 32),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                _AreaCard(icon: Icons.dashboard, title: "Home Central", subtitle: "Gestao geral da agencia", onTap: () => _goTo(context, "admin", const AdminShell())),
                _AreaCard(icon: Icons.groups, title: "Area do Gestor", subtitle: "Em construcao", onTap: () => _goTo(context, "gestor", const _StubAreaPage(title: "Area do Gestor"))),
                _AreaCard(icon: Icons.person_search, title: "Area do Recrutador", subtitle: "Dashboard e leads", onTap: () => _goTo(context, "recruiter", const RecruiterShell())),
              ],
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                html.window.localStorage.remove("mduck_area");
                Supabase.instance.client.auth.signOut();
              },
              child: const Text("Sair"),
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _AreaCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
        child: Column(
          children: [
            Icon(icon, size: 44, color: const Color(0xFF7A0BD4)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _StubAreaPage extends StatelessWidget {
  final String title;
  const _StubAreaPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(backgroundColor: Colors.black, title: Text(title)),
      body: const Center(child: Text("Em construcao", style: TextStyle(color: Colors.white54, fontSize: 18))),
    );
  }
}
