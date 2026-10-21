import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../providers/relatorios_provider.dart';
import '../../widgets/logout_button.dart';

class RelatorioScreen extends ConsumerStatefulWidget {
  final String tipo;
  final String? titulo;
  final String? filtroInicial;
  final bool voltarParaHome;

  const RelatorioScreen({
    super.key,
    required this.tipo,
    this.titulo,
    this.filtroInicial,
    this.voltarParaHome = false,
  });

  @override
  ConsumerState<RelatorioScreen> createState() => _RelatorioScreenState();
}

class _RelatorioScreenState extends ConsumerState<RelatorioScreen> {
  late DateTime _dataInicio;
  late DateTime _dataFim;
  String? _sortColumn;
  bool _sortAscending = true;
  int _limitePagina = 50;
  late String _filtroFrequencia;
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dataInicio = DateTime(now.year, 1, 1);
    _dataFim = now;
    _filtroFrequencia = widget.filtroInicial ?? 'todos';
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RelatorioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filtroInicial != oldWidget.filtroInicial && widget.filtroInicial != null) {
      setState(() {
        _filtroFrequencia = widget.filtroInicial!;
      });
    }
  }

  double _extrairPercentual(Map<String, dynamic> row) {
    final raw = (row['percentual'] ?? row['frequencia'] ?? row['taxa_presenca'] ?? '100').toString();
    final clean = raw.replaceAll('%', '').replaceAll(',', '.').trim();
    return double.tryParse(clean) ?? 100.0;
  }

  bool _isAbaixo75(Map<String, dynamic> row) {
    return _extrairPercentual(row) < 75.0;
  }

  Future<void> _selecionarPeriodo() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(
        start: _dataInicio,
        end: _dataFim,
      ),
    );

    if (range != null) {
      setState(() {
        _dataInicio = range.start;
        _dataFim = range.end;
        _limitePagina = 50;
      });
      ref.read(relatorioProvider(widget.tipo).notifier).aplicarFiltros(
            dataInicio: _dataInicio,
            dataFim: _dataFim,
          );
    }
  }

  String _formatTitle(String tipo, String? titulo) {
    if (titulo != null && titulo.isNotEmpty) {
      return titulo.replaceAll('_', ' ');
    }
    final map = {
      'frequencia': 'Frequência de Internos',
      'internos_campo': 'Internos em Campo',
      'frequencia_acumulada': 'Frequência Acumulada',
      'inconformidades_gps': 'Inconformidades de GPS',
      'avaliacoes': 'Relatório de Avaliações',
      'atividades': 'Relatório de Atividades',
      'legislacao': 'Relatório de Legislação',
    };
    if (map.containsKey(tipo)) return map[tipo]!;
    return 'Relatório: ${tipo.replaceAll('_', ' ')}';
  }

  String _formatDt(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatColumnHeader(String col) {
    final map = {
      'aluno_nome': 'Aluno',
      'campo_nome': 'Campo de Estágio',
      'turno_tipo': 'Turno',
      'data_inicio': 'Data Início',
      'data_fim': 'Data Fim',
      'status': 'Situação',
      'percentual': 'Frequência (%)',
      'total_dias': widget.tipo == 'frequencia' ? 'Total Registros' : 'Total Dias',
      'pendentes': 'Pendentes',
      'validadas': 'Validadas',
      'ratificadas': 'Ratificadas',
      'presencas': 'Presenças',
      'faltas': 'Ausentes',
      'abonos': 'Abonos',
    };
    final key = col.toLowerCase();
    if (map.containsKey(key)) return map[key]!;
    return col.replaceAll('_', ' ').toLowerCase().split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }

  String _formatCellValue(String col, dynamic val) {
    if (val == null) return '-';
    final valStr = val.toString().trim();
    if (col.toLowerCase().contains('data') || col.toLowerCase().contains('created_at')) {
      try {
        final dt = DateTime.parse(valStr);
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {}
    }
    return valStr;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(relatorioProvider(widget.tipo));
    final isFrequencia = widget.tipo == 'frequencia';

    final List<Map<String, dynamic>> rawFrequencia = List.from(state.dados);

    // Agrupa os registros de frequência por usuário (aluno)
    final List<Map<String, dynamic>> baseDados = isFrequencia
        ? agruparFrequenciaPorUsuario(rawFrequencia)
        : rawFrequencia;

    final int abaixo75Count = isFrequencia
        ? baseDados.where(_isAbaixo75).length
        : 0;
    final int regularCount = isFrequencia
        ? baseDados.where((r) => !_isAbaixo75(r)).length
        : 0;

    List<Map<String, dynamic>> dados = baseDados.where((row) {
      if (!isFrequencia || _filtroFrequencia == 'todos') return true;
      if (_filtroFrequencia == 'abaixo_75') return _isAbaixo75(row);
      if (_filtroFrequencia == 'regular') return !_isAbaixo75(row);
      return true;
    }).toList();

    if (_sortColumn != null && dados.isNotEmpty) {
      dados.sort((a, b) {
        final valA = a[_sortColumn]?.toString() ?? '';
        final valB = b[_sortColumn]?.toString() ?? '';
        final comp = valA.compareTo(valB);
        return _sortAscending ? comp : -comp;
      });
    }

    final colunasBrutas = dados.isNotEmpty
        ? dados.first.keys.toList()
        : (baseDados.isNotEmpty ? baseDados.first.keys.toList() : <String>[]);

    // Ocultar UUIDs brutos e campos auxiliares para deixar a tabela visualmente limpa
    final colunas = colunasBrutas.where((col) {
      final c = col.toLowerCase();
      if (isFrequencia && (c == 'data_inicio' || c == 'data_fim')) return false;
      return c != 'aluno_id' &&
          c != 'campo_id' &&
          c != 'alocacao_id' &&
          c != 'id' &&
          c != 'usuario_id' &&
          !c.startsWith('_');
    }).toList();
    final colunasExibicao = colunas.isNotEmpty ? colunas : colunasBrutas;

    return Scaffold(
      appBar: AppBar(
        leading: (widget.voltarParaHome || widget.filtroInicial == 'abaixo_75')
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Voltar para Visão Geral',
                onPressed: () {
                  context.go('/coordenacao/home');
                },
              )
            : null,
        title: Text(_formatTitle(widget.tipo, widget.titulo)),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Exportar',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Exportação disponível em breve'),
                ),
              );
            },
          ),
          const LogoutButton(),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.date_range, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Período: ${_formatDt(_dataInicio)} a ${_formatDt(_dataFim)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    TextButton(
                      onPressed: _selecionarPeriodo,
                      child: const Text('Alterar'),
                    ),
                  ],
                ),
                if (isFrequencia) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          selected: _filtroFrequencia == 'abaixo_75',
                          selectedColor: Colors.red.shade100,
                          checkmarkColor: Colors.red.shade900,
                          avatar: Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: Colors.red.shade800,
                          ),
                          label: Text(
                            'Abaixo de 75% ($abaixo75Count)',
                            style: TextStyle(
                              fontWeight: _filtroFrequencia == 'abaixo_75'
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: Colors.red.shade900,
                            ),
                          ),
                          onSelected: (_) {
                            setState(() {
                              _filtroFrequencia = 'abaixo_75';
                              _limitePagina = 50;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _filtroFrequencia == 'regular',
                          selectedColor: Colors.green.shade100,
                          checkmarkColor: Colors.green.shade900,
                          avatar: Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: Colors.green.shade800,
                          ),
                          label: Text(
                            'Regular ≥ 75% ($regularCount)',
                            style: TextStyle(
                              fontWeight: _filtroFrequencia == 'regular'
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: Colors.green.shade900,
                            ),
                          ),
                          onSelected: (_) {
                            setState(() {
                              _filtroFrequencia = 'regular';
                              _limitePagina = 50;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _filtroFrequencia == 'todos',
                          selectedColor: Colors.blue.shade100,
                          checkmarkColor: Colors.blue.shade900,
                          label: Text(
                            'Todos (${baseDados.length})',
                            style: TextStyle(
                              fontWeight: _filtroFrequencia == 'todos'
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          onSelected: (_) {
                            setState(() {
                              _filtroFrequencia = 'todos';
                              _limitePagina = 50;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...'))
                : (state.erro != null && !isFrequencia)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Falha ao gerar relatório.',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                state.erro!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => ref
                                    .read(relatorioProvider(widget.tipo)
                                        .notifier)
                                    .carregar(),
                                child: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : dados.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhum registro encontrado para o período selecionado.',
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) => SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Scrollbar(
                                    controller: _horizontalScrollController,
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      controller: _horizontalScrollController,
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                        child: DataTable(
                                          horizontalMargin: 12,
                                          columnSpacing: 14,
                                          sortColumnIndex: _sortColumn != null
                                              ? colunasExibicao.indexOf(_sortColumn!)
                                              : null,
                                          sortAscending: _sortAscending,
                                          columns: colunasExibicao.map((col) {
                                            return DataColumn(
                                              label: Text(
                                                _formatColumnHeader(col),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              onSort: (columnIndex, ascending) {
                                                setState(() {
                                                  _sortColumn = colunasExibicao[columnIndex];
                                                  _sortAscending = ascending;
                                                  _limitePagina = 50;
                                                });
                                              },
                                            );
                                          }).toList(),
                                          rows: dados.take(_limitePagina).map((row) {
                                            final emRisco = isFrequencia && _isAbaixo75(row);
                                            return DataRow(
                                              cells: colunasExibicao.map((col) {
                                                final valorFormatted = _formatCellValue(col, row[col]);
                                                final colLower = col.toLowerCase();
                                                final isAlunoCol = colLower == 'aluno_nome' || colLower == 'aluno';
                                                final isCampoCol = colLower == 'campo_nome';
                                                final isPercentualCol = colLower == 'percentual';
                                                return DataCell(
                                                  InkWell(
                                                    onTap: () => _exibirFichaAluno(context, row),
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                                      child: isPercentualCol
                                                          ? Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                              decoration: BoxDecoration(
                                                                color: emRisco ? Colors.red.shade50 : Colors.green.shade50,
                                                                borderRadius: BorderRadius.circular(16),
                                                                border: Border.all(
                                                                  color: emRisco ? Colors.red.shade200 : Colors.green.shade200,
                                                                ),
                                                              ),
                                                              child: Text(
                                                                valorFormatted,
                                                                style: TextStyle(
                                                                  color: emRisco ? Colors.red.shade900 : Colors.green.shade900,
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 13,
                                                                ),
                                                              ),
                                                            )
                                                          : Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                if (isAlunoCol) ...[
                                                                  Icon(
                                                                    Icons.account_circle,
                                                                    size: 18,
                                                                    color: emRisco ? Colors.red.shade700 : Colors.teal,
                                                                  ),
                                                                  const SizedBox(width: 6),
                                                                ],
                                                                if (isCampoCol)
                                                                  Tooltip(
                                                                    message: valorFormatted,
                                                                    child: ConstrainedBox(
                                                                      constraints: const BoxConstraints(maxWidth: 200),
                                                                      child: Text(
                                                                        valorFormatted,
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                        style: const TextStyle(fontSize: 13),
                                                                      ),
                                                                    ),
                                                                  )
                                                                else
                                                                  Text(
                                                                    valorFormatted,
                                                                    style: TextStyle(
                                                                      fontSize: 13,
                                                                      color: isAlunoCol
                                                                          ? (emRisco ? Colors.red.shade900 : Colors.teal.shade900)
                                                                          : null,
                                                                      fontWeight: isAlunoCol ? FontWeight.bold : FontWeight.normal,
                                                                      decoration: isAlunoCol ? TextDecoration.underline : TextDecoration.none,
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (dados.length > _limitePagina)
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _limitePagina += 50;
                                          });
                                        },
                                        icon: const Icon(Icons.expand_more),
                                        label: Text('Carregar mais (${dados.length - _limitePagina} restantes)'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isFrequencia
                      ? 'Exibindo ${dados.length < _limitePagina ? dados.length : _limitePagina} de ${dados.length} usuários (${rawFrequencia.length} registros agrupados)'
                      : 'Exibindo ${dados.length < _limitePagina ? dados.length : _limitePagina} de ${dados.length} registros',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (dados.length > _limitePagina)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _limitePagina += 50;
                      });
                    },
                    child: const Text('Carregar +50'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _exibirFichaAluno(BuildContext context, Map<String, dynamic> row) {
    final alunoNome = row['aluno_nome']?.toString() ?? row['nome']?.toString() ?? 'Aluno';
    final campoNome = row['campo_nome']?.toString() ?? 'Campo de Estágio';
    final turno = row['turno_tipo']?.toString() ?? 'Manhã';
    final dataInicio = _formatCellValue('data_inicio', row['data_inicio']);
    final dataFim = _formatCellValue('data_fim', row['data_fim']);
    final alunoId = row['aluno_id']?.toString() ?? row['id']?.toString() ?? '';
    final percentual = row['percentual']?.toString();
    final pendentes = row['pendentes']?.toString() ?? '0';
    final validadas = row['validadas']?.toString() ?? '0';
    final ratificadas = row['ratificadas']?.toString() ?? '0';
    final faltas = row['faltas']?.toString() ?? '0';
    final totalDias = row['total_dias']?.toString() ?? '0';
    final resumoValidados = row['_resumo_validados']?.toString();
    final emRisco = percentual != null && _isAbaixo75(row);
    final registrosDetalhe = (row['_registros_detalhe'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        const <Map<String, dynamic>>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: emRisco ? Colors.red.shade100 : Colors.teal.shade100,
                  child: Text(
                    alunoNome.isNotEmpty ? alunoNome.substring(0, 1).toUpperCase() : 'A',
                    style: TextStyle(
                      fontSize: 22,
                      color: emRisco ? Colors.red.shade900 : Colors.teal.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alunoNome, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: emRisco ? Colors.red.shade50 : Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: emRisco ? Colors.red.shade200 : Colors.teal.shade200),
                        ),
                        child: Text(
                          emRisco
                              ? 'Atenção: Frequência em Risco ($percentual)'
                              : (percentual != null ? 'Frequência Regular ($percentual)' : 'Interno em Estágio'),
                          style: TextStyle(
                            fontSize: 12,
                            color: emRisco ? Colors.red.shade900 : Colors.teal.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            const Text('Resumo Consolidado do Banco', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildInfoTile(Icons.local_hospital, 'Campos por Onde Já Passou', campoNome),
            _buildInfoTile(Icons.access_time, 'Turno(s) de Estágio', turno.toUpperCase()),
            if (percentual != null)
              _buildInfoTile(
                Icons.bar_chart,
                'Frequência no Banco',
                resumoValidados != null ? '$percentual ($resumoValidados)' : percentual,
              ),
            if (percentual != null)
              _buildInfoTile(
                Icons.fact_check_outlined,
                'Contagem por Status ($totalDias registros)',
                '$pendentes Pendentes • $validadas Validadas • $ratificadas Ratificadas • $faltas Ausentes',
              ),
            if (dataInicio != '-' || dataFim != '-')
              _buildInfoTile(Icons.calendar_today, 'Período dos Registros', '$dataInicio até $dataFim'),

            if (registrosDetalhe.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Registros Agrupados (${registrosDetalhe.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: registrosDetalhe.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, idx) {
                      final item = registrosDetalhe[idx];
                      final dt = _formatCellValue('data_registro', item['data_registro']);
                      final trn = (item['turno_tipo'] ?? item['turno'] ?? '-').toString();
                      final st = (item['status'] ?? '-').toString();
                      final isAusente = st.toLowerCase() == 'ausente' || st.toLowerCase() == 'falta' || st.toLowerCase() == 'rejeitado';
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: Icon(
                          isAusente ? Icons.cancel_outlined : Icons.check_circle_outline,
                          size: 18,
                          color: isAusente ? Colors.red.shade700 : Colors.green.shade700,
                        ),
                        title: Text('$dt • $trn', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        trailing: Text(
                          st,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isAusente ? Colors.red.shade800 : Colors.green.shade800,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            if (alunoId.isNotEmpty) ...[
              const Text('Ações Rápidas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/avaliacao/nova?tipo=do_interno&alunoId=$alunoId');
                      },
                      icon: const Icon(Icons.assessment),
                      label: const Text('Avaliação'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/supervisor/atividades/$alunoId/validar');
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Atividades'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.teal),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              Text(subtitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
