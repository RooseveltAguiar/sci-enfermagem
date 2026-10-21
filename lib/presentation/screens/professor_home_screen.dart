import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/frequencia_provider.dart';
import '../widgets/status_chip.dart';
import '../widgets/confirmation_bottom_sheet.dart';

class ProfessorHomeScreen extends ConsumerWidget {
  const ProfessorHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frequenciasAsync = ref.watch(pendentesRatificacaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ratificação de Abonos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(pendentesRatificacaoProvider.notifier).loadPendentesRatificacao();
            },
          ),
        ],
      ),
      body: frequenciasAsync.when(
        data: (frequencias) {
          if (frequencias.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Nenhum abono pendente de ratificação.', 
                    style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: frequencias.length,
            padding: const EdgeInsets.all(8.0),
            itemBuilder: (context, index) {
              final frequencia = frequencias[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              frequencia.alunoNome ?? 'Aluno Desconhecido',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          const StatusChip(status: FrequenciaStatus.abonadoPendRatificacao),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Data da Falta: ${frequencia.dataRegistro}'),
                      const Divider(),
                      const Text(
                        'Ações:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              // Navegar para ver o PDF ou detalhes da justificativa (abono)
                            },
                            child: const Text('Ver Documento'),
                          ),
                          const Spacer(),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            onPressed: () => _showRecusarDialog(context, ref, frequencia.id),
                            child: const Text('Recusar'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: () {
                              ConfirmationBottomSheet.show(
                                context,
                                title: 'Ratificar Abono',
                                message: 'Deseja confirmar a ratificação deste abono? Isso reverterá a ausência em presença computada.',
                                confirmText: 'Ratificar',
                                onConfirm: () {
                                  ref.read(pendentesRatificacaoProvider.notifier).ratificarAbono(frequencia.id);
                                },
                              );
                            },
                            child: const Text('Ratificar'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Erro ao carregar abonos: $err'),
        ),
      ),
    );
  }

  void _showRecusarDialog(BuildContext context, WidgetRef ref, String frequenciaId) {
    final textController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Recusar Abono', 
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 16),
              const Text('Motivo da recusa (Mínimo de 20 caracteres):'),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Atestado ilegível ou inválido...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  if (textController.text.trim().length >= 20) {
                    Navigator.pop(ctx);
                    await ref.read(pendentesRatificacaoProvider.notifier).recusarAbono(frequenciaId, textController.text);
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('A justificativa deve ter no mínimo 20 caracteres.')),
                    );
                  }
                },
                child: const Text('Confirmar Recusa'),
              ),
            ],
          ),
        );
      },
    );
  }
}
