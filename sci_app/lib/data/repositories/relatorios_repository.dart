import 'package:supabase_flutter/supabase_flutter.dart';

class RelatoriosRepository {
  final SupabaseClient _supabase;

  RelatoriosRepository([SupabaseClient? supabase])
      : _supabase = supabase ?? Supabase.instance.client;

  String mapTipoParaRpc(String tipo) {
    switch (tipo) {
      case 'frequencia':
        return 'fn_relatorio_frequencia';
      case 'atividades':
        return 'fn_relatorio_atividades';
      case 'avaliacoes':
        return 'fn_relatorio_avaliacoes';
      case 'internos_campo':
        return 'fn_relatorio_internos_em_campo';
      case 'locais_estagio':
        return 'fn_relatorio_locais_estagio';
      case 'supervisores':
        return 'fn_relatorio_supervisores';
      default:
        throw ArgumentError('Tipo de relatório desconhecido: $tipo');
    }
  }

  Future<List<Map<String, dynamic>>> gerarRelatorio({
    required String tipo,
    required DateTime dataInicio,
    required DateTime dataFim,
    String? campoId,
  }) async {
    final rpcName = mapTipoParaRpc(tipo);
    final params = <String, dynamic>{
      'p_data_inicio': _formatDate(dataInicio),
      'p_data_fim': _formatDate(dataFim),
    };

    if (campoId != null && campoId.isNotEmpty && campoId != 'todos') {
      params['p_campo_id'] = campoId;
    } else {
      params['p_campo_id'] = null;
    }

    final response = await _supabase.rpc(rpcName, params: params);

    if (response == null) return [];
    if (response is List) {
      return response
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    throw Exception('Formato de resposta inesperado do relatório $tipo.');
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
