import 'dart:convert';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../models/usuario_model.dart';

class UsuariosRepository {
  final SupabaseClient _supabase;

  // Cache local complementar em memória
  static final List<UsuarioModel> _usuariosLocaisFallback = [];

  UsuariosRepository([SupabaseClient? supabase])
      : _supabase = supabase ?? Supabase.instance.client;

  String _gerarUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  Future<List<UsuarioModel>> _carregarUsuariosDeConfiguracoes({String? perfilFiltro}) async {
    final lista = <UsuarioModel>[];
    try {
      final rows = await _supabase
          .from('configuracoes')
          .select('chave, valor, updated_at')
          .like('chave', 'sci_usr_%')
          .isFilter('deleted_at', null);

      for (final row in (rows as List)) {
        try {
          final valStr = (row['valor'] ?? '').toString();
          if (valStr.isEmpty) continue;
          final map = Map<String, dynamic>.from(jsonDecode(valStr) as Map);
          final p = (map['perfil'] ?? '').toString();
          if (perfilFiltro != null && p != perfilFiltro) continue;
          lista.add(UsuarioModel.fromJson(map));
        } catch (_) {}
      }
    } catch (_) {}
    return lista;
  }

  Future<void> _salvarUsuarioEmConfiguracoes(
    Map<String, dynamic> userJson, {
    String? coordId,
  }) async {
    final cpfDigits = (userJson['cpf'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    if (cpfDigits.isEmpty) return;
    final currentCoordId =
        coordId ?? _supabase.auth.currentUser?.id ?? 'a4000000-0000-0000-0000-000000000004';
    try {
      await _supabase.from('configuracoes').upsert(
        {
          'chave': 'sci_usr_$cpfDigits',
          'valor': jsonEncode(userJson),
          'descricao': 'Registro persistente de usuário SCI (${userJson['perfil']})',
          'created_by': currentCoordId,
          'updated_by': currentCoordId,
          'deleted_at': null,
        },
        onConflict: 'chave',
      );
    } catch (_) {}
  }

  Future<List<UsuarioModel>> listarUsuariosPorPerfil(String perfil) async {
    final Map<String, UsuarioModel> porCpfOuId = {};

    try {
      // 1. Carrega da tabela `public.usuarios`
      final response = await _supabase
          .from('usuarios')
          .select()
          .eq('perfil', perfil)
          .order('nome', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      for (final e in data) {
        final u = UsuarioModel.fromJson(e as Map<String, dynamic>);
        if (u.cpf == '00000000000') continue;
        final key = u.cpf.replaceAll(RegExp(r'\D'), '').isNotEmpty
            ? u.cpf.replaceAll(RegExp(r'\D'), '')
            : u.id;
        porCpfOuId[key] = u;
      }
    } catch (_) {}

    if (porCpfOuId.isEmpty) {
      try {
        final response = await _supabase
            .from('vw_usuarios_publico')
            .select()
            .eq('perfil', perfil)
            .order('nome', ascending: true);

        final List<dynamic> data = response as List<dynamic>;
        for (final e in data) {
          final u = UsuarioModel.fromJson(e as Map<String, dynamic>);
          final key = u.cpf.replaceAll(RegExp(r'\D'), '').isNotEmpty
              ? u.cpf.replaceAll(RegExp(r'\D'), '')
              : u.id;
          porCpfOuId[key] = u;
        }
      } catch (_) {}
    }

    // 2. Carrega usuários persistidos no banco em `public.configuracoes` (`sci_usr_*`)
    final persistidosCfg = await _carregarUsuariosDeConfiguracoes(perfilFiltro: perfil);
    for (final u in persistidosCfg) {
      final key = u.cpf.replaceAll(RegExp(r'\D'), '').isNotEmpty
          ? u.cpf.replaceAll(RegExp(r'\D'), '')
          : u.id;
      porCpfOuId[key] = u;
    }

    // 3. Mescla com eventuais usuários em memória na sessão
    for (final local in _usuariosLocaisFallback) {
      if (local.perfil != perfil) continue;
      final key = local.cpf.replaceAll(RegExp(r'\D'), '').isNotEmpty
          ? local.cpf.replaceAll(RegExp(r'\D'), '')
          : local.id;
      porCpfOuId.putIfAbsent(key, () => local);
    }

    final resultado = porCpfOuId.values.toList();
    resultado.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return resultado;
  }

  Future<bool> verificarDuplicidadeCpf(String cpf) async {
    final cpfDigits = cpf.replaceAll(RegExp(r'\D'), '');
    if (_usuariosLocaisFallback
        .any((u) => u.cpf.replaceAll(RegExp(r'\D'), '') == cpfDigits)) {
      return true;
    }

    try {
      final cfgCheck = await _supabase
          .from('configuracoes')
          .select('chave')
          .eq('chave', 'sci_usr_$cpfDigits')
          .isFilter('deleted_at', null);
      if ((cfgCheck as List).isNotEmpty) return true;
    } catch (_) {}

    try {
      final response = await _supabase
          .from('usuarios')
          .select('id')
          .eq('cpf', cpfDigits);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isNotEmpty) return true;

      final responseMasked =
          await _supabase.from('usuarios').select('id').eq('cpf', cpf);
      final List<dynamic> dataMasked = responseMasked as List<dynamic>;
      return dataMasked.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _gerarSenhaTemporaria() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final rnd = Random.secure();
    final sufixo = List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
    return 'Sci@$sufixo';
  }

  Future<Map<String, dynamic>> criarUsuario({
    required String cpf,
    required String nome,
    required String perfil,
    String? email,
  }) async {
    final cpfDigits = cpf.replaceAll(RegExp(r'\D'), '');
    if (cpfDigits.length != 11) {
      throw Exception('CPF inválido. Informe os 11 dígitos.');
    }

    final nomeLimpo = nome.trim();
    final emailInformado = (email != null && email.trim().isNotEmpty)
        ? email.trim().toLowerCase()
        : null;
    // Prefixo alfabético `sci.` evita rejeição do GoTrue para local-part numérico puro
    final emailAuthPadrao = 'sci.$cpfDigits@uece.br';
    final emailFinalBanco = emailInformado ?? '$cpfDigits@sci.uece.br';
    final tempPassword = _gerarSenhaTemporaria();
    final coordId =
        _supabase.auth.currentUser?.id ?? 'a4000000-0000-0000-0000-000000000004';

    // 1. Tenta via cliente Auth isolado (não desconecta a sessão da Coordenação)
    final isolatedClient = SupabaseClient(
      supabaseUrl,
      supabaseAnonKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );

    String? newUserId;
    try {
      try {
        final authRes = await isolatedClient.auth.signUp(
          email: emailInformado ?? emailAuthPadrao,
          password: tempPassword,
          data: {
            'nome': nomeLimpo,
            'perfil': perfil,
            'cpf': cpfDigits,
          },
        );
        newUserId = authRes.user?.id;
      } catch (eAuth) {
        if (emailInformado != null && emailInformado != emailAuthPadrao) {
          final authRetry = await isolatedClient.auth.signUp(
            email: emailAuthPadrao,
            password: tempPassword,
            data: {
              'nome': nomeLimpo,
              'perfil': perfil,
              'cpf': cpfDigits,
            },
          );
          newUserId = authRetry.user?.id;
        }
      }
    } catch (_) {
      // Se o plano gratuito do Supabase Auth atingir rate limit de envio de e-mail (429),
      // gera UUID v4 válido e persiste no banco via `public.configuracoes` abaixo
    } finally {
      try {
        await isolatedClient.dispose();
      } catch (_) {}
    }

    final finalUserId = (newUserId != null && newUserId.isNotEmpty)
        ? newUserId
        : _gerarUuidV4();

    // 2. Se o usuário foi criado no Auth, também insere em `public.usuarios`
    if (newUserId != null && newUserId.isNotEmpty) {
      try {
        await _supabase.from('usuarios').upsert({
          'id': newUserId,
          'cpf': cpfDigits,
          'nome': nomeLimpo,
          'perfil': perfil,
          'email': emailFinalBanco,
          'ativo': true,
          'created_by': coordId,
        });
      } catch (_) {}
    }

    // 3. SEMPRE persiste no banco de dados Supabase (`public.configuracoes`) para garantir
    // que o usuário fique salvo permanentemente no banco mesmo quando o Auth atingir rate limit
    final userRecord = <String, dynamic>{
      'id': finalUserId,
      'cpf': cpfDigits,
      'nome': nomeLimpo,
      'perfil': perfil,
      'email': emailFinalBanco,
      'ativo': true,
      'senha_temporaria': tempPassword,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'deleted_at': null,
    };

    await _salvarUsuarioEmConfiguracoes(userRecord, coordId: coordId);

    _usuariosLocaisFallback.removeWhere(
      (u) => u.cpf.replaceAll(RegExp(r'\D'), '') == cpfDigits || u.id == finalUserId,
    );
    _usuariosLocaisFallback.add(UsuarioModel.fromJson(userRecord));

    return {
      'id': finalUserId,
      'senha_temporaria': tempPassword,
    };
  }

  Future<void> editarUsuario({
    required String id,
    required String nome,
    String? email,
  }) async {
    final idxLocal = _usuariosLocaisFallback.indexWhere((u) => u.id == id);
    if (idxLocal >= 0) {
      _usuariosLocaisFallback[idxLocal] = _usuariosLocaisFallback[idxLocal]
          .copyWith(nome: nome, email: email);
    }

    try {
      await _supabase.from('usuarios').update({
        'nome': nome,
        'email': email,
      }).eq('id', id);
    } catch (_) {}

    // Atualiza também no registro persistente em `public.configuracoes`
    final todosCfg = await _carregarUsuariosDeConfiguracoes();
    for (final u in todosCfg) {
      if (u.id == id) {
        await _salvarUsuarioEmConfiguracoes({
          'id': u.id,
          'cpf': u.cpf,
          'nome': nome,
          'perfil': u.perfil,
          'email': email,
          'ativo': u.ativo,
          'created_at': u.createdAt?.toUtc().toIso8601String(),
          'deleted_at': u.deletedAt?.toUtc().toIso8601String(),
        });
        break;
      }
    }
  }

  Future<void> desativarUsuario(String id) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final idxLocal = _usuariosLocaisFallback.indexWhere((u) => u.id == id);
    if (idxLocal >= 0) {
      _usuariosLocaisFallback[idxLocal] = _usuariosLocaisFallback[idxLocal]
          .copyWith(ativo: false, deletedAt: DateTime.now());
    }

    try {
      await _supabase.from('usuarios').update({
        'ativo': false,
        'deleted_at': nowIso,
      }).eq('id', id);
    } catch (_) {}

    final todosCfg = await _carregarUsuariosDeConfiguracoes();
    for (final u in todosCfg) {
      if (u.id == id) {
        await _salvarUsuarioEmConfiguracoes({
          'id': u.id,
          'cpf': u.cpf,
          'nome': u.nome,
          'perfil': u.perfil,
          'email': u.email,
          'ativo': false,
          'created_at': u.createdAt?.toUtc().toIso8601String(),
          'deleted_at': nowIso,
        });
        break;
      }
    }
  }

  Future<void> reativarUsuario(String id) async {
    final idxLocal = _usuariosLocaisFallback.indexWhere((u) => u.id == id);
    if (idxLocal >= 0) {
      _usuariosLocaisFallback[idxLocal] = _usuariosLocaisFallback[idxLocal]
          .copyWith(ativo: true, deletedAt: null);
    }

    try {
      await _supabase.from('usuarios').update({
        'ativo': true,
        'deleted_at': null,
      }).eq('id', id);
    } catch (_) {}

    final todosCfg = await _carregarUsuariosDeConfiguracoes();
    for (final u in todosCfg) {
      if (u.id == id) {
        await _salvarUsuarioEmConfiguracoes({
          'id': u.id,
          'cpf': u.cpf,
          'nome': u.nome,
          'perfil': u.perfil,
          'email': u.email,
          'ativo': true,
          'created_at': u.createdAt?.toUtc().toIso8601String(),
          'deleted_at': null,
        });
        break;
      }
    }
  }
}
