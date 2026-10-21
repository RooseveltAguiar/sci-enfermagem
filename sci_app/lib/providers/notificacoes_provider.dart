import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'conversas_provider.dart';

class Notificacao {
  final String id;
  final String titulo;
  final String mensagem;
  final String? tipo;
  final String categoria; // 'mensagem', 'atualizacao', 'informacao'
  final String? frequenciaId;
  final String? referenciaTipo; // 'conversa', 'avaliacao', 'frequencia', 'atividade'
  final String? referenciaId;
  final String? remetenteId;
  final String? remetenteNome;
  final String? remetentePerfil;
  final String? destinatarioId;
  final String? destinatarioNome;
  final String dataCriacao;
  final DateTime createdAt;
  final bool lida;

  Notificacao({
    required this.id,
    required this.titulo,
    required this.mensagem,
    this.tipo,
    required this.categoria,
    this.frequenciaId,
    this.referenciaTipo,
    this.referenciaId,
    this.remetenteId,
    this.remetenteNome,
    this.remetentePerfil,
    this.destinatarioId,
    this.destinatarioNome,
    required this.dataCriacao,
    required this.createdAt,
    required this.lida,
  });

  Notificacao copyWith({
    bool? lida,
    String? remetenteNome,
    String? remetentePerfil,
    String? destinatarioNome,
    String? mensagem,
    String? titulo,
  }) {
    return Notificacao(
      id: id,
      titulo: titulo ?? this.titulo,
      mensagem: mensagem ?? this.mensagem,
      tipo: tipo,
      categoria: categoria,
      frequenciaId: frequenciaId,
      referenciaTipo: referenciaTipo,
      referenciaId: referenciaId,
      remetenteId: remetenteId,
      remetenteNome: remetenteNome ?? this.remetenteNome,
      remetentePerfil: remetentePerfil ?? this.remetentePerfil,
      destinatarioId: destinatarioId,
      destinatarioNome: destinatarioNome ?? this.destinatarioNome,
      dataCriacao: dataCriacao,
      createdAt: createdAt,
      lida: lida ?? this.lida,
    );
  }

  static String inferirCategoria(String? tipo, String? refTipo) {
    final t = (tipo ?? '').toLowerCase();
    final r = (refTipo ?? '').toLowerCase();
    if (t.contains('mensagem') || t.contains('chat') || r == 'conversa' || r == 'mensagem') {
      return 'mensagem';
    }
    if (t.contains('avaliacao') ||
        t.contains('freq') ||
        t.contains('atividade') ||
        t.contains('abono') ||
        t.contains('ratifica') ||
        t.contains('valida') ||
        r == 'avaliacao' ||
        r == 'frequencia' ||
        r == 'atividade') {
      return 'atualizacao';
    }
    return 'informacao';
  }

  static String formatarDataHora(DateTime dt) {
    final local = dt.toLocal();
    final dia = local.day.toString().padLeft(2, '0');
    final mes = local.month.toString().padLeft(2, '0');
    final ano = local.year;
    final hora = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$ano às $hora:$min';
  }

