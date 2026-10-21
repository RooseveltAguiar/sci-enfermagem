import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/legislacao_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/legislacao_provider.dart';
import 'legislacao_form_screen.dart';

class LegislacaoDetalheScreen extends ConsumerWidget {
  final LegislacaoModel doc;

  const LegislacaoDetalheScreen({
    super.key,
    required this.doc,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(
      userProfileProvider.select((asyncState) => asyncState.value ?? ''),
    );
    final podeEditar = perfil == 'professor' || perfil == 'coordenacao';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(doc.tipo),
        actions: podeEditar
            ? [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Editar',
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LegislacaoFormScreen(doc: doc),
                      ),
                    );
                    ref.read(legislacoesProvider.notifier).carregarLegislacoes();
                  },
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                ),
                Text(
                  'Vigência: $vigenciaTexto',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              doc.titulo,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 32),
            SelectableText(
              doc.conteudo,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
