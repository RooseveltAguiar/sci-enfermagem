import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/models/conflito_model.dart';
import '../../../providers/campos_provider.dart';
import '../../../providers/conflitos_provider.dart';

class ConflitosListaScreen extends ConsumerStatefulWidget {
  const ConflitosListaScreen({super.key});

  @override
  ConsumerState<ConflitosListaScreen> createState() =>
      _ConflitosListaScreenState();
}

class _ConflitosListaScreenState extends ConsumerState<ConflitosListaScreen> {
  DateTime? _dataInicio;
  DateTime? _dataFim;

  Future<void> _filtrarPorDataInicio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataInicio ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _dataInicio = picked);
      _recarregar();
    }
  }

  Future<void> _filtrarPorDataFim() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataFim ?? DateTime.now(),
      firstDate: _dataInicio ?? DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _dataFim = picked);
      _recarregar();
    }
  }

  void _limparDatas() {
    setState(() {
      _dataInicio = null;
      _dataFim = null;
    });
    _recarregar();
  }

  void _recarregar() {
    ref.read(conflitosControllerProvider.notifier).carregarConflitos(
          dataInicio: _dataInicio,
          dataFim: _dataFim,
        );
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(conflitosControllerProvider);
    final camposAsync = ref.watch(camposProvider);
    final campoFiltro = ref.watch(conflitosFiltroCampoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Ocorrências e Conflitos'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/conflitos/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Registrar Ocorrência'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                camposAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (campos) {
                    return DropdownButtonFormField<String?>(
                      initialValue: campoFiltro,
                      decoration: const InputDecoration(
                        labelText: 'Filtrar por Campo de Estágio',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todos os Campos'),
                        ),
                        ...campos.map((c) => DropdownMenuItem<String?>(
                              value: c.id,
                              child: Text(c.nome),
                            )),
                      ],
                      onChanged: (val) {
                        ref
                            .read(conflitosFiltroCampoProvider.notifier)
                            .state = val;
                        _recarregar();
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _filtrarPorDataInicio,
                        icon: const Icon(Icons.calendar_today, size: 14),
                        label: Text(
                          _dataInicio != null
                              ? 'De: ${DateFormat('dd/MM/yy').format(_dataInicio!)}'
                              : 'Data Início',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _filtrarPorDataFim,
                        icon: const Icon(Icons.calendar_today, size: 14),
                        label: Text(
                          _dataFim != null
                              ? 'Até: ${DateFormat('dd/MM/yy').format(_dataFim!)}'
                              : 'Data Fim',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    if (_dataInicio != null || _dataFim != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Limpar datas',
                        onPressed: _limparDatas,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _recarregar(),
              child: estado.when(
                loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
                error: (erro, st) => Center(
                  child: Text('Erro ao carregar ocorrências: $erro'),
                ),
                data: (lista) {
                  if (lista.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.report_problem_outlined,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Nenhuma ocorrência registrada.',
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: lista.length,
                    itemBuilder: (context, index) {
                      return _ConflitoCard(conflito: lista[index]);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflitoCard extends StatefulWidget {
  final ConflitoModel conflito;

  const _ConflitoCard({required this.conflito});

  @override
  State<_ConflitoCard> createState() => _ConflitoCardState();
}

class _ConflitoCardState extends State<_ConflitoCard> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final dataStr = widget.conflito.dataOcorrencia != null
        ? DateFormat('dd/MM/yyyy').format(widget.conflito.dataOcorrencia!)
        : 'Data não informada';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _expandido = !_expandido),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      htmlEscape.convert(widget.conflito.alunoNome ?? 'Aluno ID: ${widget.conflito.alunoId}'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    dataStr,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.place_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    htmlEscape.convert(widget.conflito.campoNome ?? 'Campo ID: ${widget.conflito.campoId}'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                htmlEscape.convert(widget.conflito.descricao),
                maxLines: _expandido ? null : 2,
                overflow: _expandido ? null : TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _expandido ? 'Recolher detalhes ▲' : 'Ver mais ▼',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
