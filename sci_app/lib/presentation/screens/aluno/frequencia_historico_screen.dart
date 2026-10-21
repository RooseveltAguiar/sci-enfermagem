import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/frequencia_provider.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/sync_status_icon.dart';

class FrequenciaHistoricoScreen extends ConsumerWidget {
  const FrequenciaHistoricoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historicoAsync = ref.watch(historicoAlunoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Frequência'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Exportar Relatórios',
            onPressed: () => context.push('/exportacao'),
          ),
        ],
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
                  title: Text(freq.campoNome ?? 'Campo'),
                  subtitle: Text('${freq.dataRegistro} • ${freq.turnoDescricao ?? ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SyncStatusIcon(registroId: freq.id),
                      const SizedBox(width: 8),
                      StatusChip(status: _parseStatus(freq.status)),
                    ],
                  ),
                  onTap: () {
                    context.push('/frequencia/${freq.id}/auditoria');
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
    );
  }

  FrequenciaStatus _parseStatus(String? status) {
    switch (status) {
      case 'validado':
        return FrequenciaStatus.validado;
      case 'rejeitado':
        return FrequenciaStatus.rejeitado;
      case 'ausente':
        return FrequenciaStatus.ausente;
      case 'abonado_pend_ratificacao':
        return FrequenciaStatus.abonadoPendRatificacao;
      case 'ratificado':
        return FrequenciaStatus.ratificado;
      case 'pendente_validacao':
      default:
        return FrequenciaStatus.pendenteValidacao;
    }
  }
}
