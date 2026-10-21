import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/atividades_provider.dart';
import '../../widgets/sync_status_icon.dart';

class AtividadesListaScreen extends ConsumerStatefulWidget {
  const AtividadesListaScreen({super.key});

  @override
  ConsumerState<AtividadesListaScreen> createState() => _AtividadesListaScreenState();
}

class _AtividadesListaScreenState extends ConsumerState<AtividadesListaScreen> {
  String _filtroStatus = 'Todos';

  @override
  Widget build(BuildContext context) {
    final atividadesAsync = ref.watch(atividadesAlunoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Atividades'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Exportar Relatórios',
            onPressed: () => context.push('/exportacao'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['Todos', 'Pendentes', 'Validadas'].map((status) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(status),
                    selected: _filtroStatus == status,
                    onSelected: (selected) {
                      if (selected) setState(() => _filtroStatus = status);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: atividadesAsync.when(
        data: (todas) {
          final atividades = todas.where((a) {
            if (_filtroStatus == 'Pendentes') return a['status'] == 'pendente_validacao';
            if (_filtroStatus == 'Validadas') return a['status'] == 'validado';
            return true;
          }).toList();

          if (atividades.isEmpty) {
            return const Center(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Nenhuma atividade registrada.'),
              ],
            ),
          );
        }

        return RefreshIndicator(
            onRefresh: () async => ref.read(atividadesAlunoProvider.notifier).refresh(),
            child: ListView.builder(
              itemCount: atividades.length,
              itemBuilder: (context, index) {
                final a = atividades[index];
                final isValidado = a['status'] == 'validado';
                final hasComentario = a['comentario_aluno'] != null && a['comentario_aluno'].toString().isNotEmpty;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: InkWell(
                    onTap: isValidado ? () => _abrirComentarioDialog(context, a) : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                 child: Text(a['descricao'] ?? a['nome'] ?? 'Atividade', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                              SyncStatusIcon(registroId: a['id'].toString()),
                              const SizedBox(width: 8),
                              _buildStatusChip(a['status']),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Data: ${_formatarData(a)}'),
                          if (hasComentario) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200)
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.comment, size: 16, color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(a['comentario_aluno'], style: TextStyle(color: Colors.blue.shade900))),
                                ],
                              ),
                            )
                          ],
                          if (isValidado && !hasComentario) ...[
                            const SizedBox(height: 8),
                            const Text('Toque para adicionar um comentário', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12))
                          ]
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/aluno/atividades/registrar'),
        icon: const Icon(Icons.add),
        label: const Text('Registrar Atividade'),
      ),
    );
  }

  String _formatarData(Map<String, dynamic> a) {
    final raw = a['data_formatada'] ?? a['data_registro'] ?? a['data_atividade'] ?? a['data'] ?? a['created_at'];
    if (raw == null) return '';
    final str = raw.toString().trim();
    if (str.isEmpty) return '';
    final dateOnly = str.split('T')[0].split(' ')[0];
    final parts = dateOnly.split('-');
    if (parts.length == 3 && parts[0].length == 4) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return dateOnly;
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    if (status == 'validado') {
      color = Colors.green;
      label = 'Validado';
    } else if (status == 'rejeitado') {
      color = Colors.red;
      label = 'Rejeitado';
    } else {
      color = Colors.orange;
      label = 'Pendente';
    }
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.1),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
      side: BorderSide.none,
    );
  }

  void _abrirComentarioDialog(BuildContext context, Map<String, dynamic> atividade) {
    final controller = TextEditingController(text: atividade['comentario_aluno']);
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
            const Text('Comentário do Aluno', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLength: 500,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Adicione suas reflexões sobre a prática...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                // Aqui chamaria o provider para salvar o comentário
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comentário salvo!')));
              },
              child: const Text('SALVAR COMENTÁRIO'),
            )
          ],
        ),
      ),
    );
  }
}
