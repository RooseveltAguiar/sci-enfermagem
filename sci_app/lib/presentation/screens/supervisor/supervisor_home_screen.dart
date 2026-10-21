import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/frequencia_provider.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/logout_button.dart';

class SupervisorHomeScreen extends ConsumerWidget {
  const SupervisorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendentesAsync = ref.watch(pendentesValidacaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Validação de Ponto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar pontos pendentes',
            onPressed: () {
              ref.read(pendentesValidacaoProvider.notifier).loadPendentesValidacao();
            },
          ),
          const LogoutButton(),
        ],
      ),
      body: pendentesAsync.when(
        data: (frequencias) {
          if (frequencias.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('Tudo certo! Nenhuma validação pendente.', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          // Para a home, mostramos os primeiros ou a lista com banner
          return ListView.builder(
            itemCount: frequencias.length,
            padding: const EdgeInsets.only(bottom: 80),
            itemBuilder: (context, index) {
              final freq = frequencias[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: InkWell(
                  onTap: () {
                    context.push('/supervisor/home/validar/${freq.id}');
                  },
                  child: Column(
                    children: [
                      if (!freq.gpsDisponivel || freq.mockLocationDetectado)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade200,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: const Text(
                            '⚠️ Confirmação presencial necessária',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ListTile(
                        title: Text(freq.alunoNome ?? 'Aluno'),
                        subtitle: Text('${freq.dataRegistro} • ${freq.turnoDescricao ?? 'Turno'}'),
                        trailing: StatusChip(status: FrequenciaStatus.pendenteValidacao),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/supervisor/home/validar');
        },
        icon: const Icon(Icons.playlist_add_check),
        label: const Text('Ver todos os pendentes'),
      ),
    );
  }
}
