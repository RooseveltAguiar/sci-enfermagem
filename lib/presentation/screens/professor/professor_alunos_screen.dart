import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Para navegar para historico:
import 'package:go_router/go_router.dart';

// Simulação de provedor para os alunos do professor (isso viria de uma view do banco)
final alunosProfessorProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  // Simulando retorno do banco:
  await Future.delayed(const Duration(seconds: 1));
  return [
    {'id': '1', 'nome': 'Ana Silva', 'percentual': 85.0},
    {'id': '2', 'nome': 'Carlos Souza', 'percentual': 70.0},
    {'id': '3', 'nome': 'Beatriz Lima', 'percentual': 92.0},
  ];
});

class ProfessorAlunosScreen extends ConsumerWidget {
  const ProfessorAlunosScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alunosAsync = ref.watch(alunosProfessorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Alunos'),
      ),
      body: alunosAsync.when(
        data: (alunos) {
          if (alunos.isEmpty) {
            return const Center(child: Text('Você não possui alunos sob sua supervisão.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(alunosProfessorProvider.future),
            child: ListView.builder(
              itemCount: alunos.length,
              itemBuilder: (context, index) {
                final aluno = alunos[index];
                final percentual = aluno['percentual'] as double;
                final emRisco = percentual < 75.0;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: emRisco ? Colors.red.shade100 : Colors.teal.shade100,
                      child: Text(aluno['nome'].substring(0, 1), 
                        style: TextStyle(color: emRisco ? Colors.red.shade900 : Colors.teal.shade900)),
                    ),
                    title: Text(aluno['nome']),
                    subtitle: Text('Frequência: ${percentual.toStringAsFixed(1)}%'),
                    trailing: emRisco 
                        ? Chip(
                            label: const Text('Abaixo 75%'),
                            backgroundColor: Colors.red.shade100,
                            labelStyle: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () {
                      // O professor pode ver o histórico do aluno (uma tela similar à do próprio aluno)
                      // context.push('/professor/home/historico/${aluno['id']}');
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
