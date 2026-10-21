import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'conversas_provider.dart';
import 'notificacoes_provider.dart';

class MensagemChat {
  final String id;
  final String conversaId;
  final String remetenteId;
  final String conteudo;
  final bool lida;
  final DateTime createdAt;

  const MensagemChat({
    required this.id,
    required this.conversaId,
    required this.remetenteId,
    required this.conteudo,
    required this.lida,
    required this.createdAt,
  });

  factory MensagemChat.fromJson(Map<String, dynamic> json) {
    return MensagemChat(
      id: (json['id'] ?? '').toString(),
      conversaId: (json['conversa_id'] ?? '').toString(),
      remetenteId: (json['remetente_id'] ?? '').toString(),
      conteudo: (json['conteudo'] ?? '').toString(),
      lida: json['lida'] == true,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

// Estado local em memória para garantir renderização imediata de mensagens enviadas
final mensagensLocaisProvider = StateProvider.family<List<MensagemChat>, String>((ref, conversaId) => []);

final mensagensProvider = FutureProvider.family.autoDispose<List<MensagemChat>, String>((ref, conversaId) async {
  final supabase = ref.read(supabaseClientProvider);
  final locais = ref.watch(mensagensLocaisProvider(conversaId));

  try {
    final response = await supabase
        .from('mensagens')
        .select('*')
        .eq('conversa_id', conversaId)
        .order('created_at', ascending: true);

    final list = response as List;
    final remotas = list.map((json) => MensagemChat.fromJson(json)).toList();

    final combinadas = List<MensagemChat>.from(remotas);

    for (final local in locais) {
      final jaExiste = remotas.any((r) =>
          r.id == local.id ||
          (isUserMatch(r.remetenteId, local.remetenteId) &&
           r.conteudo == local.conteudo &&
           r.createdAt.difference(local.createdAt).abs().inSeconds < 60));

      if (!jaExiste) {
        combinadas.add(local);
      }
    }
    combinadas.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return combinadas;
  } catch (_) {
    return locais;
  }
});

// StreamProvider Realtime para inscricao ao vivo via Supabase Realtime (REPLICA IDENTITY)
final mensagensStreamProvider = StreamProvider.family.autoDispose<List<MensagemChat>, String>((ref, conversaId) {
  final supabase = ref.read(supabaseClientProvider);
  final locais = ref.watch(mensagensLocaisProvider(conversaId));

  // Assiste ao mensagensProvider para reatividade quando ref.invalidate é chamado
  ref.watch(mensagensProvider(conversaId));

  try {
    return supabase
        .from('mensagens')
        .stream(primaryKey: ['id'])
        .eq('conversa_id', conversaId)
        .order('created_at', ascending: true)
        .map((list) {
          final remotas = list.map((json) => MensagemChat.fromJson(json)).toList();
          final combinadas = List<MensagemChat>.from(remotas);

          for (final local in locais) {
            final jaExiste = remotas.any((r) =>
                r.id == local.id ||
                (isUserMatch(r.remetenteId, local.remetenteId) &&
                 r.conteudo == local.conteudo &&
                 r.createdAt.difference(local.createdAt).abs().inSeconds < 60));

            if (!jaExiste) {
              combinadas.add(local);
            }
          }
          combinadas.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return combinadas;
        });
  } catch (_) {
    return Stream.value(locais);
  }
});

class MensagensService {
  final Ref ref;

  MensagensService(this.ref);

  Future<void> enviarMensagem(String conversaId, String conteudo) async {
    final texto = conteudo.trim();
    if (texto.isEmpty) {
      throw ArgumentError('A mensagem não pode ser vazia.');
    }
    if (texto.length > 5000) {
      throw ArgumentError('A mensagem não pode ter mais de 5000 caracteres.');
    }

    final supabase = ref.read(supabaseClientProvider);
    final meId = ref.read(currentUserIdProvider);

    final novaMensagem = MensagemChat(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversaId: conversaId,
      remetenteId: meId,
      conteudo: texto,
      lida: false,
      createdAt: DateTime.now(),
    );

    // 1. Adiciona instantaneamente no estado local para que apareça na tela do chat imediatamente
    ref.read(mensagensLocaisProvider(conversaId).notifier).update((list) => [...list, novaMensagem]);

    // 2. Atualiza a lista de conversas locais e identifica o destinatário da mensagem
    String destinatarioId = '';

    ref.read(conversasLocaisProvider.notifier).update((listaConversas) {
      final now = DateTime.now();
      final index = listaConversas.indexWhere((c) => c.id == conversaId);
      if (index >= 0) {
        final ex = listaConversas[index];
        destinatarioId = isUserMatch(ex.participante1Id, meId) ? ex.participante2Id : ex.participante1Id;
        final listMsgs = ref.read(mensagensLocaisProvider(conversaId));
        final naoLidas = listMsgs.where((m) => !isUserMatch(m.remetenteId, meId) && !m.lida).length;

        final updated = ConversaItem(
          id: ex.id,
          participante1Id: ex.participante1Id,
          participante2Id: ex.participante2Id,
          outroUsuarioId: ex.outroUsuarioId,
          outroUsuarioNome: ex.outroUsuarioNome,
          outroUsuarioPerfil: ex.outroUsuarioPerfil,
          outroUsuarioAvatar: ex.outroUsuarioAvatar,
          ultimaMensagemConteudo: texto,
          ultimaMensagemData: now,
          mensagensNaoLidas: naoLidas,
        );
        final list = List<ConversaItem>.from(listaConversas);
        list[index] = updated;
        return list;
      }
      return listaConversas;
    });

    if (destinatarioId.isEmpty) {
      final convList = ref.read(conversasProvider).value ?? [];
      final found = convList.where((c) => c.id == conversaId).toList();
      if (found.isNotEmpty) {
        destinatarioId = found.first.outroUsuarioId;
      } else {
        try {
          final res = await supabase
              .from('conversas')
              .select('participante_1_id, participante_2_id')
              .eq('id', conversaId)
              .maybeSingle();
          if (res != null) {
            final p1 = (res['participante_1_id'] ?? '').toString();
            final p2 = (res['participante_2_id'] ?? '').toString();
            destinatarioId = isUserMatch(p1, meId) ? p2 : p1;
          }
        } catch (_) {}
      }
    }

    if (destinatarioId.isEmpty) {
      debugPrint('[enviarMensagem] ERRO CRÍTICO: Não foi possível determinar o destinatário para a conversa $conversaId.');
      throw StateError('Destinatário não identificado para a conversa $conversaId');
    }

    // 3. Força atualização reativa dos provedores de conversas
    ref.invalidate(conversasProvider);
    ref.invalidate(conversasStreamProvider);

    // 4. Gera notificação direcionada ao destinatário e ao remetente
    try {
      final meUsuarioMap = await ref.read(usuarioAtualProvider.future);
      final remetenteNome = meUsuarioMap['nome'] ?? 'Usuário';
      final remetentePerfil = meUsuarioMap['perfil'] ?? 'Usuário';
      final previewText = texto.length > 60 ? '${texto.substring(0, 60)}...' : texto;
      final notificacaoMsg = '$remetenteNome ($remetentePerfil) enviou: "$previewText"';

      final novaNotif = NotificacaoLocalItem(
        id: 'notif-msg-${DateTime.now().millisecondsSinceEpoch}',
        destinatarioId: destinatarioId,
        remetenteId: meId,
        remetenteNome: remetenteNome,
        remetentePerfil: remetentePerfil,
        titulo: 'Mensagem enviada',
        mensagem: notificacaoMsg,
        tipo: 'nova_mensagem',
        referenciaTipo: 'conversa',
        referenciaId: conversaId,
        dataCriacao: Notificacao.formatarDataHora(DateTime.now()),
        createdAt: DateTime.now(),
        lida: false,
      );

      ref.read(notificacoesLocaisProvider.notifier).update((list) => [novaNotif, ...list]);
      ref.read(notificacoesProvider.notifier).loadNotificacoes();

      await supabase.from('notificacoes').insert({
        'destinatario_id': destinatarioId,
        'tipo': 'nova_mensagem',
        'titulo': 'Nova mensagem',
        'corpo': notificacaoMsg,
        'referencia_tipo': 'conversa',
        'referencia_id': conversaId,
        'lida': false,
        if (meId.isNotEmpty) 'created_by': meId,
      });
    } catch (_) {}

    // 5. Persiste a mensagem no Supabase DB se a conexão/sessão estiver disponível
    try {
      await supabase.from('mensagens').insert({
        'conversa_id': conversaId,
        'remetente_id': meId,
        'conteudo': texto,
        'lida': false,
      });

      // Remove a mensagem temporária do estado local pois ela foi confirmada no Supabase
      ref.read(mensagensLocaisProvider(conversaId).notifier).update(
        (list) => list.where((m) => m.id != novaMensagem.id).toList(),
      );
    } catch (_) {
      // Mantém a mensagem visível em tela via mensagensLocaisProvider mesmo se o Supabase estiver em fallback
    }
  }

  Future<void> marcarComoLidas(String conversaId) async {
    final supabase = ref.read(supabaseClientProvider);
    final meId = ref.read(currentUserIdProvider);

    if (meId.isEmpty) return;

    // Atualiza estado local de mensagens
    ref.read(mensagensLocaisProvider(conversaId).notifier).update((list) {
      return list.map((m) {
        if (!isUserMatch(m.remetenteId, meId)) {
          return MensagemChat(
            id: m.id,
            conversaId: m.conversaId,
            remetenteId: m.remetenteId,
            conteudo: m.conteudo,
            lida: true,
            createdAt: m.createdAt,
          );
        }
        return m;
      }).toList();
    });

    // Zera mensagens não lidas no estado local de conversas
    ref.read(conversasLocaisProvider.notifier).update((listaConversas) {
      final index = listaConversas.indexWhere((c) => c.id == conversaId);
      if (index >= 0) {
        final ex = listaConversas[index];
        final updated = ConversaItem(
          id: ex.id,
          participante1Id: ex.participante1Id,
          participante2Id: ex.participante2Id,
          outroUsuarioId: ex.outroUsuarioId,
          outroUsuarioNome: ex.outroUsuarioNome,
          outroUsuarioPerfil: ex.outroUsuarioPerfil,
          outroUsuarioAvatar: ex.outroUsuarioAvatar,
          ultimaMensagemConteudo: ex.ultimaMensagemConteudo,
          ultimaMensagemData: ex.ultimaMensagemData,
          mensagensNaoLidas: 0,
        );
        final list = List<ConversaItem>.from(listaConversas);
        list[index] = updated;
        return list;
      }
      return listaConversas;
    });

    ref.invalidate(conversasProvider);
    ref.invalidate(conversasStreamProvider);

    try {
      await supabase
          .from('mensagens')
          .update({'lida': true})
          .eq('conversa_id', conversaId)
          .neq('remetente_id', meId)
          .eq('lida', false);
    } catch (_) {}
  }
}

final mensagensServiceProvider = Provider<MensagensService>((ref) => MensagensService(ref));

