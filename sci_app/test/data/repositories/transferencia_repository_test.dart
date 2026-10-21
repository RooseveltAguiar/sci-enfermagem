// test/data/repositories/transferencia_repository_test.dart
//
// REESCRITO integralmente contra a versão mais recente do código
// recebida do Antigravity — as 4 mensagens amigáveis mudaram de texto
// em relação à versão anterior (que este arquivo testava antes), e um
// segundo bloco `catch (e)` genérico foi adicionado para exceções
// que não são PostgrestException (ex: falha de rede antes de virar
// um erro Postgres estruturado).
//
// Mesmo padrão de mock de avaliacao_repository_test.dart — .rpc()
// retorna PostgrestFilterBuilder, que implementa Future via then().

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sci_app/data/repositories/transferencia_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

void _stubAwait(
  MockPostgrestFilterBuilder builder, {
  List<Map<String, dynamic>> value = const [],
  Object? error,
}) {
  when(() => builder.then<dynamic>(any(), onError: any(named: 'onError'))).thenAnswer(
    (invocation) {
      if (error != null) {
        final onError = invocation.namedArguments[#onError] as Function?;
        if (onError != null) {
          Future.microtask(() => onError(error, StackTrace.current));
          return Future<dynamic>.value(null);
        }
        return Future<dynamic>.error(error);
      }
      final onValue = invocation.positionalArguments[0] as Function;
      return Future<dynamic>.value(onValue(value));
    },
  );
}

void main() {
  late MockSupabaseClient mockClient;
  late MockPostgrestFilterBuilder mockFilterBuilder;
  late TransferenciaRepository repository;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockClient = MockSupabaseClient();
    mockFilterBuilder = MockPostgrestFilterBuilder();
    repository = TransferenciaRepository(mockClient);

    when(() => mockClient.rpc(any(), params: any(named: 'params')))
        .thenAnswer((_) => mockFilterBuilder);
  });

  const alunoId = 'aluno-001';
  const campoDestinoId = 'campo-002';
  const turnoDestinoId = 'turno-003';

  group('TransferenciaRepository.transferirAluno — contrato da RPC', () {
    test(
      'chama fn_transferir_aluno com exatamente os 3 parâmetros e '
      'nomes que a função real do banco espera',
      () async {
        _stubAwait(mockFilterBuilder);

        await repository.transferirAluno(
          alunoId: alunoId,
          campoDestinoId: campoDestinoId,
          turnoDestinoId: turnoDestinoId,
        );

        final captured = verify(() => mockClient.rpc(
              captureAny(),
              params: captureAny(named: 'params'),
            )).captured;

        expect(captured[0], 'fn_transferir_aluno');
        final params = captured[1] as Map<dynamic, dynamic>;
        expect(params['p_aluno_id'], alunoId);
        expect(params['p_novo_campo_id'], campoDestinoId);
        expect(params['p_novo_turno_id'], turnoDestinoId);
      },
    );

    test('sucesso não lança nenhuma exceção', () async {
      _stubAwait(mockFilterBuilder);
      await expectLater(
        repository.transferirAluno(
          alunoId: alunoId,
          campoDestinoId: campoDestinoId,
          turnoDestinoId: turnoDestinoId,
        ),
        completes,
      );
    });
  });

  group('PostgrestException — os 4 códigos reais, texto ATUAL', () {
    test('alocacao_dupla_detectada', () async {
      _stubAwait(mockFilterBuilder,
          error: const PostgrestException(
              message: 'alocacao_dupla_detectada',
              code: 'alocacao_dupla_detectada'));

      await expectLater(
        () => repository.transferirAluno(
            alunoId: alunoId,
            campoDestinoId: campoDestinoId,
            turnoDestinoId: turnoDestinoId),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensagem',
          contains('Este aluno já possui alocação ativa em outro campo. '
              'Encerre a alocação atual antes de transferir.'),
        )),
      );
    });

    test('turno_destino_invalido', () async {
      _stubAwait(mockFilterBuilder,
          error: const PostgrestException(
              message: 'turno_destino_invalido',
              code: 'turno_destino_invalido'));

      await expectLater(
        () => repository.transferirAluno(
            alunoId: alunoId,
            campoDestinoId: campoDestinoId,
            turnoDestinoId: turnoDestinoId),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensagem',
          contains('O turno de destino está inativo ou é inválido. '
              'Selecione outro turno.'),
        )),
      );
    });

    test('campo_destino_invalido', () async {
      _stubAwait(mockFilterBuilder,
          error: const PostgrestException(
              message: 'campo_destino_invalido',
              code: 'campo_destino_invalido'));

      await expectLater(
        () => repository.transferirAluno(
            alunoId: alunoId,
            campoDestinoId: campoDestinoId,
            turnoDestinoId: turnoDestinoId),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensagem',
          contains('O campo de estágio selecionado não existe ou '
              'está inativo.'),
        )),
      );
    });

    test('apenas_coordenacao', () async {
      _stubAwait(mockFilterBuilder,
          error: const PostgrestException(
              message: 'apenas_coordenacao', code: 'apenas_coordenacao'));

      await expectLater(
        () => repository.transferirAluno(
            alunoId: alunoId,
            campoDestinoId: campoDestinoId,
            turnoDestinoId: turnoDestinoId),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensagem',
          contains('Acesso negado: apenas membros da coordenação '
              'podem transferir alunos.'),
        )),
      );
    });

    test('code vem em maiúsculas — code?.toLowerCase() normaliza '
        'antes de comparar', () async {
      _stubAwait(mockFilterBuilder,
          error: const PostgrestException(
              message: 'erro genérico do postgres',
              code: 'CAMPO_DESTINO_INVALIDO'));

      await expectLater(
        () => repository.transferirAluno(
            alunoId: alunoId,
            campoDestinoId: campoDestinoId,
            turnoDestinoId: turnoDestinoId),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensagem',
          contains('O campo de estágio selecionado não existe ou '
              'está inativo.'),
        )),
      );
    });

    test('code nulo, só a mensagem contém o texto do código', () async {
      _stubAwait(mockFilterBuilder,
          error: const PostgrestException(
              message: 'ERROR: turno_destino_invalido detectado no banco',
              code: null));

      await expectLater(
        () => repository.transferirAluno(
            alunoId: alunoId,
            campoDestinoId: campoDestinoId,
            turnoDestinoId: turnoDestinoId),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensagem',
          contains('O turno de destino está inativo ou é inválido. '
              'Selecione outro turno.'),
        )),
      );
    });

    test('código desconhecido cai na mensagem genérica ATUAL '
        '("Falha na transferência:", não mais "Erro ao transferir")',
        () async {
      _stubAwait(mockFilterBuilder,
          error: const PostgrestException(
              message: 'erro_nao_mapeado_qualquer',
              code: 'erro_nao_mapeado_qualquer'));

      await expectLater(
        () => repository.transferirAluno(
            alunoId: alunoId,
            campoDestinoId: campoDestinoId,
            turnoDestinoId: turnoDestinoId),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensagem',
          allOf(
            contains('Falha na transferência:'),
            contains('erro_nao_mapeado_qualquer'),
          ),
        )),
      );
    });
  });

  group(
    'catch (e) genérico — exceções que NÃO são PostgrestException '
    '(ex: falha de rede antes de virar erro Postgres estruturado) — '
    'bloco novo, fecha as 9 linhas antes descobertas (68.97%)',
    () {
      test('erro genérico cujo texto contém uma palavra-chave '
          'reconhecida → mesma mensagem amigável do caminho '
          'PostgrestException', () async {
        _stubAwait(mockFilterBuilder,
            error: Exception('timeout de rede: alocacao_dupla_detectada'));

        await expectLater(
          () => repository.transferirAluno(
              alunoId: alunoId,
              campoDestinoId: campoDestinoId,
              turnoDestinoId: turnoDestinoId),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'mensagem',
            contains('Este aluno já possui alocação ativa em outro '
                'campo. Encerre a alocação atual antes de transferir.'),
          )),
        );
      });

      test('erro genérico SEM nenhuma palavra-chave reconhecida → '
          'rethrow do erro original, sem reescrever a mensagem',
          () async {
        final erroOriginal = Exception('falha de conexão totalmente '
            'genérica, sem relação com nenhum código de negócio');

        _stubAwait(mockFilterBuilder, error: erroOriginal);

        await expectLater(
          () => repository.transferirAluno(
              alunoId: alunoId,
              campoDestinoId: campoDestinoId,
              turnoDestinoId: turnoDestinoId),
          throwsA(same(erroOriginal)),
        );
      });

      test('cada uma das 4 palavras-chave é reconhecida também no '
          'caminho não-Postgrest, não só no caminho Postgrest',
          () async {
        final casos = {
          'turno_destino_invalido': 'O turno de destino está inativo ou '
              'é inválido. Selecione outro turno.',
          'campo_destino_invalido': 'O campo de estágio selecionado não '
              'existe ou está inativo.',
          'apenas_coordenacao': 'Acesso negado: apenas membros da '
              'coordenação podem transferir alunos.',
        };

        for (final entry in casos.entries) {
          final localClient = MockSupabaseClient();
          final localBuilder = MockPostgrestFilterBuilder();
          final localRepo = TransferenciaRepository(localClient);

          when(() => localClient.rpc(any(), params: any(named: 'params')))
              .thenAnswer((_) => localBuilder);
          _stubAwait(localBuilder,
              error: Exception('erro genérico contendo ${entry.key}'));

          await expectLater(
            () => localRepo.transferirAluno(
                alunoId: alunoId,
                campoDestinoId: campoDestinoId,
                turnoDestinoId: turnoDestinoId),
            throwsA(isA<Exception>().having(
              (e) => e.toString(),
              'mensagem',
              contains(entry.value),
            )),
            reason: 'Falhou para a palavra-chave ${entry.key}',
          );
        }
      });
    },
  );
}
