import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/models/legislacao_model.dart';
import '../../../providers/legislacao_provider.dart';
import '../../widgets/confirmation_bottom_sheet.dart';

class LegislacaoFormScreen extends ConsumerStatefulWidget {
  final LegislacaoModel? doc;

  const LegislacaoFormScreen({
    super.key,
    this.doc,
  });

  @override
  ConsumerState<LegislacaoFormScreen> createState() =>
      _LegislacaoFormScreenState();
}

class _LegislacaoFormScreenState extends ConsumerState<LegislacaoFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _tituloController;
  late final TextEditingController _tipoController;
  late final TextEditingController _conteudoController;

  DateTime? _vigenciaInicio;
  DateTime? _vigenciaFim;
  bool _ativo = true;
  bool _saving = false;

  bool get isEdicao => widget.doc != null;

  @override
  void initState() {
    super.initState();
    final doc = widget.doc;
    _tituloController = TextEditingController(text: doc?.titulo ?? '');
    _tipoController = TextEditingController(text: doc?.tipo ?? 'Portaria');
    _conteudoController = TextEditingController(text: doc?.conteudo ?? '');
    _vigenciaInicio = doc?.vigenciaInicio;
    _vigenciaFim = doc?.vigenciaFim;
    _ativo = doc?.ativo ?? true;
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _tipoController.dispose();
    _conteudoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarDataInicio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _vigenciaInicio ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _vigenciaInicio = picked;
        if (_vigenciaFim != null && _vigenciaFim!.isBefore(_vigenciaInicio!)) {
          _vigenciaFim = null;
        }
      });
    }
  }

  Future<void> _selecionarDataFim() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _vigenciaFim ??
          (_vigenciaInicio ?? DateTime.now()).add(const Duration(days: 1)),
      firstDate: _vigenciaInicio ?? DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _vigenciaFim = picked;
      });
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vigenciaInicio != null &&
        _vigenciaFim != null &&
        _vigenciaFim!.isBefore(_vigenciaInicio!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'A vigência final não pode ser anterior à vigência inicial.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (isEdicao) {
        await ref.read(legislacoesProvider.notifier).editarLegislacao(
              id: widget.doc!.id,
              titulo: _tituloController.text.trim(),
              conteudo: _conteudoController.text.trim(),
              tipo: _tipoController.text.trim(),
              vigenciaInicio: _vigenciaInicio,
              vigenciaFim: _vigenciaFim,
              ativo: _ativo,
            );
      } else {
        await ref.read(legislacoesProvider.notifier).criarLegislacao(
              titulo: _tituloController.text.trim(),
              conteudo: _conteudoController.text.trim(),
              tipo: _tipoController.text.trim(),
              vigenciaInicio: _vigenciaInicio,
              vigenciaFim: _vigenciaFim,
              ativo: _ativo,
            );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEdicao
                  ? 'Legislação atualizada.'
                  : 'Legislação cadastrada.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _desativar() async {
    await ConfirmationBottomSheet.show(
      context,
      title: 'Desativar Documento',
      message:
          'Desativar este documento? Ele não aparecerá mais para os usuários.',
      confirmText: 'Desativar',
      isDestructive: true,
      onConfirm: () async {
        Navigator.of(context).pop();
        setState(() => _saving = true);
        try {
          await ref
              .read(legislacoesProvider.notifier)
              .desativarLegislacao(widget.doc!.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Documento desativado.')),
            );
            context.go('/legislacao');
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao desativar: $e')),
            );
            setState(() => _saving = false);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdicao ? 'Editar Legislação' : 'Nova Legislação'),
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
                  labelText: 'Título do Documento *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Informe o título do documento'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tipoController,
                decoration: const InputDecoration(
                  labelText: 'Tipo / Categoria *',
                  hintText: 'Ex: Portaria, Resolução, Regimento',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Informe a categoria/tipo'
                    : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selecionarDataInicio,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _vigenciaInicio != null
                            ? 'Início: ${DateFormat('dd/MM/yyyy').format(_vigenciaInicio!)}'
                            : 'Vigência Inicial',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selecionarDataFim,
                      icon: const Icon(Icons.event),
                      label: Text(
                        _vigenciaFim != null
                            ? 'Fim: ${DateFormat('dd/MM/yyyy').format(_vigenciaFim!)}'
                            : 'Vigência Final',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Documento Ativo'),
                subtitle: const Text('Visível para consulta dos usuários'),
                value: _ativo,
                onChanged: (val) => setState(() => _ativo = val),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _conteudoController,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Conteúdo *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Informe o conteúdo da legislação'
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
                    : const Text('Salvar Legislação'),
              ),
              if (isEdicao) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _saving ? null : _desativar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Desativar documento'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
