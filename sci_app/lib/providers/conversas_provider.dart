import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';

class ContatoPermitido {
  final String id;
  final String nome;
  final String perfil;
  final String? email;
  final String? avatarUrl;

  const ContatoPermitido({
    required this.id,
    required this.nome,
    required this.perfil,
    this.email,
    this.avatarUrl,
  });

  factory ContatoPermitido.fromJson(Map<String, dynamic> json) {
    return ContatoPermitido(
      id: (json['contato_id'] ?? json['id'] ?? json['usuario_id'] ?? '').toString(),
      nome: (json['contato_nome'] ?? json['nome'] ?? json['nome_completo'] ?? 'Usuário').toString(),
      perfil: (json['contato_perfil'] ?? json['perfil'] ?? json['papel'] ?? 'usuario').toString(),
      email: json['email']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}

class ConversaItem {
  final String id;
  final String participante1Id;
  final String participante2Id;
  final String outroUsuarioId;
  final String outroUsuarioNome;
  final String outroUsuarioPerfil;
  final String? outroUsuarioAvatar;
  final String? ultimaMensagemConteudo;
  final DateTime? ultimaMensagemData;
  final int mensagensNaoLidas;

  const ConversaItem({
    required this.id,
    required this.participante1Id,
    required this.participante2Id,
    required this.outroUsuarioId,
    required this.outroUsuarioNome,
    required this.outroUsuarioPerfil,
    this.outroUsuarioAvatar,
    this.ultimaMensagemConteudo,
    this.ultimaMensagemData,
    this.mensagensNaoLidas = 0,
  });

  factory ConversaItem.fromJson(Map<String, dynamic> json, String meId) {
    final p1 = (json['participante_1_id'] ?? '').toString();
    final p2 = (json['participante_2_id'] ?? '').toString();
    final isP1Me = isUserMatch(p1, meId);

    final outroId = isP1Me ? p2 : p1;
    final outroMap = isP1Me ? json['participante_2'] : json['participante_1'];

    String nome = 'Usuário';
    String perfil = 'usuario';
    String? avatar;

    if (outroMap is Map<String, dynamic>) {
      nome = (outroMap['nome'] ?? 'Usuário').toString();
      perfil = (outroMap['perfil'] ?? 'usuario').toString();
      avatar = outroMap['avatar_url']?.toString();
    } else if (json['outro_nome'] != null) {
      nome = json['outro_nome'].toString();
      perfil = (json['outro_perfil'] ?? 'usuario').toString();
    }

    String? conteudo = json['ultima_mensagem_conteudo']?.toString();
    String? dateStr = json['ultima_mensagem_created_at']?.toString() ?? json['created_at']?.toString();
    int naoLidas = (json['nao_lidas'] as num?)?.toInt() ?? 0;

    if (json['ultima_mensagem'] is Map<String, dynamic>) {
      final ultMsg = json['ultima_mensagem'] as Map<String, dynamic>;
      conteudo = ultMsg['conteudo']?.toString() ?? conteudo;
      dateStr = ultMsg['created_at']?.toString() ?? dateStr;
    } else if (json['mensagens'] is List && (json['mensagens'] as List).isNotEmpty) {
      final msgs = List<Map<String, dynamic>>.from(json['mensagens'] as List)
        ..sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
      final topMsg = msgs.first;
      conteudo = topMsg['conteudo']?.toString();
      dateStr = topMsg['created_at']?.toString();
      if (json['nao_lidas'] == null) {
        naoLidas = msgs.where((m) => !isUserMatch(m['remetente_id']?.toString() ?? '', meId) && m['lida'] != true).length;
      }
    }

    return ConversaItem(
      id: (json['id'] ?? '').toString(),
      participante1Id: p1,
      participante2Id: p2,
      outroUsuarioId: outroId,
      outroUsuarioNome: nome,
      outroUsuarioPerfil: perfil,
      outroUsuarioAvatar: avatar,
      ultimaMensagemConteudo: conteudo,
      ultimaMensagemData: dateStr != null ? DateTime.tryParse(dateStr) : null,
      mensagensNaoLidas: naoLidas,
    );
  }
}

// Provedor de ID do usuário atual sincronizado com a sessão ativa
final currentUserIdProvider = Provider<String>((ref) {
  ref.watch(authStateProvider);
  final supabase = ref.watch(supabaseClientProvider);
  final user = supabase.auth.currentUser;
  return user?.id ?? '';
});

// Comparador estrito de identidade de usuário por UUID
bool isUserMatch(String targetId, String activeUserId) {
  if (targetId.isEmpty || activeUserId.isEmpty) return false;
  return targetId.trim().toLowerCase() == activeUserId.trim().toLowerCase();
}

// Estado local de conversas para persistência em memória durante sessões
final conversasLocaisProvider = StateProvider<List<ConversaItem>>((ref) => []);

final contatosPermitidosProvider = FutureProvider.autoDispose<List<ContatoPermitido>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final meId = ref.watch(currentUserIdProvider);

  if (meId.isEmpty) return [];

  // Exclusão estrita do próprio usuário por UUID (c.id == meId)
  bool isMe(ContatoPermitido c) {
    if (c.id.isEmpty) return false;
    return isUserMatch(c.id, meId);
  }

  final idSet = <String>{};
  final resultList = <ContatoPermitido>[];

  void addContato(ContatoPermitido c) {
    if (c.id.isNotEmpty && !isMe(c) && idSet.add(c.id.toLowerCase())) {
      resultList.add(c);
    }
  }

  // 1. Consulta prioritária via 'vw_contatos_permitidos' (regra do BUG-CHAT-002)
  try {
    final response = await supabase
        .from('vw_contatos_permitidos')
        .select('*');
    final list = response as List;
    for (final json in list) {
      addContato(ContatoPermitido.fromJson(Map<String, dynamic>.from(json as Map)));
    }
  } catch (e) {
    debugPrint('[contatosPermitidosProvider] Falha ao consultar vw_contatos_permitidos: $e');
  }

  // 2. Fallback resiliente: tabela usuarios direta excluindo explicitamente o próprio usuário por ID
  if (resultList.isEmpty) {
    try {
      final response = await supabase
          .from('usuarios')
          .select('id, nome, perfil, email')
          .neq('id', meId);
      final list = response as List;
      for (final json in list) {
        addContato(ContatoPermitido.fromJson(Map<String, dynamic>.from(json as Map)));
      }
    } catch (e) {
      debugPrint('[contatosPermitidosProvider] Falha ao consultar usuarios: $e');
    }
  }

  resultList.sort((a, b) => a.nome.compareTo(b.nome));
  return resultList;
});

