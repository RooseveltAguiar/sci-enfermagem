import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/services/cache_service.dart';
import 'package:sci_app/services/sync_service.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

void _stubAwait(
  MockPostgrestFilterBuilder builder,
  List<Map<String, dynamic>> returnValue,
) {
  when(() => builder.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final callback = invocation.positionalArguments[0] as Function;
    final onError = invocation.namedArguments[#onError] as Function?;
    return Future<List<Map<String, dynamic>>>.value(returnValue).then(
      (v) => callback(v),
      onError: onError,
    );
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CacheService cacheService;
  late MockSupabaseClient mockSupabase;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockPostgrestFilterBuilder mockFilterBuilder;
  late SyncService syncService;

  bool simulatedOnline = true;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'check') {
          return simulatedOnline ? ['wifi'] : ['none'];
        }
        return simulatedOnline ? ['wifi'] : ['none'];
      },
    );
  });

  setUp(() {
    simulatedOnline = true;
    cacheService = CacheService(NativeDatabase.memory());
    mockSupabase = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockFilterBuilder = MockPostgrestFilterBuilder();

    when(() => mockSupabase.from(any())).thenAnswer((_) => mockQueryBuilder);

    syncService = SyncService(cacheService, mockSupabase);
  });

  tearDown(() async {
    syncService.dispose();
    await cacheService.close();
  });

  group('SyncService - statusStream e monitoring', () {
    test('startMonitoring emite estado inicial na statusStream e stopMonitoring para listener', () async {
      final statuses = <SyncStatus>[];
      final sub = syncService.statusStream.listen(statuses.add);

      syncService.startMonitoring();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(statuses, contains(SyncStatus.idle));
      expect(syncService.currentStatus, SyncStatus.idle);

      syncService.stopMonitoring();
      await sub.cancel();
    });

    test('checkOnline reflete o status de rede (online ou offline)', () async {
      simulatedOnline = true;
      expect(await syncService.checkOnline(), isTrue);

      simulatedOnline = false;
      expect(await syncService.checkOnline(), isFalse);
    });
  });

  group('SyncService - processQueue', () {
    test('não processa se estiver offline ou se fila estiver vazia', () async {
      simulatedOnline = false;
      await syncService.processQueue();
      expect(syncService.currentStatus, SyncStatus.idle);

      simulatedOnline = true;
      await syncService.processQueue(); // Fila vazia
      expect(syncService.currentStatus, SyncStatus.idle);
    });

    test('processa insert com sucesso, notifica callback e limpa da syncQueue', () async {
      await cacheService.enqueueSync(
        operacao: 'insert',
        tabela: 'frequencias',
        payload: '{"aluno_id": "user123", "tipo": "ENTRADA"}',
        registroId: 'reg-1',
      );

      when(() => mockQueryBuilder.insert(any())).thenAnswer((_) => mockFilterBuilder);
      _stubAwait(mockFilterBuilder, <Map<String, dynamic>>[]);

      String? notificationMsg;
      syncService.onSyncNotification = (msg) {
        notificationMsg = msg;
      };

      await syncService.processQueue();

      expect(syncService.currentStatus, SyncStatus.idle);
      expect(await cacheService.getPendingSyncEntries(), isEmpty);
      expect(notificationMsg, contains('1 registro(s) sincronizado(s) com sucesso'));
    });

    test('processa update com id, remove id do map na chamada eq e limpa da fila', () async {
      await cacheService.enqueueSync(
        operacao: 'update',
        tabela: 'atividades',
        payload: '{"id": "ativ-99", "status": "validado"}',
        registroId: 'ativ-99',
      );

      when(() => mockQueryBuilder.update(any())).thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.eq('id', 'ativ-99')).thenAnswer((_) => mockFilterBuilder);
      _stubAwait(mockFilterBuilder, <Map<String, dynamic>>[]);

      await syncService.processQueue();

      expect(await cacheService.getPendingSyncEntries(), isEmpty);
      verify(() => mockQueryBuilder.update({'status': 'validado'})).called(1);
    });

    test('bloqueia e registra erro ao tentar processar update sem id no payload', () async {
      await cacheService.enqueueSync(
        operacao: 'update',
        tabela: 'configuracoes',
        payload: '{"chave": "valor"}',
      );

      await syncService.processQueue();

      final pending = await cacheService.getPendingSyncEntries();
      expect(pending, isNotEmpty);
      expect(pending.first.tentativas, 1);
      expect(pending.first.erroUltimo, contains('Sincronização de update sem id não é permitida: configuracoes'));
    });

    test('em falha no supabase, incrementa tentativas no cache e emite SyncStatus.error', () async {
      await cacheService.enqueueSync(
        operacao: 'insert',
        tabela: 'frequencias',
        payload: '{"aluno_id": "falha"}',
      );

      when(() => mockQueryBuilder.insert(any())).thenThrow(Exception('Erro de rede postgrest'));

      await syncService.processQueue();

      expect(syncService.currentStatus, SyncStatus.error);

      final pendentes = await cacheService.getPendingSyncEntries();
      expect(pendentes, hasLength(1));
      expect(pendentes.first.tentativas, 1);
      expect(pendentes.first.erroUltimo, contains('Erro de rede postgrest'));
    });
  });
}
