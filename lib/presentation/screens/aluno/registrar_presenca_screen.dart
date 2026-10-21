import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/campos_provider.dart';
import '../../../providers/auth_provider.dart';

class RegistrarPresencaScreen extends ConsumerStatefulWidget {
  const RegistrarPresencaScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RegistrarPresencaScreen> createState() => _RegistrarPresencaScreenState();
}

class _RegistrarPresencaScreenState extends ConsumerState<RegistrarPresencaScreen> {
  int _currentStep = 0;
  CampoEstagio? _selectedCampo;
  String? _selectedTurno; // Simplificado para string no mockup
  
  bool _isGettingLocation = false;
  bool _locationObtained = false;
  bool _gpsDisponivel = true; // Simula leitura
  
  @override
  Widget build(BuildContext context) {
    final camposAsync = ref.watch(camposAlunoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Presença')),
      body: Stepper(
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
                      value: _selectedCampo,
                      items: campos.map((c) => DropdownMenuItem(value: c, child: Text(c.nome))).toList(),
                      onChanged: (val) => setState(() => _selectedCampo = val),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Turno', border: OutlineInputBorder()),
                      value: _selectedTurno,
                      items: ['Manhã', 'Tarde', 'Noite'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setState(() => _selectedTurno = val),
                    ),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
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
                      CircularProgressIndicator(),
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
      ),
    );
  }

  Future<void> _obterLocalizacao() async {
    setState(() {
      _isGettingLocation = true;
      _locationObtained = false;
      _gpsDisponivel = true;
    });

    // Simulacao de chamada a geolocator
    await Future.delayed(const Duration(seconds: 2));

    // Exemplo: se falhar, setar gpsDisponivel = false
    setState(() {
      _isGettingLocation = false;
      _locationObtained = true; 
    });
  }

  void _confirmarPresenca() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Confirmar Check-in?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Local: ${_selectedCampo?.nome}'),
            Text('Turno: $_selectedTurno'),
            Text('Horário: ${TimeOfDay.now().format(context)}'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executarRegistroBanco();
              },
              child: const Text('CONFIRMAR'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executarRegistroBanco() async {
    // Chamaria: await supabase.rpc('fn_registrar_frequencia', ...)
    // Por enquanto, apenas mocka sucesso
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Presença registrada com sucesso!'), backgroundColor: Colors.green),
    );
    context.go('/aluno/home');
  }
}