final conversasProvider = FutureProvider.autoDispose<List<ConversaItem>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final meId = ref.watch(currentUserIdProvider);
  final locais = ref.watch(conversasLocaisProvider);

  final resultMap = <String, ConversaItem>{};

  if (meId.isNotEmpty) {
    dynamic response;
    // 1. Consulta com Foreign Keys explícitas do Supabase
    try {
      response = await supabase
          .from('conversas')
          .select('''
            *,
            participante_1:usuarios!conversas_participante_1_id_fkey(id, nome, perfil),
            participante_2:usuarios!conversas_participante_2_id_fkey(id, nome, perfil),
            mensagens(id, conteudo, lida, remetente_id, created_at)
          ''')
          .or('participante_1_id.eq.$meId,participante_2_id.eq.$meId')
          .order('created_at', ascending: false);
    } catch (e1) {
      debugPrint('[conversasProvider] Tentativa 1 com FKey explícita falhou: $e1');

      // 2. Consulta com joins automáticos de foreign key
      try {
        response = await supabase
            .from('conversas')
            .select('''
              *,
              participante_1:usuarios(id, nome, perfil),
              participante_2:usuarios(id, nome, perfil),
              mensagens(id, conteudo, lida, remetente_id, created_at)
            ''')
            .or('participante_1_id.eq.$meId,participante_2_id.eq.$meId')
            .order('created_at', ascending: false);
      } catch (e2) {
        debugPrint('[conversasProvider] Tentativa 2 com join automático falhou: $e2');

        // 3. Fallback resiliente: tabela conversas pura + preenchimento individual de perfis e mensagens
        try {
          final convs = await supabase
              .from('conversas')
              .select('*')
              .or('participante_1_id.eq.$meId,participante_2_id.eq.$meId')
              .order('created_at', ascending: false);

          final rawList = List<Map<String, dynamic>>.from(convs as List);

          for (final item in rawList) {
            final p1Id = item['participante_1_id']?.toString() ?? '';
            final p2Id = item['participante_2_id']?.toString() ?? '';
            final otherId = isUserMatch(p1Id, meId) ? p2Id : p1Id;

            // Busca perfil do outro participante
            if (otherId.isNotEmpty) {
              try {
                final userResp = await supabase
                    .from('usuarios')
                    .select('id, nome, perfil')
                    .eq('id', otherId)
                    .maybeSingle();

                if (userResp != null) {
                  if (isUserMatch(p1Id, meId)) {
                    item['participante_2'] = userResp;
                  } else {
                    item['participante_1'] = userResp;
                  }
                }
              } catch (_) {}
            }

            // Busca última mensagem e não lidas
            final convId = item['id']?.toString();
            if (convId != null) {
              try {
                final msgResp = await supabase
                    .from('mensagens')
                    .select('conteudo, created_at, lida, remetente_id')
                    .eq('conversa_id', convId)
                    .order('created_at', ascending: false)
                    .limit(10);
                if (msgResp.isNotEmpty) {
                  item['ult_conteudo'] = msgResp.first['conteudo']?.toString();
                  item['ult_created_at'] = msgResp.first['created_at']?.toString();
                  int naoLidas = 0;
                  for (final m in msgResp) {
                    final remetente = m['remetente_id']?.toString();
                    final lida = m['lida'] == true;
                    if (!isUserMatch(remetente ?? '', meId) && !lida) {
                      naoLidas++;
                    }
                  }
                  item['nao_lidas'] = naoLidas;
                }
              } catch (_) {}
            }
          }
          response = rawList;
        } catch (e3) {
          debugPrint('[conversasProvider] Falha geral ao carregar conversas: $e3');
          response = [];
        }
      }
    }

    if (response is List) {
      for (final raw in response) {
        final map = Map<String, dynamic>.from(raw as Map);
        final convItem = ConversaItem.fromJson(map, meId);
        resultMap[convItem.id] = convItem;
      }
    }
  }

  // Mescla com as conversas locais apenas se pertencer ao usuário e não estiver no banco
  for (final localItem in locais) {
    final isP1Me = isUserMatch(localItem.participante1Id, meId);
    final isP2Me = isUserMatch(localItem.participante2Id, meId);

    if (isP1Me || isP2Me) {
      if (!resultMap.containsKey(localItem.id)) {
        resultMap[localItem.id] = localItem;
      }
    }
  }

  final resultList = resultMap.values.toList();
  resultList.sort((a, b) {
    if (a.ultimaMensagemData == null && b.ultimaMensagemData == null) return 0;
    if (a.ultimaMensagemData == null) return 1;
    if (b.ultimaMensagemData == null) return -1;
    return b.ultimaMensagemData!.compareTo(a.ultimaMensagemData!);
  });

  return resultList;
});

