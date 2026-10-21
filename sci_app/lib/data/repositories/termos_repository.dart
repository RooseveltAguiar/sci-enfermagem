import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/termo_model.dart';

class TermosRepository {
  final SupabaseClient _supabase;

  TermosRepository(this._supabase);

  Future<TermoModel?> buscarTermoAtivo() async {
    final response = await _supabase
        .from('termos')
        .select()
        .eq('ativo', true)
        .isFilter('deleted_at', null)
        .maybeSingle();

    if (response == null) return null;
    return TermoModel.fromJson(response);
  }

  Future<List<TermoModel>> listarTodasVersoes() async {
    final response = await _supabase
        .from('termos')
        .select()
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((e) => TermoModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> criarTermo({
    required String titulo,
    required String versao,
    required String conteudo,
    required DateTime vigenciaInicio,
    required bool ativar,
  }) async {
    final payload = {
      'titulo': titulo,
      'versao': versao,
      'conteudo': conteudo,
      'vigencia_inicio': vigenciaInicio.toIso8601String(),
      'ativo': ativar,
      'created_by': _supabase.auth.currentUser?.id,
    };

    await _supabase.from('termos').insert(payload);
  }

  Future<void> ativarVersao(String id) async {
    await _supabase.from('termos').update({'ativo': true}).eq('id', id);
  }

  Future<void> aceitarTermo(String versao) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('usuarios').update({
      'data_aceite_termos': DateTime.now().toIso8601String(),
      'versao_termos_aceita': versao,
    }).eq('id', userId);
  }

  Future<bool> verificarTermoPendente(String userId) async {
    final termoAtivo = await buscarTermoAtivo();
    if (termoAtivo == null) return false;

    final userRes = await _supabase
        .from('usuarios')
        .select('versao_termos_aceita')
        .eq('id', userId)
        .maybeSingle();

    if (userRes == null) return false;
    final versaoAceita = userRes['versao_termos_aceita'] as String?;

    return versaoAceita != termoAtivo.versao;
  }
}
