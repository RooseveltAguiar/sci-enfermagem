import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/avaliacoes_provider.dart';
import '../../../providers/professor_turmas_provider.dart';
import '../../../providers/campos_provider.dart';
import '../../widgets/avaliacao_status_chip.dart';
import '../../widgets/sync_status_icon.dart';

class AvaliacaoListaScreen extends ConsumerWidget {
  const AvaliacaoListaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avaliações'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Exportar Relatórios',
            onPressed: () => context.push('/exportacao'),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Perfil não encontrado.'));
          }
          switch (profile) {
            case 'aluno':
              return const _AlunoAvaliacoesView();
            case 'supervisor':
              return const _SupervisorAvaliacoesView();
            case 'professor':
              return const _ProfessorAvaliacoesView();
            case 'coordenacao':
            default:
              return const _CoordenacaoAvaliacoesView();
          }
        },
        loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
        error: (e, stack) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}

class _AlunoAvaliacoesView extends ConsumerWidget {
  const _AlunoAvaliacoesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avaliacoesAsync = ref.watch(avaliacoesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/avaliacao/nova'),
        icon: const Icon(Icons.add),
        label: const Text('Nova avaliação'),
      ),
      body: avaliacoesAsync.when(
        data: (avaliacoes) {
          if (avaliacoes.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(avaliacoesProvider.future),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Nenhuma avaliação no período atual.')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(avaliacoesProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: avaliacoes.length,
              itemBuilder: (context, index) {
                final a = avaliacoes[index];
                final isDoInterno = a.tipo == 'do_interno';
                final isLocked = isDoInterno && a.status != 'aprovada';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      isLocked ? Icons.lock_outline : Icons.assessment_outlined,
                      color: isLocked ? Colors.grey : Colors.teal,
                    ),
                    title: Text(
                      _getTipoLabel(a.tipo),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Período: ${_formatDate(a.periodoReferencia)}'),
                        if (isLocked)
                          const Text(
                            'Disponível após aprovação',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SyncStatusIcon(registroId: a.id),
                        const SizedBox(width: 8),
                        AvaliacaoStatusChip.fromString(a.status, comentarioValidacao: a.comentarioValidacao),
                      ],
                    ),
                    onTap: () {
                      context.push('/avaliacao/${a.id}');
                    },
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
        error: (e, stack) => Center(child: Text('Erro ao carregar: $e')),
      ),
    );
  }

  String _getTipoLabel(String tipo) {
    switch (tipo) {
      case 'setorial':
        return 'Avaliação Setorial';
      case 'autoavaliacao':
        return 'Autoavaliação';
      case 'do_interno':
      default:
        return 'Avaliação do Interno';
    }
  }

  String _formatDate(DateTime date) {
    final meses = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    return '${meses[date.month - 1]}/${date.year}';
  }
}

