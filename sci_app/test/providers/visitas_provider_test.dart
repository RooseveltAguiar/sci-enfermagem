import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/providers/visitas_provider.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}
class MockPostgrestTransformBuilder extends Mock implements PostgrestTransformBuilder<Map<String, dynamic>?> {}
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
    when(() => mockUser.id).thenReturn('prof_123');
  });

  group('VisitaTecnica & ProgressoVisitasMensal Models & Validation (Sprint 12)', () {
    test('VisitaTecnica.fromJson deserializa campos de visita e relacionamentos reais do Supabase', () {
      final json = {
        'id': 'v-100',
        'professor_id': 'prof-01',
        'usuarios': {
          'nome': 'Prof. Ricardo',
        },
        'campo_id': 'campo-01',
        'campos_estagio': {
          'nome': 'Hospital Geral',
        },
        'relato': 'Acompanhamento dos alunos no setor de UTI neonatal e orientação de procedimentos.',
        'status': 'pendente_validacao',
        'lat': -3.7912,
        'lng': -38.5534,
        'gps_disponivel': true,
        'distancia_metros': 25.5,
        'mock_location_detectado': false,
        'created_at': '2026-08-23T14:30:00.000',
      };

      final visita = VisitaTecnica.fromJson(json);

      expect(visita.id, equals('v-100'));
      expect(visita.professorId, equals('prof-01'));
      expect(visita.professorNome, equals('Prof. Ricardo'));
      expect(visita.campoId, equals('campo-01'));
      expect(visita.campoNome, equals('Hospital Geral'));
      expect(visita.relato.length, greaterThanOrEqualTo(30));
      expect(visita.status, equals('pendente_validacao'));
      expect(visita.lat, equals(-3.7912));
      expect(visita.lng, equals(-38.5534));
      expect(visita.gpsDisponivel, isTrue);
      expect(visita.distanciaMetros, equals(25.5));
      expect(visita.mockLocationDetectado, isFalse);
    });

    test('progressoVisitasMensalProvider executa busca Supabase e filtra rejeitadas (Mocking Real)', () async {
      final mockConfigBuilder = MockSupabaseQueryBuilder();
      final mockConfigFilter = MockPostgrestFilterBuilder();
      final mockConfigSingle = MockPostgrestTransformBuilder();

      final mockTurmasBuilder = MockSupabaseQueryBuilder();
      final mockTurmasFilter = MockPostgrestFilterBuilder();

      final mockVisitasBuilder = MockSupabaseQueryBuilder();
      final mockVisitasFilter = MockPostgrestFilterBuilder();

      // 1. Stub configuracoes
      when(() => mockSupabase.from('configuracoes')).thenAnswer((_) => mockConfigBuilder);
      when(() => mockConfigBuilder.select('valor')).thenAnswer((_) => mockConfigFilter);
      when(() => mockConfigFilter.eq('chave', 'visitas_minimas_por_mes')).thenAnswer((_) => mockConfigFilter);
      when(() => mockConfigFilter.maybeSingle()).thenAnswer((_) => mockConfigSingle);
      when(() => mockConfigSingle.then<dynamic>(any(), onError: any(named: 'onError')))
          .thenAnswer((invocation) {
        final onValue = invocation.positionalArguments[0] as Function;
        return Future<dynamic>.value(onValue({'valor': '1'}));
      });

      // 2. Stub professor_turmas
      when(() => mockSupabase.from('professor_turmas')).thenAnswer((_) => mockTurmasBuilder);
      when(() => mockTurmasBuilder.select('campo_id, campos_estagio(id, nome)')).thenAnswer((_) => mockTurmasFilter);
      when(() => mockTurmasFilter.eq('professor_id', 'prof_123')).thenAnswer((_) => mockTurmasFilter);
      _stubAwait(mockTurmasFilter, value: [
        {
          'campo_id': 'c1',
          'campos_estagio': {'id': 'c1', 'nome': 'Hospital Geral'},
        },
        {
          'campo_id': 'c2',
          'campos_estagio': {'id': 'c2', 'nome': 'Posto de Saúde'},
        },
      ]);

      // 3. Stub visitas_tecnicas
      when(() => mockSupabase.from('visitas_tecnicas')).thenAnswer((_) => mockVisitasBuilder);
      when(() => mockVisitasBuilder.select('campo_id, created_at')).thenAnswer((_) => mockVisitasFilter);
      when(() => mockVisitasFilter.eq('professor_id', 'prof_123')).thenAnswer((_) => mockVisitasFilter);
      when(() => mockVisitasFilter.inFilter('status', ['pendente_validacao', 'validada'])).thenAnswer((_) => mockVisitasFilter);
      when(() => mockVisitasFilter.gte('created_at', any())).thenAnswer((_) => mockVisitasFilter);
      when(() => mockVisitasFilter.lte('created_at', any())).thenAnswer((_) => mockVisitasFilter);
      _stubAwait(mockVisitasFilter, value: [
        {'campo_id': 'c1', 'created_at': '2026-08-20T10:00:00.000'},
      ]);

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final resultado = await container.read(progressoVisitasMensalProvider(null).future);

      expect(resultado.length, equals(2));

      final c1Progresso = resultado.firstWhere((p) => p.campoId == 'c1');
      final c2Progresso = resultado.firstWhere((p) => p.campoId == 'c2');

      expect(c1Progresso.realizadas, equals(1));
      expect(c1Progresso.minimasRequeridas, equals(1));
      expect(c1Progresso.atingiuMinimo, isTrue);

      expect(c2Progresso.realizadas, equals(0));
      expect(c2Progresso.minimasRequeridas, equals(1));
      expect(c2Progresso.atingiuMinimo, isFalse);
    });

    test('VisitasService.registrarVisita lança ArgumentError se relato tiver menos de 30 caracteres', () {
      final container = ProviderContainer();
      final service = container.read(visitasServiceProvider);

      expect(
        () => service.registrarVisita(
          campoId: 'campo-1',
          relato: 'Relato muito curto',
          lat: -3.7,
          lng: -38.5,
          gpsDisponivel: true,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('VisitasService.rejeitarVisita lança ArgumentError se justificativa tiver menos de 20 caracteres', () {
      final container = ProviderContainer();
      final service = container.read(visitasServiceProvider);

      expect(
        () => service.rejeitarVisita('v-1', 'Curto demais'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
