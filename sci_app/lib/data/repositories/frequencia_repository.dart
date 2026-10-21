import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/location_service.dart';

class FrequenciaRepository {
  final SupabaseClient _supabase;

  FrequenciaRepository(this._supabase);

  Future<void> registrarPonto({
    required String alunoId,
    required String tipoRegistro, // 'ENTRADA' ou 'SAIDA'
    required LocationResult location,
  }) async {
    // 1. Buscar a alocação ativa do aluno
    final alocacaoResponse = await _supabase
        .from('alocacoes')
        .select('id, turnos_permitidos')
        .eq('aluno_id', alunoId)
        .eq('status', 'ativa')
        .limit(1)
        .maybeSingle();

    if (alocacaoResponse == null) {
      throw Exception('Nenhuma alocação ativa encontrada para este aluno.');
    }

    final alocacaoId = alocacaoResponse['id'];
    
    // Para a Sprint 1, vamos pegar o primeiro turno permitido da alocação
    final turnosPermitidos = alocacaoResponse['turnos_permitidos'] as List<dynamic>? ?? [];
    if (turnosPermitidos.isEmpty) {
      throw Exception('Nenhum turno configurado na alocação.');
    }
    final turnoId = turnosPermitidos.first.toString();

    // 2. Inserir a frequência
    final payload = buildInsertPayload(alocacaoId, turnoId, tipoRegistro, location);
    await _supabase.from('frequencias').insert(payload);
  }

  /// Expõe a lógica de payload para facilitar testes unitários dos cenários de GPS
  Map<String, dynamic> buildInsertPayload(
    String alocacaoId,
    String turnoId,
    String tipoRegistro,
    LocationResult location,
  ) {
    return {
      'alocacao_id': alocacaoId,
      'turno_id': turnoId,
      'tipo_registro': tipoRegistro,
      'lat_registro': location.isAvailable ? location.latitude : null,
      'lng_registro': location.isAvailable ? location.longitude : null,
      'gps_disponivel': location.isAvailable,
      'gps_precisao_metros': location.accuracy,
    };
  }
}

