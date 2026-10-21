import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../providers/usuarios_provider.dart';
import '../../widgets/usuario_status_chip.dart';
import '../../widgets/logout_button.dart';

class UsuariosListaScreen extends ConsumerStatefulWidget {
  const UsuariosListaScreen({super.key});

  @override
  ConsumerState<UsuariosListaScreen> createState() =>
      _UsuariosListaScreenState();
}

class _UsuariosListaScreenState extends ConsumerState<UsuariosListaScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestão de Usuários'),
          actions: const [
            LogoutButton(),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: 'Limpar busca',
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Alunos'),
                    Tab(text: 'Supervisores'),
                    Tab(text: 'Professores'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _UsuariosAbaLista(
              perfil: 'aluno',
              nomeSingular: 'aluno',
              searchQuery: _searchQuery,
            ),
            _UsuariosAbaLista(
              perfil: 'supervisor',
              nomeSingular: 'supervisor',
              searchQuery: _searchQuery,
            ),
            _UsuariosAbaLista(
              perfil: 'professor',
              nomeSingular: 'professor',
              searchQuery: _searchQuery,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go('/coordenacao/usuarios/novo'),
          icon: const Icon(Icons.add),
          label: const Text('Novo usuário'),
        ),
      ),
    );
  }
}

class _UsuariosAbaLista extends ConsumerWidget {
  final String perfil;
  final String nomeSingular;
  final String searchQuery;

  const _UsuariosAbaLista({
    required this.perfil,
    required this.nomeSingular,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuariosAsync = ref.watch(usuariosPorPerfilProvider(perfil));

    return usuariosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Falha ao carregar lista.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                err.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref
                    .read(usuariosPorPerfilProvider(perfil).notifier)
                    .refresh(),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
      data: (usuarios) {
        final filtered = usuarios.where((u) {
          if (searchQuery.isEmpty) return true;
          return u.nome.toLowerCase().contains(searchQuery);
        }).toList();

        if (filtered.isEmpty) {
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(usuariosPorPerfilProvider(perfil).notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 300,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        searchQuery.isNotEmpty
                            ? 'Nenhum usuário encontrado para "$searchQuery".'
                            : 'Nenhum $nomeSingular cadastrado. Toque em + para adicionar.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () =>
              ref.read(usuariosPorPerfilProvider(perfil).notifier).refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final user = filtered[index];
              return ListTile(
                title: Text(
                  user.nome,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(user.cpfMascarado),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user.perfil == 'aluno')
                      IconButton(
                        icon: const Icon(Icons.folder_shared_outlined, color: Color(0xFF005A9C)),
                        tooltip: 'Ver Dossiê do Aluno',
                        onPressed: () => context.push('/coordenacao/alunos/${user.id}/dossie'),
                      ),
                    UsuarioStatusChip(ativo: user.ativo),
                  ],
                ),
                onTap: () => context.go(
                  '/coordenacao/usuarios/${user.id}/editar',
                  extra: user,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
