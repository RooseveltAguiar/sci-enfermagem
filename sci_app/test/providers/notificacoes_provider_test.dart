// test/providers/notificacoes_provider_test.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/providers/notificacoes_provider.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestSelectBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

class MockPostgrestRpcBuilder extends Mock
    implements PostgrestFilterBuilder<dynamic> {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockPostgrestFilterBuilderDynamic extends Mock
    implements PostgrestFilterBuilder<dynamic> {}

void _stubAwaitSelect(
  MockPostgrestSelectBuilder builder, {
  List<Map<String, dynamic>> value = const [],
}) {
  when(() => builder.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onValue = invocation.positionalArguments[0] as Function;
    return Future<dynamic>.value(onValue(value));
  });
}

void _stubAwaitSelectError(MockPostgrestSelectBuilder builder, Object error) {
  when(() => builder.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onError = invocation.namedArguments[#onError] as Function?;
    if (onError != null) {
      if (onError is Function(Object, StackTrace)) {
        return Future<dynamic>.sync(() => onError(error, StackTrace.current));
      } else if (onError is Function(Object)) {
        return Future<dynamic>.sync(() => onError(error));
      } else {
        return Future<dynamic>.sync(() {
          try {
            return (onError as dynamic)(error, StackTrace.current);
          } catch (_) {
            return (onError as dynamic)(error);
          }
        });
      }
    }
    return Future<dynamic>.error(error);
  });
}


void _stubAwaitUpdate(MockPostgrestFilterBuilderDynamic builder, {dynamic value}) {
  when(() => builder.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onValue = invocation.positionalArguments[0] as Function;
    return Future<dynamic>.value(onValue(value));
  });
}

