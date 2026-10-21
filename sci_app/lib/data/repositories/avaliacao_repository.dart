import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/avaliacao_model.dart';

class AvaliacaoRepository {
  final SupabaseClient _supabase;
  static final List<AvaliacaoModel> _localStore = [
    AvaliacaoModel(
      id: 'mock-sample-1',
      alocacaoId: '00000000-0000-0000-0000-000000000000',
      avaliadorId: '00000000101',
      tipo: 'setorial',
      periodoReferencia: DateTime.now(),
      notaGeral: 8,
      pontosPositivos: 'Excelente infraestrutura e apoio da equipe de enfermagem.',
      pontosMelhoria: 'Maior disponibilidade de insumos no turno da noite.',
      comentarioLivre: 'Estágio muito proveitoso.',
      status: 'submetida',
    ),
    AvaliacaoModel(
      id: 'mock-sample-2',
      alocacaoId: '00000000-0000-0000-0000-000000000000',
      avaliadorId: '00000000201',
      tipo: 'do_interno',
      periodoReferencia: DateTime.now(),
      notaGeral: 9,
      pontosPositivos: 'Aluno demonstra excelente pontualidade e habilidade técnica.',
      pontosMelhoria: 'Aprimorar registros em prontuário.',
      comentarioLivre: 'Desempenho muito satisfatório.',
      status: 'validada',
    ),
  ];

  AvaliacaoRepository(this._supabase);

