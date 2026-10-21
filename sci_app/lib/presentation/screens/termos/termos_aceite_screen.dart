import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/termos_provider.dart';

class TermosAceiteScreen extends ConsumerStatefulWidget {
  const TermosAceiteScreen({super.key});

  @override
  ConsumerState<TermosAceiteScreen> createState() => _TermosAceiteScreenState();
}

class _TermosAceiteScreenState extends ConsumerState<TermosAceiteScreen> {
  bool _aceito = false;
  bool _salvando = false;

  Future<void> _confirmarAceite(String versao) async {
    setState(() => _salvando = true);
    try {
      await ref.read(termosListaProvider.notifier).aceitarTermo(versao);
      if (mounted) {
        try {
          context.go('/aluno/home');
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aceitar termos: $e')),
        );
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final termoAsync = ref.watch(termoAtivoProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Termos Institucionais'),
        ),
        body: termoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
          error: (erro, st) => Center(
            child: Text('Erro ao carregar termos: $erro'),
          ),
          data: (termo) {
            if (termo == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('Nenhum termo ativo no momento.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        try {
                          context.go('/aluno/home');
                        } catch (_) {}
                      },
                      child: const Text('Continuar'),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Termos de Uso do Internato — Versão ${termo.versao}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          termo.titulo,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Divider(height: 32),
                        Text(
                          termo.conteudo,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          value: _aceito,
                          onChanged: (val) => setState(() => _aceito = val ?? false),
                          title: const Text(
                            'Li e concordo com os termos acima',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_aceito && !_salvando)
                              ? () => _confirmarAceite(termo.versao)
                              : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _salvando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, semanticsLabel: 'Carregando...'))
                              : const Text('Aceitar e continuar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
