import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/providers/banco_horas_provider.dart';

void main() {
  group('BancoHoras Model Tests (Sprint 10)', () {
    test('BancoHorasAluno identifica credito e deficit corretamente', () {
      final jsonCredito = {
        'aluno_id': 'aluno-1',
        'saldo_minutos': 180,
      };

      final jsonDeficit = {
        'aluno_id': 'aluno-2',
        'saldo_minutos': -120,
      };

      final saldoCred = BancoHorasAluno.fromJson(jsonCredito);
      final saldoDef = BancoHorasAluno.fromJson(jsonDeficit);

      expect(saldoCred.isCredito, isTrue);
      expect(saldoCred.isDeficit, isFalse);
      expect(saldoCred.saldoHoras, equals(3.0));

      expect(saldoDef.isCredito, isFalse);
      expect(saldoDef.isDeficit, isTrue);
      expect(saldoDef.saldoHoras, equals(-2.0));
    });

    test('BancoHorasLancamento deserializa campos corretamente', () {
      final json = {
        'id': 'lanc-01',
        'aluno_id': 'aluno-1',
        'data_lancamento': '2026-08-21',
        'tipo': 'credito',
        'minutos': 120,
        'motivo': 'Reposição de turno em 21/08',
        'saldo_resultante_minutos': 120,
      };

      final item = BancoHorasLancamento.fromJson(json);

      expect(item.id, equals('lanc-01'));
      expect(item.tipo, equals('credito'));
      expect(item.horas, equals(2.0));
      expect(item.motivo, equals('Reposição de turno em 21/08'));
    });
  });
}
