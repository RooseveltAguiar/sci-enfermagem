import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/usuarios_repository.dart';
import 'auth_provider.dart';

class ProfissionalOpcao {
  final String id;
  final String nome;
  final String perfil; // 'professor' ou 'supervisor'
  final String? email;

  const ProfissionalOpcao({
    required this.id,
    required this.nome,
    required this.perfil,
    this.email,
  });
}

class ResponsaveisCampo {
  final String? professorId;
  final String professorNome;
  final String? supervisorId;
  final String supervisorNome;

  const ResponsaveisCampo({
    this.professorId,
    required this.professorNome,
    this.supervisorId,
    required this.supervisorNome,
  });

  ResponsaveisCampo copyWith({
    String? professorId,
    String? professorNome,
    String? supervisorId,
    String? supervisorNome,
  }) {
    return ResponsaveisCampo(
      professorId: professorId ?? this.professorId,
      professorNome: professorNome ?? this.professorNome,
      supervisorId: supervisorId ?? this.supervisorId,
      supervisorNome: supervisorNome ?? this.supervisorNome,
    );
  }
}

// Cache local em memória por campoId para garantir atualização imediata mesmo em sessão demo
final responsaveisCampoLocalProvider =
    StateProvider<Map<String, ResponsaveisCampo>>((ref) => {});

class ResponsaveisCampoService {
  final Ref ref;
  ResponsaveisCampoService(this.ref);

  Future<List<ProfissionalOpcao>> listarProfissionaisPorPerfil(String perfil) async {
    final supabase = ref.read(supabaseClientProvider);
    final repo = UsuariosRepository(supabase);
    final resultado = <ProfissionalOpcao>[];
    final ids = <String>{};

    try {
      final usuarios = await repo.listarUsuariosPorPerfil(perfil);
      for (final u in usuarios) {
        if (!u.ativo || u.deletedAt != null) continue;
        if (u.id.isNotEmpty && u.nome.isNotEmpty && ids.add(u.id)) {
          resultado.add(ProfissionalOpcao(
            id: u.id,
            nome: u.nome,
            perfil: perfil,
            email: u.email,
          ));
        }
      }
    } catch (_) {}

    if (resultado.isEmpty) {
      if (perfil == 'professor') {
        resultado.add(const ProfissionalOpcao(
          id: 'a3000000-0000-0000-0000-000000000003',
          nome: 'Prof. Dr. Roberto Silva',
          perfil: 'professor',
        ));
      } else if (perfil == 'supervisor') {
        resultado.add(const ProfissionalOpcao(
          id: 'a2000000-0000-0000-0000-000000000002',
          nome: 'Enf. Dra. Ana Paula Santos',
          perfil: 'supervisor',
        ));
      }
    }

    return resultado;
  }