class _SupervisorAvaliacoesView extends ConsumerWidget {
  const _SupervisorAvaliacoesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avaliacoesAsync = ref.watch(avaliacoesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/avaliacao/nova?tipo=do_interno'),
        icon: const Icon(Icons.rate_review),
        label: const Text('Avaliar interno'),
      ),
      body: avaliacoesAsync.when(
        data: (list) {
          final doInternoList = list.where((a) => a.tipo == 'do_interno').toList();
          if (doInternoList.isEmpty) {
            return const Center(
              child: Text('Nenhuma avaliação do interno cadastrada.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(avaliacoesProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: doInternoList.length,
              itemBuilder: (context, index) {
                final a = doInternoList[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(a.alunoNome ?? 'Avaliação do Interno'),
                    subtitle: Text('Período: ${a.periodoReferencia.month}/${a.periodoReferencia.year}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SyncStatusIcon(registroId: a.id),
                        const SizedBox(width: 8),
                        AvaliacaoStatusChip.fromString(a.status, comentarioValidacao: a.comentarioValidacao),
                      ],
                    ),
                    onTap: () => context.push('/avaliacao/${a.id}'),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
        error: (e, stack) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}

class _ProfessorAvaliacoesView extends ConsumerStatefulWidget {
  const _ProfessorAvaliacoesView();

  @override
  ConsumerState<_ProfessorAvaliacoesView> createState() => _ProfessorAvaliacoesViewState();
}

class _ProfessorAvaliacoesViewState extends ConsumerState<_ProfessorAvaliacoesView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alunosAsync = ref.watch(alunosDoProfessorProvider);
    final avaliacoesAsync = ref.watch(avaliacoesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Filtrar por aluno ou campo de estágio...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          indicatorColor: Colors.teal,
          tabs: const [
            Tab(text: 'Meus Alunos'),
            Tab(text: 'Ratificar'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              alunosAsync.when(
                data: (alunos) {
                  if (alunos.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma turma vinculada. Contate a coordenação.'),
                    );
                  }

                  final filtered = alunos.where((al) {
                    if (_searchQuery.isEmpty) return true;
                    final matchNome = al.nome.toLowerCase().contains(_searchQuery);
                    final matchCampo = al.campoNome != null &&
                        al.campoNome!.toLowerCase().contains(_searchQuery);
                    return matchNome || matchCampo;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('Nenhum aluno encontrado para o filtro informado.'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final al = filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(al.nome),
                          subtitle: Text(al.campoNome ?? 'Sem campo'),
                          trailing: Chip(
                            label: const Text('Pendente Eval'),
                            backgroundColor: Colors.amber.shade100,
                          ),
                          onTap: () => context.push('/avaliacao/nova?tipo=do_interno&aluno=${al.alunoId}'),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
                error: (e, s) => Center(child: Text('Erro: $e')),
              ),
              avaliacoesAsync.when(
                data: (list) {
                  final validadas = list.where((a) => a.status == 'validada').where((a) {
                    if (_searchQuery.isEmpty) return true;
                    final matchAluno = a.alunoNome != null && a.alunoNome!.toLowerCase().contains(_searchQuery);
                    final matchCampo = a.campoNome != null && a.campoNome!.toLowerCase().contains(_searchQuery);
                    return matchAluno || matchCampo;
                  }).toList();

                  if (validadas.isEmpty) {
                    return const Center(child: Text('Nenhuma avaliação encontrada para o filtro informado.'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: validadas.length,
                    itemBuilder: (context, index) {
                      final a = validadas[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(a.alunoNome ?? 'Avaliação'),
                          subtitle: Text('Status: ${a.status}'),
                          trailing: AvaliacaoStatusChip.fromString(a.status, comentarioValidacao: a.comentarioValidacao),
                          onTap: () => context.push('/avaliacao/${a.id}'),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
                error: (e, s) => Center(child: Text('Erro: $e')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CoordenacaoAvaliacoesView extends ConsumerStatefulWidget {
  const _CoordenacaoAvaliacoesView();

  @override
  ConsumerState<_CoordenacaoAvaliacoesView> createState() => _CoordenacaoAvaliacoesViewState();
}

class _CoordenacaoAvaliacoesViewState extends ConsumerState<_CoordenacaoAvaliacoesView> {
  String? _selectedCampoId;

  @override
  Widget build(BuildContext context) {
    final avaliacoesAsync = ref.watch(avaliacoesProvider);
    final camposAsync = ref.watch(camposProvider);

    final camposList = camposAsync.value ?? [];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 104,
          title: Container(
            margin: const EdgeInsets.only(top: 8),
            child: DropdownButtonFormField<String?>(
              initialValue: _selectedCampoId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Filtro por Campo de Estágio',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todos os campos'),
                ),
                ...camposList.map((c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.nome, overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedCampoId = val;
                });
              },
            ),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pendentes de Validação'),
              Tab(text: 'Todas as Avaliações'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/avaliacao/nova'),
          icon: const Icon(Icons.add),
          label: const Text('Nova avaliação'),
        ),
        body: avaliacoesAsync.when(
          data: (list) {
            final filteredList = list.where((a) {
              if (_selectedCampoId == null || _selectedCampoId == 'todos') return true;
              final selectedCampo = camposList.firstWhere(
                (c) => c.id == _selectedCampoId,
                orElse: () => CampoEstagio(id: '', nome: '', endereco: '', ativo: true, raioMetros: 150, lat: 0, lng: 0),
              );
              return a.campoId == _selectedCampoId || a.campoNome == selectedCampo.nome;
            }).toList();

            final submetidas = filteredList.where((a) => a.status == 'submetida').toList();

            return TabBarView(
              children: [
                // Tab 1: Pendentes
                submetidas.isEmpty
                    ? RefreshIndicator(
                        onRefresh: () async => ref.refresh(avaliacoesProvider.future),
                        child: ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Text(
                                'Nenhuma avaliação encontrada para o campo selecionado.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref.refresh(avaliacoesProvider.future),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: submetidas.length,
                          itemBuilder: (context, index) {
                            final a = submetidas[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text('${_getTipoLabel(a.tipo)} — ${a.alunoNome ?? "Aluno"}'),
                                subtitle: Text('Período: ${_formatDate(a.periodoReferencia)}'),
                                trailing: AvaliacaoStatusChip.fromString(a.status, comentarioValidacao: a.comentarioValidacao),
                                onTap: () => context.push('/avaliacao/${a.id}/validar'),
                              ),
                            );
                          },
                        ),
                      ),

                // Tab 2: Todas
                filteredList.isEmpty
                    ? RefreshIndicator(
                        onRefresh: () async => ref.refresh(avaliacoesProvider.future),
                        child: ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Text(
                                'Nenhuma avaliação encontrada para o campo selecionado.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref.refresh(avaliacoesProvider.future),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final a = filteredList[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text('${_getTipoLabel(a.tipo)} — ${a.alunoNome ?? "Aluno"}'),
                                subtitle: Text('Período: ${_formatDate(a.periodoReferencia)} • Status: ${a.status}'),
                                trailing: AvaliacaoStatusChip.fromString(a.status, comentarioValidacao: a.comentarioValidacao),
                                onTap: () => context.push('/avaliacao/${a.id}'),
                              ),
                            );
                          },
                        ),
                      ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
          error: (e, s) => Center(child: Text('Erro: $e')),
        ),
      ),
    );
  }

  static String _getTipoLabel(String tipo) {
    switch (tipo) {
      case 'setorial':
        return 'Avaliação Setorial';
      case 'do_interno':
        return 'Avaliação do Interno';
      case 'autoavaliacao':
        return 'Autoavaliação';
      default:
        return tipo;
    }
  }

  static String _formatDate(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
