import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/data/repositories/legislacao_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}
class MockPostgrestTransformBuilder extends Mock
    implements PostgrestTransformBuilder<Map<String, dynamic>> {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockUser extends Mock implements User {}

void _stubAwait(
  MockPostgrestFilterBuilder builder, {
  List<Map<String, dynamic>> value = const <Map<String, dynamic>>[],
  Object? error,
}) {
  when(() => builder.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
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
  });
}

void main() {
  late MockSupabaseClient mockClient;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockPostgrestFilterBuilder mockFilterBuilder;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late LegislacaoRepository repository;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockClient = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockFilterBuilder = MockPostgrestFilterBuilder();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();

    when(() => mockUser.id).thenReturn('user_123');
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockClient.auth).thenReturn(mockAuth);
    when(() => mockClient.from('legislacoes'))
        .thenAnswer((_) => mockQueryBuilder);
    repository = LegislacaoRepository(mockClient);
  });

  group('LegislacaoRepository', () {
    test('listarLegislacoesAtivas deve retornar lista de LegislacaoModel',
        () async {
      _stubAwait(mockFilterBuilder, value: <Map<String, dynamic>>[
        {
          'id': 'leg_1',
          'titulo': 'Portaria 01',
          'conteudo': 'Texto portaria',
          'tipo': 'Portaria',
          'ativo': true,
        }
      ]);

      when(() => mockQueryBuilder.select())
          .thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.eq('ativo', true))
          .thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.isFilter('deleted_at', null))
          .thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.order('created_at', ascending: false))
          .thenAnswer((_) => mockFilterBuilder);

      final resultado = await repository.listarLegislacoesAtivas();

      expect(resultado.length, 1);
      expect(resultado.first.id, 'leg_1');
      expect(resultado.first.titulo, 'Portaria 01');
      verify(() => mockClient.from('legislacoes')).called(1);
    });

    test('buscarLegislacaoPorId deve retornar LegislacaoModel do id informado',
        () async {
      final mockTransformBuilder = MockPostgrestTransformBuilder();
      when(() => mockTransformBuilder.then<dynamic>(any(),
              onError: any(named: 'onError')))
          .thenAnswer((invocation) {
        final onValue = invocation.positionalArguments[0] as Function;
        return Future<dynamic>.value(onValue(<String, dynamic>{
          'id': 'leg_1',
          'titulo': 'Portaria 01',
          'conteudo': 'Texto portaria',
          'tipo': 'Portaria',
          'ativo': true,
        }));
      });

      when(() => mockQueryBuilder.select())
          .thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.eq('id', 'leg_1'))
          .thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.single())
          .thenAnswer((_) => mockTransformBuilder);

      final resultado = await repository.buscarLegislacaoPorId('leg_1');
      expect(resultado.id, 'leg_1');
      expect(resultado.titulo, 'Portaria 01');
    });

    test('criarLegislacao deve chamar insert com payload correto', () async {
      _stubAwait(mockFilterBuilder, value: <Map<String, dynamic>>[]);
      when(() => mockQueryBuilder.insert(any()))
          .thenAnswer((_) => mockFilterBuilder);

      await repository.criarLegislacao(
        titulo: 'Portaria 02',
        conteudo: 'Conteudo',
        tipo: 'Resolução',
        ativo: true,
      );

      verify(() => mockQueryBuilder
          .insert(any(that: isA<Map<String, dynamic>>()))).called(1);
    });

    test('editarLegislacao deve chamar update e eq', () async {
      _stubAwait(mockFilterBuilder, value: <Map<String, dynamic>>[]);
      when(() => mockQueryBuilder.update(any()))
          .thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.eq('id', 'leg_1'))
          .thenAnswer((_) => mockFilterBuilder);

      await repository.editarLegislacao(
        id: 'leg_1',
        titulo: 'Portaria Editada',
        conteudo: 'Novo conteudo',
        tipo: 'Portaria',
        ativo: true,
      );

      verify(() => mockQueryBuilder.update(any())).called(1);
      verify(() => mockFilterBuilder.eq('id', 'leg_1')).called(1);
    });

    test('desativarLegislacao deve chamar update marcando ativo=false',
        () async {
      _stubAwait(mockFilterBuilder, value: <Map<String, dynamic>>[]);
      when(() => mockQueryBuilder.update(any()))
          .thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.eq('id', 'leg_1'))
          .thenAnswer((_) => mockFilterBuilder);

      await repository.desativarLegislacao('leg_1');

      verify(() => mockQueryBuilder.update(
          any(that: containsPair('ativo', false)))).called(1);
      verify(() => mockFilterBuilder.eq('id', 'leg_1')).called(1);
    });
  });
}
