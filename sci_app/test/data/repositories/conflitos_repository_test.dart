import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/data/repositories/conflitos_repository.dart';

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
  late ConflitosRepository repository;

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
    when(() => mockClient.from('conflitos'))
        .thenAnswer((_) => mockQueryBuilder);
    repository = ConflitosRepository(mockClient);
  });

  group('ConflitosRepository', () {
    test('listarConflitos deve aplicar filtros e retornar lista', () async {
      _stubAwait(mockFilterBuilder, value: <Map<String, dynamic>>[
        {
          'id': 'cnf_1',
          'aluno_id': 'aln_1',
          'campo_id': 'cmp_1',
          'descricao': 'Ocorrência teste',
          'data_ocorrencia': '2025-06-10T10:00:00Z',
          'usuarios': {'nome': 'Gabriel'},
          'campos_estagio': {'nome': 'Hospital Geral'},
        }
      ]);

      when(() => mockQueryBuilder.select(any()))
          .thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.isFilter('deleted_at', null))
          .thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.eq('campo_id', 'cmp_1'))
          .thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.order('data_ocorrencia', ascending: false))
          .thenAnswer((_) => mockFilterBuilder);

      final lista = await repository.listarConflitos(campoId: 'cmp_1');

      expect(lista.length, 1);
      expect(lista.first.alunoNome, 'Gabriel');
      verify(() => mockFilterBuilder.eq('campo_id', 'cmp_1')).called(1);
    });

    test('registrarConflito deve inserir registro append-only', () async {
      _stubAwait(mockFilterBuilder, value: <Map<String, dynamic>>[]);
      when(() => mockQueryBuilder.insert(any()))
          .thenAnswer((_) => mockFilterBuilder);

      await repository.registrarConflito(
        alunoId: 'aln_1',
        campoId: 'cmp_1',
        descricao: 'Descrição detalhada com no mínimo 30 caracteres válidos.',
        dataOcorrencia: DateTime(2025, 6, 10),
      );

      verify(() => mockQueryBuilder
          .insert(any(that: isA<Map<String, dynamic>>()))).called(1);
    });
  });
}
