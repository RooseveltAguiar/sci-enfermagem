import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/frequencia_provider.dart';
import '../../widgets/confirmation_bottom_sheet.dart';

class ValidarDetalheScreen extends ConsumerWidget {
  final String frequenciaId;

  const ValidarDetalheScreen({Key? key, required this.frequenciaId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Para simplificar, buscamos o objeto completo da lista atual no Provider
    final pendentes = ref.watch(pendentesValidacaoProvider).value ?? [];
    
    // Se não encontrou, talvez seja uma ratificacao, entao procura nos abonos pendentes
    final ratificacoes = ref.watch(pendentesRatificacaoProvider).value ?? [];
    
    Frequencia? freq;
    bool isRatificacao = false;
    
    try {
      freq = pendentes.firstWhere((f) => f.id == frequenciaId);
    } catch (_) {
      try {
        freq = ratificacoes.firstWhere((f) => f.id == frequenciaId);
        isRatificacao = true;
      } catch (_) {
        // Nao encontrado
      }
    }

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
                onPressed: () => _confirmarValidacao(context, ref, freq!),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.all(16)),
                icon: const Icon(Icons.close),
                label: const Text('REJEITAR'),
                onPressed: () => _showRejectBottomSheet(context, ref, freq!),
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
        color: color.withOpacity(0.1),
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
        await ref.read(pendentesValidacaoProvider.notifier).validarFrequencia(freq.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Presença validada com sucesso!')));
          context.pop();
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
                    await ref.read(pendentesValidacaoProvider.notifier).rejeitarFrequencia(freq.id, textController.text);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro rejeitado.')));
                      context.pop(); // Volta pra lista
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
}
