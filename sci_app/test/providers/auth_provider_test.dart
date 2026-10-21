import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/providers/auth_provider.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockUser extends Mock implements User {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder<PostgrestList> {}
class MockPostgrestTransformBuilder extends Mock implements PostgrestTransformBuilder<Map<String, dynamic>> {}

void _stubTransformAwait(
  MockPostgrestTransformBuilder builder, {
  required Map<String, dynamic> value,
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
  });

  group('userProfileProvider', () {
    test('retorna perfil do demoProfileProvider se estiver definido', () async {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      container.read(demoProfileProvider.notifier).state = 'coordenacao';
      final profile = await container.read(userProfileProvider.future);

      expect(profile, 'coordenacao');
    });

    test('retorna null se não há usuário logado no Supabase e demoProfile null', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final profile = await container.read(userProfileProvider.future);
      expect(profile, isNull);
    });

    test('retorna perfil do appMetadata quando presente', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.appMetadata).thenReturn({'perfil': 'supervisor'});

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final profile = await container.read(userProfileProvider.future);
      expect(profile, 'supervisor');
    });

    test('retorna perfil do userMetadata quando presente e ausente no appMetadata', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.appMetadata).thenReturn({});
      when(() => mockUser.userMetadata).thenReturn({'perfil': 'professor'});

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final profile = await container.read(userProfileProvider.future);
      expect(profile, 'professor');
    });

    test('busca perfil da tabela usuarios quando não está em metadados', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.id).thenReturn('user-123');
      when(() => mockUser.appMetadata).thenReturn({});
      when(() => mockUser.userMetadata).thenReturn({});

      final mockBuilder = MockSupabaseQueryBuilder();
      final mockFilter = MockPostgrestFilterBuilder();
      final mockTransform = MockPostgrestTransformBuilder();

      when(() => mockSupabase.from('usuarios')).thenAnswer((_) => mockBuilder);
      when(() => mockBuilder.select('perfil')).thenAnswer((_) => mockFilter);
      when(() => mockFilter.eq('id', 'user-123')).thenAnswer((_) => mockFilter);
      when(() => mockFilter.single()).thenAnswer((_) => mockTransform);
      _stubTransformAwait(mockTransform, value: {'perfil': 'aluno'});

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final profile = await container.read(userProfileProvider.future);
      expect(profile, 'aluno');
    });

    test('retorna null se a consulta à tabela usuarios falhar', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.id).thenReturn('user-err');
      when(() => mockUser.appMetadata).thenReturn({});
      when(() => mockUser.userMetadata).thenReturn({});

      when(() => mockSupabase.from('usuarios')).thenThrow(Exception('Erro no banco'));

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final profile = await container.read(userProfileProvider.future);
      expect(profile, isNull);
    });
  });

  group('AuthNotifier', () {
    test('login falha quando CPF não tem 11 dígitos', () async {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.login('123', 'senha123');

      final state = container.read(authNotifierProvider);
      expect(state.hasError, true);
      expect(state.error.toString(), contains('CPF deve conter exatamente 11 dígitos'));
    });

    test('login sucesso para aluno com CPF normal', () async {
      when(() => mockAuth.signInWithPassword(
        email: '11111111111@sci.uece.br',
        password: 'password123',
      )).thenAnswer((_) async => AuthResponse());

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.login('111.111.111-11', 'password123');

      final state = container.read(authNotifierProvider);
      expect(state.hasError, false);
      expect(state.isLoading, false);
    });

    test('login sucesso para supervisor com CPF terminado em 201', () async {
      when(() => mockAuth.signInWithPassword(
        email: '00000000201@sci.uece.br',
        password: 'password123',
      )).thenAnswer((_) async => AuthResponse());

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.login('00000000201', 'password123');

      final state = container.read(authNotifierProvider);
      expect(state.hasError, false);
      expect(state.isLoading, false);
    });

    test('login sucesso para professor com CPF terminado em 301', () async {
      when(() => mockAuth.signInWithPassword(
        email: '00000000301@sci.uece.br',
        password: 'password123',
      )).thenAnswer((_) async => AuthResponse());

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.login('00000000301', 'password123');

      final state = container.read(authNotifierProvider);
      expect(state.hasError, false);
      expect(state.isLoading, false);
    });

    test('login sucesso para coordenacao com CPF terminado em 401', () async {
      when(() => mockAuth.signInWithPassword(
        email: '00000000401@sci.uece.br',
        password: 'password123',
      )).thenAnswer((_) async => AuthResponse());

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.login('00000000401', 'password123');

      final state = container.read(authNotifierProvider);
      expect(state.hasError, false);
      expect(state.isLoading, false);
    });

    test('login rethrow erro de signIn quando kModoTesteLogin é false', () async {
      when(() => mockAuth.signInWithPassword(
        email: '99999999999@sci.uece.br',
        password: 'err',
      )).thenThrow(AuthException('Falha no login'));

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.login('99999999999', 'err');

      final state = container.read(authNotifierProvider);
      expect(state.hasError, true);
    });

    test('logout limpa demoProfileProvider e chama signOut', () async {
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      container.read(demoProfileProvider.notifier).state = 'aluno';
      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.logout();

      expect(container.read(demoProfileProvider), isNull);
      verify(() => mockAuth.signOut()).called(1);
    });

    test('logout silencia exceção do signOut sem quebrar', () async {
      when(() => mockAuth.signOut()).thenThrow(Exception('Erro no signout'));

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.logout();

      expect(container.read(demoProfileProvider), isNull);
    });
  });
}
