import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/legislacao_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/legislacao_provider.dart';
import 'legislacao_detalhe_screen.dart';
import 'legislacao_form_screen.dart';

class LegislacaoListaScreen extends ConsumerWidget {
  const LegislacaoListaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(legislacoesProvider);
    final perfil = ref.watch(
      userProfileProvider.select((asyncState) => asyncState.value ?? ''),
    );
    final podeEditar = perfil == 'professor' || perfil == 'coordenacao';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Legislação e Normas'),
      ),
      floatingActionButton: podeEditar
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LegislacaoFormScreen(),
                  ),
                );
                ref.read(legislacoesProvider.notifier).carregarLegislacoes();
              },
              icon: const Icon(Icons.add),
              label: const Text('Nova Legislação'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref
              .read(legislacoesProvider.notifier)
              .carregarLegislacoes();
        },
        child: estado.when(
          loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
          error: (erro, st) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text('Erro ao carregar legislação: $erro'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref
                      .read(legislacoesProvider.notifier)
                      .carregarLegislacoes(),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
          data: (lista) {
            if (lista.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.gavel_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Nenhum documento legislativo cadastrado.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: lista.length,
              itemBuilder: (context, index) {
                final doc = lista[index];
                return _LegislacaoCard(
                  doc: doc,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LegislacaoDetalheScreen(doc: doc),
                      ),
                    );
                    ref.read(legislacoesProvider.notifier).carregarLegislacoes();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _LegislacaoCard extends StatelessWidget {
  final LegislacaoModel doc;
  final VoidCallback onTap;

  const _LegislacaoCard({
    required this.doc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vigente = doc.isVigente;

    String vigenciaTexto = 'Sem data definida';
    if (doc.vigenciaInicio != null || doc.vigenciaFim != null) {
      final inicio = doc.vigenciaInicio != null
          ? DateFormat('dd/MM/yyyy').format(doc.vigenciaInicio!)
          : '...';
      final fim = doc.vigenciaFim != null
          ? DateFormat('dd/MM/yyyy').format(doc.vigenciaFim!)
          : 'Indefinido';
      vigenciaTexto = '$inicio a $fim';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      doc.tipo,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      vigente ? 'Vigente' : 'Encerrada',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: vigente
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: vigente ? Colors.green[800] : Colors.orange[800],
                      fontWeight: FontWeight.bold,
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                doc.titulo,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Vigência: $vigenciaTexto',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
