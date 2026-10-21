import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/models/termo_model.dart';
import '../../../providers/termos_provider.dart';

class TermosListaScreen extends ConsumerWidget {
  const TermosListaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(termosListaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Termos Institucionais'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/coordenacao/termos/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Nova Versão'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(termosListaProvider.notifier).carregarTermos();
        },
        child: estado.when(
          loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
          error: (erro, st) => Center(
            child: Text('Erro ao carregar termos: $erro'),
          ),
          data: (lista) {
            final temAtivo = lista.any((t) => t.ativo);

            return ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (!temAtivo)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.amber),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Nenhum termo ativo. Alunos sem termo para aceitar.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (lista.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text(
                        'Nenhuma versão de termos cadastrada.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ...lista.map((termo) => _TermoCard(termo: termo)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TermoCard extends StatelessWidget {
  final TermoModel termo;

  const _TermoCard({required this.termo});

  @override
  Widget build(BuildContext context) {
    final vigencia = termo.vigenciaInicio != null
        ? DateFormat('dd/MM/yyyy').format(termo.vigenciaInicio!)
        : 'Indefinida';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Versão ${termo.versao}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Chip(
              label: Text(
                termo.ativo ? 'Ativo' : 'Inativo',
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: termo.ativo
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: termo.ativo ? Colors.green[800] : Colors.grey[800],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(termo.titulo),
            const SizedBox(height: 4),
            Text(
              'Vigência a partir de: $vigencia',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        onTap: () =>
            context.push('/coordenacao/termos/${termo.id}/editar', extra: termo),
      ),
    );
  }
}
