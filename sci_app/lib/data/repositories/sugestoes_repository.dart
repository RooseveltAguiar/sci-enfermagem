import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sugestao_model.dart';

class SugestoesRepository {
  final SupabaseClient _supabase;

  SugestoesRepository(this._supabase);

  Future<void> enviarSugestao(String conteudo) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuário não autenticado');

    await _supabase.from('sugestoes').insert({
      'autor_id': userId,
      'conteudo': conteudo,
    });
  }

  Future<List<SugestaoModel>> listarMinhasSugestoes() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('sugestoes')
        .select()
        .eq('autor_id', userId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((e) => SugestaoModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SugestaoModel>> listarTodasSugestoes({String? perfil}) async {
    // Busca com join para pegar nome e perfil do autor
    var query = _supabase
        .from('sugestoes')
        .select('*, usuarios(nome, perfil)')
        .isFilter('deleted_at', null);

    final response = await query.order('created_at', ascending: false);

    final lista = (response as List<dynamic>)
        .map((e) => SugestaoModel.fromJson(e as Map<String, dynamic>))
        .toList();

    if (perfil != null && perfil != 'todos') {
      return lista.where((s) => s.autorPerfil == perfil).toList();
    }
    return lista;
  }
}
