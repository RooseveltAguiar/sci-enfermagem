import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/visitas_provider.dart';
import '../../widgets/confirmation_bottom_sheet.dart';

class VisitasValidarScreen extends ConsumerStatefulWidget {
  const VisitasValidarScreen({super.key});

  @override
  ConsumerState<VisitasValidarScreen> createState() => _VisitasValidarScreenState();
}

class _VisitasValidarScreenState extends ConsumerState<VisitasValidarScreen> {
  void _exibirDetalhesModal(VisitaTecnica visita) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Detalhes da Visita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  Text('Professor: ${visita.professorNome ?? 'Professor'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('Campo: ${visita.campoNome ?? 'Campo de Estágio'}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),

                  // Banner de GPS / Mock Location
                  if (visita.mockLocationDetectado)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade300)),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text('Atenção: Localização Fictícia (Mock Location) Detectada!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Icon(visita.gpsDisponivel ? Icons.gps_fixed : Icons.gps_not_fixed, size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 8),
                          Text(
                            visita.gpsDisponivel
                                ? 'GPS Confirmado (Distância: ${visita.distanciaMetros?.toInt() ?? 0}m)'
                                : 'GPS Indisponível no momento do registro',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                          ),
                        ],
                      ),
                    ),

                  const Text('Relato:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: Text(visita.relato, style: const TextStyle(height: 1.3)),
                  ),
                  const SizedBox(height: 16),

                  // Ações
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _exibirDialogRejeicao(visita.id);
                          },
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text('Rejeitar', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _validarVisita(visita.id);
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Validar'),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B6B45)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _validarVisita(String id) {
    ConfirmationBottomSheet.show(
      context,
      title: 'Validar Visita Técnica?',
      message: 'Confirma a aprovação desta visita técnica?',
      confirmText: 'Validar',
      onConfirm: () async {
        context.pop();
        try {
          await ref.read(visitasServiceProvider).validarVisita(id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visita validada com sucesso!'), backgroundColor: Color(0xFF1B6B45)));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
          }
        }
      },
    );
  }

  void _exibirDialogRejeicao(String id) {
    final justController = TextEditingController();
    String? erroJustificativa;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rejeitar Visita Técnica'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Informe a justificativa de rejeição (mínimo 20 caracteres):'),
              const SizedBox(height: 12),
              TextField(
                controller: justController,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'Justificativa *',
                  errorText: erroJustificativa,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (val) {
                  if (val.trim().length >= 20 && erroJustificativa != null) {
                    setDialogState(() => erroJustificativa = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final just = justController.text.trim();
                if (just.length < 20) {
                  setDialogState(() => erroJustificativa = 'Mínimo de 20 caracteres necessário.');
                  return;
                }

                final messenger = ScaffoldMessenger.of(context);
                final dialogNavigator = Navigator.of(ctx);
                final parentNavigator = Navigator.of(context);

                dialogNavigator.pop(); // Fecha dialog de justificativa
                parentNavigator.pop(); // Fecha modal de detalhes

                try {
                  await ref.read(visitasServiceProvider).rejeitarVisita(id, just);
                  if (mounted) {
                    messenger.showSnackBar(const SnackBar(content: Text('Visita rejeitada com sucesso.'), backgroundColor: Colors.red));
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(SnackBar(content: Text('Erro ao rejeitar visita: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Confirmar Rejeição'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendentesAsync = ref.watch(visitasPendentesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Validar Visitas Técnicas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(visitasPendentesProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(visitasPendentesProvider),
        child: pendentesAsync.when(
          data: (visitas) {
            if (visitas.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Nenhuma visita pendente de validação.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: visitas.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final v = visitas[index];
                return Card(
                  elevation: 1,
                  child: ListTile(
                    onTap: () => _exibirDetalhesModal(v),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF1B6B45),
                      child: Text(v.professorNome != null && v.professorNome!.isNotEmpty ? v.professorNome![0].toUpperCase() : 'P', style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(v.professorNome ?? 'Professor', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Campo: ${v.campoNome ?? 'Campo de Estágio'}'),
                        const SizedBox(height: 4),
                        Text(v.relato, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando pendências...')),
          error: (err, _) => Center(child: Text('Erro: $err')),
        ),
      ),
    );
  }
}