  Future<ResponsaveisCampo> carregarResponsaveis(String campoId) async {
    final supabase = ref.read(supabaseClientProvider);
    final localMap = ref.read(responsaveisCampoLocalProvider);
    final local = localMap[campoId];

    String? profId = local?.professorId;
    String profNome = local?.professorNome ?? 'Não atribuído';
    String? supId = local?.supervisorId;
    String supNome = local?.supervisorNome ?? 'Não atribuído';

    // 0. Verifica registro persistente em `public.configuracoes` (`sci_resp_campo_<campoId>`)
    try {
      final cfgRow = await supabase
          .from('configuracoes')
          .select('valor')
          .eq('chave', 'sci_resp_campo_$campoId')
          .isFilter('deleted_at', null)
          .maybeSingle();

      if (cfgRow != null && cfgRow['valor'] != null) {
        final decoded = Map<String, dynamic>.from(
          jsonDecode(cfgRow['valor'].toString()) as Map,
        );
        final pid = decoded['professor_id']?.toString();
        final pnome = decoded['professor_nome']?.toString();
        final sid = decoded['supervisor_id']?.toString();
        final snome = decoded['supervisor_nome']?.toString();
        if (pid != null && pid.isNotEmpty) profId = pid;
        if (pnome != null && pnome.isNotEmpty) profNome = pnome;
        if (sid != null && sid.isNotEmpty) supId = sid;
        if (snome != null && snome.isNotEmpty) supNome = snome;
      }
    } catch (_) {}

    if (profId == null || profNome == 'Não atribuído') {
      try {
        // 1. Busca vínculo ativo em professor_turmas
        final profRows = await supabase
            .from('professor_turmas')
            .select('professor_id, data_inicio, data_fim, usuarios:professor_id(id, nome)')
            .eq('campo_id', campoId)
            .isFilter('deleted_at', null)
            .order('created_at', ascending: false)
            .limit(5);

        if ((profRows as List).isNotEmpty) {
          final row = profRows.firstWhere(
            (r) => r['data_fim'] == null,
            orElse: () => profRows.first,
          );
          final usr = row['usuarios'] as Map?;
          final pid = (row['professor_id'] ?? usr?['id'] ?? '').toString();
          final pnome = (usr?['nome'] ?? '').toString();
          if (pid.isNotEmpty) {
            profId = pid;
            if (pnome.isNotEmpty) {
              profNome = pnome;
            } else {
              final u = await supabase
                  .from('usuarios')
                  .select('nome')
                  .eq('id', pid)
                  .maybeSingle();
              if (u != null && u['nome'] != null) {
                profNome = u['nome'].toString();
              }
            }
          }
        }
      } catch (_) {}
    }

    if (supId == null || supNome == 'Não atribuído') {
      try {
        // 2. Busca vínculo ativo em supervisor_campos
        final supRows = await supabase
            .from('supervisor_campos')
            .select('supervisor_id, data_inicio, data_fim, usuarios:supervisor_id(id, nome)')
            .eq('campo_id', campoId)
            .isFilter('deleted_at', null)
            .order('created_at', ascending: false)
            .limit(5);

        if ((supRows as List).isNotEmpty) {
          final row = supRows.firstWhere(
            (r) => r['data_fim'] == null,
            orElse: () => supRows.first,
          );
          final usr = row['usuarios'] as Map?;
          final sid = (row['supervisor_id'] ?? usr?['id'] ?? '').toString();
          final snome = (usr?['nome'] ?? '').toString();
          if (sid.isNotEmpty) {
            supId = sid;
            if (snome.isNotEmpty) {
              supNome = snome;
            } else {
              final u = await supabase
                  .from('usuarios')
                  .select('nome')
                  .eq('id', sid)
                  .maybeSingle();
              if (u != null && u['nome'] != null) {
                supNome = u['nome'].toString();
              }
            }
          }
        }
      } catch (_) {}
    }

    // Se não encontrou vínculo salvo, usa o primeiro profissional disponível como sugestão visual
    if (profId == null || profNome == 'Não atribuído') {
      final profs = await listarProfissionaisPorPerfil('professor');
      if (profs.isNotEmpty) {
        profId ??= profs.first.id;
        profNome = profs.first.nome;
      }
    }
    if (supId == null || supNome == 'Não atribuído') {
      final sups = await listarProfissionaisPorPerfil('supervisor');
      if (sups.isNotEmpty) {
        supId ??= sups.first.id;
        supNome = sups.first.nome;
      }
    }

    return ResponsaveisCampo(
      professorId: profId,
      professorNome: profNome,
      supervisorId: supId,
      supervisorNome: supNome,
    );
  }

