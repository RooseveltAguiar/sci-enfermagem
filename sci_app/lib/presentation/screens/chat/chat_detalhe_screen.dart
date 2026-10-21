import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/conversas_provider.dart';
import '../../../providers/mensagens_provider.dart';
import '../../widgets/chat_bubble.dart';

class ChatDetalheScreen extends ConsumerStatefulWidget {
  final String conversaId;

  const ChatDetalheScreen({
    super.key,
    required this.conversaId,
  });

  @override
  ConsumerState<ChatDetalheScreen> createState() => _ChatDetalheScreenState();
}

class _ChatDetalheScreenState extends ConsumerState<ChatDetalheScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onTextChanged);
    // Marcar como lidas ao abrir a tela e invalidar a lista de conversas para zerar o badge
    Future.microtask(() async {
      await ref.read(mensagensServiceProvider).marcarComoLidas(widget.conversaId);
      if (mounted) {
        ref.invalidate(conversasProvider);
        ref.invalidate(conversasStreamProvider);
      }
    });
  }

  void _onTextChanged() {
    setState(() {
      _charCount = _inputController.text.length;
    });
  }

  @override
  void dispose() {
    _inputController.removeListener(_onTextChanged);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _enviarMensagem() async {
    final texto = _inputController.text.trim();
    if (texto.isEmpty || _isSending) return;

    if (texto.length > 5000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mensagem muito longa! O limite máximo é de 5000 caracteres.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await ref.read(mensagensServiceProvider).enviarMensagem(widget.conversaId, texto);
      
      _inputController.clear();
      ref.invalidate(mensagensProvider(widget.conversaId));
      ref.invalidate(conversasProvider);

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      // Em caso de erro: MANTEM O TEXTO NO CAMPO DE TEXTO (sem perder a mensagem digitada)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao enviar. Tente novamente: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
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
  Widget build(BuildContext context) {
    final meId = ref.watch(currentUserIdProvider);
    final mensagensAsync = ref.watch(mensagensStreamProvider(widget.conversaId));
    final conversasAsync = ref.watch(conversasProvider);
    final contatosAsync = ref.watch(contatosPermitidosProvider);

    final conversas = conversasAsync.asData?.value ?? [];
    final contatos = contatosAsync.asData?.value ?? [];

    ConversaItem? conversa = conversas.cast<ConversaItem?>().firstWhere(
      (c) => c?.id == widget.conversaId,
      orElse: () => null,
    );

    String outroNome = conversa?.outroUsuarioNome ?? '';
    String outroPerfil = conversa?.outroUsuarioPerfil ?? '';

    // Se o nome ou perfil não vieram da conversa, busca na lista de contatos permitidos
    if (outroNome.isEmpty || outroNome == 'Chat' || outroNome == 'Usuário') {
      for (final c in contatos) {
        if (c.id == conversa?.outroUsuarioId || widget.conversaId.contains(c.id)) {
          outroNome = c.nome;
          outroPerfil = c.perfil;
          break;
        }
      }
    }

    if (outroNome.isEmpty || outroNome == 'Chat') {
      outroNome = 'Contato SCI';
    }
    if (outroPerfil.isEmpty || outroPerfil == 'usuario') {
      outroPerfil = 'aluno';
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF1B6B45),
              child: Text(
                outroNome.isNotEmpty ? outroNome[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outroNome,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _corPerfil(outroPerfil).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _corPerfil(outroPerfil).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _formatarPerfil(outroPerfil).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        color: _corPerfil(outroPerfil),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: mensagensAsync.when(
                data: (mensagens) {
                  if (mensagens.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.forum_outlined, size: 56, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'Diga olá! Esta conversa está vazia.',
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: mensagens.length,
                    itemBuilder: (context, index) {
                      final msg = mensagens[index];
                      final isMe = isUserMatch(msg.remetenteId, meId);

                      return ChatBubble(
                        conteudo: msg.conteudo,
                        isMe: isMe,
                        timestamp: msg.createdAt,
                        lida: msg.lida,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando mensagens...')),
                error: (err, stack) => Center(
                  child: Text('Erro ao carregar mensagens: $err'),
                ),
              ),
            ),

            // Contador de Caracteres se proximo do limite (> 4500)
            if (_charCount > 4500)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '$_charCount / 5000',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _charCount > 5000 ? Colors.red : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),

            // Campo de Texto e Botao Enviar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      maxLength: 5000,
                      maxLines: 4,
                      minLines: 1,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      decoration: InputDecoration(
                        hintText: 'Digite sua mensagem...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF1B6B45),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSending ? null : _enviarMensagem,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
