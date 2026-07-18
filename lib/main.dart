import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:flutter_web_plugins/url_strategy.dart";
import "features/auth/auth_gate.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await Supabase.initialize(
    url: "https://ecpddfnzukhqafhnhmpf.supabase.co",
    anonKey: "sb_publishable_NszHMwgU1mBr_O8LuXkNow_9Z0c_DSr",
  );
  runApp(const MDuckAdminApp());
}

class MDuckAdminApp extends StatelessWidget {
  const MDuckAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: const AuthGate(),
    );
  }
}
