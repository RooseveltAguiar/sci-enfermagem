import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/confirmation_bottom_sheet.dart';

final limiarConfigProvider = StateProvider<double>((ref) => 75.0);

class ConfiguracoesScreen extends ConsumerWidget {
  const ConfiguracoesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limiar = ref.watch(limiarConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações do Sistema')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Limiar de Risco de Frequência', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Define a porcentagem mínima de presença para que o aluno não entre na faixa de risco (alerta vermelho).'),
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Valor Atual:'),
                        Text('${limiar.toInt()}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
                      ],
                    ),
                    
                    Slider(
                      value: limiar,
                      min: 50,
                      max: 100,
                      divisions: 10,
                      label: '${limiar.toInt()}%',
                      onChanged: (val) => ref.read(limiarConfigProvider.notifier).state = val,
                    ),
                    
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () {
                        ConfirmationBottomSheet.show(
                          context,
                          title: 'Alterar Limiar?',
                          message: 'Esta alteração afeta o cálculo de risco de todos os alunos imediatamente. Deseja confirmar?',
                          confirmText: 'Salvar Configuração',
                          onConfirm: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Limiar atualizado com sucesso!')));
                          },
                        );
                      },
                      child: const Text('SALVAR'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            // Placeholder para futuras configurações (Sprint 5)
            const Opacity(
              opacity: 0.5,
              child: Card(
                child: ListTile(
                  leading: Icon(Icons.settings_applications),
                  title: Text('Integração Acadêmica (Em breve)'),
                  subtitle: Text('Configurações do módulo de integração com o sistema acadêmico.'),
                  trailing: Icon(Icons.lock),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
