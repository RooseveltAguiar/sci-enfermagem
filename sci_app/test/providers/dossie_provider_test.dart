import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/providers/dossie_provider.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class FakePostgrestTransformBuilder<T> extends Fake implements PostgrestTransformBuilder<T> {
  final T _data;
  FakePostgrestTransformBuilder(this._data);

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) {
    return Future.value(_data).then(onValue, onError: onError);
  }

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) {
    return Future.value(_data).catchError(onError, test: test);
  }
}

class FakePostgrestFilterBuilder extends Fake implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  final dynamic _data;
  FakePostgrestFilterBuilder(this._data);

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> eq(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> isFilter(String column, Object? value) => this;

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> order(String column, {bool ascending = true, bool nullsFirst = false, String? referencedTable}) => this;

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    return FakePostgrestTransformBuilder<Map<String, dynamic>?>(_data is Map<String, dynamic> ? _data : null);
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(List<Map<String, dynamic>> value) onValue, {Function? onError}) {
    final listVal = _data is List ? List<Map<String, dynamic>>.from(_data) : <Map<String, dynamic>>[];
    return Future.value(listVal).then(onValue, onError: onError);
  }

  @override
  Future<List<Map<String, dynamic>>> catchError(Function onError, {bool Function(Object error)? test}) {
    final listVal = _data is List ? List<Map<String, dynamic>>.from(_data) : <Map<String, dynamic>>[];
    return Future.value(listVal).catchError(onError, test: test);
  }
}

class FakePostgrestRpcFilterBuilder extends Fake implements PostgrestFilterBuilder<dynamic> {
  final dynamic _data;
  FakePostgrestRpcFilterBuilder(this._data);

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    return FakePostgrestTransformBuilder<Map<String, dynamic>?>(_data is Map<String, dynamic> ? _data : null);
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue, {Function? onError}) {
    return Future.value(_data).then(onValue, onError: onError);
  }

  @override
  Future<dynamic> catchError(Function onError, {bool Function(Object error)? test}) {
    return Future.value(_data).catchError(onError, test: test);
  }
}

class FakeErrorPostgrestTransformBuilder extends Fake implements PostgrestTransformBuilder<Map<String, dynamic>?> {
  final Object _error;
  FakeErrorPostgrestTransformBuilder(this._error);

  @override
  Future<R> then<R>(FutureOr<R> Function(Map<String, dynamic>? value) onValue, {Function? onError}) {
    return Future<Map<String, dynamic>?>.error(_error).then(onValue, onError: onError);
  }

  @override
  Future<Map<String, dynamic>?> catchError(Function onError, {bool Function(Object error)? test}) {
    return Future<Map<String, dynamic>?>.error(_error).catchError(onError, test: test);
  }
}

class FakeErrorPostgrestFilterBuilder extends Fake implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  final Object _error;
  FakeErrorPostgrestFilterBuilder(this._error);

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    return FakeErrorPostgrestTransformBuilder(_error);
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(List<Map<String, dynamic>> value) onValue, {Function? onError}) {
    return Future<List<Map<String, dynamic>>>.error(_error).then(onValue, onError: onError);
  }

  @override
  Future<List<Map<String, dynamic>>> catchError(Function onError, {bool Function(Object error)? test}) {
    return Future<List<Map<String, dynamic>>>.error(_error).catchError(onError, test: test);
  }
}

