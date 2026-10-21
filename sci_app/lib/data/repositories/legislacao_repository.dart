import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/legislacao_model.dart';

class LegislacaoRepository {
  final SupabaseClient _supabase;

  LegislacaoRepository(this._supabase);

  Future<List<LegislacaoModel>> listarLegislacoesAtivas() async {
    final response = await _supabase
        .from('legislacoes')
        .select()
        .eq('ativo', true)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((e) => LegislacaoModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LegislacaoModel> buscarLegislacaoPorId(String id) async {
    final response = await _supabase
        .from('legislacoes')
        .select()
        .eq('id', id)
        .single();

    return LegislacaoModel.fromJson(response);
  }

  Future<void> criarLegislacao({
    required String titulo,
    required String conteudo,
    required String tipo,
    DateTime? vigenciaInicio,
    DateTime? vigenciaFim,
    required bool ativo,
  }) async {
    final payload = {
      'titulo': titulo,
      'conteudo': conteudo,
      'tipo': tipo,
      'vigencia_inicio': vigenciaInicio?.toIso8601String(),
      'vigencia_fim': vigenciaFim?.toIso8601String(),
      'ativo': ativo,
      'created_by': _supabase.auth.currentUser?.id,
    };

    await _supabase.from('legislacoes').insert(payload);
  }

  Future<void> editarLegislacao({
    required String id,
    required String titulo,
    required String conteudo,
    required String tipo,
    DateTime? vigenciaInicio,
    DateTime? vigenciaFim,
    required bool ativo,
  }) async {
    final payload = {
      'titulo': titulo,
      'conteudo': conteudo,
      'tipo': tipo,
      'vigencia_inicio': vigenciaInicio?.toIso8601String(),
      'vigencia_fim': vigenciaFim?.toIso8601String(),
      'ativo': ativo,
    };

    await _supabase.from('legislacoes').update(payload).eq('id', id);
  }

  Future<void> desativarLegislacao(String id) async {
    final payload = {
      'ativo': false,
      'deleted_at': DateTime.now().toIso8601String(),
    };

    await _supabase.from('legislacoes').update(payload).eq('id', id);
  }
}
