import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Provedor que expõe o estado do usuário (logado/deslogado)
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

// Provedor que busca o perfil (ator) logado do banco de dados (app_metadata / usuarios)
final userProfileProvider = FutureProvider<String?>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final user = supabase.auth.currentUser;
  
  if (user == null) return null;

  // No Supabase, se injetamos o perfil no JWT, podemos acessar:
  final appMetadata = user.appMetadata;
  if (appMetadata.containsKey('perfil')) {
    return appMetadata['perfil'] as String;
  }

  // Fallback: buscar na tabela usuarios
  try {
    final res = await supabase
        .from('usuarios')
        .select('perfil')
        .eq('id', user.id)
        .single();
    return res['perfil'] as String;
  } catch (e) {
    return null;
  }
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final SupabaseClient _supabase;

  AuthNotifier(this._supabase) : super(const AsyncData(null));

  Future<void> login(String cpf, String password) async {
    state = const AsyncLoading();
    try {
      // Regra de negocio: mascarar CPF para email
      // cpf deve vir limpo (somente numeros, 11 digitos)
      final cleanCpf = cpf.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanCpf.length != 11) {
        throw Exception('CPF inválido');
      }

      final email = '$cleanCpf@sci.uece.br';

      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AuthNotifier(supabase);
});
