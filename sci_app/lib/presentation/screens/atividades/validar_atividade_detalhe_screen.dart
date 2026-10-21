import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/confirmation_bottom_sheet.dart';

// Mock das atividades pendentes de um aluno
final atividadesParaValidarProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return [
    {'id': '1', 'nome': 'Aferição de pressão arterial', 'status': 'pendente_validacao'},
    {'id': '2', 'nome': 'Coleta de sangue venoso', 'status': 'pendente_validacao', 'outra_descricao': 'Paciente na UTI leito 4'},
  ];
});

class ValidarAtividadeDetalheScreen extends ConsumerWidget {
  final String alunoId;

  const ValidarAtividadeDetalheScreen({super.key, required this.alunoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atividadesAsync = ref.watch(atividadesParaValidarProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Validar Atividades')),
      body: atividadesAsync.when(
        data: (atividades) {
          if (atividades.isEmpty) return const Center(child: Text('Nenhuma atividade pendente.'));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: const Text('Aluno: João Silva'),
                  subtitle: Text('Data: ${DateTime.now().toString().split(' ')[0]}'),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Atividades Relatadas:', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: atividades.length,
                  itemBuilder: (context, index) {
                    final a = atividades[index];
                    return ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(htmlEscape.convert(a['nome'].toString())),
                      subtitle: a['outra_descricao'] != null ? Text(htmlEscape.convert(a['outra_descricao'].toString())) : null,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16)),
                        icon: const Icon(Icons.done_all),
                        label: const Text('VALIDAR TODAS'),
                        onPressed: () {
                          ConfirmationBottomSheet.show(
                            context,
                            title: 'Validar Atividades',
                            message: 'Confirma a validação de todas as ${atividades.length} atividades?',
                            confirmText: 'Validar',
                            onConfirm: () {
                              Navigator.pop(context); // close modal
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Atividades validadas!')));
                              context.pop(); // go back
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)),
                        icon: const Icon(Icons.close),
                        label: const Text('REJEITAR...'),
                        onPressed: () => _abrirRejeitarDialog(context),
                      ),
                    ),
                  ],
                ),
              )
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
    );
  }

  void _abrirRejeitarDialog(BuildContext context) {
    final controller = TextEditingController();
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
            const Text('Rejeitar Atividades', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 16),
            const Text('Descreva o motivo da rejeição (mínimo de 20 caracteres):'),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                if (controller.text.trim().length >= 20) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Atividades rejeitadas.')));
                  context.pop();
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Justificativa muito curta.')));
                }
              },
              child: const Text('CONFIRMAR REJEIÇÃO'),
            )
          ],
        ),
      ),
    );
  }
}
