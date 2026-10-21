import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/legislacao_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/legislacao_provider.dart';
import 'legislacao_file_helper.dart';
import 'legislacao_form_screen.dart';

class LegislacaoDetalheScreen extends ConsumerStatefulWidget {
  final LegislacaoModel doc;

  const LegislacaoDetalheScreen({
    super.key,
    required this.doc,
  });

  @override
  ConsumerState<LegislacaoDetalheScreen> createState() =>
      _LegislacaoDetalheScreenState();
}

class _LegislacaoDetalheScreenState
    extends ConsumerState<LegislacaoDetalheScreen> {
  bool _baixando = false;

  Future<void> _abrirDocumento() async {
    setState(() => _baixando = true);
    try {
      await LegislacaoFileHelper.abrirOuBaixarDocumento(context, widget.doc);
    } finally {
      if (mounted) setState(() => _baixando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
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

            // ==========================================
            // CARD DE ANEXO (SE HOUVER ARQUIVO)
            // ==========================================
            if (doc.temAnexo) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: doc.isPdf
                      ? Colors.red.shade50.withValues(alpha: 0.5)
                      : Colors.blue.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: doc.isPdf
                        ? Colors.red.shade200
                        : Colors.blue.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: doc.isPdf
                                ? Colors.red.shade100
                                : Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            doc.isPdf
                                ? Icons.picture_as_pdf
                                : Icons.description,
                            color: doc.isPdf
                                ? Colors.red.shade700
                                : Colors.blue.shade700,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc.arquivoNome ?? 'Documento em Anexo',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${LegislacaoFileHelper.formatarTamanho(doc.arquivoTamanho)} • ${doc.isPdf ? "Arquivo PDF" : "Arquivo Word"}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: doc.isPdf
                              ? Colors.red.shade700
                              : Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _baixando ? null : _abrirDocumento,
                        icon: _baixando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_rounded),
                        label: Text(
                          _baixando
                              ? 'Abrindo documento...'
                              : 'Baixar / Visualizar Documento',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (doc.conteudo.isNotEmpty) ...[
              const Divider(height: 32),
              SelectableText(
                doc.conteudo,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
