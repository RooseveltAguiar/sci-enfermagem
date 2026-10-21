import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/campos_provider.dart';

class CamposEstagioScreen extends ConsumerWidget {
  const CamposEstagioScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camposAsync = ref.watch(camposProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Campos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(camposProvider.notifier).loadCampos();
            },
          ),
        ],
      ),
      body: camposAsync.when(
        data: (campos) {
          if (campos.isEmpty) {
            return const Center(child: Text('Nenhum campo de estágio cadastrado.'));
          }
          return ListView.builder(
            itemCount: campos.length,
            padding: const EdgeInsets.only(bottom: 80),
            itemBuilder: (context, index) {
              final campo = campos[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: campo.ativo ? Colors.teal.shade100 : Colors.grey.shade300,
                    child: Icon(Icons.business, color: campo.ativo ? Colors.teal : Colors.grey),
                  ),
                  title: Text(campo.nome),
                  subtitle: Text(campo.endereco),
                  trailing: Chip(
                    label: Text(campo.ativo ? 'Ativo' : 'Inativo'),
                    backgroundColor: campo.ativo ? Colors.green.shade50 : Colors.grey.shade200,
                  ),
                  onTap: () {
                    context.push('/coordenacao/campos/${campo.id}/editar');
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/coordenacao/campos/novo');
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo Campo'),
      ),
    );
  }
}