  Future<List<AvaliacaoModel>> listar() async {
    final response = await _supabase
        .from('avaliacoes')
        .select()
        .isFilter('deleted_at', null)
        .order('periodo_referencia', ascending: false);
    final list = (response as List<dynamic>)
        .map((e) => AvaliacaoModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<AvaliacaoModel> salvarRascunho(Map<String, dynamic> data) async {
    String? userId;
    try {
      userId = _supabase.auth.currentUser?.id;
    } catch (_) {}

    userId ??= data['aluno_id'] as String?;
    userId ??= data['avaliador_id'] as String?;

    if (userId == null || userId.isEmpty) {
      throw Exception('Usuário não autenticado no Supabase.');
    }

    String alocacaoId = data['alocacao_id'] ?? '';
    if (alocacaoId.isEmpty || alocacaoId == '00000000-0000-0000-0000-000000000000') {
      try {
        final alocRes = await _supabase
            .from('alocacoes_alunos')
            .select('id')
            .eq('aluno_id', userId)
            .isFilter('deleted_at', null)
            .order('data_inicio', ascending: false)
            .limit(1)
            .maybeSingle();

        if (alocRes != null && alocRes['id'] != null) {
          alocacaoId = alocRes['id'] as String;
        }
      } catch (_) {}
    }

    if (alocacaoId.isEmpty || alocacaoId == '00000000-0000-0000-0000-000000000000') {
      try {
        final alocRes = await _supabase
            .from('alocacoes_alunos')
            .select('id')
            .isFilter('deleted_at', null)
            .limit(1)
            .maybeSingle();

        if (alocRes != null && alocRes['id'] != null) {
          alocacaoId = alocRes['id'] as String;
        }
      } catch (_) {}
    }

    final pontosPos = data['pontos_positivos'] as String?;
    final pontosMelh = data['pontos_melhoria'] as String?;
    final comLivre = data['comentario_livre'] as String?;

    final payload = <String, dynamic>{
      ...data,
      'aluno_id': data['aluno_id'] ?? userId,
      'avaliador_id': userId,
      'created_by': userId,
      'status': 'rascunho',
      'pontos_positivos': (pontosPos != null && pontosPos.trim().length >= 20) ? pontosPos.trim() : null,
      'pontos_melhoria': (pontosMelh != null && pontosMelh.trim().length >= 20) ? pontosMelh.trim() : null,
      'comentario_livre': (comLivre != null && comLivre.trim().isNotEmpty) ? comLivre.trim() : null,
    };

    if (alocacaoId.isNotEmpty && alocacaoId != '00000000-0000-0000-0000-000000000000') {
      payload['alocacao_id'] = alocacaoId;
    }

    final response = await _supabase
        .from('avaliacoes')
        .upsert(payload)
        .select()
        .single();
    final model = AvaliacaoModel.fromJson(response);
    _localStore.removeWhere((a) => a.id == model.id);
    _localStore.insert(0, model);
    return model;
  }

  Future<void> excluirRascunho(String id) async {
    await _supabase.from('avaliacoes').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    _localStore.removeWhere((a) => a.id == id);
  }

  Future<void> submeter(String id) async {
    String? userId;
    try {
      userId = _supabase.auth.currentUser?.id;
    } catch (_) {}

    await _supabase.from('avaliacoes').update({
      'status': 'submetida',
      'updated_at': DateTime.now().toIso8601String(),
      'updated_by':? userId,
    }).eq('id', id);

    final idx = _localStore.indexWhere((a) => a.id == id);
    if (idx != -1) {
      final old = _localStore[idx];
      _localStore[idx] = AvaliacaoModel(
        id: old.id,
        alocacaoId: old.alocacaoId,
        tipo: old.tipo,
        periodoReferencia: old.periodoReferencia,
        status: 'submetida',
        notaGeral: old.notaGeral,
        pontosPositivos: old.pontosPositivos,
        pontosMelhoria: old.pontosMelhoria,
        comentarioLivre: old.comentarioLivre,
        comentarioValidacao: old.comentarioValidacao,
        avaliadorId: old.avaliadorId,
        avaliadorNome: old.avaliadorNome,
        alunoNome: old.alunoNome,
        campoNome: old.campoNome,
      );
    }
  }

  Future<void> validar(String id, {String? comentario}) async {
    final payload = <String, dynamic>{
      'status': 'validada',
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (comentario != null && comentario.trim().isNotEmpty) {
      payload['comentario_validacao'] = comentario.trim();
    }
    await _supabase.from('avaliacoes').update(payload).eq('id', id);

    final idx = _localStore.indexWhere((a) => a.id == id);
    if (idx != -1) {
      final old = _localStore[idx];
      _localStore[idx] = AvaliacaoModel(
        id: old.id,
        alocacaoId: old.alocacaoId,
        tipo: old.tipo,
        periodoReferencia: old.periodoReferencia,
        status: 'validada',
        notaGeral: old.notaGeral,
        pontosPositivos: old.pontosPositivos,
        pontosMelhoria: old.pontosMelhoria,
        comentarioLivre: old.comentarioLivre,
        comentarioValidacao: comentario ?? old.comentarioValidacao,
        avaliadorId: old.avaliadorId,
        avaliadorNome: old.avaliadorNome,
        alunoNome: old.alunoNome,
        campoNome: old.campoNome,
      );
    }
  }

  Future<void> aprovar(String id, {String? comentario}) async {
    final payload = <String, dynamic>{
      'status': 'aprovada',
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (comentario != null && comentario.trim().isNotEmpty) {
      payload['comentario_validacao'] = comentario.trim();
    }
    await _supabase.from('avaliacoes').update(payload).eq('id', id);

    final idx = _localStore.indexWhere((a) => a.id == id);
    if (idx != -1) {
      final old = _localStore[idx];
      _localStore[idx] = AvaliacaoModel(
        id: old.id,
        alocacaoId: old.alocacaoId,
        tipo: old.tipo,
        periodoReferencia: old.periodoReferencia,
        status: 'aprovada',
        notaGeral: old.notaGeral,
        pontosPositivos: old.pontosPositivos,
        pontosMelhoria: old.pontosMelhoria,
        comentarioLivre: old.comentarioLivre,
        comentarioValidacao: comentario ?? old.comentarioValidacao,
        avaliadorId: old.avaliadorId,
        avaliadorNome: old.avaliadorNome,
        alunoNome: old.alunoNome,
        campoNome: old.campoNome,
      );
    }
  }

  Future<void> devolver(String id, String comentario) async {
    if (comentario.trim().length < 20) {
      throw Exception('O comentário de devolução deve ter no mínimo 20 caracteres.');
    }
    await _supabase.from('avaliacoes').update({
      'status': 'rascunho',
      'comentario_validacao': comentario.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);

    final idx = _localStore.indexWhere((a) => a.id == id);
    if (idx != -1) {
      final old = _localStore[idx];
      _localStore[idx] = AvaliacaoModel(
        id: old.id,
        alocacaoId: old.alocacaoId,
        tipo: old.tipo,
        periodoReferencia: old.periodoReferencia,
        status: 'rascunho',
        notaGeral: old.notaGeral,
        pontosPositivos: old.pontosPositivos,
        pontosMelhoria: old.pontosMelhoria,
        comentarioLivre: old.comentarioLivre,
        comentarioValidacao: comentario.trim(),
        avaliadorId: old.avaliadorId,
        avaliadorNome: old.avaliadorNome,
        alunoNome: old.alunoNome,
        campoNome: old.campoNome,
      );
    }
  }
}