  Future<void> salvarResponsaveis({
    required String campoId,
    String? professorId,
    String? professorNome,
    String? supervisorId,
    String? supervisorNome,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    final currentUserId =
        supabase.auth.currentUser?.id ?? 'a4000000-0000-0000-0000-000000000004';
    final now = DateTime.now();
    final hojeStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Atualiza estado local imediatamente
    final atual = await carregarResponsaveis(campoId);
    final novo = atual.copyWith(
      professorId: professorId,
      professorNome: professorNome,
      supervisorId: supervisorId,
      supervisorNome: supervisorNome,
    );
    ref.read(responsaveisCampoLocalProvider.notifier).update((map) => {
          ...map,
          campoId: novo,
        });

    // Persiste em `public.configuracoes` (`sci_resp_campo_<campoId>`) para garantir gravação no banco para qualquer profissional
    try {
      await supabase.from('configuracoes').upsert(
        {
          'chave': 'sci_resp_campo_$campoId',
          'valor': jsonEncode({
            'professor_id': novo.professorId,
            'professor_nome': novo.professorNome,
            'supervisor_id': novo.supervisorId,
            'supervisor_nome': novo.supervisorNome,
            'updated_at': now.toUtc().toIso8601String(),
          }),
          'descricao': 'Responsáveis (Professor e Supervisor) do campo $campoId',
          'escopo_id': campoId,
          'created_by': currentUserId,
          'updated_by': currentUserId,
          'deleted_at': null,
        },
        onConflict: 'chave',
      );
    } catch (_) {}

    if (professorId != null && professorId.isNotEmpty) {
      try {
        await supabase
            .from('professor_turmas')
            .update({
              'data_fim': hojeStr,
              'deleted_at': now.toUtc().toIso8601String(),
              'updated_by': currentUserId,
            })
            .eq('campo_id', campoId)
            .isFilter('deleted_at', null);

        await supabase.from('professor_turmas').upsert(
          {
            'professor_id': professorId,
            'campo_id': campoId,
            'data_inicio': hojeStr,
            'data_fim': null,
            'deleted_at': null,
            'created_by': currentUserId,
            'updated_by': currentUserId,
          },
          onConflict: 'professor_id,campo_id,data_inicio',
        );
      } catch (_) {}
    }

    if (supervisorId != null && supervisorId.isNotEmpty) {
      try {
        await supabase
            .from('supervisor_campos')
            .update({
              'data_fim': hojeStr,
              'deleted_at': now.toUtc().toIso8601String(),
              'updated_by': currentUserId,
            })
            .eq('campo_id', campoId)
            .isFilter('deleted_at', null);

        await supabase.from('supervisor_campos').upsert(
          {
            'supervisor_id': supervisorId,
            'campo_id': campoId,
            'data_inicio': hojeStr,
            'data_fim': null,
            'deleted_at': null,
            'created_by': currentUserId,
            'updated_by': currentUserId,
          },
          onConflict: 'supervisor_id,campo_id,data_inicio',
        );
      } catch (_) {}
    }
  }
}

final responsaveisCampoServiceProvider =
    Provider<ResponsaveisCampoService>((ref) => ResponsaveisCampoService(ref));

class CampoEstagio {
  final String id;
  final String nome;
  final String endereco;
  final bool ativo;
  final double raioMetros;
  final double lat;
  final double lng;

  CampoEstagio({
    required this.id,
    required this.nome,
    required this.endereco,
    required this.ativo,
    required this.raioMetros,
    required this.lat,
    required this.lng,
  });

  factory CampoEstagio.fromJson(Map<String, dynamic> json) {
    final rawLat = json['latitude'] ?? json['lat_centro'] ?? json['lat'];
    final rawLng = json['longitude'] ?? json['lng_centro'] ?? json['lng'];
    return CampoEstagio(
      id: (json['id'] ?? '').toString(),
      nome: (json['nome'] ?? 'Campo de Estágio').toString(),
      endereco: (json['endereco'] ?? '').toString(),
      ativo: json['ativo'] ?? true,
      raioMetros: json['raio_metros'] != null ? (json['raio_metros'] as num).toDouble() : 150.0,
      lat: rawLat != null ? (rawLat as num).toDouble() : 0.0,
      lng: rawLng != null ? (rawLng as num).toDouble() : 0.0,
    );
  }
}

class CamposNotifier extends StateNotifier<AsyncValue<List<CampoEstagio>>> {
  final Ref ref;

  CamposNotifier(this.ref) : super(const AsyncValue.loading());

  Future<void> loadCampos() async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('campos_estagio')
          .select('*')
          .isFilter('deleted_at', null)
          .order('nome', ascending: true);

      final campos = (response as List).map((n) => CampoEstagio.fromJson(n)).toList();
      state = AsyncValue.data(campos);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadCamposDoAluno() async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;

      if (userId == null || userId.trim().isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }

      // Busca alocacoes_alunos ativas do aluno
      final response = await supabase
          .from('alocacoes_alunos')
          .select('*, campos_estagio(*)')
          .eq('aluno_id', userId)
          .eq('ativo', true)
          .isFilter('deleted_at', null);

      final campos = (response as List)
          .map((n) => CampoEstagio.fromJson(n['campos_estagio']))
          .toList();

      state = AsyncValue.data(campos);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final camposProvider = StateNotifierProvider<CamposNotifier, AsyncValue<List<CampoEstagio>>>((ref) {
  final notifier = CamposNotifier(ref);
  notifier.loadCampos();
  return notifier;
});

// Provider especifico para os campos onde o aluno está alocado
final camposAlunoProvider = StateNotifierProvider<CamposNotifier, AsyncValue<List<CampoEstagio>>>((ref) {
  final notifier = CamposNotifier(ref);
  notifier.loadCamposDoAluno();
  return notifier;
});
