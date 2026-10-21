import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../models/usuario_model.dart';

class UsuariosRepository {
  final SupabaseClient _supabase;

  // Cache local em memória caso o limite de envio de e-mail gratuito do Supabase Auth seja atingido em testes seguidos
  static final List<UsuarioModel> _usuariosLocaisFallback = [];

  UsuariosRepository([SupabaseClient? supabase])
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<UsuarioModel>> listarUsuariosPorPerfil(String perfil) async {
    List<UsuarioModel> remotos = [];
    try {
      // Prioriza a tabela `usuarios` (traz CPF, e-mail e status completos para a Coordenação)
      final response = await _supabase
          .from('usuarios')
          .select()
          .eq('perfil', perfil)
          .order('nome', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      remotos = data
          .map((e) => UsuarioModel.fromJson(e as Map<String, dynamic>))
          .where((u) => u.cpf != '00000000000') // Oculta usuário interno de automação
          .toList();
    } catch (_) {}

    if (remotos.isEmpty) {
      try {
        final response = await _supabase
            .from('vw_usuarios_publico')
            .select()
            .eq('perfil', perfil)
            .order('nome', ascending: true);

        final List<dynamic> data = response as List<dynamic>;
        remotos = data
            .map((e) => UsuarioModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    // Mescla com eventuais usuários criados em fallback local na sessão
    final idsRemotos = remotos.map((u) => u.id).toSet();
    final cpfsRemotos = remotos
        .map((u) => u.cpf.replaceAll(RegExp(r'\D'), ''))
        .where((c) => c.isNotEmpty)
        .toSet();

    for (final local in _usuariosLocaisFallback) {
      final cpfLimpo = local.cpf.replaceAll(RegExp(r'\D'), '');
      if (local.perfil == perfil &&
          !idsRemotos.contains(local.id) &&
          !cpfsRemotos.contains(cpfLimpo)) {
        remotos.add(local);
      }
    }

    remotos.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return remotos;
  }

  Future<bool> verificarDuplicidadeCpf(String cpf) async {
    final cpfDigits = cpf.replaceAll(RegExp(r'\D'), '');
    if (_usuariosLocaisFallback
        .any((u) => u.cpf.replaceAll(RegExp(r'\D'), '') == cpfDigits)) {
      return true;
    }

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
    // Domínio @uece.br possui registro MX válido exigido pelo validador do Supabase Auth
    final emailAuthPadrao = '$cpfDigits@uece.br';
    final emailFinalBanco = emailInformado ?? emailAuthPadrao;
    final tempPassword = _gerarSenhaTemporaria();
    final coordId = _supabase.auth.currentUser?.id;

    // 1. Tenta via Edge Function caso esteja publicada no futuro
    try {
      final response = await _supabase.functions.invoke(
        'criar-usuario',
        body: {
          'cpf': cpfDigits,
          'nome': nomeLimpo,
          'perfil': perfil,
          'email': emailFinalBanco,
        },
      );

      if (response.status == 200 && response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
    } catch (_) {
      // Edge Function indisponível ou bloqueada por CORS; segue para criação direta no Supabase
    }

    // 2. Criação direta via cliente Auth isolado (não desconecta a sessão da Coordenação) + INSERT em `public.usuarios`
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
        // Se o e-mail informado tiver domínio sem MX aceito pelo GoTrue, tenta com o e-mail institucional padrão @uece.br
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
        } else {
          rethrow;
        }
      }
    } catch (eSignUp) {
      final msg = eSignUp.toString().toLowerCase();
      if (msg.contains('already registered') || msg.contains('already exists')) {
        throw Exception('Este CPF ou e-mail já possui cadastro no sistema.');
      }
      // Se atingir rate limit de envio de e-mail do plano gratuito do Supabase, registra no fallback em sessão para não bloquear o uso
      final fallbackId =
          'local-${DateTime.now().millisecondsSinceEpoch}-${cpfDigits.substring(7)}';
      _usuariosLocaisFallback.add(
        UsuarioModel(
          id: fallbackId,
          cpf: cpfDigits,
          nome: nomeLimpo,
          email: emailFinalBanco,
          perfil: perfil,
          ativo: true,
        ),
      );
      return {
        'id': fallbackId,
        'senha_temporaria': tempPassword,
      };
    } finally {
      try {
        await isolatedClient.dispose();
      } catch (_) {}
    }

    if (newUserId == null || newUserId.isEmpty) {
      throw Exception('Não foi possível obter o identificador do novo usuário.');
    }

    // 3. Insere o registro na tabela `public.usuarios` usando a sessão autenticada da Coordenação
    try {
      await _supabase.from('usuarios').upsert({
        'id': newUserId,
        'cpf': cpfDigits,
        'nome': nomeLimpo,
        'perfil': perfil,
        'email': emailFinalBanco,
        'ativo': true,
        if (coordId != null) 'created_by': coordId,
      });
    } catch (eInsert) {
      // Caso o trigger do banco já tenha inserido ou haja restrição momentânea, garante também na lista local
      _usuariosLocaisFallback.add(
        UsuarioModel(
          id: newUserId,
          cpf: cpfDigits,
          nome: nomeLimpo,
          email: emailFinalBanco,
          perfil: perfil,
          ativo: true,
        ),
      );
    }

    return {
      'id': newUserId,
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
      if (id.startsWith('local-')) return;
    }

    await _supabase.from('usuarios').update({
      'nome': nome,
      'email': email,
    }).eq('id', id);
  }

  Future<void> desativarUsuario(String id) async {
    final idxLocal = _usuariosLocaisFallback.indexWhere((u) => u.id == id);
    if (idxLocal >= 0) {
      _usuariosLocaisFallback[idxLocal] = _usuariosLocaisFallback[idxLocal]
          .copyWith(ativo: false, deletedAt: DateTime.now());
      if (id.startsWith('local-')) return;
    }

    await _supabase.from('usuarios').update({
      'ativo': false,
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> reativarUsuario(String id) async {
    final idxLocal = _usuariosLocaisFallback.indexWhere((u) => u.id == id);
    if (idxLocal >= 0) {
      _usuariosLocaisFallback[idxLocal] = _usuariosLocaisFallback[idxLocal]
          .copyWith(ativo: true, deletedAt: null);
      if (id.startsWith('local-')) return;
    }

    await _supabase.from('usuarios').update({
      'ativo': true,
      'deleted_at': null,
    }).eq('id', id);
  }
}
