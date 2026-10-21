// test/data/repositories/termos_repository_test.dart
//
// Testes unitários de TermosRepository — buscarTermoAtivo, criarTermo,
// ativarVersao, aceitarTermo, listarTodasVersoes, verificarTermoPendente.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sci_app/data/repositories/termos_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

class MockPostgrestMapNullableTransformBuilder extends Mock
    implements PostgrestTransformBuilder<Map<String, dynamic>?> {}

void _stubAwait(
  MockPostgrestFilterBuilder builder, {
  List<Map<String, dynamic>> value = const [],
}) {
  when(() => builder.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onValue = invocation.positionalArguments[0] as Function;
    return Future<dynamic>.value(onValue(value));
  });
}

void _stubAwaitSingle(
  MockPostgrestMapNullableTransformBuilder builder, {
  Map<String, dynamic>? value,
}) {
  when(() => builder.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onValue = invocation.positionalArguments[0] as Function;
    return Future<dynamic>.value(onValue(value));
  });
}

void main() {
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late TermosRepository repository;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    repository = TermosRepository(mockClient);

    when(() => mockClient.from(any())).thenAnswer((_) => mockQueryBuilder);
    when(() => mockClient.auth).thenReturn(mockAuth);
  });

  group('TermosRepository.buscarTermoAtivo', () {
    test('retorna o termo quando existe um ativo=true', () async {
      final filterBuilder = MockPostgrestFilterBuilder();
      final singleBuilder = MockPostgrestMapNullableTransformBuilder();

      when(() => mockQueryBuilder.select()).thenAnswer((_) => filterBuilder);
      when(() => filterBuilder.eq('ativo', true)).thenAnswer((_) => filterBuilder);
      when(() => filterBuilder.isFilter('deleted_at', null))
          .thenAnswer((_) => filterBuilder);
      when(() => filterBuilder.maybeSingle()).thenAnswer((_) => singleBuilder);
      _stubAwaitSingle(singleBuilder, value: {
        'id': 'termo-001',
        'titulo': 'Termo Vigente',
        'versao': 'v3.0',
        'conteudo': 'Conteúdo',
        'vigencia_inicio': '2026-01-01T00:00:00.000Z',
        'ativo': true,
      });

      final result = await repository.buscarTermoAtivo();

      expect(result, isNotNull);
      expect(result!.versao, 'v3.0');
      verify(() => mockClient.from('termos')).called(1);
    });

    test('retorna null quando não há termo ativo', () async {
      final filterBuilder = MockPostgrestFilterBuilder();
      final singleBuilder = MockPostgrestMapNullableTransformBuilder();

      when(() => mockQueryBuilder.select()).thenAnswer((_) => filterBuilder);
      when(() => filterBuilder.eq('ativo', true)).thenAnswer((_) => filterBuilder);
      when(() => filterBuilder.isFilter('deleted_at', null))
          .thenAnswer((_) => filterBuilder);
      when(() => filterBuilder.maybeSingle()).thenAnswer((_) => singleBuilder);
      _stubAwaitSingle(singleBuilder, value: null);

      final result = await repository.buscarTermoAtivo();

      expect(result, isNull);
    });
  });

  group('TermosRepository.criarTermo', () {
    test('monta o payload com os 5 campos + created_by do usuário '
        'autenticado', () async {
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('coord-999');
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      final filterBuilder = MockPostgrestFilterBuilder();
      when(() => mockQueryBuilder.insert(any())).thenAnswer((_) => filterBuilder);
      _stubAwait(filterBuilder);

      final vigencia = DateTime(2026, 9, 1);
      await repository.criarTermo(
        titulo: 'Termo Novo',
        versao: 'v4.0',
        conteudo: 'Conteúdo do termo novo',
        vigenciaInicio: vigencia,
        ativar: true,
      );

      final captured = verify(() => mockQueryBuilder.insert(captureAny()))
          .captured
          .single as Map<dynamic, dynamic>;

      expect(captured['titulo'], 'Termo Novo');
      expect(captured['versao'], 'v4.0');
      expect(captured['ativo'], true);
      expect(captured['created_by'], 'coord-999');
      expect(captured['vigencia_inicio'], vigencia.toIso8601String());
    });
  });

  group('TermosRepository.ativarVersao', () {
    test('envia ativo=true para o id certo', () async {
      final filterBuilder = MockPostgrestFilterBuilder();
      when(() => mockQueryBuilder.update(any())).thenAnswer((_) => filterBuilder);
      when(() => filterBuilder.eq('id', 'termo-777'))
          .thenAnswer((_) => filterBuilder);
      _stubAwait(filterBuilder);

      await repository.ativarVersao('termo-777');

      final captured = verify(() => mockQueryBuilder.update(captureAny()))
          .captured
          .single as Map<dynamic, dynamic>;
      expect(captured['ativo'], true);
      verify(() => filterBuilder.eq('id', 'termo-777')).called(1);
    });
  });

  group(
    'TermosRepository.aceitarTermo — cenário 3 exigido pelo PO/BA: '
    'atualiza os campos certos em usuarios',
    () {
      test('atualiza data_aceite_termos E versao_termos_aceita no '
          'usuário autenticado', () async {
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('aluno-555');
        when(() => mockAuth.currentUser).thenReturn(mockUser);

        final filterBuilder = MockPostgrestFilterBuilder();
        when(() => mockQueryBuilder.update(any())).thenAnswer((_) => filterBuilder);
        when(() => filterBuilder.eq('id', 'aluno-555'))
            .thenAnswer((_) => filterBuilder);
        _stubAwait(filterBuilder);

        await repository.aceitarTermo('v4.0');

        final captured = verify(() => mockQueryBuilder.update(captureAny()))
            .captured
            .single as Map<dynamic, dynamic>;

        expect(captured.containsKey('data_aceite_termos'), isTrue);
        expect(captured['versao_termos_aceita'], 'v4.0');
        expect(
          () => DateTime.parse(captured['data_aceite_termos'] as String),
          returnsNormally,
        );
        verify(() => mockClient.from('usuarios')).called(1);
      });

      test('sem usuário autenticado → retorna silenciosamente, SEM '
          'chamar o banco — comportamento atual do repository, '
          'testado explicitamente para não ser alterado sem querer '
          'num refactor futuro', () async {
        when(() => mockAuth.currentUser).thenReturn(null);

        await repository.aceitarTermo('v4.0');

        verifyNever(() => mockClient.from('usuarios'));
      });
    },
  );

  group('TermosRepository.listarTodasVersoes', () {
    test(
      'consulta termos, filtra deleted_at IS NULL, ordena por '
      'created_at desc — método esquecido na primeira entrega deste '
      'arquivo, explica por que a cobertura ficou em 78.95% em vez '
      'de perto de 100%',
      () async {
        final filterBuilder = MockPostgrestFilterBuilder();
        when(() => mockQueryBuilder.select()).thenAnswer((_) => filterBuilder);
        when(() => filterBuilder.isFilter('deleted_at', null))
            .thenAnswer((_) => filterBuilder);
        when(() => filterBuilder.order('created_at', ascending: false))
            .thenAnswer((_) => filterBuilder);
        _stubAwait(filterBuilder, value: [
          {
            'id': 'termo-1',
            'titulo': 'T1',
            'versao': 'v1.0',
            'conteudo': 'c',
            'vigencia_inicio': '2026-01-01T00:00:00.000Z',
            'ativo': false,
          },
          {
            'id': 'termo-2',
            'titulo': 'T2',
            'versao': 'v2.0',
            'conteudo': 'c',
            'vigencia_inicio': '2026-06-01T00:00:00.000Z',
            'ativo': true,
          },
        ]);

        final result = await repository.listarTodasVersoes();

        expect(result, hasLength(2));
        verify(() => mockClient.from('termos')).called(1);
        verify(() => filterBuilder.isFilter('deleted_at', null)).called(1);
        verify(() => filterBuilder.order('created_at', ascending: false))
            .called(1);
      },
    );

    test('lista vazia quando não há nenhuma versão cadastrada',
        () async {
      final filterBuilder = MockPostgrestFilterBuilder();
      when(() => mockQueryBuilder.select()).thenAnswer((_) => filterBuilder);
      when(() => filterBuilder.isFilter('deleted_at', null))
          .thenAnswer((_) => filterBuilder);
      when(() => filterBuilder.order('created_at', ascending: false))
          .thenAnswer((_) => filterBuilder);
      _stubAwait(filterBuilder, value: []);

      final result = await repository.listarTodasVersoes();
      expect(result, isEmpty);
    });
  });

  group('TermosRepository.verificarTermoPendente', () {
    test('sem termo ativo no sistema → false, sem consultar o '
        'usuário', () async {
      final filterBuilderTermos = MockPostgrestFilterBuilder();
      final singleBuilder = MockPostgrestMapNullableTransformBuilder();
      when(() => mockQueryBuilder.select()).thenAnswer((_) => filterBuilderTermos);
      when(() => filterBuilderTermos.eq('ativo', true))
          .thenAnswer((_) => filterBuilderTermos);
      when(() => filterBuilderTermos.isFilter('deleted_at', null))
          .thenAnswer((_) => filterBuilderTermos);
      when(() => filterBuilderTermos.maybeSingle()).thenAnswer((_) => singleBuilder);
      _stubAwaitSingle(singleBuilder, value: null);

      final result = await repository.verificarTermoPendente('user-001');

      expect(result, false);
    });

    test('usuário nunca aceitou nenhum termo (versao_termos_aceita '
        'nulo) → true (pendente)', () async {
      final filterBuilderTermos = MockPostgrestFilterBuilder();
      final singleBuilderTermo = MockPostgrestMapNullableTransformBuilder();
      when(() => mockQueryBuilder.select()).thenAnswer((_) => filterBuilderTermos);
      when(() => filterBuilderTermos.eq('ativo', true))
          .thenAnswer((_) => filterBuilderTermos);
      when(() => filterBuilderTermos.isFilter('deleted_at', null))
          .thenAnswer((_) => filterBuilderTermos);
      when(() => filterBuilderTermos.maybeSingle())
          .thenAnswer((_) => singleBuilderTermo);
      _stubAwaitSingle(singleBuilderTermo, value: {
        'id': 'termo-001',
        'titulo': 'T',
        'versao': 'v4.0',
        'conteudo': 'c',
        'vigencia_inicio': '2026-01-01T00:00:00.000Z',
        'ativo': true,
      });

      final filterBuilderUser = MockPostgrestFilterBuilder();
      final singleBuilderUser = MockPostgrestMapNullableTransformBuilder();
      when(() => mockQueryBuilder.select('versao_termos_aceita'))
          .thenAnswer((_) => filterBuilderUser);
      when(() => filterBuilderUser.eq('id', 'user-002'))
          .thenAnswer((_) => filterBuilderUser);
      when(() => filterBuilderUser.maybeSingle())
          .thenAnswer((_) => singleBuilderUser);
      _stubAwaitSingle(singleBuilderUser, value: {
        'versao_termos_aceita': null,
      });

      final result = await repository.verificarTermoPendente('user-002');

      expect(result, true);
    });

    test('usuário aceitou versão diferente da ativa → true (pendente)',
        () async {
      final filterBuilderTermos = MockPostgrestFilterBuilder();
      final singleBuilderTermo = MockPostgrestMapNullableTransformBuilder();
      when(() => mockQueryBuilder.select()).thenAnswer((_) => filterBuilderTermos);
      when(() => filterBuilderTermos.eq('ativo', true))
          .thenAnswer((_) => filterBuilderTermos);
      when(() => filterBuilderTermos.isFilter('deleted_at', null))
          .thenAnswer((_) => filterBuilderTermos);
      when(() => filterBuilderTermos.maybeSingle())
          .thenAnswer((_) => singleBuilderTermo);
      _stubAwaitSingle(singleBuilderTermo, value: {
        'id': 'termo-001',
        'titulo': 'T',
        'versao': 'v4.0',
        'conteudo': 'c',
        'vigencia_inicio': '2026-01-01T00:00:00.000Z',
        'ativo': true,
      });

      final filterBuilderUser = MockPostgrestFilterBuilder();
      final singleBuilderUser = MockPostgrestMapNullableTransformBuilder();
      when(() => mockQueryBuilder.select('versao_termos_aceita'))
          .thenAnswer((_) => filterBuilderUser);
      when(() => filterBuilderUser.eq('id', 'user-003'))
          .thenAnswer((_) => filterBuilderUser);
      when(() => filterBuilderUser.maybeSingle())
          .thenAnswer((_) => singleBuilderUser);
      _stubAwaitSingle(singleBuilderUser, value: {
        'versao_termos_aceita': 'v3.0',
      });

      final result = await repository.verificarTermoPendente('user-003');

      expect(result, true);
    });

    test('usuário aceitou exatamente a versão ativa → false (em dia)',
        () async {
      final filterBuilderTermos = MockPostgrestFilterBuilder();
      final singleBuilderTermo = MockPostgrestMapNullableTransformBuilder();
      when(() => mockQueryBuilder.select()).thenAnswer((_) => filterBuilderTermos);
      when(() => filterBuilderTermos.eq('ativo', true))
          .thenAnswer((_) => filterBuilderTermos);
      when(() => filterBuilderTermos.isFilter('deleted_at', null))
          .thenAnswer((_) => filterBuilderTermos);
      when(() => filterBuilderTermos.maybeSingle())
          .thenAnswer((_) => singleBuilderTermo);
      _stubAwaitSingle(singleBuilderTermo, value: {
        'id': 'termo-001',
        'titulo': 'T',
        'versao': 'v4.0',
        'conteudo': 'c',
        'vigencia_inicio': '2026-01-01T00:00:00.000Z',
        'ativo': true,
      });

      final filterBuilderUser = MockPostgrestFilterBuilder();
      final singleBuilderUser = MockPostgrestMapNullableTransformBuilder();
      when(() => mockQueryBuilder.select('versao_termos_aceita'))
          .thenAnswer((_) => filterBuilderUser);
      when(() => filterBuilderUser.eq('id', 'user-004'))
          .thenAnswer((_) => filterBuilderUser);
      when(() => filterBuilderUser.maybeSingle())
          .thenAnswer((_) => singleBuilderUser);
      _stubAwaitSingle(singleBuilderUser, value: {
        'versao_termos_aceita': 'v4.0',
      });

      final result = await repository.verificarTermoPendente('user-004');

      expect(result, false);
    });
  });
}
