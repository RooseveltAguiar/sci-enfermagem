import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/conflito_model.dart';

class ConflitosRepository {
  final SupabaseClient _supabase;

  ConflitosRepository(this._supabase);

  Future<List<ConflitoModel>> listarConflitos({
    String? campoId,
    DateTime? dataInicio,
    DateTime? dataFim,
  }) async {
    var query = _supabase
        .from('conflitos')
        .select('*, usuarios(nome), campos_estagio(nome)')
        .isFilter('deleted_at', null);

    if (campoId != null && campoId.isNotEmpty && campoId != 'todos') {
      query = query.eq('campo_id', campoId);
    }
    if (dataInicio != null) {
      query = query.gte('data_ocorrencia', dataInicio.toIso8601String());
    }
    if (dataFim != null) {
      query = query.lte('data_ocorrencia', dataFim.toIso8601String());
    }

    final response = await query.order('data_ocorrencia', ascending: false);

    return (response as List<dynamic>)
        .map((e) => ConflitoModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> registrarConflito({
    required String alunoId,
    required String campoId,
    required String descricao,
    required DateTime dataOcorrencia,
  }) async {
    await _supabase.from('conflitos').insert({
      'aluno_id': alunoId,
      'campo_id': campoId,
      'descricao': descricao,
      'data_ocorrencia': dataOcorrencia.toIso8601String(),
      'created_by': _supabase.auth.currentUser?.id,
    });
  }
}
