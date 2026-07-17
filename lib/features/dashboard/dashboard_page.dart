import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MDuck Admin"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: const Center(
        child: Text(
          "Painel em construcao — proxima etapa: importacao da planilha",
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
