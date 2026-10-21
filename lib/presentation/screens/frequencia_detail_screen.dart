import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Note: Flutter Map required in pubspec.yaml: flutter_map, latlong2
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/providers/frequencia_provider.dart';
import '../widgets/status_chip.dart';
import '../widgets/confirmation_bottom_sheet.dart';
import 'abono_form_screen.dart';

class FrequenciaDetailScreen extends ConsumerWidget {
  final Frequencia frequencia;

  const FrequenciaDetailScreen({Key? key, required this.frequencia}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasGps = frequencia.gpsDisponivel && frequencia.lat != null && frequencia.lng != null;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Registro'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Map View
            if (hasGps)
              SizedBox(
                height: 250,
                child: FlutterMap(
                  options: MapOptions(
                    center: LatLng(frequencia.lat!, frequencia.lng!),
                    zoom: 16.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'br.uece.sci',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(frequencia.lat!, frequencia.lng!),
                          width: 40,
                          height: 40,
                          builder: (ctx) => const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 250,
                color: Colors.grey.shade200,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('GPS Indisponível no momento do registro', 
                        style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ),

            // Detalhes Anti-spoofing e Informacoes
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          frequencia.alunoNome ?? 'Aluno Desconhecido',
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      StatusChip(status: FrequenciaStatus.pendenteValidacao), // Placeholder de cast
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Data: ${frequencia.dataRegistro}', style: theme.textTheme.titleMedium),
                  const Divider(height: 32),
                  
                  const Text('Auditoria e Segurança', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  
                  _buildAuditRow(
                    icon: Icons.my_location,
                    label: 'Distância do Centro',
                    value: frequencia.distanciaMetros != null 
                        ? '${frequencia.distanciaMetros!.toStringAsFixed(2)}m' 
                        : 'N/A',
                  ),
                  _buildAuditRow(
                    icon: Icons.speed,
                    label: 'Velocidade Registrada',
                    value: frequencia.velocidadeMs != null 
                        ? '${frequencia.velocidadeMs!.toStringAsFixed(2)} m/s' 
                        : 'N/A',
                  ),
                  _buildAuditRow(
                    icon: Icons.security,
                    label: 'Mock Location',
                    value: frequencia.mockLocationDetectado ? 'Detectado (Suspeito)' : 'Limpo',
                    isWarning: frequencia.mockLocationDetectado,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Acoes
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {
                            ConfirmationBottomSheet.show(
                              context,
                              title: 'Validar Presença',
                              message: 'Confirma a presença do aluno no campo de estágio?',
                              confirmText: 'Validar',
                              onConfirm: () async {
                                await ref.read(pendentesValidacaoProvider.notifier).validarFrequencia(frequencia.id);
                                if (context.mounted) Navigator.pop(context);
                              },
                            );
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('VALIDAR'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {
                            _showRejectDialog(context, ref);
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('REJEITAR'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AbonoFormScreen(frequenciaId: frequencia.id)),
                        );
                      },
                      icon: const Icon(Icons.assignment_turned_in),
                      label: const Text('ABONAR FALTA DIRETAMENTE'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditRow({required IconData icon, required String label, required String value, bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: isWarning ? Colors.red : Colors.grey.shade700),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.black87)),
          const Spacer(),
          Text(
            value, 
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isWarning ? Colors.red : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
              Text('Rejeitar Presença', 
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 16),
              const Text('Descreva o motivo da rejeição (Mínimo de 20 caracteres):'),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'O aluno não estava no setor...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  if (textController.text.trim().length >= 20) {
                    Navigator.pop(ctx);
                    await ref.read(pendentesValidacaoProvider.notifier).rejeitarFrequencia(frequencia.id, textController.text);
                    if (context.mounted) Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('A justificativa deve ter no mínimo 20 caracteres.')),
                    );
                  }
                },
                child: const Text('Confirmar Rejeição'),
              ),
            ],
          ),
        );
      },
    );
  }
}