  factory Notificacao.fromJson(
    Map<String, dynamic> json, {
    Map<String, Map<String, String>> usuariosMap = const {},
  }) {
    final rawCreated = (json['created_at'] ?? json['data_criacao'] ?? '').toString();
    final parsedDate = DateTime.tryParse(rawCreated)?.toLocal() ?? DateTime.now();
    final tipoStr = (json['tipo_notificacao'] ?? json['tipo'] ?? 'informacao').toString();
    final refTipo = json['referencia_tipo']?.toString();
    final refId = (json['referencia_id'] ?? json['frequencia_id'] ?? json['frequenciaId'])?.toString();

    final tituloStr = (json['titulo'] ??
            _tituloPadraoPorTipo(tipoStr, refTipo))
        .toString();

    final corpoStr = (json['corpo'] ??
            json['mensagem'] ??
            json['conteudo'] ??
            json['texto'] ??
            json['descricao'] ??
            tituloStr)
        .toString();

    final remId = (json['created_by'] ?? json['remetente_id'] ?? '').toString();
    final destId = (json['destinatario_id'] ?? json['usuario_id'] ?? '').toString();

    final remInfo = usuariosMap[remId];
    final destInfo = usuariosMap[destId];

    return Notificacao(
      id: (json['id'] ?? json['notificacao_id'] ?? '').toString(),
      titulo: tituloStr,
      mensagem: corpoStr,
      tipo: tipoStr,
      categoria: inferirCategoria(tipoStr, refTipo),
      frequenciaId: refTipo == 'frequencia'
          ? refId
          : (json['frequencia_id'] ?? json['frequenciaId'])?.toString(),
      referenciaTipo: refTipo,
      referenciaId: refId,
      remetenteId: remId.isNotEmpty ? remId : null,
      remetenteNome: remInfo?['nome'] ?? json['remetente_nome']?.toString(),
      remetentePerfil: remInfo?['perfil'] ?? json['remetente_perfil']?.toString(),
      destinatarioId: destId.isNotEmpty ? destId : null,
      destinatarioNome: destInfo?['nome'] ?? json['destinatario_nome']?.toString(),
      dataCriacao: formatarDataHora(parsedDate),
      createdAt: parsedDate,
      lida: json['lida'] == true,
    );
  }

  static String _tituloPadraoPorTipo(String tipo, String? refTipo) {
    final t = tipo.toLowerCase();
    if (t == 'nova_mensagem') return 'Nova mensagem recebida';
    if (t == 'mensagem_enviada') return 'Mensagem enviada';
    if (t == 'avaliacao_submetida') return 'Nova avaliação submetida';
    if (t == 'avaliacao_validada') return 'Avaliação validada';
    if (t.contains('freq_validada') || t == 'validado') return 'Frequência validada';
    if (t.contains('freq_ratificada') || t == 'ratificado') return 'Frequência ratificada';
    if (t.contains('freq_rejeitada') || t == 'rejeitado') return 'Frequência rejeitada';
    if (t.contains('freq_pendente')) return 'Registro de frequência pendente';
    if (t.contains('atividade')) return 'Atualização de atividade';
    if (refTipo == 'conversa') return 'Mensagem no Chat';
    if (refTipo == 'avaliacao') return 'Atualização de avaliação';
    if (refTipo == 'frequencia') return 'Atualização de frequência';
    return 'Notificação do Sistema';
  }
}

class NotificacaoLocalItem {
  final String id;
  final String destinatarioId;
  final String? destinatarioNome;
  final String? remetenteId;
  final String? remetenteNome;
  final String? remetentePerfil;
  final String titulo;
  final String mensagem;
  final String? tipo;
  final String? referenciaTipo;
  final String? referenciaId;
  final String? frequenciaId;
  final String dataCriacao;
  final DateTime? createdAt;
  final bool lida;

  const NotificacaoLocalItem({
    required this.id,
    required this.destinatarioId,
    this.destinatarioNome,
    this.remetenteId,
    this.remetenteNome,
    this.remetentePerfil,
    this.titulo = 'Notificação',
    required this.mensagem,
    this.tipo,
    this.referenciaTipo,
    this.referenciaId,
    this.frequenciaId,
    required this.dataCriacao,
    this.createdAt,
    this.lida = false,
  });
}

final notificacoesLocaisProvider = StateProvider<List<NotificacaoLocalItem>>((ref) => []);

// Conjunto de IDs marcados como lidos localmente na sessão (para itens derivados de eventos/mensagens)
final notificacoesLidasIdsProvider = StateProvider<Set<String>>((ref) => <String>{});

class NotificacoesNotifier extends StateNotifier<AsyncValue<List<Notificacao>>> {
  final Ref ref;

  NotificacoesNotifier(this.ref) : super(const AsyncValue.loading());

