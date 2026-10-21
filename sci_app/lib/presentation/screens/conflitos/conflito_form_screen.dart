import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../providers/campos_provider.dart';
import '../../../providers/conflitos_provider.dart';
import '../../widgets/confirmation_bottom_sheet.dart';
import '../transferencia/transferencia_screen.dart';

class ConflitoFormScreen extends ConsumerStatefulWidget {
  const ConflitoFormScreen({super.key});

  @override
  ConsumerState<ConflitoFormScreen> createState() => _ConflitoFormScreenState();
}

class _ConflitoFormScreenState extends ConsumerState<ConflitoFormScreen> {
  final _controller = TextEditingController();
  AlunoTransferenciaItem? _alunoSelecionado;
  CampoEstagio? _campoSelecionado;
  DateTime _dataOcorrencia = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {}); // Re-render para atualizar botão de registro
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _podeRegistrar =>
      _controller.text.trim().length >= 30 &&
      _alunoSelecionado != null &&
      _campoSelecionado != null &&
      !_saving;

  Future<void> _registrar() async {
    if (!_podeRegistrar) return;

    final aluno = _alunoSelecionado!;
    final campo = _campoSelecionado!;
    final descricao = _controller.text.trim();

    await ConfirmationBottomSheet.show(
      context,
      title: 'Registrar Ocorrência',
      message:
          'Registrar ocorrência para ${aluno.nome}?\n\nEste registro não poderá ser editado após o envio.',
      confirmText: 'Registrar',
      onConfirm: () async {
        setState(() => _saving = true);
        try {
          await ref.read(conflitosControllerProvider.notifier).registrarConflito(
                alunoId: aluno.id,
                campoId: campo.id,
                descricao: descricao,
                dataOcorrencia: _dataOcorrencia,
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ocorrência registrada com sucesso.')),
            );
            context.pop();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao registrar ocorrência: $e')),
            );
            setState(() => _saving = false);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final alunosAsync = ref.watch(alunosParaTransferenciaProvider);
    final camposAsync = ref.watch(camposProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Ocorrência / Conflito'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Os registros de ocorrências são imutáveis (append-only) e não poderão ser alterados ou excluídos após o envio.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            alunosAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Erro ao carregar alunos: $err'),
              data: (alunos) {
                return DropdownButtonFormField<AlunoTransferenciaItem>(
                  key: const Key('dropdown_aluno_conflito'),
                  initialValue: _alunoSelecionado,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Aluno Envolvido *',
                    border: OutlineInputBorder(),
                  ),
                  items: alunos.map((a) {
                    return DropdownMenuItem(
                      value: a,
                      child: Text('${a.nome} (${a.campoAtual})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _alunoSelecionado = val);
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            camposAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Erro ao carregar campos: $err'),
              data: (campos) {
                return DropdownButtonFormField<CampoEstagio>(
                  key: const Key('dropdown_campo_conflito'),
                  initialValue: _campoSelecionado,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Campo de Estágio *',
                    border: OutlineInputBorder(),
                  ),
                  items: campos.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(c.nome),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _campoSelecionado = val);
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dataOcorrencia,
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _dataOcorrencia = picked);
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(
                'Data da Ocorrência: ${DateFormat('dd/MM/yyyy').format(_dataOcorrencia)}',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('field_descricao_conflito'),
              controller: _controller,
              maxLength: 2000,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Descrição Detalhada * (mínimo 30 caracteres)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              key: const Key('btn_registrar_conflito'),
              onPressed: _podeRegistrar ? _registrar : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: 'Carregando...'))
                  : const Icon(Icons.app_registration),
              label: const Text(
                'Registrar Ocorrência',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
