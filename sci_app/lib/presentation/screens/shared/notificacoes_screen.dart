import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/conversas_provider.dart';
import '../../../providers/notificacoes_provider.dart';

class NotificacoesScreen extends ConsumerStatefulWidget {
  const NotificacoesScreen({super.key});

  @override
  ConsumerState<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends ConsumerState<NotificacoesScreen> {
  String _filtroSelecionado = 'todas'; // 'todas', 'nao_lidas', 'mensagem', 'atualizacao', 'informacao'

  String _formatarPerfil(String? p) {
    switch ((p ?? '').toLowerCase().trim()) {
      case 'aluno':
        return 'Aluno';
      case 'supervisor':
        return 'Supervisor';
      case 'professor':
        return 'Professor';
      case 'coordenacao':
      case 'coordenador':
        return 'Coordenação';
      default:
        return '';
    }
  }

  ({IconData icon, Color color, String badgeLabel}) _estiloNotificacao(Notificacao n) {
    final tipo = (n.tipo ?? '').toLowerCase();
    final cat = n.categoria;

    if (cat == 'mensagem' || tipo.contains('mensagem')) {
      final isEnviada = tipo == 'mensagem_enviada';
      return (
        icon: isEnviada ? Icons.outbox_rounded : Icons.mark_chat_unread_rounded,
        color: isEnviada ? Colors.teal.shade700 : Colors.indigo.shade600,
        badgeLabel: isEnviada ? 'MENSAGEM ENVIADA' : 'MENSAGEM RECEBIDA',
      );
    }

    if (tipo.contains('avaliacao') || n.referenciaTipo == 'avaliacao') {
      final validada = tipo.contains('validada');
      return (
        icon: validada ? Icons.verified_rounded : Icons.assignment_turned_in_rounded,
        color: validada ? Colors.green.shade700 : Colors.deepPurple.shade600,
        badgeLabel: 'AVALIAÇÃO',
      );
    }

    if (tipo.contains('ativ') || n.referenciaTipo == 'atividade') {
      return (
        icon: Icons.checklist_rtl_rounded,
        color: Colors.orange.shade800,
        badgeLabel: 'ATIVIDADE',
      );
    }

    if (tipo.contains('freq') || n.referenciaTipo == 'frequencia') {
      if (tipo.contains('rejeit') || tipo.contains('recus')) {
        return (
          icon: Icons.cancel_rounded,
          color: Colors.red.shade700,
          badgeLabel: 'FREQUÊNCIA',
        );
      }
      if (tipo.contains('valid') || tipo.contains('ratific')) {
        return (
          icon: Icons.check_circle_rounded,
          color: Colors.green.shade700,
          badgeLabel: 'FREQUÊNCIA',
        );
      }
      return (
        icon: Icons.access_time_filled_rounded,
        color: Colors.amber.shade800,
        badgeLabel: 'FREQUÊNCIA',
      );
    }

    if (tipo == 'erro') {
      return (
        icon: Icons.error_rounded,
        color: Colors.red.shade700,
        badgeLabel: 'ALERTA',
      );
    }
    if (tipo == 'alerta') {
      return (
        icon: Icons.warning_amber_rounded,
        color: Colors.orange.shade800,
        badgeLabel: 'AVISO',
      );
    }

    return (
      icon: Icons.notifications_active_rounded,
      color: const Color(0xFF1B6B45),
      badgeLabel: 'INFORMAÇÃO',
    );
  }

  void _abrirDestinoNotificacao(BuildContext context, Notificacao n) {
    if (!n.lida) {
      ref.read(notificacoesProvider.notifier).marcarComoLida(n.id);
    }

    final refTipo = (n.referenciaTipo ?? '').toLowerCase();
    final refId = n.referenciaId;

    if (refTipo == 'conversa' && refId != null && refId.isNotEmpty) {
      context.push('/chat/$refId');
      return;
    }

    if (refTipo == 'avaliacao' && refId != null && refId.isNotEmpty) {
      final perfil = ref.read(userProfileProvider).value;
      if (perfil == 'coordenacao' && (n.tipo ?? '').contains('submetida')) {
        context.push('/avaliacao/$refId/validar');
      } else {
        context.push('/avaliacao/$refId');
      }
      return;
    }

    final freqId = n.frequenciaId ?? (refTipo == 'frequencia' ? refId : null);
    if (freqId != null && freqId.isNotEmpty) {
      context.push('/frequencia/$freqId/auditoria');
      return;
    }

    if (refTipo == 'atividade') {
      final perfil = ref.read(userProfileProvider).value;
      if (perfil == 'supervisor' && refId != null && refId.isNotEmpty) {
        context.push('/supervisor/atividades/$refId/validar');
      } else if (perfil == 'aluno') {
        context.go('/aluno/atividades');
      } else {
        _exibirDetalheModal(context, n);
      }
      return;
    }

    _exibirDetalheModal(context, n);
  }

  void _exibirDetalheModal(BuildContext context, Notificacao n) {
    final estilo = _estiloNotificacao(n);
    final perfilRem = _formatarPerfil(n.remetentePerfil);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: estilo.color.withValues(alpha: 0.14),
                  child: Icon(estilo.icon, color: estilo.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        estilo.badgeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: estilo.color,
                        ),
                      ),
                      Text(
                        n.titulo,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            if (n.remetenteNome != null && n.remetenteNome!.isNotEmpty) ...[
              Text(
                'Enviado / Atualizado por: ${n.remetenteNome}${perfilRem.isNotEmpty ? ' ($perfilRem)' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
            ],
            if (n.destinatarioNome != null && n.destinatarioNome!.isNotEmpty) ...[
              Text(
                'Destinatário: ${n.destinatarioNome}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                n.mensagem,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Data: ${n.dataCriacao}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('FECHAR'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificacoesAsync = ref.watch(notificacoesStreamProvider);
    final meId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Central de Notificações e Atualizações'),
        actions: [
          IconButton(
            tooltip: 'Atualizar lista',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(notificacoesProvider.notifier).loadNotificacoes();
            },
          ),
          IconButton(
            tooltip: 'Marcar todas como lidas',
            icon: const Icon(Icons.done_all_rounded),
            onPressed: () {
              ref.read(notificacoesProvider.notifier).marcarTodasComoLidas();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Todas as notificações foram marcadas como lidas.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: notificacoesAsync.when(
        data: (notifs) {
          final naoLidasCount = notifs.where((n) => !n.lida).length;
          final msgCount = notifs.where((n) => n.categoria == 'mensagem').length;
          final atualizacoesCount = notifs.where((n) => n.categoria == 'atualizacao').length;

          final filtradas = notifs.where((n) {
            if (_filtroSelecionado == 'nao_lidas') return !n.lida;
            if (_filtroSelecionado == 'mensagem') return n.categoria == 'mensagem';
            if (_filtroSelecionado == 'atualizacao') return n.categoria == 'atualizacao';
            if (_filtroSelecionado == 'informacao') return n.categoria == 'informacao';
            return true;
          }).toList();

          return Column(
            children: [
              // Barra de Filtros por Categoria
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('todas', 'Todas (${notifs.length})', Icons.all_inbox_rounded),
                      const SizedBox(width: 8),
                      _buildFilterChip('nao_lidas', 'Não lidas ($naoLidasCount)', Icons.mark_email_unread_outlined),
                      const SizedBox(width: 8),
                      _buildFilterChip('mensagem', 'Mensagens ($msgCount)', Icons.forum_outlined),
                      const SizedBox(width: 8),
                      _buildFilterChip('atualizacao', 'Atualizações ($atualizacoesCount)', Icons.sync_alt_rounded),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: filtradas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhuma notificação encontrada para este filtro.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref.read(notificacoesProvider.notifier).loadNotificacoes(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filtradas.length,
                          itemBuilder: (context, index) {
                            final n = filtradas[index];
                            final estilo = _estiloNotificacao(n);
                            final isRemMe = n.remetenteId != null && isUserMatch(n.remetenteId!, meId);
                            final remLabel = isRemMe
                                ? 'Você'
                                : (n.remetenteNome ?? '');
                            final perfilRem = _formatarPerfil(n.remetentePerfil);
                            final destLabel = n.destinatarioNome != null &&
                                    n.destinatarioId != null &&
                                    isUserMatch(n.destinatarioId!, meId)
                                ? 'Você'
                                : (n.destinatarioNome ?? '');

                            String participantesInfo = '';
                            if (remLabel.isNotEmpty && destLabel.isNotEmpty && remLabel != destLabel) {
                              participantesInfo =
                                  '$remLabel${perfilRem.isNotEmpty && !isRemMe ? ' ($perfilRem)' : ''} → $destLabel';
                            } else if (remLabel.isNotEmpty) {
                              participantesInfo =
                                  '$remLabel${perfilRem.isNotEmpty && !isRemMe ? ' ($perfilRem)' : ''}';
                            }

                            return Card(
                              elevation: n.lida ? 0.5 : 2,
                              color: n.lida
                                  ? Colors.white
                                  : estilo.color.withValues(alpha: 0.06),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: n.lida
                                      ? Colors.grey.shade200
                                      : estilo.color.withValues(alpha: 0.35),
                                  width: n.lida ? 1 : 1.3,
                                ),
                              ),
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _abrirDestinoNotificacao(context, n),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: estilo.color.withValues(alpha: 0.14),
                                        child: Icon(estilo.icon, color: estilo.color, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: estilo.color.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    estilo.badgeLabel,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: estilo.color,
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                ),
                                                if (participantesInfo.isNotEmpty) ...[
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      participantesInfo,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ] else
                                                  const Spacer(),
                                                if (!n.lida)
                                                  Container(
                                                    width: 9,
                                                    height: 9,
                                                    decoration: BoxDecoration(
                                                      color: estilo.color,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              n.titulo,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: n.lida ? FontWeight.w600 : FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              n.mensagem,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                color: n.lida ? Colors.grey.shade700 : Colors.black87,
                                                height: 1.35,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.schedule_rounded, size: 13, color: Colors.grey.shade500),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      n.dataCriacao,
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (!n.lida)
                                                      InkWell(
                                                        onTap: () {
                                                          ref.read(notificacoesProvider.notifier).marcarComoLida(n.id);
                                                        },
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          child: Text(
                                                            'Marcar lida',
                                                            style: TextStyle(
                                                              fontSize: 11.5,
                                                              color: estilo.color,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    Icon(
                                                      Icons.chevron_right_rounded,
                                                      size: 18,
                                                      color: Colors.grey.shade500,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando notificações...')),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Erro ao carregar notificações: $err', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => ref.read(notificacoesProvider.notifier).loadNotificacoes(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String valor, String label, IconData icon) {
    final selecionado = _filtroSelecionado == valor;
    final primary = const Color(0xFF1B6B45);

    return ChoiceChip(
      selected: selecionado,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 16,
        color: selecionado ? Colors.white : primary,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: selecionado ? FontWeight.bold : FontWeight.w600,
          color: selecionado ? Colors.white : Colors.black87,
        ),
      ),
      selectedColor: primary,
      backgroundColor: Colors.grey.shade100,
      onSelected: (_) {
        setState(() {
          _filtroSelecionado = valor;
        });
      },
    );
  }
}
