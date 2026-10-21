import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/avaliacoes_provider.dart';
import 'avaliacao_detalhe_screen.dart';

class AvaliacaoValidarScreen extends ConsumerWidget {
  final String avaliacaoId;

  const AvaliacaoValidarScreen({
    super.key,
    required this.avaliacaoId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AvaliacaoDetalheScreen(
                avaliacaoId: avaliacaoId,
                modoValidacao: true,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Devolver (Orange)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade900,
                        side: BorderSide(color: Colors.orange.shade700),
                      ),
                      onPressed: () => _showDevolverModal(context, ref),
                      child: const Text('Devolver'),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Validar (Blue)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade900,
                        side: BorderSide(color: Colors.blue.shade700),
                      ),
                      onPressed: () => _showValidarModal(context, ref),
                      child: const Text('Validar'),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Aprovar (Teal)
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.teal,
                      ),
                      onPressed: () => _showAprovarModal(context, ref),
                      child: const Text('Aprovar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showValidarModal(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _ValidarModalContent(
          title: 'Validar esta avaliação?',
          confirmText: 'Validar',
          color: Colors.blue,
          requireCommentMin20: false,
          controller: controller,
          onConfirm: () async {
            Navigator.pop(ctx);
            await ref.read(avaliacoesProvider.notifier).validarAvaliacao(
              avaliacaoId,
              comentario: controller.text,
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Avaliação validada com sucesso!')),
              );
              context.pop();
            }
          },
        ),
      ),
    );
  }

  void _showAprovarModal(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _ValidarModalContent(
          title: 'Aprovar esta avaliação?',
          subtitle: 'Após aprovada, o registro será imutável.',
          confirmText: 'Aprovar',
          color: Colors.teal,
          requireCommentMin20: false,
          controller: controller,
          onConfirm: () async {
            Navigator.pop(ctx);
            await ref.read(avaliacoesProvider.notifier).aprovarAvaliacao(
              avaliacaoId,
              comentario: controller.text,
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Avaliação aprovada!')),
              );
              context.pop();
            }
          },
        ),
      ),
    );
  }

  void _showDevolverModal(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _ValidarModalContent(
          title: 'Devolver avaliação?',
          subtitle: 'Informe o motivo da devolução (obrigatório, mín. 20 caracteres).',
          confirmText: 'Devolver',
          color: Colors.orange.shade900,
          requireCommentMin20: true,
          controller: controller,
          onConfirm: () async {
            Navigator.pop(ctx);
            await ref.read(avaliacoesProvider.notifier).devolverAvaliacao(
              avaliacaoId,
              controller.text,
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Avaliação devolvida para rascunho.')),
              );
              context.pop();
            }
          },
        ),
      ),
    );
  }
}

class _ValidarModalContent extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String confirmText;
  final Color color;
  final bool requireCommentMin20;
  final TextEditingController controller;
  final VoidCallback onConfirm;

  const _ValidarModalContent({
    required this.title,
    this.subtitle,
    required this.confirmText,
    required this.color,
    required this.requireCommentMin20,
    required this.controller,
    required this.onConfirm,
  });

  @override
  State<_ValidarModalContent> createState() => _ValidarModalContentState();
}

class _ValidarModalContentState extends State<_ValidarModalContent> {
  String _errorText = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 8),
            Text(widget.subtitle!, style: TextStyle(color: Colors.grey.shade700)),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: widget.controller,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: widget.requireCommentMin20
                  ? 'Comentário da Coordenação *'
                  : 'Comentário (opcional)',
              border: const OutlineInputBorder(),
              errorText: _errorText.isEmpty ? null : _errorText,
              helperText: widget.requireCommentMin20 ? 'Mínimo 20 caracteres' : null,
            ),
            onChanged: (v) {
              if (_errorText.isNotEmpty) setState(() => _errorText = '');
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: widget.color),
                onPressed: () {
                  if (widget.requireCommentMin20 &&
                      widget.controller.text.trim().length < 20) {
                    setState(() {
                      _errorText = 'Informe pelo menos 20 caracteres.';
                    });
                    return;
                  }
                  widget.onConfirm();
                },
                child: Text(widget.confirmText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
