import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/frequencia_provider.dart';
import '../../widgets/status_chip.dart';

class FrequenciaHistoricoScreen extends ConsumerWidget {
  const FrequenciaHistoricoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historicoAsync = ref.watch(historicoAlunoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Frequência'),
      ),
      body: historicoAsync.when(
        data: (frequencias) {
          if (frequencias.isEmpty) {
            return const Center(child: Text('Nenhum registro encontrado.'));
          }

          return ListView.builder(
            itemCount: frequencias.length,
            itemBuilder: (context, index) {
              final freq = frequencias[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('${freq.campoNome ?? 'Campo'}'),
                  subtitle: Text('${freq.dataRegistro} • ${freq.turnoDescricao ?? ''}'),
                  trailing: StatusChip(status: FrequenciaStatus.pendenteValidacao), // Placeholder de status
                  onTap: () {
                    context.push('/frequencia/${freq.id}/auditoria');
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
    );
  }
}
