import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/location_service.dart';
import '../../../data/repositories/frequencia_repository.dart';

final frequenciaRepositoryProvider = Provider((ref) => FrequenciaRepository(Supabase.instance.client));

class AlunoFrequenciaScreen extends ConsumerStatefulWidget {
  const AlunoFrequenciaScreen({super.key});

  @override
  ConsumerState<AlunoFrequenciaScreen> createState() => _AlunoFrequenciaScreenState();
}

class _AlunoFrequenciaScreenState extends ConsumerState<AlunoFrequenciaScreen> {
  bool _isLoading = false;
  final _locationService = LocationService();

  Future<void> _fazerCheckIn() async {
    setState(() => _isLoading = true);
    try {
      final location = await _locationService.getCurrentPosition();
      
      // O backend já espera receber lat_registro nulo se gps_disponivel for false
      await ref.read(frequenciaRepositoryProvider).registrarPonto(
        alunoId: Supabase.instance.client.auth.currentUser!.id,
        tipoRegistro: 'ENTRADA', // Aqui poderia ter lógica pra saber se é entrada ou saída
        location: location,
      );

      if (!mounted) return;

      if (!location.isAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Localização indisponível. Seu supervisor será notificado para confirmar sua presença.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ponto registrado com sucesso! (Aguardando processamento geográfico no servidor)'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao registrar ponto: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Frequência'),
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isLoading ? Icons.satellite_alt : Icons.location_on, 
              size: 80, 
              color: _isLoading ? const Color(0xFF005A9C) : Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text('Pronto para bater o ponto?'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2, semanticsLabel: 'Carregando...'))
                : const Icon(Icons.check_circle),
              label: Text(_isLoading ? 'Obtendo GPS e Registrando...' : 'Fazer Check-in (ENTRADA)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005A9C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              onPressed: _isLoading ? null : _fazerCheckIn,
            ),
          ],
        ),
      ),
    );
  }
}

