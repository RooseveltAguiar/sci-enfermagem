import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/frequencia_provider.dart';
import '../widgets/status_chip.dart';
// Note: as rotas (go_router) serao usadas pelo app. Por enquanto, usamos push simples ou placeholders para navegacao.
import 'frequencia_detail_screen.dart'; 

class SupervisorHomeScreen extends ConsumerWidget {
  const SupervisorHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frequenciasAsync = ref.watch(pendentesValidacaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Validação de Ponto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(pendentesValidacaoProvider.notifier).loadPendentesValidacao();
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
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('Tudo certo! Nenhuma validação pendente.', 
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
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    frequencia.alunoNome ?? 'Aluno Desconhecido',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text('Data: ${frequencia.dataRegistro}'),
                      if (frequencia.mockLocationDetectado || !frequencia.gpsDisponivel)
                        const Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Text(
                            '⚠️ Atenção: GPS suspeito ou indisponível',
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  trailing: const StatusChip(status: FrequenciaStatus.pendenteValidacao),
                  onTap: () {
                    // Navigate to FrequenciaDetailScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FrequenciaDetailScreen(frequencia: frequencia),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Erro ao carregar validações: $err'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Acao rapida: talvez ir para o perfil, ou iniciar validacao em lote
        },
        icon: const Icon(Icons.playlist_add_check),
        label: const Text('Validar Tudo'),
      ),
    );
  }
}
