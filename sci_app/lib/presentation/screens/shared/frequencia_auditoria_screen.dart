import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../providers/frequencia_provider.dart';
import '../../../providers/abono_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/confirmation_bottom_sheet.dart';

class FrequenciaAuditoriaScreen extends ConsumerWidget {
  final String frequenciaId;

  const FrequenciaAuditoriaScreen({super.key, required this.frequenciaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditoriaAsync = ref.watch(auditoriaFrequenciaProvider(frequenciaId));
    final frequenciaAsync = ref.watch(frequenciaDetalheProvider(frequenciaId));
    final userProfile = ref.watch(userProfileProvider).value;

    final freq = frequenciaAsync.value;
    final double? lat = freq?.lat;
    final double? lng = freq?.lng;
    final bool temGpsValido = lat != null && lng != null && lat != 0 && lng != 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trilha de Auditoria'),
      ),
      body: Stack(
        children: [
          // 1. Fundo do Mapa com Ponto GPS do Aluno
          if (temGpsValido)
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(lat, lng),
                initialZoom: 16.0,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.sci.enfermagem.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(lat, lng),
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                    if (freq?.latSaida != null && freq?.lngSaida != null)
                      Marker(
                        point: LatLng(freq!.latSaida!, freq.lngSaida!),
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.blue,
                          size: 40,
                        ),
                      ),
                  ],
                ),
              ],
            )
          else
            Container(color: Colors.grey.shade100),

          // 2. Camada Semitransparente para legibilidade da Trilha de Auditoria
          Container(
            color: Colors.white.withValues(alpha: 0.88),
          ),

          // 3. Conteúdo em Primeiro Plano (Card de Dados GPS + Trilha + Ações)
          auditoriaAsync.when(
            data: (linhas) {
              if (linhas.isEmpty) {
                return const Center(child: Text('Nenhum dado de auditoria encontrado.'));
              }

              final statusAtual = freq?.status ?? (linhas.isNotEmpty ? (linhas.last['status_novo'] ?? 'pendente_validacao') : 'pendente_validacao');
              final isAvaliador = userProfile == 'supervisor' || userProfile == 'professor' || userProfile == 'coordenacao';

              return Column(
                children: [
                  // Card com as Coordenadas de GPS do Aluno
                  if (temGpsValido)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: freq?.mockLocationDetectado == true ? Colors.amber.shade100 : Colors.teal.shade100,
                            child: Icon(
                              freq?.mockLocationDetectado == true ? Icons.warning_amber_rounded : Icons.my_location,
                              color: freq?.mockLocationDetectado == true ? Colors.amber.shade900 : Colors.teal.shade900,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ponto de GPS do Registro',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Lat: ${lat.toStringAsFixed(6)} | Lng: ${lng.toStringAsFixed(6)}',
                                  style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
                                ),
                                if (freq?.distanciaMetros != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Distância do Campo: ${freq!.distanciaMetros!.toStringAsFixed(0)}m',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Lista da Trilha de Auditoria (Timeline)
                  Expanded(
                    child: ListView.builder(
                      itemCount: linhas.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                    ),
                  ),

                  // Barra de Ações (Validar, Rejeitar, Ratificar ou Solicitar Abono)
                  _buildBottomActions(context, ref, statusAtual, userProfile, isAvaliador),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
            error: (err, stack) => Center(child: Text('Erro: $err')),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    WidgetRef ref,
    String statusAtual,
    String? userProfile,
    bool isAvaliador,
  ) {
    final podeValidar = isAvaliador && statusAtual == 'pendente_validacao';
    final podeRatificar = isAvaliador && statusAtual == 'abonado_pend_ratificacao';
    final podeSolicitarAbono = (statusAtual == 'ausente' || statusAtual == 'rejeitado') && userProfile == 'aluno';

    if (!podeValidar && !podeRatificar && !podeSolicitarAbono) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: _getStatusBannerColor(statusAtual),
        child: Text(
          _getStatusBannerText(statusAtual, userProfile),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (podeValidar)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('VALIDAR PRESENÇA'),
                    onPressed: () => _confirmarValidacaoModal(context, ref),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('REJEITAR...'),
                    onPressed: () => _showRejeitarModal(context, ref),
                  ),
                ),
              ],
            ),
          if (podeRatificar)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.gavel),
                    label: const Text('RATIFICAR ABONO'),
                    onPressed: () => _confirmarRatificacaoModal(context, ref),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text('RECUSAR ABONO...'),
                    onPressed: () => _showRecusarAbonoModal(context, ref),
                  ),
                ),
              ],
            ),
          if (podeSolicitarAbono)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.description),
                label: const Text('SOLICITAR ABONO'),
                onPressed: () => _showSolicitarAbonoModal(context, ref),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusBannerColor(String status) {
    if (status == 'validado' || status == 'ratificado') return Colors.green.shade700;
    if (status == 'rejeitado' || status == 'ausente') return Colors.red.shade700;
    if (status == 'abonado_pend_ratificacao') return Colors.blue.shade700;
    return Colors.amber.shade800;
  }

  String _getStatusBannerText(String status, String? userProfile) {
    if (status == 'validado') return 'Presença Validada ✓';
    if (status == 'ratificado') return 'Abono Ratificado ✓';
    if (status == 'rejeitado') return 'Frequência Rejeitada';
    if (status == 'ausente') return 'Marcado Ausente';
    if (status == 'abonado_pend_ratificacao') return 'Abono Pendente de Ratificação';
    if (status == 'pendente_validacao') return 'Aguardando validação do supervisor/preceptor';
    return 'Status: $status';
  }

  void _confirmarValidacaoModal(BuildContext context, WidgetRef ref) {
    ConfirmationBottomSheet.show(
      context,
      title: 'Validar Presença',
      message: 'Confirma a validação desta frequência?',
      confirmText: 'Validar',
      onConfirm: () async {
        Navigator.pop(context);
        try {
          await ref.read(pendentesValidacaoProvider.notifier).validarFrequencia(frequenciaId);
          ref.invalidate(auditoriaFrequenciaProvider(frequenciaId));
          ref.invalidate(frequenciaDetalheProvider(frequenciaId));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Presença validada com sucesso!')));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao validar: ${e.toString().replaceAll('Exception: ', '')}')));
          }
        }
      },
    );
  }

  void _showRejeitarModal(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
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
            const Text('Rejeitar Presença', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 16),
            const Text('Descreva o motivo (mínimo de 20 caracteres):'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final just = controller.text.trim();
                if (just.length < 20) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Justificativa muito curta (mín. 20 caracteres).')));
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await ref.read(pendentesValidacaoProvider.notifier).rejeitarFrequencia(frequenciaId, just);
                  ref.invalidate(auditoriaFrequenciaProvider(frequenciaId));
                  ref.invalidate(frequenciaDetalheProvider(frequenciaId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Presença rejeitada.')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao rejeitar: ${e.toString().replaceAll('Exception: ', '')}')));
                  }
                }
              },
              child: const Text('CONFIRMAR REJEIÇÃO'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarRatificacaoModal(BuildContext context, WidgetRef ref) {
    ConfirmationBottomSheet.show(
      context,
      title: 'Ratificar Abono',
      message: 'Confirma a ratificação deste abono?',
      confirmText: 'Ratificar',
      onConfirm: () async {
        Navigator.pop(context);
        try {
          await ref.read(pendentesRatificacaoProvider.notifier).ratificarAbono(frequenciaId);
          ref.invalidate(auditoriaFrequenciaProvider(frequenciaId));
          ref.invalidate(frequenciaDetalheProvider(frequenciaId));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Abono ratificado com sucesso!')));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao ratificar: ${e.toString().replaceAll('Exception: ', '')}')));
          }
        }
      },
    );
  }

  void _showRecusarAbonoModal(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
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
            const Text('Recusar Abono', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 16),
            const Text('Descreva o motivo (mínimo de 20 caracteres):'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final just = controller.text.trim();
                if (just.length < 20) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Justificativa muito curta (mín. 20 caracteres).')));
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await ref.read(pendentesRatificacaoProvider.notifier).recusarAbono(frequenciaId, just);
                  ref.invalidate(auditoriaFrequenciaProvider(frequenciaId));
                  ref.invalidate(frequenciaDetalheProvider(frequenciaId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Abono recusado.')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao recusar: ${e.toString().replaceAll('Exception: ', '')}')));
                  }
                }
              },
              child: const Text('CONFIRMAR RECUSA'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSolicitarAbonoModal(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Solicitar Abono de Ausência',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 16),
            const Text('Justificativa (obrigatório, mín. 50 caracteres):'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Descreva o motivo legal da ausência (atestado, emergência, etc.)',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.blue.shade700),
                  onPressed: () async {
                    final just = controller.text.trim();
                    if (just.length < 50) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('A justificativa deve conter pelo menos 50 caracteres.')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final tempDir = Directory.systemTemp;
                    final mockFile = File('${tempDir.path}/abono_$frequenciaId.pdf');
                    if (!mockFile.existsSync()) {
                      mockFile.writeAsStringSync('Documento de Abono Mock');
                    }
                    await ref.read(abonoProvider.notifier).solicitarAbono(
                      frequenciaId: frequenciaId,
                      justificativa: just,
                      documento: mockFile,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Solicitação de abono enviada com sucesso!')),
                      );
                    }
                  },
                  child: const Text('CONFIRMAR ENVIO'),
                ),
              ],
            ),
          ],
        ),
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

class TimelineTile extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const TimelineTile({
    super.key,
    required this.isFirst,
    required this.isLast,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

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
