import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/providers/sync_provider.dart';
import 'package:sci_app/services/cache_service.dart';
import 'package:sci_app/services/sync_service.dart';

class MockSyncService extends Mock implements SyncService {}
class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CacheService memoryCacheService;
  late MockSupabaseClient mockSupabase;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (MethodCall methodCall) async {
        return ['wifi'];
      },
    );
  });

  setUp(() {
    memoryCacheService = CacheService(NativeDatabase.memory());
    mockSupabase = MockSupabaseClient();
  });

  tearDown(() async {
    await memoryCacheService.close();
  });

  group('SyncProvider e providers relacionados', () {
    test('cacheServiceProvider default cria instancia real e pode ser fechada', () async {
      final container = ProviderContainer();
      final service = container.read(cacheServiceProvider);
      expect(service, isA<CacheService>());
      await service.close();
      container.dispose();
    });

    test('cacheServiceProvider com override retorna instancia mockada', () {
      final container = ProviderContainer(
        overrides: [
          cacheServiceProvider.overrideWithValue(memoryCacheService),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(cacheServiceProvider);
      expect(service, equals(memoryCacheService));
    });

    test('syncServiceProvider real constrói SyncService, inicia monitoramento e chama dispose no encerramento', () async {
      final container = ProviderContainer(
        overrides: [
          cacheServiceProvider.overrideWithValue(memoryCacheService),
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );

      final service = container.read(syncServiceProvider);
      expect(service, isA<SyncService>());
      
      container.dispose();
    });

    test('syncServiceProvider com override de comportamento chama callbacks customizados', () {
      final mockSync = MockSyncService();
      when(() => mockSync.startMonitoring()).thenReturn(null);
      when(() => mockSync.dispose()).thenReturn(null);
      when(() => mockSync.statusStream).thenAnswer((_) => const Stream.empty());

      final container = ProviderContainer(
        overrides: [
          syncServiceProvider.overrideWith((ref) {
            mockSync.startMonitoring();
            ref.onDispose(() => mockSync.dispose());
            return mockSync;
          }),
        ],
      );

      final service = container.read(syncServiceProvider);
      expect(service, equals(mockSync));
      verify(() => mockSync.startMonitoring()).called(1);

      container.dispose();
      verify(() => mockSync.dispose()).called(1);
    });

    test('syncStatusProvider emite o status stream do SyncService', () async {
      final controller = StreamController<SyncStatus>();
      final mockSync = MockSyncService();
      when(() => mockSync.startMonitoring()).thenReturn(null);
      when(() => mockSync.dispose()).thenReturn(null);
      when(() => mockSync.statusStream).thenAnswer((_) => controller.stream);

      final container = ProviderContainer(
        overrides: [
          syncServiceProvider.overrideWithValue(mockSync),
        ],
      );
      addTearDown(() {
        controller.close();
        container.dispose();
      });

      final statuses = <AsyncValue<SyncStatus>>[];
      container.listen(syncStatusProvider, (prev, next) {
        statuses.add(next);
      }, fireImmediately: true);

      controller.add(SyncStatus.syncing);
      await Future.delayed(Duration.zero);
      controller.add(SyncStatus.idle);
      await Future.delayed(Duration.zero);

      expect(statuses.any((s) => s.value == SyncStatus.syncing), isTrue);
      expect(statuses.any((s) => s.value == SyncStatus.idle), isTrue);
    });

    test('pendingSyncCountProvider retorna a quantidade de itens na fila de sync sem timeout', () async {
      await memoryCacheService.enqueueSync(
        operacao: 'insert',
        tabela: 'frequencias',
        payload: '{}',
      );
      await memoryCacheService.enqueueSync(
        operacao: 'update',
        tabela: 'atividades',
        payload: '{}',
      );

      final container = ProviderContainer(
        overrides: [
          cacheServiceProvider.overrideWithValue(memoryCacheService),
          syncStatusProvider.overrideWith((ref) => Stream.value(SyncStatus.idle)),
        ],
      );
      addTearDown(container.dispose);

      container.read(syncStatusProvider);
      await Future.delayed(const Duration(milliseconds: 10));

      final count = await container.read(pendingSyncCountProvider.future);
      expect(count, 2);
    });
  });
}
