import "dart:async";
import "dart:html" as html;
import "package:flutter/material.dart";
import "package:flutter/foundation.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:flutter_web_plugins/url_strategy.dart";
import "features/auth/auth_gate.dart";
import "features/public/privacy_policy_page.dart";
import "features/public/terms_page.dart";

final navigatorKey = GlobalKey<NavigatorState>();

void _forceBackToLogin() {
  html.window.localStorage.remove("mduck_area");
  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const AuthGate()),
    (route) => false,
  );
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    usePathUrlStrategy();

    ErrorWidget.builder = (details) {
      FlutterError.presentError(details);
      return Material(
        color: const Color(0xFF121212),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                const SizedBox(height: 12),
                const Text("Ocorreu um erro ao carregar esta tela.", style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 4),
                Text(kDebugMode ? details.exceptionAsString() : "Tente recarregar a pagina.",
                    style: const TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => html.window.location.reload(), child: const Text("Recarregar")),
              ],
            ),
          ),
        ),
      );
    };

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
    };

    await Supabase.initialize(
      url: "https://ecpddfnzukhqafhnhmpf.supabase.co",
      anonKey: "sb_publishable_NszHMwgU1mBr_O8LuXkNow_9Z0c_DSr",
    );

    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut) {
        _forceBackToLogin();
      }
    });

    runApp(const MDuckAdminApp());
  }, (error, stack) {
    debugPrint("[Uncaught] $error\n$stack");
  });
}

class MDuckAdminApp extends StatelessWidget {
  const MDuckAdminApp({super.key});

  Widget _resolveHome() {
    switch (Uri.base.path) {
      case "/privacy":
        return const PrivacyPolicyPage();
      case "/terms":
        return const TermsPage();
      default:
        return const AuthGate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: "MDuck Admin",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7A0BD4),
          brightness: Brightness.dark,
        ),
      ),
      home: _resolveHome(),
    );
  }
}
