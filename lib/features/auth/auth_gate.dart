import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "admin_auth_repository.dart";
import "login_page.dart";
import "../shell/admin_shell.dart";

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = AdminAuthRepository();
    return StreamBuilder<AuthState>(
      stream: repository.authStateChanges,
      builder: (context, snapshot) {
        final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
        if (isLoggedIn) {
          return const AdminShell();
        }
        return const AdminLoginPage();
      },
    );
  }
}
