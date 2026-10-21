import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/conversas_provider.dart';
import '../../widgets/contato_tile.dart';

class NovaConversaScreen extends ConsumerStatefulWidget {
  const NovaConversaScreen({super.key});

  @override
  ConsumerState<NovaConversaScreen> createState() => _NovaConversaScreenState();
}

class _NovaConversaScreenState extends ConsumerState<NovaConversaScreen> {
  final _searchController = TextEditingController();
  String _filtro = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizar(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final contatosAsync = ref.watch(contatosPermitidosProvider);
    final perfilAsync = ref.watch(userProfileProvider);
    final isCoordenador = perfilAsync.value == 'coordenacao';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Conversa'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: AutofillGroup(
              child: TextField(
                controller: _searchController,
                autofillHints: const [AutofillHints.name, AutofillHints.username],
                decoration: InputDecoration(
                  hintText: 'Buscar contato por nome ou perfil...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _filtro.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _filtro = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) => setState(() => _filtro = _normalizar(val)),
              ),
            ),
          ),
          Expanded(
            child: contatosAsync.when(
              data: (contatos) {
                final filtrados = contatos.where((c) {
                  final nomeNorm = _normalizar(c.nome);
                  final perfilNorm = _normalizar(c.perfil);
                  final emailNorm = _normalizar(c.email ?? '');
                  return nomeNorm.contains(_filtro) ||
                      perfilNorm.contains(_filtro) ||
                      emailNorm.contains(_filtro);
                }).toList();

                if (filtrados.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_off_outlined, size: 56, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            _filtro.isEmpty
                                ? 'Nenhum contato disponível.'
                                : 'Nenhum resultado para "$_filtro".',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isCoordenador
                                ? 'Nenhum usuário encontrado no sistema para iniciar conversa.'
                                : 'Você só pode conversar com pessoas vinculadas ao seu campo de estágio.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtrados.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final contato = filtrados[index];
                    return ContatoTile(
                      nome: contato.nome,
                      perfil: contato.perfil,
                      avatarUrl: contato.avatarUrl,
                      onTap: () async {
                        try {
                          final conversaId = await ref
                              .read(conversasServiceProvider)
                              .criarOuAbrirConversa(contato.id);

                          if (context.mounted) {
                            ref.invalidate(conversasProvider);
                            context.pushReplacement('/chat/$conversaId');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erro ao abrir conversa: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando contatos...')),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Erro ao carregar contatos permitidos: $err'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(contatosPermitidosProvider),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
