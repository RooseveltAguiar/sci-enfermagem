import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/campos_provider.dart';
import '../../../providers/frequencia_provider.dart';
import '../../widgets/confirmation_bottom_sheet.dart';

class RegistrarPresencaScreen extends ConsumerStatefulWidget {
  const RegistrarPresencaScreen({super.key});

  @override
  ConsumerState<RegistrarPresencaScreen> createState() => _RegistrarPresencaScreenState();
}

class _RegistrarPresencaScreenState extends ConsumerState<RegistrarPresencaScreen> {
  int _currentStep = 0;
  CampoEstagio? _selectedCampo;
  String? _selectedTurno;
  
  bool _isGettingLocation = false;
  bool _locationObtained = false;
  bool _gpsDisponivel = true;
  double? _lat;
  double? _lng;
  
  @override
  Widget build(BuildContext context) {
    final camposAsync = ref.watch(camposAlunoProvider);
    final jornadaAsync = ref.watch(frequenciaHojeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Presença / Saída')),
      body: jornadaAsync.when(
        data: (jornada) {
          // Se o aluno já realizou o Check-in e está em campo, exibe o modo Check-out
          if (jornada.status == StatusJornada.emCampo) {
            return _buildCheckoutMode(context, jornada);
          }

          if (jornada.status == StatusJornada.finalizado) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF1B6B45), size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Jornada de hoje finalizada!',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Entrada e saída registradas com sucesso para ${jornada.frequenciaAtual?.campoNome ?? 'o campo'}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.go('/aluno/home'),
                      child: const Text('Voltar ao Início'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Modo Padrão: Check-in
          return _buildCheckinStepper(context, camposAsync);
        },
        loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
    );
  }

  Widget _buildCheckoutMode(BuildContext context, EstadoJornadaHoje jornada) {
    final freq = jornada.frequenciaAtual;
    final horaEntradaStr = jornada.horaEntrada != null
        ? '${jornada.horaEntrada!.hour.toString().padLeft(2, '0')}:${jornada.horaEntrada!.minute.toString().padLeft(2, '0')}'
        : '07:00';
    final horasEmCampo = jornada.horasEmCampo;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: const Color(0xFF1B6B45).withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: const Color(0xFF1B6B45).withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Icon(Icons.timer_outlined, color: Color(0xFF1B6B45), size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Você está Em Campo',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B6B45)),
                  ),
                  const SizedBox(height: 6),
                  Text('Campo: ${freq?.campoNome ?? 'Estágio de Enfermagem'}'),
                  Text('Entrada registrada às $horaEntradaStr'),
                  const SizedBox(height: 12),
                  Chip(
                    label: Text('${horasEmCampo.toStringAsFixed(1)}h decorridas hoje'),
                    backgroundColor: Colors.white,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B6B45)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Check-out com Validação GPS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),

          if (_isGettingLocation)
            const Column(
              children: [
                CircularProgressIndicator(semanticsLabel: 'Carregando...'),
                SizedBox(height: 16),
                Text('Obtendo localização de saída via GPS...'),
              ],
            )
          else if (_locationObtained && _gpsDisponivel)
            const Column(
              children: [
                Icon(Icons.location_on, color: Colors.green, size: 56),
                SizedBox(height: 8),
                Text('Localização de saída obtida!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            )
          else if (!_gpsDisponivel)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('GPS indisponível para saída. O registro será enviado com pendência para o supervisor.'),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          if (!_locationObtained && !_isGettingLocation)
            OutlinedButton.icon(
              onPressed: _obterLocalizacao,
              icon: const Icon(Icons.my_location),
              label: const Text('Obter Localização de Saída'),
            ),

          const SizedBox(height: 16),

          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: (_locationObtained || !_gpsDisponivel)
                ? () => _confirmarCheckoutModal(context, freq?.id ?? '', horaEntradaStr, horasEmCampo)
                : null,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('REGISTRAR SAÍDA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckinStepper(BuildContext context, AsyncValue<List<CampoEstagio>> camposAsync) {
    return Stepper(
      currentStep: _currentStep,
      onStepCancel: () {
        if (_currentStep > 0) setState(() => _currentStep -= 1);
      },
      onStepContinue: () {
        if (_currentStep == 0 && _selectedCampo != null && _selectedTurno != null) {
          setState(() {
            _currentStep += 1;
          });
          _obterLocalizacao();
        } else if (_currentStep == 1) {
          _confirmarPresenca();
        }
      },
      controlsBuilder: (context, details) {
        if (_currentStep == 0) {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: FilledButton(
              onPressed: (_selectedCampo != null && _selectedTurno != null) ? details.onStepContinue : null,
              child: const Text('Iniciar Check-in'),
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _locationObtained || !_gpsDisponivel ? details.onStepContinue : null,
                    child: const Text('Confirmar Presença'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Voltar'),
                ),
              ],
            ),
          );
        }
      },
      steps: [
        Step(
          title: const Text('Selecionar Campo e Turno'),
          isActive: _currentStep >= 0,
          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          content: camposAsync.when(
            data: (campos) {
              if (campos.isEmpty) return const Text('Nenhum campo de estágio ativo no momento.');
              return Column(
                children: [
                  DropdownButtonFormField<CampoEstagio>(
                    decoration: const InputDecoration(labelText: 'Campo de Estágio', border: OutlineInputBorder()),
                    initialValue: _selectedCampo,
                    items: campos.map((c) => DropdownMenuItem(value: c, child: Text(c.nome))).toList(),
                    onChanged: (val) => setState(() => _selectedCampo = val),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Turno', border: OutlineInputBorder()),
                    initialValue: _selectedTurno,
                    items: ['Manhã', 'Tarde', 'Noite'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) => setState(() => _selectedTurno = val),
                  ),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(semanticsLabel: 'Carregando...'),
            error: (err, stack) => Text('Erro: $err'),
          ),
        ),
        Step(
          title: const Text('Check-in com GPS'),
          isActive: _currentStep >= 1,
          state: _currentStep == 1 ? StepState.editing : StepState.indexed,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_selectedCampo != null) ...[
                Text('Local: ${_selectedCampo!.nome}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Turno: $_selectedTurno'),
                const SizedBox(height: 24),
              ],
              
              if (_isGettingLocation)
                const Column(
                  children: [
                    CircularProgressIndicator(semanticsLabel: 'Carregando...'),
                    SizedBox(height: 16),
                    Text('Obtendo localização do satélite...'),
                  ],
                )
              else if (_locationObtained && _gpsDisponivel)
                const Column(
                  children: [
                    Icon(Icons.location_on, color: Colors.green, size: 64),
                    SizedBox(height: 16),
                    Text('Localização obtida com sucesso!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                )
              else if (!_gpsDisponivel)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.amber.shade100,
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
                      SizedBox(width: 16),
                      Expanded(child: Text('Localização indisponível. Seu supervisor será notificado para confirmar sua presença fisicamente.')),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _obterLocalizacao() async {
    setState(() {
      _isGettingLocation = true;
      _locationObtained = false;
      _gpsDisponivel = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isGettingLocation = false;
      _locationObtained = true;
      _lat = -3.7319;
      _lng = -38.5267;
    });
  }

  void _confirmarPresenca() {
    ConfirmationBottomSheet.show(
      context,
      title: 'Confirmar Check-in?',
      message: 'Local: ${_selectedCampo?.nome}\nTurno: $_selectedTurno\nHorário: ${TimeOfDay.now().format(context)}',
      confirmText: 'CONFIRMAR',
      onConfirm: () {
        Navigator.pop(context);
        _executarRegistroBanco();
      },
    );
  }

  void _confirmarCheckoutModal(BuildContext context, String frequenciaId, String horaEntrada, double horasTrabalhadas) {
    final horaSaidaStr = TimeOfDay.now().format(context);
    final hCalc = horasTrabalhadas.toStringAsFixed(1);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    ConfirmationBottomSheet.show(
      context,
      title: 'Confirmar Registar Saída?',
      message: 'Confirmar saída às $horaSaidaStr?\nHoras trabalhadas hoje: ${hCalc}h',
      confirmText: 'CONFIRMAR SAÍDA',
      onConfirm: () async {
        Navigator.pop(context);
        try {
          await ref.read(historicoAlunoProvider.notifier).registrarCheckout(
            frequenciaId: frequenciaId,
            latSaida: _lat,
            lngSaida: _lng,
            gpsSaidaDisponivel: _gpsDisponivel,
          );
          if (mounted) {
            ref.invalidate(frequenciaHojeProvider);
            final estadoAtualizado = await ref.read(frequenciaHojeProvider.future);
            final horasOficiais = estadoAtualizado.frequenciaAtual?.horasTrabalhadas ?? horasTrabalhadas;
            final hOficialStr = horasOficiais.toStringAsFixed(1);

            messenger.showSnackBar(
              SnackBar(
                content: Text('Saída registrada às $horaSaidaStr com sucesso! Total: ${hOficialStr}h'),
                backgroundColor: const Color(0xFF1B6B45),
              ),
            );
            router.go('/aluno/home');
          }
        } catch (e) {
          if (mounted) {
            final errStr = e.toString();
            String msgAmigavel = 'Erro ao registrar saída: $errStr';

            if (errStr.contains('saida_fora_do_campo') || errStr.contains('fora_do_campo')) {
              msgAmigavel = 'Você está fora do perímetro do raio do campo de estágio para registrar a saída.';
            } else if (errStr.contains('chk_saida_apos_entrada')) {
              msgAmigavel = 'Horário de saída inválido: O horário de saída deve ser posterior ao horário de entrada registrado.';
            }

            if (context.mounted) {
              await showDialog(
                context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Atenção no Check-out'),
                  ],
                ),
                content: Text(msgAmigavel),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Entendido'),
                  ),
                ],
              ),
            );
            }
          }
        }
      },
    );
  }

  Future<void> _executarRegistroBanco() async {
    try {
      if (!mounted) return;
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        throw Exception('Usuário não autenticado no Supabase.');
      }

      final hojeStr = DateTime.now().toIso8601String().split('T').first;

      await supabase.from('frequencias').insert({
        'aluno_id': userId,
        'alocacao_id': _selectedCampo?.id,
        'data_registro': hojeStr,
        'status': 'pendente_validacao',
        'lat_registro': _lat,
        'lng_registro': _lng,
        'gps_disponivel': _gpsDisponivel,
        'timestamp_entrada_cliente': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ref.invalidate(frequenciaHojeProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Presença registrada com sucesso!'),
          backgroundColor: Color(0xFF1B6B45),
        ),
      );
      context.go('/aluno/home');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('fora_do_campo') || msg.contains('raio')) {
        final raioMetros = _selectedCampo?.raioMetros ?? 100;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Fora do campo de estágio'),
            content: Text(
              'Você está fora do ponto central do campo. '
              'O raio permitido é de ${raioMetros.toInt()} metros.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Ok'),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao registrar presença: $msg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
