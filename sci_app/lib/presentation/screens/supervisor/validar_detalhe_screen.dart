import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/frequencia_provider.dart';
import '../../../providers/abono_provider.dart';
import '../../widgets/confirmation_bottom_sheet.dart';

class ValidarDetalheScreen extends ConsumerWidget {
  final String frequenciaId;

  const ValidarDetalheScreen({super.key, required this.frequenciaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Otimização Sprint 7: usando .select() para recarregar a tela apenas se o item específico mudar
    final freqPendente = ref.watch(
      pendentesValidacaoProvider.select((state) {
        final lista = state.value ?? [];
        for (final f in lista) {
          if (f.id == frequenciaId) return f;
        }
        return null;
      }),
    );

    final freqRatificacao = ref.watch(
      pendentesRatificacaoProvider.select((state) {
        final lista = state.value ?? [];
        for (final f in lista) {
          if (f.id == frequenciaId) return f;
        }
        return null;
      }),
    );

    final anexoAsync = ref.watch(anexoAbonoProvider(frequenciaId));

    final freq = freqPendente ?? freqRatificacao;
    final isRatificacao = freqPendente == null && freqRatificacao != null;

    if (freq == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalhe')),
        body: const Center(child: Text('Registro não encontrado.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Validar Presença')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card do aluno
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(freq.alunoNome?.substring(0,1) ?? 'A')),
                title: Text(freq.alunoNome ?? 'Aluno'),
                subtitle: Text('${freq.campoNome}\n${freq.turnoDescricao} • ${freq.dataRegistro}'),
                isThreeLine: true,
              ),
            ),
            const SizedBox(height: 16),
            
            // Card GPS
            if (freq.mockLocationDetectado)
               _buildGpsCard(Colors.red, Icons.warning, 'Localização possivelmente falsificada (Mock Location)')
            else if (!freq.gpsDisponivel)
               _buildGpsCard(Colors.orange, Icons.location_off, 'Presença não verificada por GPS. Confirme se o aluno estava presente fisicamente.')
            else
               _buildGpsCard(Colors.green, Icons.location_on, 'Distância do centro: ${freq.distanciaMetros?.toStringAsFixed(1) ?? '?'}m'),
               
            // Seção do Anexo de Abono (se existente via createSignedUrl)
            anexoAsync.when(
              data: (anexo) {
                if (anexo == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    const Text('Justificativa e Anexo do Abono', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Card(
                      color: Colors.blue.withValues(alpha: 0.05),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Justificativa:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                            const SizedBox(height: 4),
                            Text(anexo.justificativa),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Icon(
                                  anexo.mimeType.contains('pdf') ? Icons.picture_as_pdf : Icons.image,
                                  color: Colors.blue.shade700,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(anexo.nomeArquivo, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text('Documento privado (URL Assinada)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.blue.shade700),
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  label: const Text('Visualizar'),
                                  onPressed: () => _mostrarAnexoModal(context, anexo),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando anexo...'))),
              error: (err, _) => Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('Erro ao carregar anexo: $err', style: const TextStyle(color: Colors.red))),
            ),

            const SizedBox(height: 24),
            
            // Auditoria resumida (Poderia chamar o Provider para detalhes completos)
            const Text('Auditoria Resumida', style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Registro criado pelo dispositivo do aluno'),
              subtitle: Text(freq.dataRegistro), // Em prod usar timestamp_servidor
            ),
            const SizedBox(height: 48),
            
            // Acoes
            if (!isRatificacao) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.all(16)),
                icon: const Icon(Icons.check),
                label: const Text('VALIDAR'),
                onPressed: () => _confirmarValidacao(context, ref, freq),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.all(16)),
                icon: const Icon(Icons.close),
                label: const Text('REJEITAR'),
                onPressed: () => _showRejectBottomSheet(context, ref, freq),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildGpsCard(Color color, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _confirmarValidacao(BuildContext context, WidgetRef ref, Frequencia freq) {
    ConfirmationBottomSheet.show(
      context,
      title: 'Validar Presença',
      message: 'Confirma a presença física do aluno no campo de estágio?',
      confirmText: 'Validar',
      onConfirm: () async {
        try {
          await ref.read(pendentesValidacaoProvider.notifier).validarFrequencia(freq.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Presença validada com sucesso!')));
            context.pop();
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao validar: ${e.toString().replaceAll('Exception: ', '')}')));
          }
        }
      },
    );
  }

  void _showRejectBottomSheet(BuildContext context, WidgetRef ref, Frequencia freq) {
    final textController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Rejeitar Presença', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 16),
              const Text('Descreva o motivo (mín. 20 caracteres):'),
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  if (textController.text.length >= 20) {
                    Navigator.pop(ctx);
                    try {
                      await ref.read(pendentesValidacaoProvider.notifier).rejeitarFrequencia(freq.id, textController.text);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro rejeitado.')));
                        context.pop(); // Volta pra lista
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao rejeitar: ${e.toString().replaceAll('Exception: ', '')}')));
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Justificativa muito curta.')));
                  }
                },
                child: const Text('CONFIRMAR REJEIÇÃO'),
              )
            ],
          ),
        );
      }
    );
  }

  void _mostrarAnexoModal(BuildContext context, AnexoAbonoInfo anexo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(anexo.nomeArquivo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('A URL assinada abaixo é temporária (válida por 60 minutos) para acesso seguro ao bucket privado:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
              child: SelectableText(anexo.signedUrl, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
            ),
            const SizedBox(height: 16),
            if (anexo.mimeType.contains('image'))
              Flexible(
                child: Center(
                  child: Image.network(
                    anexo.signedUrl,
                    errorBuilder: (context, error, stackTrace) => const Text('Não foi possível carregar a pré-visualização da imagem.'),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