// StreamProvider Realtime para inscrição ao vivo escopada por participante e mensagens
final conversasStreamProvider = StreamProvider.autoDispose<List<ConversaItem>>((ref) {
  final supabase = ref.read(supabaseClientProvider);
  final meId = ref.watch(currentUserIdProvider);

  if (meId.isEmpty) return Stream.value([]);

  ref.watch(conversasProvider);

  final controller = StreamController<List<ConversaItem>>.broadcast();

  Future<void> emitLatest() async {
    try {
      final fresh = await ref.refresh(conversasProvider.future);
      if (!controller.isClosed) {
        controller.add(fresh);
      }
    } catch (_) {}
  }

  ref.read(conversasProvider.future).then((initialList) {
    if (!controller.isClosed) {
      controller.add(initialList);
    }
  }).catchError((_) {});

  RealtimeChannel? channelP1;
  RealtimeChannel? channelP2;
  RealtimeChannel? channelMsg;

  try {
    channelP1 = supabase
        .channel('conversas_realtime_p1_$meId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversas',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'participante_1_id',
            value: meId,
          ),
          callback: (_) => emitLatest(),
        )
        .subscribe();
  } catch (e) {
    debugPrint('[conversasStreamProvider] Falha ao assinar conversas_p1: $e');
  }

  try {
    channelP2 = supabase
        .channel('conversas_realtime_p2_$meId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversas',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'participante_2_id',
            value: meId,
          ),
          callback: (_) => emitLatest(),
        )
        .subscribe();
  } catch (e) {
    debugPrint('[conversasStreamProvider] Falha ao assinar conversas_p2: $e');
  }

  try {
    channelMsg = supabase
        .channel('mensagens_realtime_all_$meId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'mensagens',
          callback: (_) => emitLatest(),
        )
        .subscribe();
  } catch (e) {
    debugPrint('[conversasStreamProvider] Falha ao assinar mensagens_all: $e');
  }

  ref.onDispose(() {
    channelP1?.unsubscribe();
    channelP2?.unsubscribe();
    channelMsg?.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

class ConversasService {
  final Ref ref;
  ConversasService(this.ref);

  Future<String> criarOuAbrirConversa(String outroUsuarioId) => iniciarOuBuscarConversa(outroUsuarioId);

  Future<String> iniciarOuBuscarConversa(String outroUsuarioId) async {
    final supabase = ref.read(supabaseClientProvider);
    final meId = ref.read(currentUserIdProvider);

    if (meId.isEmpty || outroUsuarioId.isEmpty) {
      throw ArgumentError('IDs de usuário inválidos para iniciar conversa');
    }

    final p1 = meId.compareTo(outroUsuarioId) < 0 ? meId : outroUsuarioId;
    final p2 = meId.compareTo(outroUsuarioId) < 0 ? outroUsuarioId : meId;

    try {
      // 1. Verifica se conversa já existe no banco
      final existenteList = await supabase
          .from('conversas')
          .select('id')
          .or('and(participante_1_id.eq.$p1,participante_2_id.eq.$p2),and(participante_1_id.eq.$p2,participante_2_id.eq.$p1)')
          .limit(1);

      if (existenteList.isNotEmpty) {
        final idDb = existenteList.first['id'].toString();
        await _registrarConversaLocal(idDb, meId, outroUsuarioId);
        ref.invalidate(conversasProvider);
        ref.invalidate(conversasStreamProvider);
        return idDb;
      }

      // 2. Se não existe, insere nova conversa
      final nova = await supabase
          .from('conversas')
          .insert({
            'participante_1_id': p1,
            'participante_2_id': p2,
          })
          .select('id')
          .single();

      final idDb = nova['id'].toString();
      await _registrarConversaLocal(idDb, meId, outroUsuarioId);
      ref.invalidate(conversasProvider);
      ref.invalidate(conversasStreamProvider);
      return idDb;
    } catch (e) {
      debugPrint('[iniciarOuBuscarConversa] Erro no banco: $e');
      rethrow;
    }
  }

  Future<void> _registrarConversaLocal(String conversaId, String meId, String outroUsuarioId) async {
    final contatosAsync = ref.read(contatosPermitidosProvider);
    final contatos = contatosAsync.value ?? [];

    String nome = '';
    String perfil = '';
    final found = contatos.where((c) => isUserMatch(c.id, outroUsuarioId)).toList();
    if (found.isNotEmpty) {
      nome = found.first.nome;
      perfil = found.first.perfil;
    } else {
      try {
        final supabase = ref.read(supabaseClientProvider);
        final userResp = await supabase
            .from('usuarios')
            .select('nome, perfil')
            .eq('id', outroUsuarioId)
            .maybeSingle();
        if (userResp != null) {
          nome = (userResp['nome'] ?? '').toString();
          perfil = (userResp['perfil'] ?? '').toString();
        }
      } catch (_) {}
    }

    if (nome.isEmpty) {
      nome = 'Usuário';
      perfil = 'usuario';
    }

    final p1 = meId.compareTo(outroUsuarioId) < 0 ? meId : outroUsuarioId;
    final p2 = meId.compareTo(outroUsuarioId) < 0 ? outroUsuarioId : meId;

    final novaConversa = ConversaItem(
      id: conversaId,
      participante1Id: p1,
      participante2Id: p2,
      outroUsuarioId: outroUsuarioId,
      outroUsuarioNome: nome,
      outroUsuarioPerfil: perfil,
      ultimaMensagemConteudo: null,
      ultimaMensagemData: DateTime.now(),
      mensagensNaoLidas: 0,
    );

    ref.read(conversasLocaisProvider.notifier).update((list) {
      final index = list.indexWhere((c) => c.id == conversaId);
      if (index >= 0) {
        return list;
      }
      return [...list, novaConversa];
    });
  }
}

final conversasServiceProvider = Provider<ConversasService>((ref) => ConversasService(ref));
