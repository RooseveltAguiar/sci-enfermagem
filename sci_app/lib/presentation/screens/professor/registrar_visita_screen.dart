import 'dart:async';
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
  Timer? _relogioTimer;
  DateTime _agora = DateTime.now();

  final _relatoController = TextEditingController();
  int _relatoCharCount = 0;
  bool _isSubmitting = false;

  CampoProfessor? _selectedCampo;
  String _selectedTurno = 'Manhã';

  // GPS Check-in (Início)
  bool _isGettingLocationInicio = false;
  bool _locationObtainedInicio = false;
  double? _latInicio;
  double? _lngInicio;
  double? _precisaoGpsInicio;
  double? _distanciaMetrosInicio;
  bool _dentroDoRaioInicio = false;
  String? _erroLocalizacaoInicio;

  // GPS Check-out (Término)
  bool _isGettingLocationTermino = false;
  bool _locationObtainedTermino = false;
  double? _latTermino;
  double? _lngTermino;
  double? _precisaoGpsTermino;
  double? _distanciaMetrosTermino;
  bool _dentroDoRaioTermino = false;
  String? _erroLocalizacaoTermino;

  @override
  void initState() {
    super.initState();
    _relogioTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _agora = DateTime.now();
        });
      }
    });

    _relatoController.addListener(() {
      setState(() => _relatoCharCount = _relatoController.text.length);
    });
  }

  @override
  void dispose() {
    _relogioTimer?.cancel();
    _relatoController.dispose();
    super.dispose();
  }

  String _formatarDistancia(double? metros) {
    if (metros == null) return '0 m';
    if (metros >= 1000) {
      return '${(metros / 1000).toStringAsFixed(2)} km (${metros.toStringAsFixed(0)} metros)';
    }
    return '${metros.toStringAsFixed(0)} metros';
  }

  String _formatarHora(DateTime? dt) {
    if (dt == null) return '--:--:--';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatarData(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }

  String _calcularTempoPermanencia(VisitaEmAndamento? visita) {
    if (visita == null) {
      return '0h 00min 00s';
    }
    final diff = _agora.difference(visita.horaInicio);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${h}h ${m}min ${s}s';
  }

  Future<void> _obterLocalizacaoInicio(CampoProfessor? campo) async {
    if (campo == null) {
      setState(() {
        _erroLocalizacaoInicio = 'Selecione um campo de estágio para validar o início da visita.';
      });
      return;
    }

    setState(() {
      _isGettingLocationInicio = true;
      _locationObtainedInicio = false;
      _erroLocalizacaoInicio = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _isGettingLocationInicio = false;
          _dentroDoRaioInicio = false;
          _erroLocalizacaoInicio = 'O serviço de GPS está desativado. Ative a localização no seu dispositivo ou navegador.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _isGettingLocationInicio = false;
            _dentroDoRaioInicio = false;
            _erroLocalizacaoInicio = 'Permissão de GPS negada. É obrigatório autorizar a localização para validar a visita no campo.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isGettingLocationInicio = false;
          _dentroDoRaioInicio = false;
          _erroLocalizacaoInicio = 'Permissão de GPS bloqueada permanentemente. Por favor, libere nas configurações do dispositivo/navegador.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final dist = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        campo.lat,
        campo.lng,
      );

      final dentro = dist <= campo.raioMetros;

      if (!mounted) return;
      setState(() {
        _isGettingLocationInicio = false;
        _locationObtainedInicio = true;
        _latInicio = position.latitude;
        _lngInicio = position.longitude;
        _precisaoGpsInicio = position.accuracy;
        _distanciaMetrosInicio = dist;
        _dentroDoRaioInicio = dentro;
        _erroLocalizacaoInicio = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGettingLocationInicio = false;
        _dentroDoRaioInicio = false;
        _erroLocalizacaoInicio = 'Erro ao capturar GPS: $e';
      });
    }
  }

  Future<void> _obterLocalizacaoTermino(CampoProfessor? campo) async {
    if (campo == null) {
      setState(() {
        _erroLocalizacaoTermino = 'Campo de estágio não identificado para validar o término.';
      });
      return;
    }

    setState(() {
      _isGettingLocationTermino = true;
      _locationObtainedTermino = false;
      _erroLocalizacaoTermino = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _isGettingLocationTermino = false;
          _dentroDoRaioTermino = false;
          _erroLocalizacaoTermino = 'O serviço de GPS está desativado. Ative a localização no seu dispositivo ou navegador.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _isGettingLocationTermino = false;
            _dentroDoRaioTermino = false;
            _erroLocalizacaoTermino = 'Permissão de GPS negada. É obrigatório autorizar a localização para validar a saída no campo.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isGettingLocationTermino = false;
          _dentroDoRaioTermino = false;
          _erroLocalizacaoTermino = 'Permissão de GPS bloqueada permanentemente. Por favor, libere nas configurações do dispositivo/navegador.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final dist = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        campo.lat,
        campo.lng,
      );

      final dentro = dist <= campo.raioMetros;

      if (!mounted) return;
      setState(() {
        _isGettingLocationTermino = false;
        _locationObtainedTermino = true;
        _latTermino = position.latitude;
        _lngTermino = position.longitude;
        _precisaoGpsTermino = position.accuracy;
        _distanciaMetrosTermino = dist;
        _dentroDoRaioTermino = dentro;
        _erroLocalizacaoTermino = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGettingLocationTermino = false;
        _dentroDoRaioTermino = false;
        _erroLocalizacaoTermino = 'Erro ao capturar GPS: $e';
      });
    }
  }

  void _confirmarInicioVisita(CampoProfessor campo) {
    if (!_dentroDoRaioInicio || _latInicio == null || _lngInicio == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.wrong_location_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text('Início Bloqueado'),
            ],
          ),
          content: Text(
            'Você está fora do perímetro do campo de estágio (${_formatarDistancia(_distanciaMetrosInicio)} de distância).\n\n'
            'Para liberar o início da visita técnica, você deve estar fisicamente presente no local do estágio.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    final horaAtualStr = _formatarHora(_agora);
    ConfirmationBottomSheet.show(
      context,
      title: 'Iniciar Visita Técnica?',
      message: 'Campo: ${campo.nome}\nTurno: $_selectedTurno\nHorário de Início: $horaAtualStr',
      confirmText: 'CONFIRMAR INÍCIO',
      onConfirm: () {
        ref.read(visitaEmAndamentoProvider.notifier).state = VisitaEmAndamento(
          campoId: campo.id,
          campoNome: campo.nome,
          turno: _selectedTurno,
          horaInicio: DateTime.now(),
          latInicio: _latInicio!,
          lngInicio: _lngInicio!,
          distanciaInicioMetros: _distanciaMetrosInicio ?? 0.0,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Visita técnica iniciada às $horaAtualStr! Cronômetro em andamento.'),
            backgroundColor: const Color(0xFF1B6B45),
          ),
        );
      },
    );
  }

  void _confirmarTerminoVisita(VisitaEmAndamento visita, CampoProfessor campo) {
    final relato = _relatoController.text.trim();
    if (relato.length < 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O relato da visita técnica deve conter no mínimo 30 caracteres.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_dentroDoRaioTermino || _latTermino == null || _lngTermino == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.wrong_location_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text('Término Bloqueado'),
            ],
          ),
          content: Text(
            'Você está fora do perímetro do campo de estágio (${_formatarDistancia(_distanciaMetrosTermino)} de distância).\n\n'
            'Para registrar o encerramento da visita técnica, você deve estar presencialmente no campo de estágio.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    final horaSaidaStr = _formatarHora(_agora);
    final horaEntradaStr = _formatarHora(visita.horaInicio);
    final duracao = _agora.difference(visita.horaInicio);
    final duracaoStr = '${duracao.inHours}h ${duracao.inMinutes.remainder(60).toString().padLeft(2, '0')}min';

    ConfirmationBottomSheet.show(
      context,
      title: 'Finalizar Visita Técnica?',
      message: 'Campo: ${visita.campoNome}\n'
          'Início: $horaEntradaStr | Término: $horaSaidaStr\n'
          'Permanência: $duracaoStr\n'
          'Confirma o envio do relato e a validação eletrônica da visita?',
      confirmText: 'CONFIRMAR E ENVIAR',
      onConfirm: () async {
        setState(() => _isSubmitting = true);
        try {
          await ref.read(visitasServiceProvider).registrarVisita(
            campoId: visita.campoId,
            relato: relato,
            lat: _latInicio ?? _latTermino,
            lng: _lngInicio ?? _lngTermino,
            gpsDisponivel: true,
            distanciaMetros: _distanciaMetrosInicio,
            horaInicio: visita.horaInicio,
            horaFim: DateTime.now(),
            turno: visita.turno,
            latSaida: _latTermino,
            lngSaida: _lngTermino,
            distanciaSaidaMetros: _distanciaMetrosTermino,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Visita técnica registrada e enviada com sucesso!'),
                backgroundColor: Color(0xFF1B6B45),
              ),
            );
            context.pop();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao registrar visita: $e'), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) setState(() => _isSubmitting = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final camposAsync = ref.watch(camposDoProfessorProvider);
    final visitaEmAndamento = ref.watch(visitaEmAndamentoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Visita Técnica'),
      ),
      body: camposAsync.when(
        data: (campos) {
          if (_selectedCampo == null && campos.isNotEmpty) {
            if (visitaEmAndamento != null) {
              try {
                _selectedCampo = campos.firstWhere((c) => c.id == visitaEmAndamento.campoId);
              } catch (_) {
                _selectedCampo = campos.first;
              }
            } else {
              _selectedCampo = campos.first;
            }
          }

          final campoAtivo = _selectedCampo ?? (campos.isNotEmpty ? campos.first : null);
          final emAndamento = visitaEmAndamento != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Card de Dados / Seleção do Estágio
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_city_rounded, color: Color(0xFF1B6B45), size: 22),
                            const SizedBox(width: 8),
                            const Text(
                              'Campo e Turno da Visita',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const Spacer(),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(_formatarData(_agora)),
                              backgroundColor: const Color(0xFF1B6B45).withValues(alpha: 0.1),
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B6B45), fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (!emAndamento) ...[
                          if (campos.isEmpty)
                            const Text(
                              'Nenhum campo de estágio disponível no momento.',
                              style: TextStyle(color: Colors.red),
                            )
                          else ...[
                            DropdownButtonFormField<CampoProfessor>(
                              decoration: const InputDecoration(
                                labelText: 'Campo de Estágio *',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              initialValue: _selectedCampo ?? (campos.isNotEmpty ? campos.first : null),
                              items: campos.map((c) => DropdownMenuItem(value: c, child: Text(c.nome, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedCampo = val;
                                  _locationObtainedInicio = false;
                                  _dentroDoRaioInicio = false;
                                  _erroLocalizacaoInicio = null;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Turno da Visita *',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              initialValue: _selectedTurno,
                              items: ['Manhã', 'Tarde', 'Noite'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedTurno = val);
                              },
                            ),
                          ],
                        ] else ...[
                          Text(
                            visitaEmAndamento.campoNome,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Turno: ${visitaEmAndamento.turno}',
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Card de Tempo de Permanência da Visita no Campo
                Card(
                  elevation: 0,
                  color: emAndamento
                      ? const Color(0xFF1B6B45).withValues(alpha: 0.08)
                      : Colors.grey.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: emAndamento
                          ? const Color(0xFF1B6B45).withValues(alpha: 0.3)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              emAndamento ? Icons.timer_outlined : Icons.hourglass_empty_rounded,
                              color: emAndamento ? const Color(0xFF1B6B45) : Colors.grey.shade600,
                              size: 26,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              emAndamento
                                  ? 'Tempo no Campo (Visita em Andamento)'
                                  : 'Tempo de Permanência da Visita',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: emAndamento ? const Color(0xFF1B6B45) : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _calcularTempoPermanencia(visitaEmAndamento),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: emAndamento ? const Color(0xFF1B6B45) : Colors.black87,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (emAndamento) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Cronômetro ativo desde a confirmação do início da visita técnica',
                            style: TextStyle(fontSize: 12, color: Color(0xFF1B6B45)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Card 1: Início da Visita Técnica (Check-in)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: emAndamento ? Colors.green.shade400 : const Color(0xFF1B6B45).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (emAndamento ? Colors.green : const Color(0xFF1B6B45)).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                emAndamento ? Icons.check_circle_rounded : Icons.login_rounded,
                                color: emAndamento ? Colors.green.shade700 : const Color(0xFF1B6B45),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                '1. Início da Visita (Check-in)',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(emAndamento ? 'Iniciado' : 'Pendente'),
                              backgroundColor: emAndamento ? Colors.green.shade50 : Colors.orange.shade50,
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: emAndamento ? Colors.green.shade800 : Colors.orange.shade800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // Horário de Início
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: emAndamento ? Colors.green.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: emAndamento ? Colors.green.shade200 : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    emAndamento ? 'Horário de Início Registrado:' : 'Horário de Início (no momento):',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: emAndamento ? Colors.green.shade900 : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    emAndamento
                                        ? _formatarHora(visitaEmAndamento.horaInicio)
                                        : _formatarHora(_agora),
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: emAndamento ? Colors.green.shade800 : const Color(0xFF1B6B45),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                Icons.access_time_rounded,
                                color: emAndamento ? Colors.green.shade700 : const Color(0xFF1B6B45),
                                size: 32,
                              ),
                            ],
                          ),
                        ),

                        if (!emAndamento) ...[
                          const SizedBox(height: 16),
                          _buildGpsBoxInicio(campoAtivo),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: (_locationObtainedInicio && _dentroDoRaioInicio && campoAtivo != null)
                                ? () => _confirmarInicioVisita(campoAtivo)
                                : null,
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('CONFIRMAR INÍCIO DA VISITA'),
                          ),
                        ] else ...[
                          const SizedBox(height: 10),
                          const Row(
                            children: [
                              Icon(Icons.verified_rounded, color: Colors.green, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Início validado presencialmente no campo de estágio',
                                style: TextStyle(fontSize: 12, color: Colors.green),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 4. Card 2: Término da Visita (Check-out) + Relatório
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: emAndamento ? Colors.orange.shade400 : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (emAndamento ? Colors.orange : Colors.grey).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                emAndamento ? Icons.logout_rounded : Icons.lock_outline_rounded,
                                color: emAndamento ? Colors.orange.shade800 : Colors.grey.shade600,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                '2. Término da Visita (Check-out)',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(emAndamento ? 'Aguardando Término' : 'Bloqueado'),
                              backgroundColor: emAndamento ? Colors.orange.shade50 : Colors.grey.shade100,
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: emAndamento ? Colors.orange.shade900 : Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        if (!emAndamento) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: Colors.grey, size: 24),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'O encerramento da visita e o preenchimento do relatório serão liberados após confirmar o início acima.',
                                    style: TextStyle(color: Colors.black54, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Horário de Saída no momento
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Horário de Término (no momento):',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatarHora(_agora),
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade900,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(Icons.alarm_on_rounded, color: Colors.orange.shade800, size: 32),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                          const Text(
                            'Validação de GPS no Campo:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          _buildGpsBoxTermino(campoAtivo),

                          const SizedBox(height: 20),
                          const Text(
                            'Relatório da Visita Técnica *',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
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
                              hintText: 'Descreva detalhadamente o que observou, alunos acompanhados e orientações prestadas...',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                          ),

                          const SizedBox(height: 20),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.orange.shade800,
                            ),
                            onPressed: (_isSubmitting ||
                                    !_locationObtainedTermino ||
                                    !_dentroDoRaioTermino ||
                                    _relatoCharCount < 30 ||
                                    campoAtivo == null)
                                ? null
                                : () => _confirmarTerminoVisita(visitaEmAndamento, campoAtivo),
                            icon: _isSubmitting
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.send_rounded),
                            label: const Text('CONFIRMAR TÉRMINO E ENVIAR VISITA'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando campos do professor...')),
        error: (err, _) => Center(child: Text('Erro ao carregar campos: $err')),
      ),
    );
  }

  Widget _buildGpsBoxInicio(CampoProfessor? campo) {
    if (_isGettingLocationInicio) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            CircularProgressIndicator(semanticsLabel: 'Carregando GPS...'),
            SizedBox(height: 12),
            Text('Capturando GPS e validando presença no campo...', style: TextStyle(fontSize: 13, color: Colors.black87)),
          ],
        ),
      );
    }

    if (_erroLocalizacaoInicio != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          children: [
            const Icon(Icons.location_off, color: Colors.red, size: 44),
            const SizedBox(height: 8),
            const Text(
              'Falha ao obter localização',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(_erroLocalizacaoInicio!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _obterLocalizacaoInicio(campo),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
            ),
          ],
        ),
      );
    }

    if (_locationObtainedInicio && _dentroDoRaioInicio) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
            const SizedBox(height: 8),
            const Text(
              'Localização validada com sucesso!',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            const Text(
              'Você está no local do estágio. Início da visita liberado!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            if (_latInicio != null && _lngInicio != null) ...[
              const SizedBox(height: 4),
              Text(
                'GPS: ${_latInicio!.toStringAsFixed(5)}, ${_lngInicio!.toStringAsFixed(5)} (±${_precisaoGpsInicio?.toStringAsFixed(0) ?? 0}m)',
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _obterLocalizacaoInicio(campo),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Atualizar GPS'),
            ),
          ],
        ),
      );
    }

    if (_locationObtainedInicio && !_dentroDoRaioInicio) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Column(
          children: [
            const Icon(Icons.wrong_location_rounded, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            const Text(
              'Visita NÃO liberada: Fora do local de estágio',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Sua distância aproximada: ${_formatarDistancia(_distanciaMetrosInicio)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Para iniciar a visita técnica, você deve estar fisicamente presente no campo de estágio.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => _obterLocalizacaoInicio(campo),
              icon: const Icon(Icons.my_location),
              label: const Text('Atualizar Minha Localização'),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: () => _obterLocalizacaoInicio(campo),
      icon: const Icon(Icons.my_location),
      label: const Text('Validar Localização via GPS'),
    );
  }

  Widget _buildGpsBoxTermino(CampoProfessor? campo) {
    if (_isGettingLocationTermino) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            CircularProgressIndicator(semanticsLabel: 'Carregando GPS...'),
            SizedBox(height: 12),
            Text('Capturando GPS e validando saída no campo...', style: TextStyle(fontSize: 13, color: Colors.black87)),
          ],
        ),
      );
    }

    if (_erroLocalizacaoTermino != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          children: [
            const Icon(Icons.location_off, color: Colors.red, size: 44),
            const SizedBox(height: 8),
            const Text(
              'Falha ao obter localização de término',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(_erroLocalizacaoTermino!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _obterLocalizacaoTermino(campo),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
            ),
          ],
        ),
      );
    }

    if (_locationObtainedTermino && _dentroDoRaioTermino) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
            const SizedBox(height: 8),
            const Text(
              'Localização de término validada!',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            const Text(
              'Você está no local do estágio. Término liberado!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            if (_latTermino != null && _lngTermino != null) ...[
              const SizedBox(height: 4),
              Text(
                'GPS: ${_latTermino!.toStringAsFixed(5)}, ${_lngTermino!.toStringAsFixed(5)} (±${_precisaoGpsTermino?.toStringAsFixed(0) ?? 0}m)',
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _obterLocalizacaoTermino(campo),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Atualizar GPS'),
            ),
          ],
        ),
      );
    }

    if (_locationObtainedTermino && !_dentroDoRaioTermino) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Column(
          children: [
            const Icon(Icons.wrong_location_rounded, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            const Text(
              'Término NÃO liberado: Fora do local de estágio',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Sua distância aproximada: ${_formatarDistancia(_distanciaMetrosTermino)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Para encerrar a visita técnica, você deve estar fisicamente presente no campo de estágio.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => _obterLocalizacaoTermino(campo),
              icon: const Icon(Icons.my_location),
              label: const Text('Atualizar Minha Localização'),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: () => _obterLocalizacaoTermino(campo),
      icon: const Icon(Icons.my_location),
      label: const Text('Validar Localização de Término via GPS'),
    );
  }
}
