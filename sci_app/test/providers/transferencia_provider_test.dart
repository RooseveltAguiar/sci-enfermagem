// test/providers/transferencia_provider_test.dart
//
// Testes de PROVIDER (não de repository) — verifica que
// TransferenciaController transiciona estado corretamente e propaga
// os argumentos certos para TransferenciaRepository.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sci_app/data/repositories/transferencia_repository.dart';
import 'package:sci_app/providers/transferencia_provider.dart';

class MockTransferenciaRepository extends Mock
    implements TransferenciaRepository {}

void main() {
  late MockTransferenciaRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockTransferenciaRepository();
    container = ProviderContainer(
      overrides: [
        transferenciaRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);
  });

  group('TransferenciaController.transferirAluno', () {
    const alunoId = 'aluno-001';
    const campoDestinoId = 'campo-002';
    const turnoDestinoId = 'turno-003';

    test(
      'propaga os 3 argumentos exatos do método público para o '
      'repository — isto é o que teria pego o bug original de '
      'nomenclatura de parâmetro se ele estivesse no controller '
      'em vez de no repository',
      () async {
        when(() => mockRepo.transferirAluno(
              alunoId: any(named: 'alunoId'),
              campoDestinoId: any(named: 'campoDestinoId'),
              turnoDestinoId: any(named: 'turnoDestinoId'),
            )).thenAnswer((_) async {});

        final controller =
            container.read(transferenciaControllerProvider.notifier);

        await controller.transferirAluno(
          alunoId: alunoId,
          campoDestinoId: campoDestinoId,
          turnoDestinoId: turnoDestinoId,
        );

        final captured = verify(() => mockRepo.transferirAluno(
              alunoId: captureAny(named: 'alunoId'),
              campoDestinoId: captureAny(named: 'campoDestinoId'),
              turnoDestinoId: captureAny(named: 'turnoDestinoId'),
            )).captured;

        expect(captured[0], alunoId);
        expect(captured[1], campoDestinoId);
        expect(captured[2], turnoDestinoId);
      },
    );

    test('em sucesso, estado final é isLoading=false, sucesso=true, '
        'erro=null', () async {
      when(() => mockRepo.transferirAluno(
            alunoId: any(named: 'alunoId'),
            campoDestinoId: any(named: 'campoDestinoId'),
            turnoDestinoId: any(named: 'turnoDestinoId'),
          )).thenAnswer((_) async {});

      final controller =
          container.read(transferenciaControllerProvider.notifier);

      await controller.transferirAluno(
        alunoId: alunoId,
        campoDestinoId: campoDestinoId,
        turnoDestinoId: turnoDestinoId,
      );

      final state = container.read(transferenciaControllerProvider);
      expect(state.isLoading, false);
      expect(state.sucesso, true);
      expect(state.erro, isNull);
    });

    test(
      'emite estado de loading (isLoading=true, sucesso=false) antes '
      'de resolver — captura via listener, não apenas o estado final',
      () async {
        when(() => mockRepo.transferirAluno(
              alunoId: any(named: 'alunoId'),
              campoDestinoId: any(named: 'campoDestinoId'),
              turnoDestinoId: any(named: 'turnoDestinoId'),
            )).thenAnswer(
          (_) => Future.delayed(const Duration(milliseconds: 10)),
        );

        final states = <TransferenciaState>[];
        container.listen<TransferenciaState>(
          transferenciaControllerProvider,
          (previous, next) => states.add(next),
          fireImmediately: true,
        );

        final controller =
            container.read(transferenciaControllerProvider.notifier);

        final future = controller.transferirAluno(
          alunoId: alunoId,
          campoDestinoId: campoDestinoId,
          turnoDestinoId: turnoDestinoId,
        );

        // Estado imediatamente após a chamada, antes do await resolver.
        await Future.delayed(const Duration(milliseconds: 1));
        expect(
          states.any((s) => s.isLoading == true && s.sucesso == false),
          isTrue,
          reason: 'Deveria ter emitido um estado de loading intermediário',
        );

        await future;

        expect(states.last.isLoading, false);
        expect(states.last.sucesso, true);
      },
    );

    test(
      'em falha, captura erro sem o prefixo "Exception: " '
      '(replaceAll aplicado corretamente) e re-lança para o chamador',
      () async {
        when(() => mockRepo.transferirAluno(
              alunoId: any(named: 'alunoId'),
              campoDestinoId: any(named: 'campoDestinoId'),
              turnoDestinoId: any(named: 'turnoDestinoId'),
            )).thenThrow(Exception('Campo de destino inválido ou inativo.'));

        final controller =
            container.read(transferenciaControllerProvider.notifier);

        await expectLater(
          () => controller.transferirAluno(
            alunoId: alunoId,
            campoDestinoId: campoDestinoId,
            turnoDestinoId: turnoDestinoId,
          ),
          throwsA(isA<Exception>()),
        );

        final state = container.read(transferenciaControllerProvider);
        expect(state.isLoading, false);
        expect(state.sucesso, false);
        expect(state.erro, isNotNull);
        expect(
          state.erro!.startsWith('Exception:'),
          isFalse,
          reason: 'erro deve vir limpo do prefixo "Exception: " — '
              'controller usa replaceAll para isso',
        );
        expect(state.erro, 'Campo de destino inválido ou inativo.');
      },
    );

    test(
      'cada um dos 4 códigos reais de erro do banco, propagado pelo '
      'repository, chega ao estado do controller sem transformação '
      'adicional (o controller não reinterpreta a mensagem — só '
      'remove o prefixo Exception:)',
      () async {
        final casos = {
          'Campo de destino inválido ou inativo.': 'campo_destino_invalido',
          'Turno de destino inválido ou sem vagas.': 'turno_destino_invalido',
          'O aluno já está alocado neste campo/turno.':
              'alocacao_dupla_detectada',
          'Apenas a coordenação pode realizar transferências.':
              'apenas_coordenacao',
        };

        for (final entry in casos.entries) {
          final localMock = MockTransferenciaRepository();
          final localContainer = ProviderContainer(
            overrides: [
              transferenciaRepositoryProvider.overrideWithValue(localMock),
            ],
          );
          addTearDown(localContainer.dispose);

          when(() => localMock.transferirAluno(
                alunoId: any(named: 'alunoId'),
                campoDestinoId: any(named: 'campoDestinoId'),
                turnoDestinoId: any(named: 'turnoDestinoId'),
              )).thenThrow(Exception(entry.key));

          final controller =
              localContainer.read(transferenciaControllerProvider.notifier);

          await expectLater(
            () => controller.transferirAluno(
              alunoId: alunoId,
              campoDestinoId: campoDestinoId,
              turnoDestinoId: turnoDestinoId,
            ),
            throwsA(isA<Exception>()),
          );

          final state = localContainer.read(transferenciaControllerProvider);
          expect(state.erro, entry.key,
              reason: 'Falhou para o código de banco ${entry.value}');
        }
      },
    );
  });
}
