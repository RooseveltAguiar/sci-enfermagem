import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/cache_service.dart';
import '../../providers/sync_provider.dart';

final syncEntryByRegistroProvider = FutureProvider.autoDispose.family<SyncQueueEntry?, String>((ref, registroId) async {
  ref.watch(syncStatusProvider);
  final cacheService = ref.read(cacheServiceProvider);
  return cacheService.getSyncEntryByRegistroId(registroId);
});

class SyncStatusIcon extends ConsumerWidget {
  final String registroId;

  const SyncStatusIcon({required this.registroId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(syncEntryByRegistroProvider(registroId));

    return entryAsync.when(
      data: (entry) {
        if (entry == null) {
          return const Icon(
            Icons.cloud_done,
            color: Colors.green,
            size: 18,
          );
        }

        if (entry.tentativas >= 3) {
          return GestureDetector(
            onTap: () => _mostrarDetalheErro(context, ref, entry),
            child: const Icon(
              Icons.cloud_off,
              color: Colors.red,
              size: 18,
            ),
          );
        }

        return const Padding(
          padding: EdgeInsets.all(4.0),
          child: Icon(Icons.cloud_upload, color: Colors.orange, size: 18),
        );
      },
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: 'Carregando...'),
      ),
      error: (_, _) => const Icon(Icons.error_outline, color: Colors.grey, size: 18),
    );
  }

  void _mostrarDetalheErro(BuildContext context, WidgetRef ref, SyncQueueEntry entry) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Falha na Sincronização',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Operação: ${entry.operacao} em ${entry.tabela}'),
              const SizedBox(height: 8),
              if (entry.erroUltimo != null)
                Text(
                  'Motivo: ${entry.erroUltimo}',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await ref.read(cacheServiceProvider).retrySyncEntryManual(entry.id);
                    ref.read(syncServiceProvider).processQueue();
                    ref.invalidate(syncEntryByRegistroProvider(registroId));
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar Sincronizar Agora'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
