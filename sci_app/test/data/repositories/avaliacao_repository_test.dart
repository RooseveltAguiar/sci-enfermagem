// test/data/repositories/avaliacao_repository_test.dart
//
// Testes unitários de AvaliacaoRepository — submeter, validar, aprovar, devolver.
// Mocktail 1.0.5 · supabase_flutter 2.15.0
//
// NOTA IMPORTANTE PARA QUEM MANTÉM ESTE ARQUIVO:
// PostgrestFilterBuilder implementa Future<T> internamente via `then()`.
// `await` em Dart desaçucara para uma chamada a `.then()` — por isso o
// padrão de mock aqui stuba `.then()` diretamente, em vez de tentar
// stubar um retorno "Future" num método que declara retornar
// PostgrestFilterBuilder (que causaria erro de tipo em tempo de
// compilação). Isso é o padrão correto e testado contra a API real do
// pacote — não uma simplificação.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sci_app/data/repositories/avaliacao_repository.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

class MockPostgrestListTransformBuilder extends Mock
    implements PostgrestTransformBuilder<List<Map<String, dynamic>>> {}

class MockPostgrestMapTransformBuilder extends Mock
    implements PostgrestTransformBuilder<Map<String, dynamic>> {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

/// Stuba o comportamento de `await` sobre um PostgrestFilterBuilder mockado.
/// `await builder` desaçucara para `builder.then(onValue, onError: ...)`.
/// Sem isso, qualquer `await` sobre o mock lança MissingStubError.
void _stubAwait(
  MockPostgrestFilterBuilder builder, {
  List<Map<String, dynamic>> value = const [],
  Object? error,
}) {
  when(() => builder.then<dynamic>(any(), onError: any(named: 'onError'))).thenAnswer(
    (invocation) {
      final onValue = invocation.positionalArguments[0] as Function;
      if (error != null) {
        final onError = invocation.namedArguments[#onError] as Function?;
        if (onError != null) {
          Future.microtask(() => onError(error, StackTrace.current));
          return Future<dynamic>.value(null);
        }
        return Future<dynamic>.error(error);
      }
      return Future<dynamic>.value(onValue(value));
    },
  );
}

void _stubAwaitSingle(
  MockPostgrestMapTransformBuilder builder, {
  required Map<String, dynamic> value,
}) {
  when(() => builder.then<dynamic>(any(), onError: any(named: 'onError'))).thenAnswer(
    (invocation) {
      final onValue = invocation.positionalArguments[0] as Function;
      return Future<dynamic>.value(onValue(value));
    },
  );
}

void main() {
  late MockSupabaseClient mockClient;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockPostgrestFilterBuilder mockFilterBuilder;
  late AvaliacaoRepository repository;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockClient = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockFilterBuilder = MockPostgrestFilterBuilder();
    repository = AvaliacaoRepository(mockClient);

    when(() => mockClient.from('avaliacoes')).thenAnswer((_) => mockQueryBuilder);
    when(() => mockQueryBuilder.update(any())).thenAnswer((_) => mockFilterBuilder);
    when(() => mockFilterBuilder.eq(any(), any()))
        .thenAnswer((_) => mockFilterBuilder);
  });

  group('AvaliacaoRepository.submeter', () {
    const id = 'aval-001';

    test('envia status=submetida e updated_at para o id correto', () async {
      _stubAwait(mockFilterBuilder);

      await repository.submeter(id);

      final captured = verify(() => mockQueryBuilder.update(captureAny()))
          .captured
          .single as Map<dynamic, dynamic>;

      expect(captured['status'], 'submetida');
      expect(captured.containsKey('updated_at'), isTrue);
      verify(() => mockFilterBuilder.eq('id', id)).called(1);
    });

    test(
      'submeter() não envia nota_geral/pontos_positivos/pontos_melhoria — '
      'assume que já foram salvos previamente via rascunho. '
      'Isso depende do trigger de banco (fn_valida_transicao_avaliacao) '
      'rejeitar a transição se esses campos estiverem nulos na LINHA, '
      'não no payload deste método.',
      () async {
        _stubAwait(mockFilterBuilder);

        await repository.submeter(id);

        final captured = verify(() => mockQueryBuilder.update(captureAny()))
            .captured
            .single as Map<dynamic, dynamic>;

        expect(captured.containsKey('nota_geral'), isFalse);
        expect(captured.containsKey('pontos_positivos'), isFalse);
        expect(captured.containsKey('pontos_melhoria'), isFalse);
      },
    );

    test('propaga PostgrestException quando o backend rejeita a transição '
        '(ex: nota_geral nulo na linha)', () async {
      final exception = PostgrestException(
        message: 'SCI: submissão exige nota_geral, pontos_positivos e '
            'pontos_melhoria preenchidos.',
        code: 'P0001',
      );
      _stubAwait(mockFilterBuilder, error: exception);

      expect(
        () => repository.submeter(id),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('AvaliacaoRepository.validar', () {
    const id = 'aval-002';

    test('envia status=validada sem comentario_validacao quando comentario '
        'é null', () async {
      _stubAwait(mockFilterBuilder);

      await repository.validar(id);

      final captured = verify(() => mockQueryBuilder.update(captureAny()))
          .captured
          .single as Map<dynamic, dynamic>;

      expect(captured['status'], 'validada');
      expect(captured.containsKey('comentario_validacao'), isFalse);
    });

    test('inclui comentario_validacao trimado quando fornecido', () async {
      _stubAwait(mockFilterBuilder);

      await repository.validar(id, comentario: '  Observação válida  ');

      final captured = verify(() => mockQueryBuilder.update(captureAny()))
          .captured
          .single as Map<dynamic, dynamic>;

      expect(captured['comentario_validacao'], 'Observação válida');
    });

    test('NÃO inclui comentario_validacao quando string é vazia após trim',
        () async {
      _stubAwait(mockFilterBuilder);

      await repository.validar(id, comentario: '   ');

      final captured = verify(() => mockQueryBuilder.update(captureAny()))
          .captured
          .single as Map<dynamic, dynamic>;

      expect(captured.containsKey('comentario_validacao'), isFalse);
    });
  });

  group('AvaliacaoRepository.aprovar', () {
    const id = 'aval-003';

    test('envia status=aprovada', () async {
      _stubAwait(mockFilterBuilder);

      await repository.aprovar(id);

      final captured = verify(() => mockQueryBuilder.update(captureAny()))
          .captured
          .single as Map<dynamic, dynamic>;

      expect(captured['status'], 'aprovada');
    });

    test('propaga erro do trigger de imutabilidade se avaliação já '
        'estiver aprovada (dupla aprovação)', () async {
      final exception = PostgrestException(
        message: "SCI: avaliação aprovada é imutável (id=$id). "
            "Operação UPDATE bloqueada.",
        code: 'P0001',
      );
      _stubAwait(mockFilterBuilder, error: exception);

      expect(
        () => repository.aprovar(id),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('AvaliacaoRepository.devolver', () {
    const id = 'aval-004';

    test(
      'lança Exception e NÃO chama o Supabase quando comentário tem '
      'menos de 20 caracteres (validação client-side, defesa em '
      'profundidade — o banco também bloqueia isso via trigger)',
      () async {
        expect(
          () => repository.devolver(id, 'Curto demais'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'mensagem',
              contains('no mínimo 20 caracteres'),
            ),
          ),
        );

        verifyNever(() => mockClient.from(any()));
      },
    );

    test('lança Exception para comentário vazio', () async {
      expect(
        () => repository.devolver(id, ''),
        throwsException,
      );
      verifyNever(() => mockClient.from(any()));
    });

    test('lança Exception para comentário só com espaços — trim() '
        'reduz a 0 caracteres, independente de quantos espaços havia '
        'originalmente', () async {
      final soEspacos = ''.padRight(30, ' ');
      expect(soEspacos.trim().length, 0);

      expect(
        () => repository.devolver(id, soEspacos),
        throwsException,
      );
      verifyNever(() => mockClient.from(any()));
    });

    test('aceita comentário com exatamente 20 caracteres (fronteira '
        'inclusiva, espelha o CHECK do banco) e envia trimado', () async {
      _stubAwait(mockFilterBuilder);
      final comentarioFronteira = ''.padRight(20, 'x');
      expect(comentarioFronteira.length, 20);

      await repository.devolver(id, comentarioFronteira);

      final captured = verify(() => mockQueryBuilder.update(captureAny()))
          .captured
          .single as Map<dynamic, dynamic>;

      expect(captured['status'], 'rascunho');
      expect(captured['comentario_validacao'], comentarioFronteira);
    });

    test('rejeita comentário com 19 caracteres (um a menos que a '
        'fronteira) — mesma construção programática do teste anterior',
        () async {
      final comentario19 = ''.padRight(19, 'x');
      expect(comentario19.length, 19);

      expect(
        () => repository.devolver(id, comentario19),
        throwsException,
      );
      verifyNever(() => mockClient.from(any()));
    });

    test('envia status=rascunho e comentario_validacao trimado para '
        'comentário válido e mais longo', () async {
      _stubAwait(mockFilterBuilder);
      const comentario =
          '  Favor detalhar melhor os pontos de melhoria observados.  ';

      await repository.devolver(id, comentario);

      final captured = verify(() => mockQueryBuilder.update(captureAny()))
          .captured
          .single as Map<dynamic, dynamic>;

      expect(captured['status'], 'rascunho');
      expect(captured['comentario_validacao'], comentario.trim());
      verify(() => mockFilterBuilder.eq('id', id)).called(1);
    });

    test('propaga erro do banco se devolução for tentada em avaliação '
        'já aprovada (trigger de imutabilidade bloqueia mesmo com '
        'comentário válido)', () async {
      final exception = PostgrestException(
        message: "SCI: avaliação aprovada é imutável (id=$id). "
            "Operação UPDATE bloqueada.",
        code: 'P0001',
      );
      _stubAwait(mockFilterBuilder, error: exception);

      expect(
        () => repository.devolver(
          id,
          'Comentário válido com mais de vinte caracteres.',
        ),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group(
    'AvaliacaoRepository.listar — método novo do refactor, sem '
    'teste até agora (LF:46/LH:22 no lcov confirmava isso)',
    () {
      test('consulta avaliacoes, filtra deleted_at IS NULL, ordena '
          'por periodo_referencia desc', () async {
        when(() => mockQueryBuilder.select()).thenAnswer((_) => mockFilterBuilder);
        when(() => mockFilterBuilder.isFilter('deleted_at', null))
            .thenAnswer((_) => mockFilterBuilder);
        when(() => mockFilterBuilder.order('periodo_referencia', ascending: false))
            .thenAnswer((_) => mockFilterBuilder);

        _stubAwait(mockFilterBuilder, value: [
          {
            'id': 'aval-1',
            'alocacao_id': 'aloc-1',
            'avaliador_id': 'av-1',
            'tipo': 'setorial',
            'periodo_referencia': '2026-06-01',
            'status': 'aprovada',
          }
        ]);

        final result = await repository.listar();

        expect(result, hasLength(1));
        expect(result.first.id, 'aval-1');
        verify(() => mockClient.from('avaliacoes')).called(1);
        verify(() => mockFilterBuilder.isFilter('deleted_at', null))
            .called(1);
        verify(() => mockFilterBuilder.order('periodo_referencia',
            ascending: false)).called(1);
      });

      test('lista vazia quando não há avaliações', () async {
        when(() => mockQueryBuilder.select()).thenAnswer((_) => mockFilterBuilder);
        when(() => mockFilterBuilder.isFilter('deleted_at', null))
            .thenAnswer((_) => mockFilterBuilder);
        when(() => mockFilterBuilder.order('periodo_referencia', ascending: false))
            .thenAnswer((_) => mockFilterBuilder);

        _stubAwait(mockFilterBuilder, value: []);
        final result = await repository.listar();
        expect(result, isEmpty);
      });
    },
  );

  group(
    'AvaliacaoRepository.salvarRascunho — método novo do refactor, '
    'sem teste até agora',
    () {
      test('lança Exception e NÃO chama o banco quando não há '
          'usuário autenticado', () async {
        final mockAuth = MockGoTrueClient();
        when(() => mockClient.auth).thenReturn(mockAuth);
        when(() => mockAuth.currentUser).thenReturn(null);

        await expectLater(
          () => repository.salvarRascunho({'tipo': 'setorial'}),
          throwsA(isA<Exception>()),
        );
        verifyNever(() => mockClient.from(any()));
      });

      test('injeta status=rascunho e avaliador_id=user.id no payload, '
          'faz upsert, e retorna o model da resposta', () async {
        final mockAuth = MockGoTrueClient();
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('aluno-abc');
        when(() => mockClient.auth).thenReturn(mockAuth);
        when(() => mockAuth.currentUser).thenReturn(mockUser);

        final listBuilder = MockPostgrestListTransformBuilder();
        final mapBuilder = MockPostgrestMapTransformBuilder();
        when(() => mockQueryBuilder.upsert(any()))
            .thenAnswer((_) => mockFilterBuilder);
        when(() => mockFilterBuilder.select()).thenAnswer((_) => listBuilder);
        when(() => listBuilder.single()).thenAnswer((_) => mapBuilder);
        _stubAwaitSingle(mapBuilder, value: {
          'id': 'aval-novo',
          'alocacao_id': 'aloc-1',
          'avaliador_id': 'aluno-abc',
          'tipo': 'setorial',
          'periodo_referencia': '2026-07-01',
          'status': 'rascunho',
        });

        final result = await repository
            .salvarRascunho({'tipo': 'setorial', 'alocacao_id': 'aloc-1'});

        expect(result.id, 'aval-novo');
        final captured = verify(() => mockQueryBuilder.upsert(captureAny()))
            .captured
            .single as Map<dynamic, dynamic>;
        expect(captured['status'], 'rascunho');
        expect(captured['avaliador_id'], 'aluno-abc');
        expect(captured['tipo'], 'setorial');
      });
    },
  );

  group(
    'AvaliacaoRepository.excluirRascunho — método novo do refactor, '
    'sem teste até agora (soft-delete client-side)',
    () {
      test('envia deleted_at preenchido (ISO 8601) para o id certo',
          () async {
        _stubAwait(mockFilterBuilder);

        await repository.excluirRascunho('aval-777');

        final captured = verify(() => mockQueryBuilder.update(captureAny()))
            .captured
            .single as Map<dynamic, dynamic>;
        expect(captured.containsKey('deleted_at'), isTrue);
        expect(
          () => DateTime.parse(captured['deleted_at'] as String),
          returnsNormally,
        );
        verify(() => mockFilterBuilder.eq('id', 'aval-777')).called(1);
      });
    },
  );
}
