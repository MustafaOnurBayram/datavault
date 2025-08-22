import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final SupabaseClient _supa = Supabase.instance.client;

  static String? get uid => _supa.auth.currentUser?.id;

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final e = email.trim(), p = password.trim();
    if (e.isEmpty || p.isEmpty) throw Exception('Email ve şifre boş olamaz.');

    final res = await _supa.auth.signInWithPassword(email: e, password: p);
    if (res.session == null) {
      throw Exception('Giriş başarısız.');
    }
  }

  static Future<void> register({
    required String email,
    required String password,
  }) async {
    final e = email.trim(), p = password.trim();
    if (e.isEmpty || p.isEmpty) throw Exception('Email ve şifre boş olamaz.');

    final res = await _supa.auth.signUp(email: e, password: p);
    if (res.user == null) {
      throw Exception('Kayıt başarısız.');
    }
    // Eğer “Confirm email” açıksa kullanıcı mail onayı bekler.
  }

  static Future<void> signOut() async {
    await _supa.auth.signOut();
  }
}
