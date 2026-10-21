import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/visitas_provider.dart';
import '../../widgets/confirmation_bottom_sheet.dart';

class RegistrarVisitaScreen extends ConsumerStatefulWidget {
  const RegistrarVisitaScreen({super.key});

  @override
  ConsumerState<RegistrarVisitaScreen> createState() => _RegistrarVisitaScreenState();
}

class _RegistrarVisitaScreenState extends ConsumerState<RegistrarVisitaScreen> {
  final _relatoController = TextEditingController();
  String? _campoIdSelecionado;
  bool _isLoadingGps = false;
  bool _gpsDisponivel = false;
  bool _precisaoBaixa = false;
  double? _lat;
  double? _lng;
  int _relatoCharCount = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _relatoController.addListener(() {
      setState(() => _relatoCharCount = _relatoController.text.length);
    });
    _capturarGps();
  }

  @override
  void dispose() {
    _relatoController.dispose();
    super.dispose();
  }

  Future<void> _capturarGps() async {
    setState(() {
      _isLoadingGps = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _gpsDisponivel = false;
          _isLoadingGps = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _gpsDisponivel = false;
            _isLoadingGps = false;
          });
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final precisaoBaixa = position.accuracy > 150.0;

      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _gpsDisponivel = true;
        _precisaoBaixa = precisaoBaixa;
        _isLoadingGps = false;
      });
    } catch (_) {
      setState(() {
        _gpsDisponivel = false;
        _isLoadingGps = false;
      });
    }
  }

  void _submeterVisita() {
    final relato = _relatoController.text.trim();
    if (_campoIdSelecionado == null || _campoIdSelecionado!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um campo de estágio.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (relato.length < 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O relato deve conter no mínimo 30 caracteres.'), backgroundColor: Colors.red),
      );
      return;
    }

    ConfirmationBottomSheet.show(
      context,
      title: 'Registrar Visita Técnica?',
      message: 'Confirma o envio do relato e a validação do local da visita?',
      confirmText: 'Confirmar Registro',
      onConfirm: () async {
        context.pop(); // Fecha bottom sheet
        setState(() => _isSubmitting = true);

        try {
          await ref.read(visitasServiceProvider).registrarVisita(
            campoId: _campoIdSelecionado!,
            relato: relato,
            lat: _lat,
            lng: _lng,
            gpsDisponivel: _gpsDisponivel,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Visita técnica registrada com sucesso!'), backgroundColor: Color(0xFF1B6B45)),
            );
            context.pop(); // Voltar para a lista
          }
        } catch (e) {
          if (mounted) {
            final erroStr = e.toString();
            if (erroStr.contains('fora_do_campo')) {
              _exibirDialogForaDoCampo();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erro ao registrar visita: $e'), backgroundColor: Colors.red),
              );
            }
          }
        } finally {
          if (mounted) setState(() => _isSubmitting = false);
        }
      },
    );
  }

  void _exibirDialogForaDoCampo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.red),
            SizedBox(width: 8),
            Text('Fora do Campo'),
          ],
        ),
        content: const Text(
          'Sua localização atual ultrapassa o raio máximo permitido para este campo de estágio. Verifique se você está presencialmente no local.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final camposAsync = ref.watch(camposDoProfessorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Visita Técnica'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status do GPS
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _gpsDisponivel ? Colors.green.shade50 : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _gpsDisponivel ? Colors.green.shade300 : Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    _gpsDisponivel ? Icons.gps_fixed : Icons.gps_not_fixed,
                    color: _gpsDisponivel ? const Color(0xFF1B6B45) : Colors.amber.shade800,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _gpsDisponivel
                              ? (_precisaoBaixa ? 'Sinal GPS Capturado (Baixa Precisão >150m)' : 'Sinal GPS Capturado (Alta Precisão)')
                              : 'GPS Indisponível',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _gpsDisponivel ? const Color(0xFF1B6B45) : Colors.amber.shade900,
                          ),
                        ),
                        Text(
                          _gpsDisponivel
                              ? 'Lat: ${_lat?.toStringAsFixed(4)}, Lng: ${_lng?.toStringAsFixed(4)}'
                              : 'O registro é permitido, mas a visita ficará sinalizada para a coordenação.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoadingGps)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _capturarGps,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Dropdown de Campo Real do Professor
            camposAsync.when(
              data: (campos) {
                if (campos.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('Nenhum campo de estágio vinculado ao seu perfil.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return DropdownButtonFormField<String>(
                  initialValue: _campoIdSelecionado,
                  decoration: const InputDecoration(
                    labelText: 'Campo de Estágio *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  items: campos.map((c) {
                    return DropdownMenuItem<String>(
                      value: c.id,
                      child: Text(c.nome),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _campoIdSelecionado = val),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando campos do professor...')),
              error: (err, _) => Center(child: Text('Erro ao carregar campos: $err')),
            ),
            const SizedBox(height: 20),

            // Campo de Relato
            TextField(
              controller: _relatoController,
              maxLines: 5,
              maxLength: 2000,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      currentLength < 30 ? 'Mínimo de 30 caracteres (faltam ${30 - currentLength})' : 'Mínimo atingido ✔',
                      style: TextStyle(
                        fontSize: 12,
                        color: currentLength < 30 ? Colors.red : const Color(0xFF1B6B45),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('$currentLength / $maxLength', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                );
              },
              decoration: const InputDecoration(
                labelText: 'Relato da Visita Técnica *',
                hintText: 'Descreva o que observou e as orientações dadas aos alunos...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: (_isSubmitting || _relatoCharCount < 30) ? null : _submeterVisita,
              icon: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: const Text('REGISTRAR VISITA'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B6B45),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
