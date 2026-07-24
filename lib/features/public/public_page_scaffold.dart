import "dart:html" as html;
import "package:flutter/material.dart";

const _purple = Color(0xFF7A0BD4);
const _cardColor = Color(0xFF15101F);

class PublicPageScaffold extends StatelessWidget {
  const PublicPageScaffold({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.children,
  });

  final String title;
  final String lastUpdated;
  final List<Widget> children;

  void _goToLogin(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      html.window.history.pushState(null, "", "/");
    } else {
      html.window.location.href = "/";
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 600 ? 16.0 : 32.0;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [Color(0xFF241238), Color(0xFF120A1E), Color(0xFF08060D)],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    "assets/logo/LogoMduck.png",
                    height: 90,
                    errorBuilder: (context, error, stack) => const Icon(Icons.hive, color: _purple, size: 60),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Última atualização: $lastUpdated",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(screenWidth < 600 ? 20 : 36),
                    decoration: BoxDecoration(
                      color: _cardColor.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Column(
                    children: [
                      const Text("© 2026 Mduck Agency", style: TextStyle(color: Colors.white38, fontSize: 12)),
                      const SizedBox(height: 4),
                      const Text("https://adm.mduckagency.com.br", style: TextStyle(color: Colors.white38, fontSize: 12)),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => _goToLogin(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: _purple),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("Voltar"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget publicSectionHeading(String text) {
  return Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
  );
}

Widget publicParagraph(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
  );
}

Widget publicBullet(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6, right: 10),
          child: CircleAvatar(radius: 2.5, backgroundColor: _purple),
        ),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5))),
      ],
    ),
  );
}
