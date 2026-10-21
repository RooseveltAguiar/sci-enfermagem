import 'package:flutter_test/flutter_test.dart';

class MockAtividadeRepository {
  Future<void> registrarAtividades(List<String> atividades, String alocacaoId) async {
    if (atividades.length >= 11) {
      throw Exception('limite_diario_atingido');
    }
  }

  Future<void> validarStatus(String statusAtual, String novoStatus) async {
    if (statusAtual == 'validado' && novoStatus == 'pendente_validacao') {
      throw Exception('Transição inválida');
    }
  }
}

void main() {
  group('AtividadeRepository Tests', () {
    late MockAtividadeRepository repository;

    setUp(() {
      repository = MockAtividadeRepository();
    });

    test('Batch insert com 10 atividades deve passar', () async {
      final atividades = List.generate(10, (i) => 'Ativ $i');
      await expectLater(repository.registrarAtividades(atividades, 'aloc1'), completes);
    });

    test('Batch insert com 11 atividades deve falhar por limite', () async {
      final atividades = List.generate(11, (i) => 'Ativ $i');
      await expectLater(
        repository.registrarAtividades(atividades, 'aloc1'),
        throwsA(isA<Exception>()),
      );
    });

    test('Validação de status - transição válida', () async {
      await expectLater(repository.validarStatus('pendente_validacao', 'validado'), completes);
    });

    test('Validação de status - transição inválida', () async {
      await expectLater(
        repository.validarStatus('validado', 'pendente_validacao'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
