import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/conversas_provider.dart';

class ConversasListaScreen extends ConsumerWidget {
  const ConversasListaScreen({super.key});

  String _formatarDataRelativa(DateTime? date) {
    if (date == null) return '';
    final agora = DateTime.now();
    final diff = agora.difference(date);

    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    if (diff.inDays == 1) return 'ontem';
    if (diff.inDays < 7) return 'há ${diff.inDays} dias';

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  String _formatarPerfil(String p) {
    switch (p.toLowerCase().trim()) {
      case 'aluno':
        return 'Aluno';
      case 'supervisor':
        return 'Supervisor';
      case 'professor':
        return 'Professor';
      case 'coordenacao':
      case 'coordenador':
        return 'Coordenador';
      default:
        return p.isNotEmpty ? p[0].toUpperCase() + p.substring(1) : 'Usuário';
    }
  }

  Color _corPerfil(String p) {
    switch (p.toLowerCase().trim()) {
      case 'aluno':
        return Colors.blue.shade700;
      case 'supervisor':
        return Colors.amber.shade800;
      case 'professor':
        return const Color(0xFF1B6B45);
      case 'coordenacao':
      case 'coordenador':
        return Colors.purple.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversasAsync = ref.watch(conversasStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensagens'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar conversas',
            onPressed: () {
              ref.invalidate(conversasProvider);
              ref.invalidate(conversasStreamProvider);
            },
          ),
        ],
      ),
      body: conversasAsync.when(
        data: (conversas) {
          if (conversas.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(conversasProvider);
                ref.invalidate(conversasStreamProvider);
              },
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Nenhuma conversa ainda.',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Toque no botão + abaixo para iniciar uma nova conversa.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(conversasProvider),
            child: ListView.separated(
              itemCount: conversas.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = conversas[index];
                final inicial = item.outroUsuarioNome.isNotEmpty ? item.outroUsuarioNome[0].toUpperCase() : '?';
                final temNaoLidas = item.mensagensNaoLidas > 0;

                return ListTile(
                  onTap: () => context.push('/chat/${item.id}'),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF1B6B45),
                        child: Text(
                          inicial,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      if (temNaoLidas)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              '${item.mensagensNaoLidas}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.outroUsuarioNome,
                                style: TextStyle(
                                  fontWeight: temNaoLidas ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: _corPerfil(item.outroUsuarioPerfil).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _corPerfil(item.outroUsuarioPerfil).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                _formatarPerfil(item.outroUsuarioPerfil),
                                style: TextStyle(
                                  color: _corPerfil(item.outroUsuarioPerfil),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatarDataRelativa(item.ultimaMensagemData),
                        style: TextStyle(
                          color: temNaoLidas ? const Color(0xFF1B6B45) : Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: temNaoLidas ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    item.ultimaMensagemConteudo ?? 'Iniciou uma conversa',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: temNaoLidas ? Colors.black87 : Colors.grey.shade600,
                      fontWeight: temNaoLidas ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando conversas...')),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Erro ao carregar conversas: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(conversasProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chat/nova'),
        icon: const Icon(Icons.edit_square),
        label: const Text('Nova conversa'),
        backgroundColor: const Color(0xFF1B6B45),
        foregroundColor: Colors.white,
      ),
    );
  }
}
