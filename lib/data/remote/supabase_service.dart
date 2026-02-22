import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // =========================================================
  // GENERIC UPLOAD (OFFLINE-FIRST SAFE)
  // =========================================================
  Future<void> uploadRecords(
    String table,
    List<Map<String, dynamic>> records,
  ) async {
    if (records.isEmpty) return;

    await _client
        .from(table)
        .upsert(
          records,
          onConflict: 'id',
        );
  }

  // =========================================================
  // GENERIC DOWNLOAD (DELTA SYNC)
  // =========================================================
  Future<List<Map<String, dynamic>>> downloadUpdates(
    String table,
    DateTime lastSync,
  ) async {
    final response = await _client
        .from(table)
        .select()
        .gt('updated_at', lastSync.toIso8601String());

    return List<Map<String, dynamic>>.from(response);
  }

  // =========================================================
  // AUTH
  // =========================================================
  Future<AuthResponse> signUp(
    String email,
    String password, {
    Map<String, dynamic>? data,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  Future<AuthResponse> login(
    String email,
    String password,
  ) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // =========================================================
  // SESSION HELPERS
  // =========================================================
  Session? get currentSession =>
      _client.auth.currentSession;

  User? get currentUser =>
      _client.auth.currentUser;

  String? get currentUserId =>
      _client.auth.currentUser?.id;

  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;
}