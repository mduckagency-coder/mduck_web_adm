import "package:supabase_flutter/supabase_flutter.dart";

class AdminAuthRepository {
  final _client = Supabase.instance.client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Confirma que o usuario logado esta cadastrado como gestor/admin.
  Future<bool> isManager() async {
    final userId = currentUser?.id;
    if (userId == null) return false;
    final result = await _client
        .from("managers")
        .select("id")
        .eq("id", userId)
        .maybeSingle();
    return result != null;
  }
}
