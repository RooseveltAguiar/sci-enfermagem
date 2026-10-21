import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/cpf_formatter.dart';
import '../models/usuario_model.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
  User? get currentUser => _supabase.auth.currentUser;

  Future<AuthResponse> signInWithCpf(String cpf, String password) async {
    final email = CpfFormatter.toAuthEmail(cpf);
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<UsuarioModel?> getUsuario(String userId) async {
    try {
      final response = await _supabase
          .from('usuarios')
          .select()
          .eq('id', userId)
          .single();
      
      return UsuarioModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }
}
