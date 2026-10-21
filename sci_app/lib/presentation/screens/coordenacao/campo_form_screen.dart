import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/campos_provider.dart';
import '../../widgets/confirmation_bottom_sheet.dart';

class HorarioDiaSemana {
  final String dia; // Segunda, Terça, Quarta, Quinta, Sexta, Sábado, Domingo
  final int diaNumero; // 1 = Segunda ... 7 = Domingo
  bool ativo;
  TimeOfDay horaInicio;
  TimeOfDay horaFim;

  HorarioDiaSemana({
    required this.dia,
    required this.diaNumero,
    this.ativo = false,
    this.horaInicio = const TimeOfDay(hour: 7, minute: 0),
    this.horaFim = const TimeOfDay(hour: 13, minute: 0),
  });
}

class TurnoModel {
  String? id;
  String tipo; // manha, tarde, noite, etc
  String nomeExibicao;
  List<HorarioDiaSemana> horarios;

  TurnoModel({
    this.id,
    required this.tipo,
    required this.nomeExibicao,
    required this.horarios,
  });

  factory TurnoModel.criarPadrao(String tipoTurno, {String? id}) {
    final nomeLabel = switch (tipoTurno.toLowerCase()) {
      'tarde' => 'Tarde (13:00 - 19:00)',
      'noite' => 'Noite (19:00 - 01:00)',
      _ => 'Manhã (07:00 - 13:00)',
    };

    return TurnoModel(
      id: id,
      tipo: tipoTurno.toLowerCase(),
      nomeExibicao: nomeLabel,
      horarios: [
        HorarioDiaSemana(dia: 'Segunda', diaNumero: 1, ativo: true, horaInicio: const TimeOfDay(hour: 7, minute: 0), horaFim: const TimeOfDay(hour: 13, minute: 0)),
        HorarioDiaSemana(dia: 'Terça', diaNumero: 2, ativo: true, horaInicio: const TimeOfDay(hour: 7, minute: 0), horaFim: const TimeOfDay(hour: 13, minute: 0)),
        HorarioDiaSemana(dia: 'Quarta', diaNumero: 3, ativo: true, horaInicio: const TimeOfDay(hour: 7, minute: 0), horaFim: const TimeOfDay(hour: 13, minute: 0)),
        HorarioDiaSemana(dia: 'Quinta', diaNumero: 4, ativo: true, horaInicio: const TimeOfDay(hour: 7, minute: 0), horaFim: const TimeOfDay(hour: 13, minute: 0)),
        HorarioDiaSemana(dia: 'Sexta', diaNumero: 5, ativo: true, horaInicio: const TimeOfDay(hour: 7, minute: 0), horaFim: const TimeOfDay(hour: 13, minute: 0)),
        HorarioDiaSemana(dia: 'Sábado', diaNumero: 6, ativo: false),
        HorarioDiaSemana(dia: 'Domingo', diaNumero: 7, ativo: false),
      ],
    );
  }
}

class CampoFormScreen extends ConsumerStatefulWidget {
  final String modo;
  final String? campoId;

  const CampoFormScreen({super.key, required this.modo, this.campoId});

  @override
  ConsumerState<CampoFormScreen> createState() => _CampoFormScreenState();
}

class _CampoFormScreenState extends ConsumerState<CampoFormScreen> {
  final _nomeController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  double _raioMetros = 150.0;
  bool _ativo = true;
  bool _isLoading = false;

  final List<TurnoModel> _turnos = [];

  @override
  void initState() {
    super.initState();
    if (widget.modo == 'editar' && widget.campoId != null) {
      _carregarDadosCampoReal();
    } else {
      _turnos.add(TurnoModel.criarPadrao('manha'));
    }
  }

