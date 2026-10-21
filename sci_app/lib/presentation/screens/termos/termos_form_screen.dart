import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/models/termo_model.dart';
import '../../../providers/termos_provider.dart';
import '../../widgets/confirmation_bottom_sheet.dart';

class TermosFormScreen extends ConsumerStatefulWidget {
  final TermoModel? termo;

  const TermosFormScreen({super.key, this.termo});

  @override
  ConsumerState<TermosFormScreen> createState() => _TermosFormScreenState();
}

class _TermosFormScreenState extends ConsumerState<TermosFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _tituloController;
  late final TextEditingController _versaoController;
  late final TextEditingController _conteudoController;

  DateTime _vigenciaInicio = DateTime.now();
  bool _ativar = true;
  bool _saving = false;

  bool get isEdicao => widget.termo != null;

  @override
  void initState() {
    super.initState();
    final t = widget.termo;
    _tituloController =
        TextEditingController(text: t?.titulo ?? 'Termos de Uso do Internato');
    _versaoController = TextEditingController(text: t?.versao ?? '2025.1');
    _conteudoController = TextEditingController(text: t?.conteudo ?? '');
    if (t?.vigenciaInicio != null) {
      _vigenciaInicio = t!.vigenciaInicio!;
    }
    _ativar = t?.ativo ?? true;
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _versaoController.dispose();
    _conteudoController.dispose();
    super.dispose();
  }

  Future<void> _executarSalvar() async {
    setState(() => _saving = true);
    try {
      await ref.read(termosListaProvider.notifier).criarTermo(
            titulo: _tituloController.text.trim(),
            versao: _versaoController.text.trim(),
            conteudo: _conteudoController.text.trim(),
            vigenciaInicio: _vigenciaInicio,
            ativar: _ativar,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Versão de termos salva com sucesso.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar termos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_ativar && (widget.termo == null || !widget.termo!.ativo)) {
      await ConfirmationBottomSheet.show(
        context,
        title: 'Ativar Nova Versão',
        message:
            'Ativar versão ${_versaoController.text}? A versão atualmente ativa será desativada automaticamente e todos os alunos deverão aceitar os novos termos.',
        confirmText: 'Ativar e Salvar',
        onConfirm: () async {
          await _executarSalvar();
        },
      );
    } else {
      await _executarSalvar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdicao ? 'Detalhes do Termo' : 'Nova Versão de Termos'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título do Termo *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Informe o título do termo'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _versaoController,
                decoration: const InputDecoration(
                  labelText: 'Versão * (ex: 2025.1)',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Informe a versão'
                    : null,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _vigenciaInicio,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setState(() => _vigenciaInicio = picked);
                  }
                },
                icon: const Icon(Icons.date_range),
                label: Text(
                  'Vigência a partir de: ${DateFormat('dd/MM/yyyy').format(_vigenciaInicio)}',
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Ativar esta versão'),
                subtitle: const Text(
                    'Desativará qualquer outra versão ativa no sistema.'),
                value: _ativar,
                onChanged: (val) => setState(() => _ativar = val),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _conteudoController,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'Conteúdo do Termo *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Informe o conteúdo dos termos'
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: 'Carregando...'))
                    : const Text('Salvar Termo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
