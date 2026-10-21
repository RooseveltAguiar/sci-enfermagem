import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Mock list
final gerenciamentoAtividadesProvider = StateProvider<List<Map<String, dynamic>>>((ref) {
  return [
    {'id': '1', 'nome': 'Aferição de pressão arterial', 'ativo': true},
    {'id': '2', 'nome': 'Verificação de sinais vitais', 'ativo': true},
    {'id': '3', 'nome': 'Procedimento obsoleto', 'ativo': false},
  ];
});

class AtividadesPadraoScreen extends ConsumerWidget {
  const AtividadesPadraoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(gerenciamentoAtividadesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Atividades Padrão')),
      body: ListView.builder(
        itemCount: lista.length,
        itemBuilder: (context, index) {
          final item = lista[index];
          return Dismissible(
            key: Key(item['id']),
            background: Container(
              color: item['ativo'] ? Colors.red : Colors.green,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: Icon(item['ativo'] ? Icons.visibility_off : Icons.visibility, color: Colors.white),
            ),
            direction: DismissDirection.endToStart,
            confirmDismiss: (dir) async {
              // Simulando soft delete (toggle ativo)
              final acao = item['ativo'] ? 'desativar' : 'ativar';
              return await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Confirmar'),
                  content: Text('Deseja $acao a atividade "${item['nome']}"?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    FilledButton(
                      onPressed: () {
                        // Modifica o state (simulação DB)
                        final novaLista = [...lista];
                        novaLista[index]['ativo'] = !item['ativo'];
                        ref.read(gerenciamentoAtividadesProvider.notifier).state = novaLista;
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Confirmar'),
                    ),
                  ],
                )
              );
            },
            child: ListTile(
              title: Text(item['nome'], style: TextStyle(decoration: item['ativo'] ? null : TextDecoration.lineThrough)),
              trailing: item['ativo'] ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.cancel, color: Colors.grey),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirCriacao(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nova Atividade Padrão'),
      ),
    );
  }

  void _abrirCriacao(BuildContext context, WidgetRef ref) {
    final nomeController = TextEditingController();
    final descController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Nova Atividade', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(labelText: 'Nome da Atividade', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Descrição Padrão', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (nomeController.text.isNotEmpty) {
                  final lista = ref.read(gerenciamentoAtividadesProvider);
                  ref.read(gerenciamentoAtividadesProvider.notifier).state = [
                    ...lista,
                    {'id': DateTime.now().toString(), 'nome': nomeController.text, 'ativo': true}
                  ];
                  Navigator.pop(ctx);
                }
              },
              child: const Text('SALVAR'),
            )
          ],
        ),
      ),
    );
  }
}