  Future<void> _carregarDadosCampoReal() async {
    setState(() => _isLoading = true);
    final supabase = ref.read(supabaseClientProvider);

    try {
      final campoRes = await supabase
          .from('campos_estagio')
          .select('*')
          .eq('id', widget.campoId!)
          .maybeSingle();

      if (campoRes != null) {
        _nomeController.text = campoRes['nome']?.toString() ?? '';
        _enderecoController.text = campoRes['endereco']?.toString() ?? '';
        _latController.text = campoRes['latitude']?.toString() ?? campoRes['lat']?.toString() ?? '-3.7912';
        _lngController.text = campoRes['longitude']?.toString() ?? campoRes['lng']?.toString() ?? '-38.5534';
        _raioMetros = campoRes['raio_metros'] != null ? (campoRes['raio_metros'] as num).toDouble() : 150.0;
        _ativo = campoRes['ativo'] ?? true;
      }

      // Carrega turnos reais lendo a coluna 'tipo' (enum manha/tarde/noite)
      final turnosRes = await supabase
          .from('turnos')
          .select('*, turnos_horarios(*)')
          .eq('campo_id', widget.campoId!);

      if (turnosRes.isNotEmpty) {
        _turnos.clear();
        for (final tRow in turnosRes as List) {
          final tId = tRow['id']?.toString();
          final tTipo = tRow['tipo']?.toString() ?? tRow['nome']?.toString() ?? 'manha';

          final padrao = TurnoModel.criarPadrao(tTipo, id: tId);

          final horariosRes = tRow['turnos_horarios'] as List?;
          if (horariosRes != null && horariosRes.isNotEmpty) {
            for (final h in padrao.horarios) {
              h.ativo = false;
            }
            for (final hRow in horariosRes) {
              final diaNumRaw = (hRow['dia_semana'] as num?)?.toInt();
              final diaNum = diaNumRaw == 0 ? 7 : diaNumRaw;
              final inicioStr = hRow['hora_inicio']?.toString() ?? '07:00';
              final fimStr = hRow['hora_fim']?.toString() ?? '13:00';

              if (diaNum != null && diaNum >= 1 && diaNum <= 7) {
                final match = padrao.horarios.firstWhere((element) => element.diaNumero == diaNum);
                match.ativo = true;
                match.horaInicio = _parseTimeOfDay(inicioStr);
                match.horaFim = _parseTimeOfDay(fimStr);
              }
            }
          }
          _turnos.add(padrao);
        }
      } else {
        _turnos.add(TurnoModel.criarPadrao('manha'));
      }
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao carregar dados do campo: $e'), backgroundColor: Colors.red),
            );
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 7, minute: 0);
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _enderecoController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _selecionarHora(HorarioDiaSemana item, bool isInicio) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isInicio ? item.horaInicio : item.horaFim,
    );

    if (picked != null) {
      setState(() {
        if (isInicio) {
          item.horaInicio = picked;
        } else {
          item.horaFim = picked;
        }
      });
    }
  }

  void _adicionarNovoTurno() {
    String tipoNovo = 'tarde';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adicionar Turno ao Campo'),
          content: DropdownButtonFormField<String>(
            initialValue: tipoNovo,
            decoration: const InputDecoration(labelText: 'Selecione o Turno', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'manha', child: Text('Manhã (07:00 - 13:00)')),
              DropdownMenuItem(value: 'tarde', child: Text('Tarde (13:00 - 19:00)')),
              DropdownMenuItem(value: 'noite', child: Text('Noite (19:00 - 01:00)')),
            ],
            onChanged: (val) {
              if (val != null) setDialogState(() => tipoNovo = val);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _turnos.add(TurnoModel.criarPadrao(tipoNovo));
                });
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }

  void _salvar() {
    if (_nomeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do campo de estágio.'), backgroundColor: Colors.red),
      );
      return;
    }

    final temAoMenosUmTurnoComDiaAtivo = _turnos.any((t) => t.horarios.any((h) => h.ativo));
    if (!temAoMenosUmTurnoComDiaAtivo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um dia ativo da semana em ao menos um turno.'), backgroundColor: Colors.red),
      );
      return;
    }

    ConfirmationBottomSheet.show(
      context,
      title: 'Salvar Campo de Estágio?',
      message: 'Confirma as alterações e os horários configurados por dia da semana?',
      confirmText: 'Salvar',
      onConfirm: () async {
        final messenger = ScaffoldMessenger.of(context);

        try {
          final supabase = ref.read(supabaseClientProvider);
          final currentUserId =
              supabase.auth.currentUser?.id ?? 'a4000000-0000-0000-0000-000000000004';
          final latNum = double.tryParse(_latController.text.trim()) ?? -3.7912;
          final lngNum = double.tryParse(_lngController.text.trim()) ?? -38.5534;
          final enderecoFinal = _enderecoController.text.trim().isNotEmpty
              ? _enderecoController.text.trim()
              : 'Endereço não informado';

          String campoIdFinal = widget.campoId ?? '';

          // Salva campos_estagio incluindo created_by / updated_by obrigatórios
          if (widget.modo == 'editar' && widget.campoId != null) {
            await supabase.from('campos_estagio').update({
              'nome': _nomeController.text.trim(),
              'endereco': enderecoFinal,
              'latitude': latNum,
              'longitude': lngNum,
              'raio_metros': _raioMetros.round(),
              'ativo': _ativo,
              'updated_by': currentUserId,
            }).eq('id', widget.campoId!);
          } else {
            final insertRes = await supabase.from('campos_estagio').insert({
              'nome': _nomeController.text.trim(),
              'endereco': enderecoFinal,
              'latitude': latNum,
              'longitude': lngNum,
              'raio_metros': _raioMetros.round(),
              'ativo': _ativo,
              'created_by': currentUserId,
            }).select('id').single();
            campoIdFinal = insertRes['id'].toString();
          }

          // Persiste turnos e horários por dia da semana (0 = Domingo, 1..6 = Seg..Sáb)
          for (final t in _turnos) {
            final turnoPayload = <String, dynamic>{
              'campo_id': campoIdFinal,
              'tipo': t.tipo,
              'ativo': true,
              'created_by': currentUserId,
            };
            if (t.id != null && t.id!.isNotEmpty) {
              turnoPayload['id'] = t.id;
              turnoPayload['updated_by'] = currentUserId;
            }

            final tRes = await supabase.from('turnos').upsert(turnoPayload).select('id').single();
            final turnoIdSalvo = tRes['id'].toString();

            for (final h in t.horarios) {
              final diaSemanaDb = h.diaNumero % 7;
              final atravessaMeiaNoite =
                  (h.horaFim.hour * 60 + h.horaFim.minute) <= (h.horaInicio.hour * 60 + h.horaInicio.minute);

              if (h.ativo) {
                final existente = await supabase
                    .from('turnos_horarios')
                    .select('id')
                    .eq('turno_id', turnoIdSalvo)
                    .eq('dia_semana', diaSemanaDb)
                    .isFilter('deleted_at', null)
                    .maybeSingle();

                if (existente != null) {
                  await supabase.from('turnos_horarios').update({
                    'hora_inicio': _formatTimeOfDay(h.horaInicio),
                    'hora_fim': _formatTimeOfDay(h.horaFim),
                    'atravessa_meia_noite': atravessaMeiaNoite,
                    'updated_by': currentUserId,
                  }).eq('id', existente['id']);
                } else {
                  await supabase.from('turnos_horarios').insert({
                    'turno_id': turnoIdSalvo,
                    'dia_semana': diaSemanaDb,
                    'hora_inicio': _formatTimeOfDay(h.horaInicio),
                    'hora_fim': _formatTimeOfDay(h.horaFim),
                    'atravessa_meia_noite': atravessaMeiaNoite,
                    'created_by': currentUserId,
                  });
                }
              }
            }
          }

          await ref.read(camposProvider.notifier).loadCampos();

          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(content: Text('Campo de estágio salvo com sucesso!'), backgroundColor: Color(0xFF1B6B45)),
            );
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/coordenacao/campos');
            }
          }
        } catch (e) {
          // EXIBE O ERRO REAL EM VERMELHO E NAO RETORNA SUCESSO FALSO
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text('Erro ao salvar campo de estágio: $e'), backgroundColor: Colors.red),
            );
          }
        }
      },
    );
  }

  void _desativar() {
    ConfirmationBottomSheet.show(
      context,
      title: 'Desativar Campo?',
      message: 'Atenção: Isso afetará todos os alunos alocados. Deseja continuar?',
      confirmText: 'Desativar',
      onConfirm: () async {
        final messenger = ScaffoldMessenger.of(context);

        try {
          if (widget.campoId != null) {
            final supabase = ref.read(supabaseClientProvider);
            final currentUserId =
                supabase.auth.currentUser?.id ?? 'a4000000-0000-0000-0000-000000000004';
            await supabase.from('campos_estagio').update({
              'ativo': false,
              'updated_by': currentUserId,
            }).eq('id', widget.campoId!);
            await ref.read(camposProvider.notifier).loadCampos();
          }
          if (mounted) {
            messenger.showSnackBar(const SnackBar(content: Text('Campo desativado com sucesso.')));
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/coordenacao/campos');
            }
          }
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(SnackBar(content: Text('Erro ao desativar campo: $e'), backgroundColor: Colors.red));
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.modo == 'criar' ? 'Novo Campo' : 'Editar Campo')),
        body: const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando dados do campo...')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.modo == 'criar' ? 'Novo Campo' : 'Editar Campo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(labelText: 'Nome do Campo *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _enderecoController,
              decoration: const InputDecoration(labelText: 'Endereço', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),

            const Text('Localização Geográfica (GPS)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Text('Raio de Aceitação: ${_raioMetros.toInt()}m', style: const TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _raioMetros,
              min: 50,
              max: 500,
              divisions: 9,
              label: '${_raioMetros.toInt()}m',
              onChanged: (val) => setState(() => _raioMetros = val),
            ),

            SwitchListTile(
              title: const Text('Campo Ativo'),
              value: _ativo,
              onChanged: (val) => setState(() => _ativo = val),
            ),

            const Divider(height: 48),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Turnos e Horários por Dia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('Gerencie turnos e dias ativos (Sprint 12)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                IconButton.filledTonal(
                  onPressed: _adicionarNovoTurno,
                  icon: const Icon(Icons.add),
                  tooltip: 'Adicionar Turno',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Múltiplos turnos com ExpansionTile e formulário por dia da semana
            ..._turnos.map((turno) {
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: Text(turno.nomeExibicao, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B6B45))),
                  subtitle: Text(
                    '${turno.horarios.where((h) => h.ativo).length} dias ativos',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      if (_turnos.length <= 1) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O campo precisa ter pelo menos um turno.')));
                        return;
                      }
                      setState(() => _turnos.remove(turno));
                    },
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: turno.horarios.map((item) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: item.ativo ? Colors.green.shade50 : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: item.ativo ? Colors.green.shade200 : Colors.grey.shade300),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.dia,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: item.ativo ? const Color(0xFF1B6B45) : Colors.grey,
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value: item.ativo,
                                      activeThumbColor: const Color(0xFF1B6B45),
                                      onChanged: (val) => setState(() => item.ativo = val),
                                    ),
                                  ],
                                ),
                                if (item.ativo) ...[
                                  const Divider(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _selecionarHora(item, true),
                                        icon: const Icon(Icons.access_time, size: 18),
                                        label: Text('Início: ${_formatTimeOfDay(item.horaInicio)}'),
                                      ),
                                      const Text('até', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      TextButton.icon(
                                        onPressed: () => _selecionarHora(item, false),
                                        icon: const Icon(Icons.access_time_filled, size: 18),
                                        label: Text('Fim: ${_formatTimeOfDay(item.horaFim)}'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 32),

            FilledButton(
              onPressed: _salvar,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B6B45), padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('SALVAR CAMPO E HORÁRIOS'),
            ),
            if (widget.modo == 'editar') ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _desativar,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('DESATIVAR CAMPO'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
