import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/visitas_provider.dart';

class VisitasListaScreen extends ConsumerWidget {
  const VisitasListaScreen({super.key});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'validada':
        return Colors.teal;
      case 'rejeitada':
        return Colors.red;
      case 'pendente_validacao':
      default:
        return Colors.amber.shade800;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'validada':
        return 'Validada';
      case 'rejeitada':
        return 'Rejeitada';
      case 'pendente_validacao':
      default:
        return 'Pendente Validação';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitasAsync = ref.watch(minhasVisitasProvider);
    final progressoAsync = ref.watch(progressoVisitasMensalProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitas Técnicas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(minhasVisitasProvider);
              ref.invalidate(progressoVisitasMensalProvider(null));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(minhasVisitasProvider);
          ref.invalidate(progressoVisitasMensalProvider(null));
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Card de Progresso Mensal
            progressoAsync.when(
              data: (listaProgresso) {
                if (listaProgresso.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Progresso Mensal de Visitas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('Nenhum campo de estágio vinculado ao seu perfil.', style: TextStyle(color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: listaProgresso.map((p) {
                    final percent = (p.realizadas / p.minimasRequeridas).clamp(0.0, 1.0);
                    final exibeAlerta = !p.atingiuMinimo && DateTime.now().day >= 20;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: exibeAlerta ? Colors.amber.shade700 : Colors.transparent, width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(p.campoNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: p.atingiuMinimo ? Colors.teal.shade50 : Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${p.realizadas} / ${p.minimasRequeridas} mínimas',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: p.atingiuMinimo ? Colors.teal.shade800 : Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: percent,
                              backgroundColor: Colors.grey.shade200,
                              color: p.atingiuMinimo ? const Color(0xFF1B6B45) : Colors.amber.shade800,
                              minHeight: 6,
                            ),
                            if (exibeAlerta) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade900),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Fechamento do mês próximo! Registre sua visita.',
                                    style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando progresso...')),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            const Text('Histórico de Visitas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),

            // Lista de Visitas
            visitasAsync.when(
              data: (visitas) {
                if (visitas.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.fact_check_outlined, size: 56, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Nenhuma visita registrada ainda.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Toque no botão + abaixo para registrar.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visitas.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final v = visitas[index];
                    final statusColor = _getStatusColor(v.status);
                    final statusLabel = _getStatusLabel(v.status);
                    final dataStr = '${v.createdAt.day.toString().padLeft(2, '0')}/${v.createdAt.month.toString().padLeft(2, '0')}/${v.createdAt.year}';

                    return Card(
                      elevation: 1,
                      child: ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(v.campoNome ?? 'Campo de Estágio', style: const TextStyle(fontWeight: FontWeight.bold))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                              child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(v.relato, maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Text(dataStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            if (v.status == 'rejeitada' && v.justificativaRejeicao != null) ...[
                              const SizedBox(height: 4),
                              Text('Justificativa: ${v.justificativaRejeicao}', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando visitas...')),
              error: (err, _) => Center(child: Text('Erro: $err')),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/professor/visitas/nova'),
        icon: const Icon(Icons.add),
        label: const Text('Nova Visita'),
        backgroundColor: const Color(0xFF1B6B45),
        foregroundColor: Colors.white,
      ),
    );
  }
}
