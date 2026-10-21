import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cache_service.dart';

enum SyncStatus { idle, syncing, error }

class SyncService {
  final CacheService _cacheService;
  final SupabaseClient _supabase;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  late final StreamController<SyncStatus> _statusController = StreamController<SyncStatus>.broadcast(
    onListen: () {
      _statusController.add(_currentStatus);
    },
  );

  SyncStatus _currentStatus = SyncStatus.idle;
  SyncStatus get currentStatus => _currentStatus;
  Stream<SyncStatus> get statusStream => _statusController.stream;

  Function(String message)? onSyncNotification;

  SyncService(this._cacheService, [SupabaseClient? supabase])
      : _supabase = supabase ?? Supabase.instance.client;

  void startMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected) {
        processQueue();
      }
    });
  }

  void stopMonitoring() {
    _connectivitySubscription?.cancel();
  }

  Future<bool> checkOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  Future<void> processQueue() async {
    if (_currentStatus == SyncStatus.syncing) return;
    final isConnected = await checkOnline();
    if (!isConnected) return;

    final pending = await _cacheService.getPendingSyncEntries();
    if (pending.isEmpty) {
      _updateStatus(SyncStatus.idle);
      return;
    }

    _updateStatus(SyncStatus.syncing);
    int sucesso = 0;
    int falhas = 0;

    for (final entry in pending) {
      try {
        final payloadMap = jsonDecode(entry.payload) as Map<String, dynamic>;
        if (entry.operacao == 'insert') {
          await _supabase.from(entry.tabela).insert(payloadMap);
        } else if (entry.operacao == 'update') {
          final id = payloadMap['id'];
          if (id != null) {
            final mapCopy = Map<String, dynamic>.from(payloadMap)..remove('id');
            await _supabase.from(entry.tabela).update(mapCopy).eq('id', id);
          } else {
            throw Exception('Sincronização de update sem id não é permitida: ${entry.tabela}');
          }
        }
        await _cacheService.removeSyncEntry(entry.id);
        sucesso++;
      } catch (e) {
        falhas++;
        final erroMsg = e.toString().replaceAll('Exception: ', '');
        await _cacheService.incrementRetry(entry.id, erroMsg);
      }
    }

    if (falhas > 0) {
      _updateStatus(SyncStatus.error);
    } else {
      _updateStatus(SyncStatus.idle);
    }

    if (sucesso > 0 && onSyncNotification != null) {
      onSyncNotification!('$sucesso registro(s) sincronizado(s) com sucesso');
    }
  }

  void _updateStatus(SyncStatus newStatus) {
    _currentStatus = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  void dispose() {
    stopMonitoring();
    _statusController.close();
  }
}
