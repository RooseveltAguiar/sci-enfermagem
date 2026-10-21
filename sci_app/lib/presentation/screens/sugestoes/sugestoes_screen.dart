import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/sugestao_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/sugestoes_provider.dart';
import '../../widgets/confirmation_bottom_sheet.dart';

class SugestoesScreen extends ConsumerStatefulWidget {
  const SugestoesScreen({super.key});

  @override
  ConsumerState<SugestoesScreen> createState() => _SugestoesScreenState();
}

class _SugestoesScreenState extends ConsumerState<SugestoesScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {}); // Re-render para atualizar habilitação do botão Enviar
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _textoValido => _controller.text.trim().length >= 20;

  Future<void> _enviarSugestao(bool isCoordenacao) async {
    final texto = _controller.text.trim();
    if (texto.length < 20) return;

    await ConfirmationBottomSheet.show(
      context,
      title: 'Enviar Sugestão',
      message: 'Enviar esta sugestão para a coordenação?',
      confirmText: 'Enviar',
      onConfirm: () async {
        setState(() => _saving = true);
        try {
          await ref
              .read(sugestoesControllerProvider.notifier)
              .enviarSugestao(texto, isCoordenacao: isCoordenacao);
          _controller.clear();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sugestão enviada com sucesso.')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao enviar sugestão: $e')),
            );
          }
        } finally {
          if (mounted) setState(() => _saving = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(
      userProfileProvider.select((asyncState) => asyncState.value ?? ''),
    );
    final isCoordenacao = perfil == 'coordenacao';
    final estado = ref.watch(sugestoesControllerProvider);
    final filtroAtual = ref.watch(sugestoesFiltroPerfilProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caixa de Sugestões'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref
              .read(sugestoesControllerProvider.notifier)
              .carregarSugestoes(isCoordenacao: isCoordenacao);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Nova Sugestão',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _controller,
                        maxLength: 1000,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText:
                              'Descreva sua sugestão de melhoria (mínimo 20 caracteres)...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        key: const Key('btn_enviar_sugestao'),
                        onPressed: (_textoValido && !_saving)
                            ? () => _enviarSugestao(isCoordenacao)
                            : null,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2, semanticsLabel: 'Carregando...'))
                            : const Icon(Icons.send),
                        label: const Text('Enviar sugestão'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (isCoordenacao) ...[
                const Text(
                  'Filtrar sugestões por perfil:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FiltroChip(
                        label: 'Todos',
                        selected: filtroAtual == 'todos',
                        onSelected: () {
                          ref
                              .read(sugestoesFiltroPerfilProvider.notifier)
                              .state = 'todos';
                          ref
                              .read(sugestoesControllerProvider.notifier)
                              .carregarSugestoes(isCoordenacao: true);
                        },
                      ),
                      const SizedBox(width: 8),
                      _FiltroChip(
                        label: 'Alunos',
                        selected: filtroAtual == 'aluno',
                        onSelected: () {
                          ref
                              .read(sugestoesFiltroPerfilProvider.notifier)
                              .state = 'aluno';
                          ref
                              .read(sugestoesControllerProvider.notifier)
                              .carregarSugestoes(isCoordenacao: true);
                        },
                      ),
                      const SizedBox(width: 8),
                      _FiltroChip(
                        label: 'Supervisores',
                        selected: filtroAtual == 'supervisor',
                        onSelected: () {
                          ref
                              .read(sugestoesFiltroPerfilProvider.notifier)
                              .state = 'supervisor';
                          ref
                              .read(sugestoesControllerProvider.notifier)
                              .carregarSugestoes(isCoordenacao: true);
                        },
                      ),
                      const SizedBox(width: 8),
                      _FiltroChip(
                        label: 'Professores',
                        selected: filtroAtual == 'professor',
                        onSelected: () {
                          ref
                              .read(sugestoesFiltroPerfilProvider.notifier)
                              .state = 'professor';
                          ref
                              .read(sugestoesControllerProvider.notifier)
                              .carregarSugestoes(isCoordenacao: true);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                isCoordenacao
                    ? 'Todas as Sugestões Recebidas'
                    : 'Minhas Sugestões Enviadas',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              estado.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
                error: (erro, st) =>
                    Center(child: Text('Erro ao carregar sugestões: $erro')),
                data: (lista) {
                  if (lista.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          isCoordenacao
                              ? 'Nenhuma sugestão recebida para este filtro.'
                              : 'Você ainda não enviou nenhuma sugestão.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: lista
                        .map((item) => _SugestaoCard(
                              sugestao: item,
                              isCoordenacao: isCoordenacao,
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FiltroChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _SugestaoCard extends StatelessWidget {
  final SugestaoModel sugestao;
  final bool isCoordenacao;

  const _SugestaoCard({
    required this.sugestao,
    required this.isCoordenacao,
  });

  @override
  Widget build(BuildContext context) {
    final dataStr = sugestao.createdAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(sugestao.createdAt!)
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCoordenacao &&
                (sugestao.autorNome != null || sugestao.autorPerfil != null)) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    htmlEscape.convert(sugestao.autorNome ?? 'Usuário'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Chip(
                    label: Text(
                      htmlEscape.convert((sugestao.autorPerfil ?? '').toUpperCase()),
                      style: const TextStyle(fontSize: 10),
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
              htmlEscape.convert(sugestao.conteudo),
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            if (dataStr.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Enviado em $dataStr',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
