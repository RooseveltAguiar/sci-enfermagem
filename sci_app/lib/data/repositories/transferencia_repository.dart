import 'package:supabase_flutter/supabase_flutter.dart';

class TransferenciaRepository {
  final SupabaseClient _supabase;

  TransferenciaRepository(this._supabase);

  Future<void> transferirAluno({
    required String alunoId,
    required String campoDestinoId,
    required String turnoDestinoId,
  }) async {
    try {
      await _supabase.rpc(
        'fn_transferir_aluno',
        params: {
          'p_aluno_id': alunoId,
          'p_novo_campo_id': campoDestinoId,
          'p_novo_turno_id': turnoDestinoId,
        },
      );
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      final code = e.code?.toLowerCase() ?? '';
      if (msg.contains('alocacao_dupla_detectada') ||
          msg.contains('alocacao_ativa_em_outro_campo') ||
          msg.contains('alocacao_em_multiplos_campos') ||
          code == 'alocacao_dupla_detectada' ||
          code == 'alocacao_ativa_em_outro_campo' ||
          code == 'alocacao_em_multiplos_campos') {
        throw Exception(
            'Este aluno já possui alocação ativa em outro campo. Encerre a alocação atual antes de transferir.');
      } else if (msg.contains('turno_destino_invalido') ||
          code == 'turno_destino_invalido') {
        throw Exception(
            'O turno de destino está inativo ou é inválido. Selecione outro turno.');
      } else if (msg.contains('campo_destino_invalido') ||
          code == 'campo_destino_invalido') {
        throw Exception(
            'O campo de estágio selecionado não existe ou está inativo.');
      } else if (msg.contains('apenas_coordenacao') ||
          code == 'apenas_coordenacao') {
        throw Exception(
            'Acesso negado: apenas membros da coordenação podem transferir alunos.');
      }
      throw Exception('Falha na transferência: ${e.message}');
    } catch (e) {
      final text = e.toString().toLowerCase();
      if (text.contains('alocacao_dupla_detectada') ||
          text.contains('alocacao_ativa_em_outro_campo') ||
          text.contains('alocacao_em_multiplos_campos')) {
        throw Exception(
            'Este aluno já possui alocação ativa em outro campo. Encerre a alocação atual antes de transferir.');
      } else if (text.contains('turno_destino_invalido')) {
        throw Exception(
            'O turno de destino está inativo ou é inválido. Selecione outro turno.');
      } else if (text.contains('campo_destino_invalido')) {
        throw Exception(
            'O campo de estágio selecionado não existe ou está inativo.');
      } else if (text.contains('apenas_coordenacao')) {
        throw Exception(
            'Acesso negado: apenas membros da coordenação podem transferir alunos.');
      }
      rethrow;
    }
  }
}
