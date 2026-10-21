import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/frequencia_provider.dart';
import '../../widgets/status_chip.dart';

class AlunoHomeScreen extends ConsumerWidget {
  const AlunoHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historicoAsync = ref.watch(historicoAlunoProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Frequência'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(historicoAlunoProvider.notifier).loadHistoricoAluno();
            },
          ),
        ],
      ),
      body: historicoAsync.when(
        data: (frequencias) {
          // Calcula percentual basico de exemplo a partir da lista
          // Na producao, deveria vir da view vw_percentual_frequencia real
          final totalAvaliadas = frequencias.where((f) => f.status == 'ratificado' || f.status == 'ausente' || f.status == 'validado').length;
          final presentes = frequencias.where((f) => f.status == 'ratificado' || f.status == 'validado').length;
          final percentual = totalAvaliadas == 0 ? 100.0 : (presentes / totalAvaliadas) * 100;
          final emRisco = percentual < 75.0;

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(historicoAlunoProvider.notifier).loadHistoricoAluno();
            },
            child: Column(
              children: [
                // Top Card - Percentual
                Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: emRisco ? Colors.red.shade50 : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: emRisco ? Colors.red : Colors.teal),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              value: percentual / 100,
                              color: emRisco ? Colors.red : Colors.teal,
                              backgroundColor: Colors.grey.shade300,
                              strokeWidth: 6,
                            ),
                          ),
                          Text('${percentual.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sua Frequência',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: emRisco ? Colors.red.shade900 : Colors.teal.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (emRisco)
                              Text('Atenção: Você está abaixo de 75%', style: TextStyle(color: Colors.red.shade700)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                
                // Lista de Registros
                Expanded(
                  child: frequencias.isEmpty 
                    ? const Center(child: Text('Nenhuma presença registrada ainda'))
                    : ListView.builder(
                        itemCount: frequencias.length,
                        itemBuilder: (context, index) {
                          final freq = frequencias[index];
                          // Em producao mapear strings com Enums para FrequenciaStatus
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.assignment)),
                            title: Text('${freq.campoNome ?? 'Campo'} - ${freq.turnoDescricao ?? 'Turno'}'),
                            subtitle: Text(freq.dataRegistro),
                            trailing: StatusChip(status: FrequenciaStatus.pendenteValidacao), // Mock
                            onTap: () {
                              context.push('/frequencia/${freq.id}/auditoria');
                            },
                          );
                        },
                      ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/aluno/home/registrar');
        },
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Registrar Presença'),
      ),
    );
  }
}
