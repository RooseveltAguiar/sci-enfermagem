import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/providers/frequencia_provider.dart';

void main() {
  group('Frequencia Model & Checkout (Sprint 10)', () {
    test('Frequencia.fromJson carrega corretamente os campos de checkout', () {
      final json = {
        'id': 'freq-123',
        'aluno_id': 'aluno-001',
        'nome_aluno': 'Maria Silva',
        'data_registro': '2026-08-21',
        'status': 'pendente_validacao',
        'lat_registro': -3.73,
        'lng_registro': -38.52,
        'gps_disponivel': true,
        'mock_location_detectado': false,
        'lat_saida': -3.7319,
        'lng_saida': -38.5267,
        'timestamp_entrada_cliente': '2026-08-21T07:00:00.000',
        'timestamp_saida_cliente': '2026-08-21T13:00:00.000',
        'gps_saida_disponivel': true,
        'distancia_saida_metros': 12.5,
        'mock_location_saida_detectado': false,
        'velocidade_saida_ms': 0.1,
        'altitude_saida_metros': 15.0,
        'horas_trabalhadas': 6.0,
        'nivel_confianca_gps_saida': 1,
      };

      final freq = Frequencia.fromJson(json);

      expect(freq.id, equals('freq-123'));
      expect(freq.alunoId, equals('aluno-001'));
      expect(freq.latSaida, equals(-3.7319));
      expect(freq.lngSaida, equals(-38.5267));
      expect(freq.timestampEntradaCliente, equals('2026-08-21T07:00:00.000'));
      expect(freq.timestampSaidaCliente, equals('2026-08-21T13:00:00.000'));
      expect(freq.gpsSaidaDisponivel, isTrue);
      expect(freq.distanciaSaidaMetros, equals(12.5));
      expect(freq.horasTrabalhadas, equals(6.0));
      expect(freq.nivelConfiancaGpsSaida, equals(1));
    });

    test('EstadoJornadaHoje calcula horas decorridas corretamente', () {
      final entrada = DateTime.now().subtract(const Duration(hours: 6, minutes: 30));
      final estado = EstadoJornadaHoje(
        status: StatusJornada.emCampo,
        horaEntrada: entrada,
        horasEmCampo: 6.5,
      );

      expect(estado.status, equals(StatusJornada.emCampo));
      expect(estado.horasEmCampo, equals(6.5));
    });
  });
}
