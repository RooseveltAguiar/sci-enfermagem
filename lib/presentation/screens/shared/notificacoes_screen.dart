import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/notificacoes_provider.dart';

class NotificacoesScreen extends ConsumerWidget {
  const NotificacoesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificacoesAsync = ref.watch(notificacoesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          IconButton(
            tooltip: 'Marcar todas como lidas',
            icon: const Icon(Icons.done_all),
            onPressed: () {
              ref.read(notificacoesProvider.notifier).marcarTodasComoLidas();
            },
          ),
        ],
      ),
      body: notificacoesAsync.when(
        data: (notifs) {
          if (notifs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Nenhuma notificação.'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.read(notificacoesProvider.notifier).loadNotificacoes(),
            child: ListView.builder(
              itemCount: notifs.length,
              itemBuilder: (context, index) {
                final n = notifs[index];
                
                IconData icon;
                Color color;
                if (n.tipo == 'sucesso') {
                  icon = Icons.check_circle;
                  color = Colors.green;
                } else if (n.tipo == 'alerta') {
                  icon = Icons.warning;
                  color = Colors.orange;
                } else if (n.tipo == 'erro') {
                  icon = Icons.error;
                  color = Colors.red;
                } else {
                  icon = Icons.info;
                  color = Colors.blue;
                }

                return Card(
                  color: n.lida ? Colors.white : Colors.blue.shade50,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Icon(icon, color: color),
                    title: Text(n.mensagem, style: TextStyle(fontWeight: n.lida ? FontWeight.normal : FontWeight.bold)),
                    subtitle: Text(n.dataCriacao),
                    onTap: () {
                      if (!n.lida) {
                        ref.read(notificacoesProvider.notifier).marcarComoLida(n.id);
                      }
                      if (n.frequenciaId != null) {
                        // Navega pra auditoria ou detalhe dependendo do perfil
                        context.push('/frequencia/${n.frequenciaId}/auditoria');
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
    );
  }
}
