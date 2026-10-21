import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/avaliacoes_provider.dart';
import '../../widgets/confirmation_bottom_sheet.dart';

class AvaliacaoFormScreen extends ConsumerStatefulWidget {
  final String? avaliacaoId;
  final String? tipoInicial;
  final String? alunoIdInicial;

  const AvaliacaoFormScreen({
    super.key,
    this.avaliacaoId,
    this.tipoInicial,
    this.alunoIdInicial,
  });

  @override
  ConsumerState<AvaliacaoFormScreen> createState() => _AvaliacaoFormScreenState();
}

class _AvaliacaoFormScreenState extends ConsumerState<AvaliacaoFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _tipo;
  late DateTime _periodoReferencia;
  int _notaGeral = 7;
  final _positivosController = TextEditingController();
  final _melhoriaController = TextEditingController();
  final _comentarioController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tipo = widget.tipoInicial ?? 'do_interno';
    final now = DateTime.now();
    _periodoReferencia = DateTime(now.year, now.month, 1);

    if (widget.avaliacaoId != null) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    final list = await ref.read(avaliacoesProvider.future);
    final found = list.where((a) => a.id == widget.avaliacaoId).firstOrNull;
    if (found != null) {
      if (found.status != 'rascunho') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              context.go('/avaliacao/${found.id}');
            } catch (_) {}
          }
        });
        return;
      }
      setState(() {
        _tipo = found.tipo;
        _periodoReferencia = found.periodoReferencia;
        _notaGeral = found.notaGeral ?? 7;
        _positivosController.text = found.pontosPositivos ?? '';
        _melhoriaController.text = found.pontosMelhoria ?? '';
        _comentarioController.text = found.comentarioLivre ?? '';
      });
    }
  }

  @override
  void dispose() {
    _positivosController.dispose();
    _melhoriaController.dispose();
    _comentarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mesesDisponiveis = _getMesesDisponiveis();
    final perfilAtual = ref.watch(userProfileProvider).value;

    final tiposDisponiveis = switch (perfilAtual) {
      'ator_1' || 'aluno' => const ['autoavaliacao', 'setorial'],
      'ator_2' || 'supervisor' => const ['do_interno', 'setorial'],
      'ator_3' || 'professor' => const ['do_interno', 'setorial'],
      'coordenacao' => const ['do_interno', 'setorial'],
      _ => const ['do_interno', 'setorial', 'autoavaliacao'],
    };

    final effectiveTipo = tiposDisponiveis.contains(_tipo)
        ? _tipo
        : (tiposDisponiveis.isNotEmpty ? tiposDisponiveis.first : _tipo);

    final dropdownItems = tiposDisponiveis.map((t) {
      final label = switch (t) {
        'do_interno' => 'Avaliação do Interno',
        'setorial' => 'Avaliação Setorial',
        'autoavaliacao' => 'Autoavaliação',
        _ => t,
      };
      return DropdownMenuItem<String>(
        value: t,
        child: Text(label),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.avaliacaoId != null ? 'Editar Avaliação' : 'Nova Avaliação'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Tipo de avaliação
            DropdownButtonFormField<String>(
              initialValue: effectiveTipo,
              decoration: const InputDecoration(
                labelText: 'Tipo de Avaliação',
                border: OutlineInputBorder(),
              ),
              items: dropdownItems,
              onChanged: widget.avaliacaoId != null
                  ? null
                  : (val) {
                      if (val != null) {
                        setState(() {
                          _tipo = val;
                        });
                      }
                    },
            ),
            const SizedBox(height: 16),

            // Período de referência
            DropdownButtonFormField<DateTime>(
              initialValue: _periodoReferencia,
              decoration: const InputDecoration(
                labelText: 'Período de Referência',
                border: OutlineInputBorder(),
              ),
              items: mesesDisponiveis.map((dt) {
                return DropdownMenuItem(
                  value: dt,
                  child: Text(_formatMesAno(dt)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _periodoReferencia = val);
              },
            ),
            const SizedBox(height: 24),

            // Nota Geral
            Text(
              'Nota Geral: $_notaGeral — ${_getLabelNota(_notaGeral)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Semantics(
              label: 'Seletor de Nota Geral, valor atual $_notaGeral',
              child: Slider(
                value: _notaGeral.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: '$_notaGeral',
                onChanged: (val) => setState(() => _notaGeral = val.toInt()),
              ),
            ),
            const SizedBox(height: 16),

            // Pontos Positivos
            TextFormField(
              controller: _positivosController,
              minLines: 3,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Pontos Positivos *',
                border: OutlineInputBorder(),
                helperText: 'Mínimo de 20 caracteres',
              ),
              validator: (val) {
                if (val == null || val.trim().length < 20) {
                  return 'Informe no mínimo 20 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Pontos de Melhoria
            TextFormField(
              controller: _melhoriaController,
              minLines: 3,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Pontos de Melhoria *',
                border: OutlineInputBorder(),
                helperText: 'Mínimo de 20 caracteres',
              ),
              validator: (val) {
                if (val == null || val.trim().length < 20) {
                  return 'Informe no mínimo 20 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Comentário Livre
            TextFormField(
              controller: _comentarioController,
              maxLength: 1000,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Comentário Livre (opcional)',
                hintText: 'Observações adicionais',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            if (widget.avaliacaoId != null) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Excluir rascunho'),
                onPressed: _confirmExcluirRascunho,
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _salvarRascunho,
                  child: const Text('Salvar rascunho'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isLoading ? null : _submeterAvaliacao,
                  child: const Text('Submeter'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DateTime> _getMesesDisponiveis() {
    final now = DateTime.now();
    final m0 = DateTime(now.year, now.month, 1);
    final m1 = DateTime(now.month == 1 ? now.year - 1 : now.year, now.month == 1 ? 12 : now.month - 1, 1);
    final m2 = DateTime(m1.month == 1 ? m1.year - 1 : m1.year, m1.month == 1 ? 12 : m1.month - 1, 1);
    final list = [m0, m1, m2];
    if (!list.any((d) => d.year == _periodoReferencia.year && d.month == _periodoReferencia.month)) {
      list.add(_periodoReferencia);
    }
    return list;
  }

  String _formatMesAno(DateTime dt) {
    final meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return '${meses[dt.month - 1]} ${dt.year}';
  }

  String _getLabelNota(int nota) {
    if (nota <= 3) return 'Insatisfatório';
    if (nota <= 6) return 'Regular';
    if (nota <= 8) return 'Bom';
    return 'Excelente';
  }

  Future<String?> _resolveUserId() async {
    try {
      final user = ref.read(supabaseClientProvider).auth.currentUser;
      if (user != null) return user.id;
    } catch (_) {}

    try {
      final supabase = ref.read(supabaseClientProvider);
      final aloc = await supabase
          .from('alocacoes_alunos')
          .select('aluno_id')
          .isFilter('deleted_at', null)
          .limit(1)
          .maybeSingle();
      if (aloc != null && aloc['aluno_id'] != null) {
        return aloc['aluno_id'] as String;
      }
    } catch (_) {}

    try {
      final supabase = ref.read(supabaseClientProvider);
      final usr = await supabase
          .from('usuarios')
          .select('id')
          .eq('perfil', 'aluno')
          .isFilter('deleted_at', null)
          .limit(1)
          .maybeSingle();
      if (usr != null && usr['id'] != null) {
        return usr['id'] as String;
      }
    } catch (_) {}

    return null;
  }

  Future<void> _salvarRascunho() async {
    setState(() => _isLoading = true);
    try {
      String? currentUserId;
      try {
        currentUserId = ref.read(supabaseClientProvider).auth.currentUser?.id;
      } catch (_) {}
      final resolvedUserId = widget.alunoIdInicial ?? await _resolveUserId();
      final notifier = ref.read(avaliacoesProvider.notifier);
      await notifier.salvarRascunho({
        if (widget.avaliacaoId != null) 'id': widget.avaliacaoId,
        'aluno_id': resolvedUserId,
        'avaliador_id': currentUserId ?? resolvedUserId,
        'tipo': _tipo,
        'periodo_referencia': '${_periodoReferencia.year}-${_periodoReferencia.month.toString().padLeft(2, '0')}-01',
        'nota_geral': _notaGeral,
        'pontos_positivos': _positivosController.text,
        'pontos_melhoria': _melhoriaController.text,
        'comentario_livre': _comentarioController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rascunho salvo com sucesso!')),
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          try {
            if (context.canPop()) context.pop();
          } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar rascunho: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _submeterAvaliacao() {
    if (!_formKey.currentState!.validate()) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => ConfirmationBottomSheet(
        title: 'Submeter avaliação?',
        message: 'Após submeter, não será possível editar esta avaliação.',
        confirmText: 'Submeter',
        cancelText: 'Cancelar',
        onConfirm: () async {
          await _executarSubmissao();
        },
      ),
    );
  }

  Future<void> _executarSubmissao() async {
    setState(() => _isLoading = true);
    try {
      String? currentUserId;
      try {
        currentUserId = ref.read(supabaseClientProvider).auth.currentUser?.id;
      } catch (_) {}
      final resolvedUserId = widget.alunoIdInicial ?? await _resolveUserId();
      final notifier = ref.read(avaliacoesProvider.notifier);
      final rascunho = await notifier.salvarRascunho({
        if (widget.avaliacaoId != null) 'id': widget.avaliacaoId,
        'aluno_id': resolvedUserId,
        'avaliador_id': currentUserId ?? resolvedUserId,
        'tipo': _tipo,
        'periodo_referencia': '${_periodoReferencia.year}-${_periodoReferencia.month.toString().padLeft(2, '0')}-01',
        'nota_geral': _notaGeral,
        'pontos_positivos': _positivosController.text,
        'pontos_melhoria': _melhoriaController.text,
        'comentario_livre': _comentarioController.text,
      });

      await notifier.submitAvaliacao(rascunho.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avaliação submetida com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          try {
            if (context.canPop()) context.pop();
          } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao submeter avaliação: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmExcluirRascunho() {
    if (widget.avaliacaoId == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ConfirmationBottomSheet(
        title: 'Excluir rascunho?',
        message: 'Esta ação não pode ser desfeita.',
        confirmText: 'Excluir',
        cancelText: 'Cancelar',
        isDestructive: true,
        onConfirm: () async {
          await ref.read(avaliacoesProvider.notifier).excluirRascunho(widget.avaliacaoId!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rascunho excluído.')),
            );
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              try {
                if (context.canPop()) context.pop();
              } catch (_) {}
            }
          }
        },
      ),
    );
  }
}
