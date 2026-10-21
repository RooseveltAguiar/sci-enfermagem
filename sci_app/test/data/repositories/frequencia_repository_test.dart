import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/data/repositories/frequencia_repository.dart';
import 'package:sci_app/core/utils/location_service.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}
class MockPostgrestTransformBuilder extends Mock implements PostgrestTransformBuilder<List<Map<String, dynamic>>> {}
class MockPostgrestTransformBuilderSingle extends Mock implements PostgrestTransformBuilder<Map<String, dynamic>?> {}

void main() {
  late MockSupabaseClient mockClient;
  late MockSupabaseQueryBuilder mockAlocacoesTable;
  late MockSupabaseQueryBuilder mockFrequenciasTable;
  late MockPostgrestFilterBuilder mockSelectBuilder;
  late MockPostgrestFilterBuilder mockEq1;
  late MockPostgrestFilterBuilder mockEq2;
  late MockPostgrestTransformBuilder mockLimit;
  late MockPostgrestTransformBuilderSingle mockSingle;
  late MockPostgrestFilterBuilder mockInsert;
  late FrequenciaRepository repository;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAlocacoesTable = MockSupabaseQueryBuilder();
    mockFrequenciasTable = MockSupabaseQueryBuilder();
    mockSelectBuilder = MockPostgrestFilterBuilder();
    mockEq1 = MockPostgrestFilterBuilder();
    mockEq2 = MockPostgrestFilterBuilder();
    mockLimit = MockPostgrestTransformBuilder();
    mockSingle = MockPostgrestTransformBuilderSingle();
    mockInsert = MockPostgrestFilterBuilder();

    when(() => mockClient.from('alocacoes')).thenAnswer((_) => mockAlocacoesTable);
    when(() => mockClient.from('frequencias')).thenAnswer((_) => mockFrequenciasTable);
    when(() => mockAlocacoesTable.select(any())).thenAnswer((_) => mockSelectBuilder);
    when(() => mockSelectBuilder.eq('aluno_id', any())).thenAnswer((_) => mockEq1);
    when(() => mockEq1.eq('status', 'ativa')).thenAnswer((_) => mockEq2);
    when(() => mockEq2.limit(1)).thenAnswer((_) => mockLimit);
    when(() => mockLimit.maybeSingle()).thenAnswer((_) => mockSingle);
    when(() => mockFrequenciasTable.insert(any())).thenAnswer((_) => mockInsert);

    repository = FrequenciaRepository(mockClient);
  });

  group('FrequenciaRepository.buildInsertPayload', () {
    test('Cenário 1: GPS Disponível e Preciso (Caminho Feliz)', () {
      final location = LocationResult(
        latitude: -3.71839,
        longitude: -38.5434,
        accuracy: 10.0,
        isAvailable: true,
      );

      final payload = repository.buildInsertPayload('aloc123', 'turno456', 'ENTRADA', location);

      expect(payload['gps_disponivel'], true);
      expect(payload['lat_registro'], -3.71839);
      expect(payload['lng_registro'], -38.5434);
      expect(payload['gps_precisao_metros'], 10.0);
    });

    test('Cenário 2: GPS Indisponível (Sem Permissão ou Desligado)', () {
      final location = LocationResult(
        isAvailable: false,
      );

      final payload = repository.buildInsertPayload('aloc123', 'turno456', 'ENTRADA', location);

      expect(payload['gps_disponivel'], false);
      expect(payload['lat_registro'], isNull);
      expect(payload['lng_registro'], isNull);
      expect(payload['gps_precisao_metros'], isNull);
    });

    test('Cenário 3: GPS Impreciso (AC-002-5)', () {
      final location = LocationResult(
        latitude: null,
        longitude: null,
        accuracy: 200.0,
        isAvailable: false,
      );

      final payload = repository.buildInsertPayload('aloc123', 'turno456', 'ENTRADA', location);

      expect(payload['gps_disponivel'], false);
      expect(payload['lat_registro'], isNull);
      expect(payload['lng_registro'], isNull);
      expect(payload['gps_precisao_metros'], 200.0);
    });
  });

  group('FrequenciaRepository.registrarPonto', () {
    final location = LocationResult(
      latitude: -3.71839,
      longitude: -38.5434,
      accuracy: 10.0,
      isAvailable: true,
    );

    test('Lança exceção quando nenhuma alocação ativa é encontrada', () async {
      when(() => mockSingle.then<dynamic>(any(), onError: any(named: 'onError'))).thenAnswer((invocation) async {
        final onValue = invocation.positionalArguments.first as dynamic Function(Map<String, dynamic>?);
        await Future.microtask(() {});
        return onValue(null);
      });

      expect(
        () => repository.registrarPonto(
          alunoId: 'aluno-1',
          tipoRegistro: 'ENTRADA',
          location: location,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Lança exceção quando turnos_permitidos está vazio ou nulo', () async {
      when(() => mockSingle.then<dynamic>(any(), onError: any(named: 'onError'))).thenAnswer((invocation) async {
        final onValue = invocation.positionalArguments.first as dynamic Function(Map<String, dynamic>?);
        await Future.microtask(() {});
        return onValue({
          'id': 'aloc-1',
          'turnos_permitidos': [],
        });
      });

      expect(
        () => repository.registrarPonto(
          alunoId: 'aluno-1',
          tipoRegistro: 'ENTRADA',
          location: location,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Insere frequência com sucesso quando alocação e turno existem', () async {
      when(() => mockSingle.then<dynamic>(any(), onError: any(named: 'onError'))).thenAnswer((invocation) async {
        final onValue = invocation.positionalArguments.first as dynamic Function(Map<String, dynamic>?);
        await Future.microtask(() {});
        return onValue({
          'id': 'aloc-1',
          'turnos_permitidos': ['turno-a', 'turno-b'],
        });
      });

      when(() => mockInsert.then<dynamic>(any(), onError: any(named: 'onError'))).thenAnswer((invocation) async {
        final onValue = invocation.positionalArguments.first as dynamic Function(List<Map<String, dynamic>>);
        await Future.microtask(() {});
        return onValue(<Map<String, dynamic>>[]);
      });

      await repository.registrarPonto(
        alunoId: 'aluno-1',
        tipoRegistro: 'ENTRADA',
        location: location,
      );

      verify(() => mockFrequenciasTable.insert(any(that: predicate<Map<dynamic, dynamic>>((payload) {
        return payload['alocacao_id'] == 'aloc-1' &&
               payload['turno_id'] == 'turno-a' &&
               payload['tipo_registro'] == 'ENTRADA' &&
               payload['gps_disponivel'] == true;
      })))).called(1);
    });
  });
}
