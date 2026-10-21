import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cache_service.dart';
import '../services/sync_service.dart';
import 'auth_provider.dart';

final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final cacheService = ref.watch(cacheServiceProvider);
  final supabase = ref.watch(supabaseClientProvider);
  final syncService = SyncService(cacheService, supabase);
  syncService.startMonitoring();
  ref.onDispose(() {
    syncService.dispose();
  });
  return syncService;
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final service = ref.watch(syncServiceProvider);
  return service.statusStream;
});

final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  ref.watch(syncStatusProvider);
  final cacheService = ref.read(cacheServiceProvider);
  final entries = await cacheService.getPendingSyncEntries();
  return entries.length;
});