  Future<void> loadNotificacoes() async {
    final meId = ref.read(currentUserIdProvider);
    final locais = ref.read(notificacoesLocaisProvider);
    final lidasLocalSet = ref.read(notificacoesLidasIdsProvider);

    final resultList = <Notificacao>[];
    final idSet = <String>{};

    try {
      final supabase = ref.read(supabaseClientProvider);

      // 1. Carrega mapa de usuários para resolver nomes e perfis (remetente / destinatário)
      final usuariosMap = <String, Map<String, String>>{};
      try {
        final usrs = await supabase
            .from('usuarios')
            .select('id, nome, perfil');
        for (final u in (usrs as List)) {
          final uid = (u['id'] ?? '').toString();
          if (uid.isNotEmpty) {
            usuariosMap[uid] = {
              'nome': (u['nome'] ?? 'Usuário').toString(),
              'perfil': (u['perfil'] ?? 'usuario').toString(),
            };
          }
        }
      } catch (e) {
        debugPrint('[NotificacoesNotifier] Aviso ao carregar usuarios: $e');
      }

      // 2. Busca notificações oficiais da tabela `notificacoes`
      try {
        final response = await supabase
            .from('notificacoes')
            .select('*')
            .order('created_at', ascending: false)
            .limit(100);

        final list = response as List;
        for (final n in list) {
          final map = Map<String, dynamic>.from(n as Map);
          final destId = (map['destinatario_id'] ?? map['usuario_id'] ?? '').toString();
          final remId = (map['created_by'] ?? '').toString();
          if (destId.isEmpty || destId == meId || remId == meId) {
            var notif = Notificacao.fromJson(map, usuariosMap: usuariosMap);
            if (lidasLocalSet.contains(notif.id)) {
              notif = notif.copyWith(lida: true);
            }
            if (idSet.add(notif.id)) {
              resultList.add(notif);
            }
          }
        }
      } catch (e) {
        debugPrint('[NotificacoesNotifier] Aviso ao carregar tabela notificacoes: $e');
      }

      // 3. Agrega mensagens enviadas e recebidas (`mensagens` + `conversas`) entre usuários
      try {
        final convsResp = await supabase
            .from('conversas')
            .select('id, participante_1_id, participante_2_id')
            .or('participante_1_id.eq.$meId,participante_2_id.eq.$meId');

        final convMap = <String, Map<String, String>>{};
        for (final c in (convsResp as List)) {
          final cid = (c['id'] ?? '').toString();
          if (cid.isNotEmpty) {
            convMap[cid] = {
              'p1': (c['participante_1_id'] ?? '').toString(),
              'p2': (c['participante_2_id'] ?? '').toString(),
            };
          }
        }

        if (convMap.isNotEmpty) {
          final msgsResp = await supabase
              .from('mensagens')
              .select('id, conversa_id, remetente_id, conteudo, lida, created_at')
              .inFilter('conversa_id', convMap.keys.toList())
              .order('created_at', ascending: false)
              .limit(40);

          for (final m in (msgsResp as List)) {
            final msgId = (m['id'] ?? '').toString();
            final convId = (m['conversa_id'] ?? '').toString();
            final remId = (m['remetente_id'] ?? '').toString();
            final conteudo = (m['conteudo'] ?? '').toString();
            final createdAtStr = (m['created_at'] ?? '').toString();
            final createdAt = DateTime.tryParse(createdAtStr)?.toLocal() ?? DateTime.now();
            final lidaDb = m['lida'] == true;

            final convParts = convMap[convId];
            final p1 = convParts?['p1'] ?? '';
            final p2 = convParts?['p2'] ?? '';
            final destId = isUserMatch(remId, p1) ? p2 : p1;

            final isSentByMe = isUserMatch(remId, meId);
            final remInfo = usuariosMap[remId];
            final destInfo = usuariosMap[destId];
            final remNome = remInfo?['nome'] ?? (isSentByMe ? 'Você' : 'Usuário');
            final remPerfil = remInfo?['perfil'] ?? '';
            final destNome = destInfo?['nome'] ?? 'Usuário';

            // Verifica se já existe uma notificação em resultList para a mesma conversa no mesmo minuto
            final jaTemNotifMesmoMinuto = resultList.any((existente) =>
                existente.referenciaId == convId &&
                existente.createdAt.difference(createdAt).abs().inSeconds < 15);

            if (jaTemNotifMesmoMinuto) {
              // Atualiza a notificação existente para exibir o conteúdo real da mensagem
              final idx = resultList.indexWhere((existente) =>
                  existente.referenciaId == convId &&
                  existente.createdAt.difference(createdAt).abs().inSeconds < 15);
              if (idx >= 0) {
                final atual = resultList[idx];
                final preview = conteudo.length > 80 ? '${conteudo.substring(0, 80)}...' : conteudo;
                resultList[idx] = atual.copyWith(
                  titulo: isSentByMe ? 'Mensagem enviada para $destNome' : 'Mensagem de $remNome',
                  mensagem: '$remNome: "$preview"',
                  remetenteNome: remNome,
                  remetentePerfil: remPerfil,
                  destinatarioNome: destNome,
                );
              }
              continue;
            }

            final syntheticId = 'msg-$msgId';
            if (idSet.add(syntheticId)) {
              final preview = conteudo.length > 80 ? '${conteudo.substring(0, 80)}...' : conteudo;
              resultList.add(Notificacao(
                id: syntheticId,
                titulo: isSentByMe ? 'Mensagem enviada para $destNome' : 'Nova mensagem de $remNome',
                mensagem: isSentByMe
                    ? 'Você enviou para $destNome: "$preview"'
                    : '$remNome enviou: "$preview"',
                tipo: isSentByMe ? 'mensagem_enviada' : 'nova_mensagem',
                categoria: 'mensagem',
                referenciaTipo: 'conversa',
                referenciaId: convId,
                remetenteId: remId,
                remetenteNome: remNome,
                remetentePerfil: remPerfil,
                destinatarioId: destId,
                destinatarioNome: destNome,
                dataCriacao: Notificacao.formatarDataHora(createdAt),
                createdAt: createdAt,
                lida: isSentByMe || lidaDb || lidasLocalSet.contains(syntheticId),
              ));
            }
          }
        }
      } catch (e) {
        debugPrint('[NotificacoesNotifier] Aviso ao agregar mensagens: $e');
      }

      // 4. Agrega atualizações de Avaliações (`avaliacoes`)
      try {
        final avalResp = await supabase
            .from('avaliacoes')
            .select('id, aluno_id, avaliador_id, tipo, status, nota_geral, created_at, updated_at')
            .isFilter('deleted_at', null)
            .order('updated_at', ascending: false)
            .limit(20);

        for (final av in (avalResp as List)) {
          final avId = (av['id'] ?? '').toString();
          final alunoId = (av['aluno_id'] ?? '').toString();
          final avaliadorId = (av['avaliador_id'] ?? '').toString();
          final tipoAv = (av['tipo'] ?? 'setorial').toString();
          final statusAv = (av['status'] ?? 'submetida').toString();
          final nota = av['nota_geral']?.toString() ?? '-';
          final dtStr = (av['updated_at'] ?? av['created_at'] ?? '').toString();
          final dt = DateTime.tryParse(dtStr)?.toLocal() ?? DateTime.now();

          final jaExisteAv = resultList.any((n) => n.referenciaId == avId);
          if (jaExisteAv) {
            final idx = resultList.indexWhere((n) => n.referenciaId == avId);
            if (idx >= 0) {
              final alunoNome = usuariosMap[alunoId]?['nome'] ?? 'Aluno';
              final atual = resultList[idx];
              resultList[idx] = atual.copyWith(
                mensagem: '${atual.mensagem} (Aluno: $alunoNome • Nota: $nota)',
              );
            }
            continue;
          }

          final syntheticId = 'aval-$avId';
          if (idSet.add(syntheticId)) {
            final alunoNome = usuariosMap[alunoId]?['nome'] ?? 'Aluno';
            final avaliadorInfo = usuariosMap[avaliadorId];
            final isValidada = statusAv == 'validada';
            resultList.add(Notificacao(
              id: syntheticId,
              titulo: isValidada ? 'Avaliação validada ($tipoAv)' : 'Avaliação $statusAv ($tipoAv)',
              mensagem: isValidada
                  ? 'Avaliação ($tipoAv) de $alunoNome foi validada (Nota geral: $nota).'
                  : 'Avaliação ($tipoAv) referente a $alunoNome encontra-se com status "$statusAv" (Nota: $nota).',
              tipo: isValidada ? 'avaliacao_validada' : 'avaliacao_submetida',
              categoria: 'atualizacao',
              referenciaTipo: 'avaliacao',
              referenciaId: avId,
              remetenteId: avaliadorId,
              remetenteNome: avaliadorInfo?['nome'] ?? alunoNome,
              remetentePerfil: avaliadorInfo?['perfil'] ?? 'aluno',
              destinatarioId: alunoId,
              destinatarioNome: alunoNome,
              dataCriacao: Notificacao.formatarDataHora(dt),
              createdAt: dt,
              lida: isValidada || lidasLocalSet.contains(syntheticId),
            ));
          }
        }
      } catch (e) {
        debugPrint('[NotificacoesNotifier] Aviso ao agregar avaliacoes: $e');
      }

      // 5. Agrega registros e validações de Atividades (`atividades`)
      try {
        final ativResp = await supabase
            .from('atividades')
            .select('id, aluno_id, tipo, descricao_outra, status, data_registro, validado_por, created_at, updated_at')
            .isFilter('deleted_at', null)
            .order('updated_at', ascending: false)
            .limit(20);

        for (final at in (ativResp as List)) {
          final atId = (at['id'] ?? '').toString();
          final alunoId = (at['aluno_id'] ?? '').toString();
          final validadorId = (at['validado_por'] ?? '').toString();
          final tipoAt = (at['tipo'] ?? 'padrao').toString();
          final statusAt = (at['status'] ?? 'pendente_validacao').toString();
          final desc = (at['descricao_outra'] ?? 'Atividade prática de estágio').toString();
          final dtStr = (at['updated_at'] ?? at['created_at'] ?? '').toString();
          final dt = DateTime.tryParse(dtStr)?.toLocal() ?? DateTime.now();

          final syntheticId = 'ativ-$atId';
          if (idSet.add(syntheticId)) {
            final alunoInfo = usuariosMap[alunoId];
            final alunoNome = alunoInfo?['nome'] ?? 'Aluno';
            final validadorInfo = usuariosMap[validadorId];

            final isPendente = statusAt.contains('pendente');
            final statusLabel = isPendente
                ? 'aguardando validação'
                : (statusAt.contains('valid') ? 'validada' : statusAt);

            resultList.add(Notificacao(
              id: syntheticId,
              titulo: isPendente
                  ? 'Atividade registrada por $alunoNome'
                  : 'Atividade $statusLabel ($alunoNome)',
              mensagem: 'Atividade ($tipoAt): "$desc" — Status: $statusLabel.',
              tipo: isPendente ? 'atividade_pendente' : 'atividade_validada',
              categoria: 'atualizacao',
              referenciaTipo: 'atividade',
              referenciaId: alunoId,
              remetenteId: validadorId.isNotEmpty ? validadorId : alunoId,
              remetenteNome: validadorInfo?['nome'] ?? alunoNome,
              remetentePerfil: validadorInfo?['perfil'] ?? (alunoInfo?['perfil'] ?? 'aluno'),
              destinatarioId: alunoId,
              destinatarioNome: alunoNome,
              dataCriacao: Notificacao.formatarDataHora(dt),
              createdAt: dt,
              lida: !isPendente || lidasLocalSet.contains(syntheticId),
            ));
          }
        }
      } catch (e) {
        debugPrint('[NotificacoesNotifier] Aviso ao agregar atividades: $e');
      }

      // 6. Agrega histórico de atualizações de Frequência (`frequencias_historico_status`)
      try {
        final histResp = await supabase
            .from('frequencias_historico_status')
            .select('id, frequencia_id, status_anterior, status_novo, alterado_por, alterado_em')
            .order('alterado_em', ascending: false)
            .limit(20);

        for (final h in (histResp as List)) {
          final hId = (h['id'] ?? '').toString();
          final freqId = (h['frequencia_id'] ?? '').toString();
          final statusAnt = h['status_anterior']?.toString();
          final statusNovo = (h['status_novo'] ?? '').toString();
          final alteradoPor = (h['alterado_por'] ?? '').toString();
          final dtStr = (h['alterado_em'] ?? '').toString();
          final dt = DateTime.tryParse(dtStr)?.toLocal() ?? DateTime.now();

          final syntheticId = 'freqhist-$hId';
          if (idSet.add(syntheticId)) {
            final autorInfo = usuariosMap[alteradoPor];
            final autorNome = autorInfo?['nome'] ?? 'Usuário';
            final autorPerfil = autorInfo?['perfil'] ?? '';

            String tituloFreq = 'Atualização de Frequência';
            String detalheStatus = statusNovo;
            if (statusNovo == 'pendente_validacao') {
              tituloFreq = 'Presença registrada por $autorNome';
              detalheStatus = 'Pendente de validação pelo supervisor';
            } else if (statusNovo == 'validado') {
              tituloFreq = 'Frequência validada por $autorNome';
              detalheStatus = 'Presença confirmada pelo supervisor';
            } else if (statusNovo == 'ratificado') {
              tituloFreq = 'Frequência ratificada por $autorNome';
              detalheStatus = 'Abono/presença ratificada pelo professor';
            } else if (statusNovo.contains('abonado')) {
              tituloFreq = 'Solicitação de abono enviada';
              detalheStatus = 'Aguardando ratificação do professor';
            } else if (statusNovo.contains('rejeitad') || statusNovo.contains('recusad')) {
              tituloFreq = 'Frequência rejeitada por $autorNome';
              detalheStatus = 'Registro contestado/rejeitado';
            }

            resultList.add(Notificacao(
              id: syntheticId,
              titulo: tituloFreq,
              mensagem: statusAnt != null
                  ? '$detalheStatus (Status: $statusAnt → $statusNovo).'
                  : '$detalheStatus.',
              tipo: 'frequencia_$statusNovo',
              categoria: 'atualizacao',
              frequenciaId: freqId,
              referenciaTipo: 'frequencia',
              referenciaId: freqId,
              remetenteId: alteradoPor,
              remetenteNome: autorNome,
              remetentePerfil: autorPerfil,
              dataCriacao: Notificacao.formatarDataHora(dt),
              createdAt: dt,
              lida: statusNovo == 'validado' ||
                  statusNovo == 'ratificado' ||
                  lidasLocalSet.contains(syntheticId),
            ));
          }
        }
      } catch (e) {
        debugPrint('[NotificacoesNotifier] Aviso ao agregar historico de frequencia: $e');
      }

      // 7. Mescla notificações criadas localmente na sessão
      for (final loc in locais) {
        if (loc.destinatarioId == meId || loc.remetenteId == meId || meId.isEmpty) {
          if (idSet.add(loc.id)) {
            final dt = loc.createdAt ?? DateTime.now();
            resultList.add(Notificacao(
              id: loc.id,
              titulo: loc.titulo,
              mensagem: loc.mensagem,
              tipo: loc.tipo,
              categoria: Notificacao.inferirCategoria(loc.tipo, loc.referenciaTipo),
              frequenciaId: loc.frequenciaId,
              referenciaTipo: loc.referenciaTipo,
              referenciaId: loc.referenciaId ?? loc.frequenciaId,
              remetenteId: loc.remetenteId,
              remetenteNome: loc.remetenteNome,
              remetentePerfil: loc.remetentePerfil,
              destinatarioId: loc.destinatarioId,
              destinatarioNome: loc.destinatarioNome,
              dataCriacao: loc.dataCriacao == 'agora'
                  ? Notificacao.formatarDataHora(dt)
                  : loc.dataCriacao,
              createdAt: dt,
              lida: loc.lida || lidasLocalSet.contains(loc.id),
            ));
          }
        }
      }

      // Ordena todas as notificações e eventos do mais recente para o mais antigo
      resultList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = AsyncValue.data(resultList);
    } catch (e, stack) {
      if (resultList.isNotEmpty) {
        state = AsyncValue.data(resultList);
      } else {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> registrarEventoSistema({
    required String destinatarioId,
    String? destinatarioNome,
    required String titulo,
    required String mensagem,
    required String tipo,
    String? referenciaTipo,
    String? referenciaId,
    String? frequenciaId,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    final meId = ref.read(currentUserIdProvider);
    final now = DateTime.now();

    String remNome = 'Usuário';
    String remPerfil = 'usuario';
    try {
      final meMap = await ref.read(usuarioAtualProvider.future);
      remNome = meMap['nome'] ?? 'Usuário';
      remPerfil = meMap['perfil'] ?? 'usuario';
    } catch (_) {}

    final localNotif = NotificacaoLocalItem(
      id: 'notif-${now.millisecondsSinceEpoch}',
      destinatarioId: destinatarioId,
      destinatarioNome: destinatarioNome,
      remetenteId: meId,
      remetenteNome: remNome,
      remetentePerfil: remPerfil,
      titulo: titulo,
      mensagem: mensagem,
      tipo: tipo,
      referenciaTipo: referenciaTipo,
      referenciaId: referenciaId,
      frequenciaId: frequenciaId,
      dataCriacao: Notificacao.formatarDataHora(now),
      createdAt: now,
      lida: false,
    );

    ref.read(notificacoesLocaisProvider.notifier).update((list) => [localNotif, ...list]);

    try {
      await supabase.from('notificacoes').insert({
        'destinatario_id': destinatarioId,
        'tipo': tipo,
        'titulo': titulo,
        'corpo': mensagem,
        'referencia_tipo': referenciaTipo,
        'referencia_id': referenciaId ?? frequenciaId,
        'lida': false,
        if (meId.isNotEmpty) 'created_by': meId,
      });
    } catch (_) {}

    await loadNotificacoes();
  }

  Future<void> marcarComoLida(String id) async {
    ref.read(notificacoesLidasIdsProvider.notifier).update((set) => {...set, id});

    ref.read(notificacoesLocaisProvider.notifier).update((list) {
      return list
          .map((n) => n.id == id
              ? NotificacaoLocalItem(
                  id: n.id,
                  destinatarioId: n.destinatarioId,
                  destinatarioNome: n.destinatarioNome,
                  remetenteId: n.remetenteId,
                  remetenteNome: n.remetenteNome,
                  remetentePerfil: n.remetentePerfil,
                  titulo: n.titulo,
                  mensagem: n.mensagem,
                  tipo: n.tipo,
                  referenciaTipo: n.referenciaTipo,
                  referenciaId: n.referenciaId,
                  frequenciaId: n.frequenciaId,
                  dataCriacao: n.dataCriacao,
                  createdAt: n.createdAt,
                  lida: true,
                )
              : n)
          .toList();
    });

    if (state.hasValue) {
      final atual = state.value!;
      state = AsyncValue.data(
        atual.map((n) => n.id == id ? n.copyWith(lida: true) : n).toList(),
      );
    }

    // Se for um UUID real da tabela notificacoes, marca como lida via RPC e update direto
    if (!id.startsWith('msg-') &&
        !id.startsWith('aval-') &&
        !id.startsWith('ativ-') &&
        !id.startsWith('freqhist-') &&
        !id.startsWith('notif-')) {
      try {
        final supabase = ref.read(supabaseClientProvider);
        try {
          await supabase.rpc('fn_marcar_notificacao_lida', params: {'p_id': id});
        } catch (_) {
          await supabase.from('notificacoes').update({'lida': true}).eq('id', id);
        }
      } catch (_) {}
    }
  }

  Future<void> marcarTodasComoLidas() async {
    if (state.hasValue) {
      final atual = state.value!;
      final allIds = atual.map((n) => n.id).toSet();
      ref.read(notificacoesLidasIdsProvider.notifier).update((set) => {...set, ...allIds});
      state = AsyncValue.data(
        atual.map((n) => n.copyWith(lida: true)).toList(),
      );
    }

    final meId = ref.read(currentUserIdProvider);
    ref.read(notificacoesLocaisProvider.notifier).update((list) {
      return list
          .map((n) => (n.destinatarioId == meId || meId.isEmpty)
              ? NotificacaoLocalItem(
                  id: n.id,
                  destinatarioId: n.destinatarioId,
                  destinatarioNome: n.destinatarioNome,
                  remetenteId: n.remetenteId,
                  remetenteNome: n.remetenteNome,
                  remetentePerfil: n.remetentePerfil,
                  titulo: n.titulo,
                  mensagem: n.mensagem,
                  tipo: n.tipo,
                  referenciaTipo: n.referenciaTipo,
                  referenciaId: n.referenciaId,
                  frequenciaId: n.frequenciaId,
                  dataCriacao: n.dataCriacao,
                  createdAt: n.createdAt,
                  lida: true,
                )
              : n)
          .toList();
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      try {
        await supabase.rpc('fn_marcar_todas_notificacoes_lidas');
      } catch (_) {
        final userId = supabase.auth.currentUser?.id ??
            ref.read(authStateProvider).value?.session?.user.id;
        if (userId != null) {
          await supabase
              .from('notificacoes')
              .update({'lida': true})
              .eq('destinatario_id', userId)
              .eq('lida', false);
        }
      }
    } catch (_) {}
  }
}

final notificacoesProvider = StateNotifierProvider<NotificacoesNotifier, AsyncValue<List<Notificacao>>>((ref) {
  ref.watch(currentUserIdProvider);
  final notifier = NotificacoesNotifier(ref);
  notifier.loadNotificacoes();
  return notifier;
});

// StreamProvider Realtime para inscrição ao vivo da tabela notificacoes e mensagens
final notificacoesStreamProvider = StreamProvider.autoDispose<List<Notificacao>>((ref) {
  final supabase = ref.read(supabaseClientProvider);
  final meId = ref.watch(currentUserIdProvider);

  if (meId.isEmpty) return Stream.value([]);

  final notifState = ref.watch(notificacoesProvider);

  final controller = StreamController<List<Notificacao>>.broadcast();

  if (notifState.hasValue) {
    controller.add(notifState.value!);
  } else {
    ref.read(notificacoesProvider.notifier).loadNotificacoes().then((_) {
      if (!controller.isClosed) {
        controller.add(ref.read(notificacoesProvider).value ?? []);
      }
    });
  }

  StreamSubscription? subNotif;
  try {
    final stream = supabase
        .from('notificacoes')
        .stream(primaryKey: ['id'])
        .eq('destinatario_id', meId)
        .order('created_at', ascending: false);

    subNotif = stream.listen((_) async {
      await ref.read(notificacoesProvider.notifier).loadNotificacoes();
      if (!controller.isClosed) {
        controller.add(ref.read(notificacoesProvider).value ?? []);
      }
    }, onError: (e) {});
  } catch (_) {}

  controller.onCancel = () {
    subNotif?.cancel();
  };

  return controller.stream;
});

final notificacoesNaoLidasCountProvider = Provider<int>((ref) {
  final asyncStream = ref.watch(notificacoesStreamProvider);
  return asyncStream.maybeWhen(
    data: (notificacoes) => notificacoes.where((n) => !n.lida).length,
    orElse: () => ref.watch(notificacoesProvider).maybeWhen(
      data: (notificacoes) => notificacoes.where((n) => !n.lida).length,
      orElse: () => 0,
    ),
  );
});
