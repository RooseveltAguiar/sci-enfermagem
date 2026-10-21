import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/atividades_provider.dart';
import '../../widgets/confirmation_bottom_sheet.dart';

class RegistrarAtividadeScreen extends ConsumerStatefulWidget {
  const RegistrarAtividadeScreen({super.key});

  @override
  ConsumerState<RegistrarAtividadeScreen> createState() => _RegistrarAtividadeScreenState();
}

class _RegistrarAtividadeScreenState extends ConsumerState<RegistrarAtividadeScreen> {
  final List<String> _selecionadasIds = [];
  bool _outraSelecionada = false;
  final _outraDescricaoController = TextEditingController();

  void _tentarRegistrar() {
    if (_selecionadasIds.isEmpty && !_outraSelecionada) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione pelo menos uma atividade.')));
      return;
    }
    if (_outraSelecionada && _outraDescricaoController.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A descrição de "Outra" deve ter no mínimo 10 caracteres.')));
      return;
    }

    // Limite de atividades por alocação/dia
    if (_selecionadasIds.length + (_outraSelecionada ? 1 : 0) > 10) {
      _mostrarErroLimite();
      return;
    }

    ConfirmationBottomSheet.show(
      context,
      title: 'Confirmar Registro',
      message: 'Você selecionou ${_selecionadasIds.length + (_outraSelecionada ? 1 : 0)} atividade(s). Deseja registrar?',
      confirmText: 'Registrar',
      onConfirm: () async {
        try {
          await ref.read(atividadesAlunoProvider.notifier).registrarAtividades(
            selecionadasIds: _selecionadasIds,
            outraDescricao: _outraSelecionada ? _outraDescricaoController.text : null,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Atividades registradas com sucesso!')));
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              try {
                if (context.canPop()) context.pop();
              } catch (_) {}
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao registrar atividades: $e'), backgroundColor: Colors.red),
            );
          }
        }
      },
    );
  }

  void _mostrarErroLimite() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning, color: Colors.orange), SizedBox(width: 8), Text('Limite Atingido')]),
        content: const Text('Você já atingiu o limite de 10 atividades registradas para esta alocação hoje.\n\nPor favor, valide se os registros estão corretos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendi'))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final padraoAsync = ref.watch(atividadesPadraoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Atividade')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Selecione as atividades realizadas:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            padraoAsync.when(
              data: (lista) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...lista.map((item) {
                    final selected = _selecionadasIds.contains(item.id);
                    return FilterChip(
                      label: Text(item.nome),
                      selected: selected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selecionadasIds.add(item.id);
                          } else {
                            _selecionadasIds.remove(item.id);
                          }
                        });
                      },
                    );
                  }),
                  FilterChip(
                    label: const Text('Outra (Descrever)'),
                    selected: _outraSelecionada,
                    selectedColor: Colors.teal.shade200,
                    onSelected: (val) {
                      setState(() {
                        _outraSelecionada = val;
                        if (!val) {
                          _outraDescricaoController.clear();
                        }
                      });
                    },
                  )
                ],
              ),
              loading: () => const CircularProgressIndicator(semanticsLabel: 'Carregando...'),
              error: (err, stack) => Text('Erro: $err'),
            ),

            if (_outraSelecionada) ...[
              const SizedBox(height: 24),
              TextField(
                controller: _outraDescricaoController,
                maxLength: 250,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Descrição da Atividade (mín. 10 caracteres)',
                  border: OutlineInputBorder(),
                ),
              )
            ],

            const SizedBox(height: 48),
            FilledButton(
              onPressed: _tentarRegistrar,
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: const Text('REGISTRAR ATIVIDADES'),
            )
          ],
        ),
      ),
    );
  }
}
