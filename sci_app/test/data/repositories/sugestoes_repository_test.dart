import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/data/repositories/sugestoes_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}
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
  late SugestoesRepository repository;

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
    when(() => mockClient.from('sugestoes'))
        .thenAnswer((_) => mockQueryBuilder);
    repository = SugestoesRepository(mockClient);
  });

  group('SugestoesRepository', () {
    test('listarMinhasSugestoes deve retornar lista do usuário autenticado',
        () async {
      _stubAwait(mockFilterBuilder, value: <Map<String, dynamic>>[
        {
          'id': 'sug_1',
          'autor_id': 'user_123',
          'conteudo': 'Minha Sugestao',
        }
      ]);

      when(() => mockQueryBuilder.select())
          .thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.eq('autor_id', 'user_123'))
          .thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.isFilter('deleted_at', null))
          .thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.order('created_at', ascending: false))
          .thenAnswer((_) => mockFilterBuilder);

      final lista = await repository.listarMinhasSugestoes();
      expect(lista.length, 1);
      expect(lista.first.conteudo, 'Minha Sugestao');
    });

    test('listarMinhasSugestoes deve retornar lista vazia se usuário for nulo',
        () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      final lista = await repository.listarMinhasSugestoes();
      expect(lista, isEmpty);
    });

    test('listarTodasSugestoes deve retornar lista e aplicar filtro local',
        () async {
      _stubAwait(mockFilterBuilder, value: <Map<String, dynamic>>[
        {
          'id': 'sug_1',
          'autor_id': 'usr_1',
          'conteudo': 'Sugestao Aluno',
          'usuarios': {'nome': 'Carlos', 'perfil': 'aluno'},
        },
        {
          'id': 'sug_2',
          'autor_id': 'usr_2',
          'conteudo': 'Sugestao Supervisor',
          'usuarios': {'nome': 'Ana', 'perfil': 'supervisor'},
        }
      ]);

      when(() => mockQueryBuilder.select(any()))
          .thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.isFilter('deleted_at', null))
          .thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.order('created_at', ascending: false))
          .thenAnswer((_) => mockFilterBuilder);

      final resultadoTodos = await repository.listarTodasSugestoes();
      expect(resultadoTodos.length, 2);

      final resultadoAluno =
          await repository.listarTodasSugestoes(perfil: 'aluno');
      expect(resultadoAluno.length, 1);
      expect(resultadoAluno.first.autorPerfil, 'aluno');
    });

    test('enviarSugestao deve inserir sugestao com id do usuario logado',
        () async {
      _stubAwait(mockFilterBuilder, value: <Map<String, dynamic>>[]);
      when(() => mockQueryBuilder.insert(any()))
          .thenAnswer((_) => mockFilterBuilder);

      await repository.enviarSugestao('Sugestão de teste 123');

      verify(() => mockQueryBuilder
          .insert(any(that: isA<Map<String, dynamic>>()))).called(1);
    });

    test('enviarSugestao lança exceção se usuário não autenticado', () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      expect(
        () => repository.enviarSugestao('Sugestão'),
        throwsException,
      );
    });
  });
}
