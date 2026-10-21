import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario_model.dart';

class UsuariosRepository {
  final SupabaseClient _supabase;

  UsuariosRepository([SupabaseClient? supabase])
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<UsuarioModel>> listarUsuariosPorPerfil(String perfil) async {
    try {
      final response = await _supabase
          .from('vw_usuarios_publico')
          .select()
          .eq('perfil', perfil)
          .order('nome', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((e) => UsuarioModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final response = await _supabase
          .from('usuarios')
          .select()
          .eq('perfil', perfil)
          .order('nome', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((e) => UsuarioModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  Future<bool> verificarDuplicidadeCpf(String cpf) async {
    final cpfDigits = cpf.replaceAll(RegExp(r'\D'), '');
    final response = await _supabase
        .from('usuarios')
        .select('id')
        .eq('cpf', cpfDigits);

    final List<dynamic> data = response as List<dynamic>;
    if (data.isNotEmpty) return true;

    // Verificar também se o CPF está armazenado com máscara
    final responseMasked =
        await _supabase.from('usuarios').select('id').eq('cpf', cpf);
    final List<dynamic> dataMasked = responseMasked as List<dynamic>;
    return dataMasked.isNotEmpty;
  }

  Future<Map<String, dynamic>> criarUsuario({
    required String cpf,
    required String nome,
    required String perfil,
    String? email,
  }) async {
    final response = await _supabase.functions.invoke(
      'criar-usuario',
      body: {
        'cpf': cpf,
        'nome': nome,
        'perfil': perfil,
        'email': email,
      },
    );

    if (response.status != 200) {
      final data = response.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Falha ao criar usuário.';
      throw Exception(msg);
    }

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> editarUsuario({
    required String id,
    required String nome,
    String? email,
  }) async {
    await _supabase.from('usuarios').update({
      'nome': nome,
      'email': email,
    }).eq('id', id);
  }

  Future<void> desativarUsuario(String id) async {
    await _supabase.from('usuarios').update({
      'ativo': false,
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> reativarUsuario(String id) async {
    await _supabase.from('usuarios').update({
      'ativo': true,
      'deleted_at': null,
    }).eq('id', id);
  }
}