void main() {
  late MockSupabaseClient mockSupabase;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();

    final dummyBuilder = MockSupabaseQueryBuilder();
    when(() => mockSupabase.from(any())).thenAnswer((_) => dummyBuilder);
    when(() => mockSupabase.rpc(any(), params: any(named: 'params'))).thenAnswer((_) => FakePostgrestRpcFilterBuilder(null));
    when(() => dummyBuilder.select(any())).thenAnswer((_) => FakePostgrestFilterBuilder([]));
    when(() => dummyBuilder.select()).thenAnswer((_) => FakePostgrestFilterBuilder([]));
  });

  group('dossieAlunoProvider Tests (Sprint 13 DoD)', () {
    test('aluno sem histórico de transferência (1 alocação só) — compila dados corretamente', () async {
      final mockUsuarios = MockSupabaseQueryBuilder();
      final mockBanco = MockSupabaseQueryBuilder();
      final mockAloc = MockSupabaseQueryBuilder();
      final mockConflitos = MockSupabaseQueryBuilder();

      // 0. usuarios
      when(() => mockSupabase.from('usuarios')).thenAnswer((_) => mockUsuarios);
      when(() => mockUsuarios.select('*')).thenAnswer((_) => FakePostgrestFilterBuilder({
        'id': 'aluno_1',
        'nome': 'João da Silva',
        'cpf': '12345678901',
        'ativo': true,
      }));

      // 1. fn_compilar_dados_aluno
      when(() => mockSupabase.rpc('fn_compilar_dados_aluno', params: any(named: 'params'))).thenAnswer((_) => FakePostgrestRpcFilterBuilder({
        'percentual_frequencia': 95.0,
        'atividades_registradas': 10,
        'atividades_validadas': 8,
        'nota_media_do_interno': 9.2,
        'nota_autoavaliacao': 8.8,
        'termos_aceitos': true,
      }));

      // 2. banco_horas_aluno
      when(() => mockSupabase.from('banco_horas_aluno')).thenAnswer((_) => mockBanco);
      when(() => mockBanco.select('*')).thenAnswer((_) => FakePostgrestFilterBuilder({
        'aluno_id': 'aluno_1',
        'saldo_minutos': 120,
        'saldo_horas': 2.0,
      }));

      // 3. alocacoes_alunos
      when(() => mockSupabase.from('alocacoes_alunos')).thenAnswer((_) => mockAloc);
      when(() => mockAloc.select(any())).thenAnswer((_) => FakePostgrestFilterBuilder([
        {
          'id': 'aloc_1',
          'data_inicio': '2026-01-10T00:00:00.000Z',
          'data_fim': null,
          'campos_estagio': {'nome': 'Hospital Central'},
          'turnos': {'tipo': 'Manhã'},
        }
      ]));

      // 4. conflitos
      when(() => mockSupabase.from('conflitos')).thenAnswer((_) => mockConflitos);
      when(() => mockConflitos.select(any())).thenAnswer((_) => FakePostgrestFilterBuilder([
        {
          'id': 'conf_1',
          'aluno_id': 'aluno_1',
          'campo_id': 'c_1',
          'descricao': 'Atraso justificado por motivo médico',
          'data_ocorrencia': '2026-02-15T08:00:00.000Z',
          'campos_estagio': {'nome': 'Hospital Central'},
        }
      ]));

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final param = (
        alunoId: 'aluno_1',
        dataInicio: DateTime(2026, 1, 1),
        dataFim: DateTime(2026, 6, 30),
      );

      final result = await container.read(dossieAlunoProvider(param).future);

      expect(result.nome, equals('João da Silva'));
      expect(result.cpfMascarado, equals('***.***.*89-01'));
      expect(result.status, equals('Ativo'));
      expect(result.campoAtual, equals('Hospital Central'));
      expect(result.turnoAtual, equals('Manhã'));
      expect(result.resumoAcademico.percentualFrequencia, equals(95.0));
      expect(result.resumoAcademico.notaMediaDoInterno, equals(9.2));
      expect(result.bancoHoras.saldoHoras, equals(2.0));
      expect(result.historicoAlocacoes.length, equals(1));
      expect(result.ocorrencias.length, equals(1));
    });

    test('aluno com transferência (2+ alocações no histórico) — ordena e identifica vigente', () async {
      final mockUsuariosBuilder = MockSupabaseQueryBuilder();
      final mockAlocBuilder = MockSupabaseQueryBuilder();

      when(() => mockSupabase.from('usuarios')).thenAnswer((_) => mockUsuariosBuilder);
      when(() => mockUsuariosBuilder.select('*')).thenAnswer((_) => FakePostgrestFilterBuilder({
        'id': 'aluno_2',
        'nome': 'Maria Oliveira',
        'cpf': '98765432100',
        'ativo': true,
      }));

      when(() => mockSupabase.from('alocacoes_alunos')).thenAnswer((_) => mockAlocBuilder);
      when(() => mockAlocBuilder.select(any())).thenAnswer((_) => FakePostgrestFilterBuilder([
        {
          'id': 'aloc_2',
          'data_inicio': '2026-03-01T00:00:00.000Z',
          'data_fim': null,
          'campos_estagio': {'nome': 'UPA Zonal'},
          'turnos': {'tipo': 'Tarde'},
        },
        {
          'id': 'aloc_1',
          'data_inicio': '2026-01-01T00:00:00.000Z',
          'data_fim': '2026-02-28T00:00:00.000Z',
          'campos_estagio': {'nome': 'Hospital Infantil'},
          'turnos': {'tipo': 'Manhã'},
        },
      ]));

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final param = (
        alunoId: 'aluno_2',
        dataInicio: DateTime(2026, 1, 1),
        dataFim: DateTime(2026, 6, 30),
      );

      final result = await container.read(dossieAlunoProvider(param).future);

      expect(result.historicoAlocacoes.length, equals(2));
      expect(result.historicoAlocacoes[0].campoNome, equals('UPA Zonal'));
      expect(result.historicoAlocacoes[0].isVigente, isTrue);
      expect(result.historicoAlocacoes[1].campoNome, equals('Hospital Infantil'));
      expect(result.historicoAlocacoes[1].isVigente, isFalse);
    });

    test('aluno sem conflitos (empty state) e sem notas — retorna estrutura tratada', () async {
      final mockUsuariosBuilder = MockSupabaseQueryBuilder();

      when(() => mockSupabase.from('usuarios')).thenAnswer((_) => mockUsuariosBuilder);
      when(() => mockUsuariosBuilder.select('*')).thenAnswer((_) => FakePostgrestFilterBuilder({
        'id': 'aluno_3',
        'nome': 'Pedro Santos',
        'cpf': '11122233344',
        'ativo': true,
      }));

      when(() => mockSupabase.rpc('fn_compilar_dados_aluno', params: any(named: 'params'))).thenAnswer((_) => FakePostgrestRpcFilterBuilder({
        'percentual_frequencia': 100.0,
        'atividades_registradas': 5,
        'atividades_validadas': 5,
        'nota_media_do_interno': null,
        'nota_autoavaliacao': null,
        'termos_aceitos': true,
      }));

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final param = (
        alunoId: 'aluno_3',
        dataInicio: DateTime(2026, 1, 1),
        dataFim: DateTime(2026, 6, 30),
      );

      final result = await container.read(dossieAlunoProvider(param).future);

      expect(result.ocorrencias, isEmpty);
      expect(result.resumoAcademico.notaMediaDoInterno, isNull);
      expect(result.resumoAcademico.notaAutoavaliacao, isNull);
    });

    test('professor tentando ver dossiê fora do escopo — RLS lança erro e provider lança exceção tratável', () async {
      final mockUsuariosBuilder = MockSupabaseQueryBuilder();

      when(() => mockSupabase.from('usuarios')).thenAnswer((_) => mockUsuariosBuilder);
      when(() => mockUsuariosBuilder.select('*')).thenAnswer((_) => FakeErrorPostgrestFilterBuilder(
        const PostgrestException(message: 'Permission denied for table usuarios'),
      ));

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final param = (
        alunoId: 'aluno_fora_escopo',
        dataInicio: DateTime(2026, 1, 1),
        dataFim: DateTime(2026, 6, 30),
      );

      expect(
        () => container.read(dossieAlunoProvider(param).future),
        throwsA(isA<Exception>()),
      );
    });
  });
}
