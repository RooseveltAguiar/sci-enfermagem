import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/campos_provider.dart';
import '../../../providers/transferencia_provider.dart';
import '../../widgets/confirmation_bottom_sheet.dart';

class AlunoTransferenciaItem {
  final String id;
  final String nome;
  final String campoAtual;
  final String turnoAtual;

  const AlunoTransferenciaItem({
    required this.id,
    required this.nome,
    required this.campoAtual,
    required this.turnoAtual,
  });

  factory AlunoTransferenciaItem.fromJson(Map<String, dynamic> json) {
    String campo = 'Não alocado';
    String turno = '-';

    if (json['alocacoes_alunos'] is List &&
        (json['alocacoes_alunos'] as List).isNotEmpty) {
      final aloc = (json['alocacoes_alunos'] as List).first;
      if (aloc['campos_estagio'] is Map) {
        campo = aloc['campos_estagio']['nome'] ?? 'Não alocado';
      }
      if (aloc['turnos'] is Map) {
        turno = aloc['turnos']['tipo'] ?? aloc['turnos']['descricao'] ?? '-';
      }
    }

    return AlunoTransferenciaItem(
      id: json['id'] as String,
      nome: json['nome'] as String? ?? 'Sem nome',
      campoAtual: campo,
      turnoAtual: turno,
    );
  }
}

class TurnoItem {
  final String id;
  final String tipo;
  final String horaInicio;
  final String horaFim;
  final bool ativo;

  const TurnoItem({
    required this.id,
    required this.tipo,
    required this.horaInicio,
    required this.horaFim,
    required this.ativo,
  });

  factory TurnoItem.fromJson(Map<String, dynamic> json) {
    return TurnoItem(
      id: json['id'] as String,
      tipo: json['tipo'] as String? ?? 'Turno',
      horaInicio: json['hora_inicio'] as String? ?? '',
      horaFim: json['hora_fim'] as String? ?? '',
      ativo: json['ativo'] as bool? ?? true,
    );
  }
}

final alunosParaTransferenciaProvider =
    FutureProvider.autoDispose<List<AlunoTransferenciaItem>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase
      .from('usuarios')
      .select(
          'id, nome, alocacoes_alunos(id, ativo, campos_estagio(nome), turnos(tipo))')
      .eq('perfil', 'aluno')
      .isFilter('deleted_at', null)
      .order('nome', ascending: true);

  return (res as List<dynamic>)
      .map((e) => AlunoTransferenciaItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

final turnosDoCampoProvider = FutureProvider.autoDispose
    .family<List<TurnoItem>, String>((ref, campoId) async {
  if (campoId.isEmpty) return [];
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase
      .from('turnos')
      .select()
      .eq('campo_id', campoId)
      .eq('ativo', true)
      .order('tipo', ascending: true);

  return (res as List<dynamic>)
      .map((e) => TurnoItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

class TransferenciaScreen extends ConsumerStatefulWidget {
  const TransferenciaScreen({super.key});

  @override
  ConsumerState<TransferenciaScreen> createState() =>
      _TransferenciaScreenState();
}

class _TransferenciaScreenState extends ConsumerState<TransferenciaScreen> {
  AlunoTransferenciaItem? _alunoSelecionado;
  CampoEstagio? _campoDestino;
  TurnoItem? _turnoDestino;
  bool _executando = false;

  Future<void> _confirmarTransferencia() async {
    if (_alunoSelecionado == null ||
        _campoDestino == null ||
        _turnoDestino == null) {
      return;
    }

    final aluno = _alunoSelecionado!;
    final campo = _campoDestino!;
    final turno = _turnoDestino!;

    await ConfirmationBottomSheet.show(
      context,
      title: 'Confirmar Transferência',
      message:
          '${aluno.nome}\nDe: ${aluno.campoAtual} — ${aluno.turnoAtual}\nPara: ${campo.nome} — ${turno.tipo}\n\nO histórico de frequência e atividades do campo anterior será preservado mas não transferido.',
      confirmText: 'Transferir',
      onConfirm: () async {
        Navigator.of(context).pop();
        setState(() => _executando = true);
        try {
          await ref
              .read(transferenciaControllerProvider.notifier)
              .transferirAluno(
                alunoId: aluno.id,
                campoDestinoId: campo.id,
                turnoDestinoId: turno.id,
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Aluno transferido com sucesso.'),
                backgroundColor: Colors.green,
              ),
            );
            setState(() {
              _alunoSelecionado = null;
              _campoDestino = null;
              _turnoDestino = null;
            });
            ref.invalidate(alunosParaTransferenciaProvider);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString().replaceAll('Exception: ', '')),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _executando = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final alunosAsync = ref.watch(alunosParaTransferenciaProvider);
    final camposAsync = ref.watch(camposProvider);
    final turnosAsync = ref.watch(
        turnosDoCampoProvider(_campoDestino?.id ?? ''));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transferência de Aluno'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '1. Selecione o Aluno',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            alunosAsync.when(
              loading: () => const Center(child: LinearProgressIndicator()),
              error: (err, _) => Text('Erro ao listar alunos: $err'),
              data: (alunos) {
                return DropdownButtonFormField<AlunoTransferenciaItem>(
                  key: const Key('dropdown_aluno'),
                  initialValue: _alunoSelecionado,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Aluno',
                  ),
                  items: alunos.map((aluno) {
                    return DropdownMenuItem(
                      value: aluno,
                      child: Text(
                        '${aluno.nome} — ${aluno.campoAtual} (${aluno.turnoAtual})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _alunoSelecionado = val;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              '2. Selecione o Campo de Estágio de Destino',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            camposAsync.when(
              loading: () => const Center(child: LinearProgressIndicator()),
              error: (err, _) => Text('Erro ao listar campos: $err'),
              data: (campos) {
                final ativos = campos.where((c) => c.ativo).toList();
                return DropdownButtonFormField<CampoEstagio>(
                  key: const Key('dropdown_campo_destino'),
                  initialValue: _campoDestino,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Campo de Destino',
                  ),
                  items: ativos.map((campo) {
                    return DropdownMenuItem(
                      value: campo,
                      child: Text(campo.nome),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _campoDestino = val;
                      _turnoDestino = null;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              '3. Selecione o Turno de Destino',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (_campoDestino == null)
              const Text(
                'Selecione um campo de destino primeiro para carregar os turnos.',
                style: TextStyle(color: Colors.grey),
              )
            else
              turnosAsync.when(
                loading: () => const Center(child: LinearProgressIndicator()),
                error: (err, _) => Text('Erro ao listar turnos: $err'),
                data: (turnos) {
                  if (turnos.isEmpty) {
                    return const Text(
                      'Nenhum turno ativo cadastrado neste campo.',
                      style: TextStyle(color: Colors.redAccent),
                    );
                  }
                  return DropdownButtonFormField<TurnoItem>(
                    key: const Key('dropdown_turno_destino'),
                    initialValue: _turnoDestino,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Turno de Destino',
                    ),
                    items: turnos.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(
                            '${t.tipo} (${t.horaInicio} - ${t.horaFim})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _turnoDestino = val;
                      });
                    },
                  );
                },
              ),
            const SizedBox(height: 36),
            ElevatedButton.icon(
              key: const Key('btn_transferir'),
              onPressed: (_alunoSelecionado != null &&
                      _campoDestino != null &&
                      _turnoDestino != null &&
                      !_executando)
                  ? _confirmarTransferencia
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _executando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: 'Carregando...'))
                  : const Icon(Icons.swap_horiz),
              label: const Text(
                'Transferir Aluno',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