void _stubAwaitUpdateError(MockPostgrestFilterBuilderDynamic builder, Object error) {
  when(() => builder.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onError = invocation.namedArguments[#onError] as Function?;
    if (onError != null) {
      if (onError is Function(Object, StackTrace)) {
        return Future<dynamic>.sync(() => onError(error, StackTrace.current));
      } else if (onError is Function(Object)) {
        return Future<dynamic>.sync(() => onError(error));
      } else {
        return Future<dynamic>.sync(() {
          try {
            return (onError as dynamic)(error, StackTrace.current);
          } catch (_) {
            return (onError as dynamic)(error);
          }
        });
      }
    }
    return Future<dynamic>.error(error);
  });
}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockAuth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
    when(() => mockAuth.currentUser).thenReturn(
      User(
        id: 'user-123',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      ),
    );
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(mockSupabase),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('Notificacao model', () {
    test('fromJson faz parsing correto com campos completos e opcionais', () {
      final jsonCompleto = {
        'id': 'notif-1',
        'mensagem': 'Nova frequência registrada',
        'tipo_notificacao': 'frequencia',
        'frequencia_id': 'freq-123',
        'created_at': '2026-07-17T10:00:00Z',
        'lida': true,
      };

      final notif = Notificacao.fromJson(jsonCompleto);
      expect(notif.id, 'notif-1');
      expect(notif.mensagem, 'Nova frequência registrada');
      expect(notif.tipo, 'frequencia');
      expect(notif.frequenciaId, 'freq-123');
      expect(notif.dataCriacao, '2026-07-17T10:00:00Z');
      expect(notif.lida, true);
    });

    test('fromJson assume lida = false quando null e lida com campos opcionais null', () {
      final jsonParcial = {
        'id': 'notif-2',
        'mensagem': 'Mensagem simples',
        'created_at': '2026-07-17T11:00:00Z',
      };

      final notif = Notificacao.fromJson(jsonParcial);
      expect(notif.id, 'notif-2');
      expect(notif.mensagem, 'Mensagem simples');
      expect(notif.tipo, isNull);
      expect(notif.frequenciaId, isNull);
      expect(notif.lida, false);
    });
  });

  group('NotificacoesNotifier', () {
    test('loadNotificacoes carrega lista com sucesso', () async {
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockSelectBuilder = MockPostgrestSelectBuilder();

      when(() => mockSupabase.from('notificacoes')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select('*')).thenAnswer((_) => mockSelectBuilder);
      when(() => mockSelectBuilder.order('created_at', ascending: false))
          .thenAnswer((_) => mockSelectBuilder);
      _stubAwaitSelect(mockSelectBuilder, value: [
        {
          'id': 'notif-1',
          'mensagem': 'Notif 1',
          'created_at': '2026-07-17T10:00:00Z',
          'lida': false,
        },
        {
          'id': 'notif-2',
          'mensagem': 'Notif 2',
          'created_at': '2026-07-17T09:00:00Z',
          'lida': true,
        }
      ]);

      final container = buildContainer();
      // O provider no init já chama loadNotificacoes()
      final notifier = container.read(notificacoesProvider.notifier);
      await notifier.loadNotificacoes();

      final state = container.read(notificacoesProvider);
      expect(state.hasValue, true);
      expect(state.value!.length, 2);
      expect(state.value![0].id, 'notif-1');
      expect(state.value![1].id, 'notif-2');
    });

    test('loadNotificacoes captura erro e reflete no estado', () async {
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockSelectBuilder = MockPostgrestSelectBuilder();

      when(() => mockSupabase.from('notificacoes')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select('*')).thenAnswer((_) => mockSelectBuilder);
      when(() => mockSelectBuilder.order('created_at', ascending: false))
          .thenAnswer((_) => mockSelectBuilder);
      _stubAwaitSelectError(mockSelectBuilder, Exception('Erro no banco de dados'));

      final container = buildContainer();
      final notifier = container.read(notificacoesProvider.notifier);
      await notifier.loadNotificacoes();

      final state = container.read(notificacoesProvider);
      expect(state.hasError, true);
    });

    test('marcarComoLida executa UPDATE e atualiza estado localmente apenas para o id correspondente', () async {
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockSelectBuilder = MockPostgrestSelectBuilder();
      final mockUpdateBuilder = MockPostgrestFilterBuilderDynamic();

      when(() => mockSupabase.from('notificacoes')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select('*')).thenAnswer((_) => mockSelectBuilder);
      when(() => mockSelectBuilder.order('created_at', ascending: false))
          .thenAnswer((_) => mockSelectBuilder);
      _stubAwaitSelect(mockSelectBuilder, value: [
        {
          'id': 'notif-1',
          'mensagem': 'Notif 1',
          'created_at': '2026-07-17T10:00:00Z',
          'lida': false,
        },
        {
          'id': 'notif-2',
          'mensagem': 'Notif 2',
          'created_at': '2026-07-17T09:00:00Z',
          'lida': false,
        }
      ]);

      when(() => mockQueryBuilder.update({'lida': true})).thenAnswer((_) => mockUpdateBuilder);
      when(() => mockUpdateBuilder.eq('id', 'notif-1')).thenAnswer((_) => mockUpdateBuilder);
      _stubAwaitUpdate(mockUpdateBuilder, value: null);

      final container = buildContainer();
      final notifier = container.read(notificacoesProvider.notifier);
      await notifier.loadNotificacoes();

      await notifier.marcarComoLida('notif-1');

      verify(() => mockQueryBuilder.update({'lida': true})).called(1);
      verify(() => mockUpdateBuilder.eq('id', 'notif-1')).called(1);

      final state = container.read(notificacoesProvider);
      expect(state.value!.firstWhere((n) => n.id == 'notif-1').lida, true);
      expect(state.value!.firstWhere((n) => n.id == 'notif-2').lida, false);
    });

    test('marcarComoLida ignora atualização de estado quando state não tem valor', () async {
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockSelectBuilder = MockPostgrestSelectBuilder();
      final mockUpdateBuilder = MockPostgrestFilterBuilderDynamic();

      when(() => mockSupabase.from('notificacoes')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select('*')).thenAnswer((_) => mockSelectBuilder);
      when(() => mockSelectBuilder.order('created_at', ascending: false))
          .thenAnswer((_) => mockSelectBuilder);
      _stubAwaitSelectError(mockSelectBuilder, Exception('Erro inicial de select'));

      when(() => mockQueryBuilder.update({'lida': true})).thenAnswer((_) => mockUpdateBuilder);
      when(() => mockUpdateBuilder.eq('id', 'notif-1')).thenAnswer((_) => mockUpdateBuilder);
      _stubAwaitUpdate(mockUpdateBuilder, value: null);

      final container = buildContainer();
      final notifier = container.read(notificacoesProvider.notifier);
      await notifier.loadNotificacoes(); // state vira erro (hasValue = false)

      await notifier.marcarComoLida('notif-1');
      verify(() => mockQueryBuilder.update({'lida': true})).called(1);
      expect(container.read(notificacoesProvider).hasError, true);
    });

    test('marcarComoLida captura erro no UPDATE genuíno e transiciona estado para erro', () async {
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockSelectBuilder = MockPostgrestSelectBuilder();
      final mockUpdateBuilder = MockPostgrestFilterBuilderDynamic();

      when(() => mockSupabase.from('notificacoes')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select('*')).thenAnswer((_) => mockSelectBuilder);
      when(() => mockSelectBuilder.order('created_at', ascending: false))
          .thenAnswer((_) => mockSelectBuilder);
      _stubAwaitSelect(mockSelectBuilder, value: [
        {
          'id': 'notif-1',
          'mensagem': 'Notif 1',
          'created_at': '2026-07-17T10:00:00Z',
          'lida': false,
        }
      ]);

      when(() => mockQueryBuilder.update({'lida': true})).thenAnswer((_) => mockUpdateBuilder);
      when(() => mockUpdateBuilder.eq('id', 'notif-1')).thenAnswer((_) => mockUpdateBuilder);
      _stubAwaitUpdateError(mockUpdateBuilder, Exception('Erro real no UPDATE'));

      final container = buildContainer();
      final notifier = container.read(notificacoesProvider.notifier);
      await notifier.loadNotificacoes();

      await notifier.marcarComoLida('notif-1');

      final state = container.read(notificacoesProvider);
      expect(state.hasError, true);
    });

    test('marcarTodasComoLidas retorna sem fazer UPDATE se userId for nulo', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockSelectBuilder = MockPostgrestSelectBuilder();

      when(() => mockSupabase.from('notificacoes')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select('*')).thenAnswer((_) => mockSelectBuilder);
      when(() => mockSelectBuilder.order('created_at', ascending: false))
          .thenAnswer((_) => mockSelectBuilder);
      _stubAwaitSelect(mockSelectBuilder, value: [
        {
          'id': 'notif-1',
          'mensagem': 'Notif 1',
          'created_at': '2026-07-17T10:00:00Z',
          'lida': false,
        }
      ]);

      final container = buildContainer();
      final notifier = container.read(notificacoesProvider.notifier);
      await notifier.loadNotificacoes();

      await notifier.marcarTodasComoLidas();

      verifyNever(() => mockQueryBuilder.update(any()));
      expect(container.read(notificacoesProvider).hasError, false);
    });

    test('marcarTodasComoLidas executa UPDATE em lote e atualiza todas no estado local para lida = true', () async {
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockSelectBuilder = MockPostgrestSelectBuilder();
      final mockUpdateBuilder = MockPostgrestFilterBuilderDynamic();

      when(() => mockSupabase.from('notificacoes')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select('*')).thenAnswer((_) => mockSelectBuilder);
      when(() => mockSelectBuilder.order('created_at', ascending: false))
          .thenAnswer((_) => mockSelectBuilder);
      _stubAwaitSelect(mockSelectBuilder, value: [
        {
          'id': 'notif-1',
          'mensagem': 'Notif 1',
          'created_at': '2026-07-17T10:00:00Z',
          'lida': false,
        },
        {
          'id': 'notif-2',
          'mensagem': 'Notif 2',
          'created_at': '2026-07-17T09:00:00Z',
          'lida': false,
        }
      ]);

      when(() => mockQueryBuilder.update({'lida': true})).thenAnswer((_) => mockUpdateBuilder);
      when(() => mockUpdateBuilder.eq('destinatario_id', 'user-123')).thenAnswer((_) => mockUpdateBuilder);
      when(() => mockUpdateBuilder.eq('lida', false)).thenAnswer((_) => mockUpdateBuilder);
      _stubAwaitUpdate(mockUpdateBuilder, value: null);

      final container = buildContainer();
      final notifier = container.read(notificacoesProvider.notifier);
      await notifier.loadNotificacoes();

      await notifier.marcarTodasComoLidas();

      verify(() => mockQueryBuilder.update({'lida': true})).called(1);
      verify(() => mockUpdateBuilder.eq('destinatario_id', 'user-123')).called(1);
      verify(() => mockUpdateBuilder.eq('lida', false)).called(1);

      final state = container.read(notificacoesProvider);
      expect(state.value!.every((n) => n.lida == true), true);
    });

    test('marcarTodasComoLidas captura erro no UPDATE genuíno e transiciona estado para erro', () async {
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockSelectBuilder = MockPostgrestSelectBuilder();
      final mockUpdateBuilder = MockPostgrestFilterBuilderDynamic();

      when(() => mockSupabase.from('notificacoes')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select('*')).thenAnswer((_) => mockSelectBuilder);
      when(() => mockSelectBuilder.order('created_at', ascending: false))
          .thenAnswer((_) => mockSelectBuilder);
      _stubAwaitSelect(mockSelectBuilder, value: [
        {
          'id': 'notif-1',
          'mensagem': 'Notif 1',
          'created_at': '2026-07-17T10:00:00Z',
          'lida': false,
        }
      ]);

      when(() => mockQueryBuilder.update({'lida': true})).thenAnswer((_) => mockUpdateBuilder);
      when(() => mockUpdateBuilder.eq('destinatario_id', 'user-123')).thenAnswer((_) => mockUpdateBuilder);
      when(() => mockUpdateBuilder.eq('lida', false)).thenAnswer((_) => mockUpdateBuilder);
      _stubAwaitUpdateError(mockUpdateBuilder, Exception('falha real no update em lote'));

      final container = buildContainer();
      final notifier = container.read(notificacoesProvider.notifier);
      await notifier.loadNotificacoes();

      await notifier.marcarTodasComoLidas();
      expect(container.read(notificacoesProvider).hasError, true);
    });
  });

  group('notificacoesNaoLidasCountProvider', () {
    test('conta apenas notificações não lidas no estado data', () async {
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockSelectBuilder = MockPostgrestSelectBuilder();

      when(() => mockSupabase.from('notificacoes')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select('*')).thenAnswer((_) => mockSelectBuilder);
      when(() => mockSelectBuilder.order('created_at', ascending: false))
          .thenAnswer((_) => mockSelectBuilder);
      _stubAwaitSelect(mockSelectBuilder, value: [
        {'id': '1', 'mensagem': 'a', 'created_at': '2026-01-01', 'lida': false},
        {'id': '2', 'mensagem': 'b', 'created_at': '2026-01-01', 'lida': true},
        {'id': '3', 'mensagem': 'c', 'created_at': '2026-01-01', 'lida': false},
      ]);

      final container = buildContainer();
      // força inicialização do provider principal
      await container.read(notificacoesProvider.notifier).loadNotificacoes();

      final count = container.read(notificacoesNaoLidasCountProvider);
      expect(count, 2);
    });

    test('retorna 0 em orElse (quando estado é loading ou error)', () async {
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockSelectBuilder = MockPostgrestSelectBuilder();

      when(() => mockSupabase.from('notificacoes')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select('*')).thenAnswer((_) => mockSelectBuilder);
      when(() => mockSelectBuilder.order('created_at', ascending: false))
          .thenAnswer((_) => mockSelectBuilder);
      _stubAwaitSelectError(mockSelectBuilder, Exception('falha'));

      final container = buildContainer();
      await container.read(notificacoesProvider.notifier).loadNotificacoes();

      final count = container.read(notificacoesNaoLidasCountProvider);
      expect(count, 0);
    });
  });
}
