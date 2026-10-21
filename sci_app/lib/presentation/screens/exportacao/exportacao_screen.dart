import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/usuario_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/export_provider.dart';
import '../../../providers/usuarios_provider.dart';
import '../../widgets/offline_banner.dart';

class ExportacaoScreen extends ConsumerStatefulWidget {
  const ExportacaoScreen({super.key});

  @override
  ConsumerState<ExportacaoScreen> createState() => _ExportacaoScreenState();
}

class _ExportacaoScreenState extends ConsumerState<ExportacaoScreen> {
  late DateTime _dataInicio;
  late DateTime _dataFim;
  final TextEditingController _alunoIdController = TextEditingController();
  List<UsuarioModel> _alunosDisponiveis = [];
  UsuarioModel? _alunoSelecionado;
  String _termoBusca = '';
  bool _mostrarSugestoes = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dataInicio = DateTime(now.year, now.month, 1);
    _dataFim = now;
    Future.microtask(_carregarAlunos);
  }

  Future<void> _carregarAlunos() async {
    try {
      final repo = ref.read(usuariosRepositoryProvider);
      final lista = await repo.listarUsuariosPorPerfil('aluno');
      if (mounted) {
        setState(() {
          _alunosDisponiveis = lista.where((u) => u.ativo).toList();
        });
      }
    } catch (_) {
      // Silencioso caso Supabase não esteja inicializado em ambiente de teste
    }
  }

  String _obterAlunoIdResolvido() {
    if (_alunoSelecionado != null) {
      return _alunoSelecionado!.id;
    }
    final digitado = _alunoIdController.text.trim();
    if (digitado.isEmpty) return '';
    final matchExato = _alunosDisponiveis.where(
      (a) =>
          a.nome.toLowerCase() == digitado.toLowerCase() ||
          a.id.toLowerCase() == digitado.toLowerCase() ||
          a.cpf == digitado,
    );
    if (matchExato.isNotEmpty) {
      return matchExato.first.id;
    }
    return digitado;
  }

  @override
  void dispose() {
    _alunoIdController.dispose();
    super.dispose();
  }

  Future<void> _selecionarPeriodo() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _dataInicio, end: _dataFim),
    );
    if (picked != null) {
      setState(() {
        _dataInicio = picked.start;
        _dataFim = picked.end;
      });
    }
  }

  void _executarExportacao({
    required String tipo,
    required bool isPdf,
  }) {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disponível apenas com conexão. Relatórios exigem dados consolidados do servidor.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final alunoIdResolvido = _obterAlunoIdResolvido();
    if (tipo == 'compilado' && alunoIdResolvido.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, informe ou selecione o ID do Aluno para gerar o relatório compilado.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final notifier = ref.read(exportProvider.notifier);
    if (isPdf) {
      notifier.gerarPdf(
        tipo: tipo,
        dataInicio: _dataInicio,
        dataFim: _dataFim,
        alunoId: tipo == 'compilado' ? alunoIdResolvido : null,
      );
    } else {
      notifier.gerarCsv(
        tipo: tipo,
        dataInicio: _dataInicio,
        dataFim: _dataFim,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final exportState = ref.watch(exportProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final perfil = ref.watch(
      userProfileProvider.select((asyncState) => asyncState.value ?? 'aluno'),
    );
    ref.watch(authStateProvider);

    ref.listen<ExportState>(exportProvider, (prev, next) {
      if (next.erro != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ${next.erro}'), backgroundColor: Colors.red),
        );
        ref.read(exportProvider.notifier).reset();
      } else if (next.sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Relatório gerado e compartilhado com sucesso!'), backgroundColor: Colors.green),
        );
        ref.read(exportProvider.notifier).reset();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exportação de Dados'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Card de filtro de datas
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Período de Referência',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${DateFormat('dd/MM/yyyy').format(_dataInicio)} a ${DateFormat('dd/MM/yyyy').format(_dataFim)}',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _selecionarPeriodo,
                                  icon: const Icon(Icons.date_range),
                                  label: const Text('Alterar'),
                                ),
                              ],
                            ),
                            if (perfil != 'aluno') ...[
                              const SizedBox(height: 16),
                              TextField(
                                controller: _alunoIdController,
                                onTap: () {
                                  if (_alunosDisponiveis.isNotEmpty) {
                                    setState(() {
                                      _mostrarSugestoes = true;
                                    });
                                  }
                                },
                                onChanged: (val) {
                                  setState(() {
                                    _termoBusca = val.trim().toLowerCase();
                                    _alunoSelecionado = null;
                                    _mostrarSugestoes = true;
                                  });
                                },
                                decoration: InputDecoration(
                                  labelText: 'Pesquisar Aluno por nome (obrigatório para Relatório Compilado)',
                                  hintText: 'Digite o nome do aluno para buscar...',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.person_search),
                                  suffixIcon: _alunoIdController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          tooltip: 'Limpar seleção',
                                          onPressed: () {
                                            setState(() {
                                              _alunoIdController.clear();
                                              _alunoSelecionado = null;
                                              _termoBusca = '';
                                              _mostrarSugestoes = false;
                                            });
                                          },
                                        )
                                      : null,
                                ),
                              ),
                              if (_alunoSelecionado != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Aluno selecionado: ${_alunoSelecionado!.nome} (CPF: ${_alunoSelecionado!.cpf})',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Builder(
                                builder: (context) {
                                  if (!_mostrarSugestoes || _alunoSelecionado != null) {
                                    return const SizedBox.shrink();
                                  }
                                  final filtrados = _alunosDisponiveis.where((a) {
                                    if (_termoBusca.isEmpty) return true;
                                    return a.nome.toLowerCase().contains(_termoBusca) ||
                                        a.cpf.toLowerCase().contains(_termoBusca) ||
                                        (a.email?.toLowerCase().contains(_termoBusca) ?? false);
                                  }).take(8).toList();

                                  if (filtrados.isEmpty) {
                                    if (_termoBusca.isEmpty) return const SizedBox.shrink();
                                    return Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Nenhum aluno encontrado com esse nome.',
                                        style: TextStyle(fontSize: 13, color: Colors.black54),
                                      ),
                                    );
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    constraints: const BoxConstraints(maxHeight: 220),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      border: Border.all(color: Colors.teal.shade200),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: filtrados.length,
                                      separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade200),
                                      itemBuilder: (context, idx) {
                                        final aluno = filtrados[idx];
                                        return ListTile(
                                          dense: true,
                                          leading: CircleAvatar(
                                            radius: 15,
                                            backgroundColor: Colors.teal.shade100,
                                            child: Text(
                                              aluno.nome.isNotEmpty ? aluno.nome[0].toUpperCase() : 'A',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.teal.shade900,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            aluno.nome,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                          ),
                                          subtitle: Text(
                                            'CPF: ${aluno.cpf}${aluno.email != null ? ' • ${aluno.email}' : ''}',
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          onTap: () {
                                            setState(() {
                                              _alunoSelecionado = aluno;
                                              _alunoIdController.text = aluno.nome;
                                              _mostrarSugestoes = false;
                                            });
                                            FocusScope.of(context).unfocus();
                                          },
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Opções de Relatório',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    if (perfil == 'aluno') ...[
                      _buildRelatorioCard(
                        titulo: 'Minha Frequência',
                        subtitulo: 'Presenças e horas validadas no período selecionado',
                        icone: Icons.check_circle_outline,
                        isOnline: isOnline,
                        onPdf: () => _executarExportacao(tipo: 'frequencia', isPdf: true),
                      ),
                      _buildRelatorioCard(
                        titulo: 'Minhas Atividades',
                        subtitulo: 'Atividades práticas realizadas no período',
                        icone: Icons.assignment_outlined,
                        isOnline: isOnline,
                        onPdf: () => _executarExportacao(tipo: 'atividades', isPdf: true),
                      ),
                    ] else ...[
                      _buildRelatorioCard(
                        titulo: 'Relatório de Frequência Geral',
                        subtitulo: 'Consolidado de presenças de internos por período',
                        icone: Icons.access_time,
                        isOnline: isOnline,
                        onPdf: () => _executarExportacao(tipo: 'frequencia', isPdf: true),
                        onCsv: () => _executarExportacao(tipo: 'frequencia', isPdf: false),
                      ),
                      _buildRelatorioCard(
                        titulo: 'Relatório de Atividades',
                        subtitulo: 'Atividades, procedimentos e quantitativos no período',
                        icone: Icons.medical_services_outlined,
                        isOnline: isOnline,
                        onPdf: () => _executarExportacao(tipo: 'atividades', isPdf: true),
                        onCsv: () => _executarExportacao(tipo: 'atividades', isPdf: false),
                      ),
                      _buildRelatorioCard(
                        titulo: 'Relatório de Avaliações',
                        subtitulo: 'Notas, rubricas e pareceres de estágio consolidados',
                        icone: Icons.grade_outlined,
                        isOnline: isOnline,
                        onPdf: () => _executarExportacao(tipo: 'avaliacoes', isPdf: true),
                        onCsv: () => _executarExportacao(tipo: 'avaliacoes', isPdf: false),
                      ),
                    ],

                    _buildRelatorioCard(
                      titulo: 'Relatório Compilado do Aluno',
                      subtitulo: 'Dossiê completo contendo resumo, frequências, atividades e avaliações',
                      icone: Icons.folder_special_outlined,
                      isOnline: isOnline,
                      onPdf: () {
                        if (perfil == 'aluno') {
                          final user = ref.read(authStateProvider).value?.session?.user ??
                              ref.read(supabaseClientProvider).auth.currentUser;
                          if (user != null) {
                            _alunoIdController.text = user.id;
                          }
                        }
                        _executarExportacao(tipo: 'compilado', isPdf: true);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (exportState.loading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(semanticsLabel: 'Carregando...'),
                        const SizedBox(height: 16),
                        Text(
                          exportState.progressoMensagem ?? 'Processando...',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRelatorioCard({
    required String titulo,
    required String subtitulo,
    required IconData icone,
    required bool isOnline,
    VoidCallback? onPdf,
    VoidCallback? onCsv,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 28, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(subtitulo, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onPdf != null)
                  ElevatedButton.icon(
                    onPressed: isOnline ? onPdf : null,
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Exportar PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOnline ? Colors.red.shade700 : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (onCsv != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: isOnline ? onCsv : null,
                    icon: const Icon(Icons.table_chart, size: 18),
                    label: const Text('Exportar CSV'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
