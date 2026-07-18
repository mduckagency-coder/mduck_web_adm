import "package:supabase_flutter/supabase_flutter.dart";
import "dart:html" as html;

class AdminAuthRepository {
  final _client = Supabase.instance.client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  static const _maxAttempts = 5;
  static const _lockoutMinutes = 10;

  Future<Map<String, dynamic>?> checkLoginStatus(String email) async {
    final row = await _client
        .from("managers")
        .select("id, failed_login_attempts, locked_until, employment_status")
        .eq("login_email", email)
        .maybeSingle();
    return row;
  }

  Future<void> recordAttempt(String email, bool success, String? managerId) async {
    await _client.from("login_attempts_log").insert({"email": email, "success": success});

    if (managerId == null) return;

    if (success) {
      await _client.from("managers").update({"failed_login_attempts": 0, "locked_until": null}).eq("id", managerId);
    } else {
      final current = await _client.from("managers").select("failed_login_attempts").eq("id", managerId).single();
      final attempts = ((current["failed_login_attempts"] as int?) ?? 0) + 1;
      final data = <String, dynamic>{"failed_login_attempts": attempts};
      if (attempts >= _maxAttempts) {
        data["locked_until"] = DateTime.now().add(const Duration(minutes: _lockoutMinutes)).toIso8601String();
      }
      await _client.from("managers").update(data).eq("id", managerId);
    }
  }

  Future<void> logSession(String managerId) async {
    final userAgent = html.window.navigator.userAgent;
    String browser = "Desconhecido";
    if (userAgent.contains("Edg/")) {
      browser = "Edge";
    } else if (userAgent.contains("Chrome/")) {
      browser = "Chrome";
    } else if (userAgent.contains("Firefox/")) {
      browser = "Firefox";
    } else if (userAgent.contains("Safari/")) {
      browser = "Safari";
    }
    String os = "Desconhecido";
    if (userAgent.contains("Windows")) {
      os = "Windows";
    } else if (userAgent.contains("Mac OS")) {
      os = "macOS";
    } else if (userAgent.contains("Linux")) {
      os = "Linux";
    } else if (userAgent.contains("Android")) {
      os = "Android";
    } else if (userAgent.contains("iOS") || userAgent.contains("iPhone")) {
      os = "iOS";
    }

    await _client.from("login_sessions").insert({
      "manager_id": managerId,
      "browser": browser,
      "os": os,
      "ip_address": null,
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> verifyRecoveryCode({required String email, required String code}) async {
    await _client.auth.verifyOTP(email: email, token: code, type: OtpType.recovery);
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

