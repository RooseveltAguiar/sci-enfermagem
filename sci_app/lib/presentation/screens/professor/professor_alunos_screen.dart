import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/professor_turmas_provider.dart';
import '../../widgets/logout_button.dart';

class ProfessorAlunosScreen extends ConsumerStatefulWidget {
  const ProfessorAlunosScreen({super.key});

  @override
  ConsumerState<ProfessorAlunosScreen> createState() => _ProfessorAlunosScreenState();
}

class _ProfessorAlunosScreenState extends ConsumerState<ProfessorAlunosScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alunosAsync = ref.watch(alunosDoProfessorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Alunos'),
        actions: const [
          LogoutButton(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por aluno ou campo de estágio...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: alunosAsync.when(
              data: (alunos) {
                if (alunos.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Nenhuma turma vinculada. Contate a coordenação.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ),
                  );
                }

                final filteredAlunos = alunos.where((aluno) {
                  if (_searchQuery.isEmpty) return true;
                  final matchNome = aluno.nome.toLowerCase().contains(_searchQuery);
                  final matchCampo = aluno.campoNome != null &&
                      aluno.campoNome!.toLowerCase().contains(_searchQuery);
                  return matchNome || matchCampo;
                }).toList();

                if (filteredAlunos.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => ref.refresh(alunosDoProfessorProvider.future),
                    child: ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              'Nenhum aluno encontrado para o filtro informado.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.black54),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(alunosDoProfessorProvider.future),
                  child: ListView.builder(
                    itemCount: filteredAlunos.length,
                    itemBuilder: (context, index) {
                      final aluno = filteredAlunos[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            child: Text(
                              aluno.nome.isNotEmpty ? aluno.nome.substring(0, 1).toUpperCase() : 'A',
                              style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(aluno.nome),
                          subtitle: Text(
                            [
                              if (aluno.campoNome != null) aluno.campoNome!,
                              if (aluno.turnoTipo != null) aluno.turnoTipo!,
                            ].join(' • '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _exibirOpcoesAluno(context, aluno),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
              error: (err, stack) => Center(child: Text('Erro ao carregar turmas: $err')),
            ),
          ),
        ],
      ),
    );
  }

  void _exibirOpcoesAluno(BuildContext context, AlunoTurmaResumo aluno) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              top: 24.0,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.teal.shade100,
                      child: Text(
                        aluno.nome.isNotEmpty ? aluno.nome.substring(0, 1).toUpperCase() : 'A',
                        style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(aluno.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (aluno.campoNome != null || aluno.turnoTipo != null)
                            Text(
                              [
                                if (aluno.campoNome != null) aluno.campoNome!,
                                if (aluno.turnoTipo != null) aluno.turnoTipo!,
                              ].join(' • '),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                ListTile(
                  leading: const Icon(Icons.assignment_turned_in, color: Colors.teal),
                  title: const Text('Validar Atividades do Aluno'),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/supervisor/atividades/${aluno.alunoId}/validar');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.assessment, color: Colors.blue),
                  title: const Text('Realizar Avaliação do Aluno'),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/avaliacao/nova?tipo=do_interno&alunoId=${aluno.alunoId}');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined, color: Colors.amber),
                  title: const Text('Banco de Horas do Aluno'),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/professor/banco-horas/${aluno.alunoId}');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder_shared_outlined, color: Color(0xFF005A9C)),
                  title: const Text('Ver Dossiê do Aluno'),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/professor/alunos/${aluno.alunoId}/dossie');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
