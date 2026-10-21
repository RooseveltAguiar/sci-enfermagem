import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/frequencia_provider.dart';

class FrequenciaAuditoriaScreen extends ConsumerWidget {
  final String frequenciaId;

  const FrequenciaAuditoriaScreen({Key? key, required this.frequenciaId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditoriaAsync = ref.watch(auditoriaFrequenciaProvider(frequenciaId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trilha de Auditoria'),
      ),
      body: auditoriaAsync.when(
        data: (linhas) {
          if (linhas.isEmpty) {
            return const Center(child: Text('Nenhum dado de auditoria encontrado.'));
          }

          return ListView.builder(
            itemCount: linhas.length,
            padding: const EdgeInsets.all(16.0),
            itemBuilder: (context, index) {
              final linha = linhas[index];
              final statusNovo = linha['status_novo'];
              
              IconData icon = Icons.check_circle_outline;
              Color color = Colors.grey;

              if (statusNovo == 'pendente_validacao') {
                icon = Icons.person_add;
                color = Colors.orange;
              } else if (statusNovo == 'validado') {
                icon = Icons.verified;
                color = Colors.green;
              } else if (statusNovo == 'rejeitado') {
                icon = Icons.cancel;
                color = Colors.red;
              } else if (statusNovo == 'abonado_pend_ratificacao') {
                icon = Icons.description;
                color = Colors.blue;
              } else if (statusNovo == 'ratificado') {
                icon = Icons.gavel;
                color = Colors.teal;
              } else if (statusNovo == 'ausente') {
                icon = Icons.person_off;
                color = Colors.grey;
              }

              return TimelineTile(
                isFirst: index == 0,
                isLast: index == linhas.length - 1,
                icon: icon,
                color: color,
                title: _buildActionText(statusNovo, linha['ator_nome']),
                subtitle: linha['timestamp_alteracao'],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
    );
  }

  String _buildActionText(String status, String atorNome) {
    if (status == 'pendente_validacao') return 'Registrado por $atorNome';
    if (status == 'validado') return 'Validado por $atorNome';
    if (status == 'rejeitado') return 'Rejeitado por $atorNome';
    if (status == 'abonado_pend_ratificacao') return 'Abonado por $atorNome';
    if (status == 'ratificado') return 'Ratificado por $atorNome';
    if (status == 'ausente') return 'Marcado ausente por $atorNome';
    return 'Alterado por $atorNome';
  }
}

// Widget simples para desenhar a linha do tempo
class TimelineTile extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const TimelineTile({
    Key? key,
    required this.isFirst,
    required this.isLast,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 20,
                  color: isFirst ? Colors.transparent : Colors.grey.shade300,
                ),
                Icon(icon, color: color),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0, top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
