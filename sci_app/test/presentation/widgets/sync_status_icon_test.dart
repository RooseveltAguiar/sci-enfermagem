import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sci_app/presentation/widgets/sync_status_icon.dart';
import 'package:sci_app/providers/sync_provider.dart';
import 'package:sci_app/services/cache_service.dart';
import 'package:sci_app/services/sync_service.dart';

class MockSyncService extends Mock implements SyncService {}

void main() {
  late CacheService memoryCacheService;
  late MockSyncService mockSyncService;

  setUp(() {
    memoryCacheService = CacheService(NativeDatabase.memory());
    mockSyncService = MockSyncService();
    when(() => mockSyncService.processQueue()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await memoryCacheService.close();
  });

  testWidgets('exibe ícone verde de sincronizado quando não há entrada na fila (entry = null)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncEntryByRegistroProvider('reg-1').overrideWith((ref) => null),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SyncStatusIcon(registroId: 'reg-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_done), findsOneWidget);
  });

  testWidgets('exibe ícone laranja de pendente quando tentativas < 3', (tester) async {
    final entry = SyncQueueEntry(
      id: 1,
      operacao: 'insert',
      tabela: 'frequencias',
      payload: '{}',
      criadoEm: DateTime.now().millisecondsSinceEpoch,
      tentativas: 1,
      erroUltimo: null,
      registroId: 'reg-2',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncEntryByRegistroProvider('reg-2').overrideWith((ref) => entry),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SyncStatusIcon(registroId: 'reg-2'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
  });

  testWidgets('exibe ícone vermelho de erro quando tentativas >= 3 e abre modal ao tocar com retry manual', (tester) async {
    final entry = SyncQueueEntry(
      id: 10,
      operacao: 'insert',
      tabela: 'atividades',
      payload: '{}',
      criadoEm: DateTime.now().millisecondsSinceEpoch,
      tentativas: 3,
      erroUltimo: 'Timeout na rede',
      registroId: 'reg-3',
    );

    await memoryCacheService.enqueueSync(
      operacao: 'insert',
      tabela: 'atividades',
      payload: '{}',
      registroId: 'reg-3',
    );
    // força tentativas a 3 no DB
    await memoryCacheService.incrementRetry(1, 'Timeout na rede');
    await memoryCacheService.incrementRetry(1, 'Timeout na rede');
    await memoryCacheService.incrementRetry(1, 'Timeout na rede');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cacheServiceProvider.overrideWithValue(memoryCacheService),
          syncServiceProvider.overrideWithValue(mockSyncService),
          syncEntryByRegistroProvider('reg-3').overrideWith((ref) => entry),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SyncStatusIcon(registroId: 'reg-3'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off), findsOneWidget);

    // Toca no ícone para abrir modal
    await tester.tap(find.byIcon(Icons.cloud_off));
    await tester.pumpAndSettle();

    expect(find.text('Falha na Sincronização'), findsOneWidget);
    expect(find.text('Operação: insert em atividades'), findsOneWidget);
    expect(find.text('Motivo: Timeout na rede'), findsOneWidget);

    // Toca no botão de tentar novamente
    expect(find.text('Tentar Sincronizar Agora'), findsOneWidget);
    await tester.tap(find.text('Tentar Sincronizar Agora'));
    await tester.pumpAndSettle();

    verify(() => mockSyncService.processQueue()).called(1);
  });

  testWidgets('exibe CircularProgressIndicator durante loading e ícone cinza de erro durante erro no future provider', (tester) async {
    final completer = Completer<SyncQueueEntry?>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncEntryByRegistroProvider('reg-load').overrideWith((ref) => completer.future),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SyncStatusIcon(registroId: 'reg-load'),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.completeError(Exception('Erro no provider'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}
