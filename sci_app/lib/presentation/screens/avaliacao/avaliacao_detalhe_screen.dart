import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/avaliacoes_provider.dart';
import '../../widgets/avaliacao_status_chip.dart';
import '../../widgets/nota_card.dart';
import '../../widgets/timeline_avaliacao.dart';

class AvaliacaoDetalheScreen extends ConsumerWidget {
  final String avaliacaoId;
  final bool modoValidacao;

  const AvaliacaoDetalheScreen({
    super.key,
    required this.avaliacaoId,
    this.modoValidacao = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avaliacoesAsync = ref.watch(avaliacoesProvider);
    final profileAsync = ref.watch(userProfileProvider);
    String? currentUserId;
    try {
      currentUserId = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Avaliação'),
      ),
      body: avaliacoesAsync.when(
        data: (list) {
          final avaliacao = list.where((a) => a.id == avaliacaoId).firstOrNull;
          if (avaliacao == null) {
            return const Center(child: Text('Avaliação não encontrada.'));
          }

          final userRole = profileAsync.value;
          final isAluno = userRole == 'aluno';
          final isDoInterno = avaliacao.tipo == 'do_interno';
          final bloqueadoParaAluno = isAluno && isDoInterno && avaliacao.status != 'aprovada';
          final isOwnerAndRascunho = avaliacao.status == 'rascunho' &&
              currentUserId != null &&
              currentUserId == avaliacao.avaliadorId;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card de Cabeçalho
                Card(
                  elevation: 0,
                  color: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getTipoLabel(avaliacao.tipo),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            AvaliacaoStatusChip.fromString(
                              avaliacao.status,
                              comentarioValidacao: avaliacao.comentarioValidacao,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Período: ${_formatMesAno(avaliacao.periodoReferencia)}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        if (avaliacao.avaliadorNome != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Avaliador: ${htmlEscape.convert(avaliacao.avaliadorNome!)}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (bloqueadoParaAluno) ...[
                  const SizedBox(height: 32),
                  const Center(
                    child: Column(
                      children: [
                        Icon(Icons.lock_outline, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'Conteúdo disponível após aprovação da coordenação.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  if (avaliacao.notaGeral != null) ...[
                    NotaCard(notaGeral: avaliacao.notaGeral!),
                    const SizedBox(height: 20),
                  ],

                  _buildSecao('Pontos Positivos', avaliacao.pontosPositivos ?? 'Não informado'),
                  const SizedBox(height: 16),

                  _buildSecao('Pontos a Melhorar', avaliacao.pontosMelhoria ?? 'Não informado'),
                  const SizedBox(height: 16),

                  if (avaliacao.comentarioLivre != null && avaliacao.comentarioLivre!.isNotEmpty) ...[
                    _buildSecao('Comentário Livre', avaliacao.comentarioLivre!),
                    const SizedBox(height: 16),
                  ],

                  if (avaliacao.comentarioValidacao != null && avaliacao.comentarioValidacao!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.admin_panel_settings, color: Colors.blue.shade900, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Comentário da Coordenação',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(htmlEscape.convert(avaliacao.comentarioValidacao!)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Timeline do ciclo de vida
                  TimelineAvaliacao(
                    steps: _buildTimelineSteps(avaliacao.status),
                  ),
                ],

                // Botão Editar (se rascunho e proprietário)
                if (isOwnerAndRascunho && !modoValidacao) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.push('/avaliacao/${avaliacao.id}/editar'),
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar Rascunho'),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
        error: (e, s) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  Widget _buildSecao(String titulo, String conteudo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            htmlEscape.convert(conteudo),
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
        ),
      ],
    );
  }

  List<TimelineStepData> _buildTimelineSteps(String currentStatus) {
    int index = 0;
    switch (currentStatus) {
      case 'submetida':
        index = 1;
        break;
      case 'validada':
        index = 2;
        break;
      case 'aprovada':
        index = 3;
        break;
      case 'rascunho':
      default:
        index = 0;
        break;
    }

    return [
      TimelineStepData(
        titulo: 'Rascunho',
        concluido: index > 0,
        atual: index == 0,
      ),
      TimelineStepData(
        titulo: 'Submetida',
        concluido: index > 1,
        atual: index == 1,
      ),
      TimelineStepData(
        titulo: 'Validada pela Coordenação',
        concluido: index > 2,
        atual: index == 2,
      ),
      TimelineStepData(
        titulo: 'Aprovada e Publicada',
        concluido: index == 3,
        atual: index == 3,
      ),
    ];
  }

  String _getTipoLabel(String tipo) {
    switch (tipo) {
      case 'setorial':
        return 'Avaliação Setorial';
      case 'autoavaliacao':
        return 'Autoavaliação';
      case 'do_interno':
      default:
        return 'Avaliação do Interno';
    }
  }

  String _formatMesAno(DateTime dt) {
    final meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return '${meses[dt.month - 1]} de ${dt.year}';
  }
}
