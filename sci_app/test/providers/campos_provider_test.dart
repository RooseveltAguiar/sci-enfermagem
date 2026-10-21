import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/providers/campos_provider.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockUser extends Mock implements User {}

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

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.id).thenReturn('aluno_123');
  });

  group('CampoEstagio model', () {
    test('fromJson processa valores completos e defaults para nulos', () {
      final jsonCompleto = {
        'id': 'cmp_1',
        'nome': 'Hospital Geral',
        'endereco': 'Rua A, 100',
        'ativo': false,
        'raio_metros': 200.5,
        'lat_centro': -3.75,
        'lng_centro': -38.52,
      };
      final campo = CampoEstagio.fromJson(jsonCompleto);
      expect(campo.id, 'cmp_1');
      expect(campo.nome, 'Hospital Geral');
      expect(campo.endereco, 'Rua A, 100');
      expect(campo.ativo, false);
      expect(campo.raioMetros, 200.5);
      expect(campo.lat, -3.75);
      expect(campo.lng, -38.52);

      final jsonParcial = {
        'id': 'cmp_2',
        'nome': 'UBS Central',
        'endereco': 'Av B, 200',
      };
      final campoParcial = CampoEstagio.fromJson(jsonParcial);
      expect(campoParcial.ativo, true);
      expect(campoParcial.raioMetros, 150.0);
      expect(campoParcial.lat, 0.0);
      expect(campoParcial.lng, 0.0);
    });
  });

  group('CamposNotifier - loadCampos', () {
    test('carrega campos com sucesso', () async {
      final mockBuilder = MockSupabaseQueryBuilder();
      final mockFilter = MockPostgrestFilterBuilder();

      when(() => mockSupabase.from('campos_estagio')).thenAnswer((_) => mockBuilder);
      when(() => mockBuilder.select('*')).thenAnswer((_) => mockFilter);
      when(() => mockFilter.isFilter('deleted_at', null)).thenAnswer((_) => mockFilter);
      when(() => mockFilter.order('nome', ascending: true)).thenAnswer((_) => mockFilter);
      _stubAwait(mockFilter, value: [
        {
          'id': 'cmp_1',
          'nome': 'Hospital A',
          'endereco': 'Rua 1',
          'ativo': true,
          'raio_metros': 150.0,
          'lat_centro': 0.0,
          'lng_centro': 0.0,
        }
      ]);

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(camposProvider.notifier);
      await notifier.loadCampos();

      expect(notifier.state.hasValue, true);
      expect(notifier.state.value!.length, 1);
      expect(notifier.state.value!.first.nome, 'Hospital A');
    });

    test('captura erro ao carregar campos', () async {
      when(() => mockSupabase.from('campos_estagio')).thenThrow(Exception('Erro de rede'));

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(camposProvider.notifier);
      await notifier.loadCampos();

      expect(notifier.state.hasError, true);
    });
  });

  group('CamposNotifier - loadCamposDoAluno', () {
    test('carrega campos onde aluno está alocado com sucesso', () async {
      final mockBuilder = MockSupabaseQueryBuilder();
      final mockFilter = MockPostgrestFilterBuilder();

      when(() => mockSupabase.from('alocacoes_alunos')).thenAnswer((_) => mockBuilder);
      when(() => mockBuilder.select('*, campos_estagio(*)')).thenAnswer((_) => mockFilter);
      when(() => mockFilter.eq('aluno_id', 'aluno_123')).thenAnswer((_) => mockFilter);
      when(() => mockFilter.eq('ativo', true)).thenAnswer((_) => mockFilter);
      when(() => mockFilter.isFilter('deleted_at', null)).thenAnswer((_) => mockFilter);
      _stubAwait(mockFilter, value: [
        {
          'campos_estagio': {
            'id': 'cmp_5',
            'nome': 'Hospital Universitário',
            'endereco': 'Campus Itaperi',
            'ativo': true,
          }
        }
      ]);

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(camposAlunoProvider.notifier);
      await notifier.loadCamposDoAluno();

      expect(notifier.state.hasValue, true);
      expect(notifier.state.value!.length, 1);
      expect(notifier.state.value!.first.id, 'cmp_5');
    });

    test('captura erro ao carregar campos do aluno', () async {
      when(() => mockSupabase.from('alocacoes_alunos')).thenThrow(Exception('Erro no banco'));

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(camposAlunoProvider.notifier);
      await notifier.loadCamposDoAluno();

      expect(notifier.state.hasError, true);
    });
  });
}
