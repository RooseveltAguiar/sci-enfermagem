import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

class AtividadePadraoModel {
  final String id;
  final String nome;
  final String? descricaoPadrao;
  final bool ativo;

  const AtividadePadraoModel({
    required this.id,
    required this.nome,
    this.descricaoPadrao,
    this.ativo = true,
  });

  factory AtividadePadraoModel.fromJson(Map<String, dynamic> json) {
    return AtividadePadraoModel(
      id: json['id'] as String,
      nome: json['nome'] as String,
      descricaoPadrao: json['descricao_padrao'] as String?,
      ativo: json['ativo'] as bool? ?? true,
    );
  }
}

final atividadesPadraoProvider = FutureProvider<List<AtividadePadraoModel>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final response = await supabase
      .from('lista_atividades_padrao')
      .select('id, nome, ativo')
      .eq('ativo', true)
      .isFilter('deleted_at', null)
      .order('nome', ascending: true);

  return (response as List<dynamic>)
      .map((item) => AtividadePadraoModel.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList();
});

class AtividadesAlunoNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref ref;

  AtividadesAlunoNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadAtividades();
  }

  Future<void> loadAtividades() async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseClientProvider);
      final user = supabase.auth.currentUser;
      if (user == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final response = await supabase
          .from('atividades')
          .select('*, alocacoes_alunos(aluno_id, campos_estagio(nome)), lista_atividades:lista_atividades_padrao(nome)')
          .eq('aluno_id', user.id)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      final list = (response as List<dynamic>)
          .map((e) {
            final item = Map<String, dynamic>.from(e as Map);
            final descOutra = item['descricao_outra'];
            final nomePadrao = item['lista_atividades'] != null ? item['lista_atividades']['nome'] : null;
            item['descricao'] = descOutra ?? nomePadrao ?? 'Atividade';
            item['nome'] = item['descricao'];

            final rawData = item['data_registro'] ?? item['data_atividade'] ?? item['data'] ?? item['created_at'];
            item['data_formatada'] = _formatarDataBR(rawData);
            item['data_atividade'] = item['data_formatada'];
            return item;
          })
          .toList();
      state = AsyncValue.data(list);
    } catch (_) {
      state = const AsyncValue.data([]);
    }
  }

  static String _formatarDataBR(dynamic val) {
    if (val == null) return '';
    final raw = val.toString().trim();
    if (raw.isEmpty) return '';
    final dateOnly = raw.split('T')[0].split(' ')[0];
    final parts = dateOnly.split('-');
    if (parts.length == 3 && parts[0].length == 4) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return dateOnly;
  }

  Future<void> registrarAtividades({
    List<String>? selecionadasIds,
    List<String>? selecionadas,
    String? outraDescricao,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    dynamic user;
    try {
      user = supabase.auth.currentUser;
    } catch (_) {}

    if (user != null) {
      final userId = user.id as String;

      // Buscar alocação do aluno no Supabase
      Map<String, dynamic>? alocRes;
      try {
        alocRes = await supabase
            .from('alocacoes_alunos')
            .select('id')
            .eq('aluno_id', userId)
            .isFilter('deleted_at', null)
            .limit(1)
            .maybeSingle();
      } catch (_) {}

      if (alocRes == null) {
        try {
          alocRes = await supabase
              .from('alocacoes')
              .select('id')
              .eq('aluno_id', userId)
              .limit(1)
              .maybeSingle();
        } catch (_) {}
      }

      if (alocRes == null) {
        throw Exception('Nenhuma alocação de estágio ativa encontrada para o aluno.');
      }

      final alocacaoId = alocRes['id'] as String;
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final payload = <Map<String, dynamic>>[];

      // 1. Atividades Padrão enviadas diretamente por ID
      if (selecionadasIds != null && selecionadasIds.isNotEmpty) {
        for (final id in selecionadasIds) {
          payload.add({
            'alocacao_id': alocacaoId,
            'aluno_id': userId,
            'created_by': userId,
            'tipo': 'padrao',
            'lista_atividade_id': id,
            'data_registro': todayStr,
            'status': 'pendente_validacao',
          });
        }
      } else if (selecionadas != null && selecionadas.isNotEmpty) {
        // Fallback legado para envio por nome
        final Map<String, String> nomeToIdMap = {};
        try {
          final listRes = await supabase.from('lista_atividades_padrao').select('id, nome');
          for (final item in (listRes as List)) {
            if (item['nome'] != null && item['id'] != null) {
              nomeToIdMap[item['nome'].toString().trim().toLowerCase()] = item['id'].toString();
            }
          }
        } catch (_) {}

        if (nomeToIdMap.isEmpty) {
          try {
            final listRes = await supabase.from('lista_atividades').select('id, nome');
            for (final item in (listRes as List)) {
              if (item['nome'] != null && item['id'] != null) {
                nomeToIdMap[item['nome'].toString().trim().toLowerCase()] = item['id'].toString();
              }
            }
          } catch (_) {}
        }

        for (final item in selecionadas) {
          var listaId = nomeToIdMap[item.trim().toLowerCase()];
          if (listaId == null || listaId.isEmpty) {
            try {
              final singleRes = await supabase
                  .from('lista_atividades_padrao')
                  .select('id')
                  .ilike('nome', '%${item.trim()}%')
                  .limit(1)
                  .maybeSingle();
              if (singleRes != null && singleRes['id'] != null) {
                listaId = singleRes['id'].toString();
              }
            } catch (_) {}
          }

          if (listaId == null || listaId.isEmpty) {
            throw Exception('Atividade padrão "$item" não encontrada na tabela lista_atividades_padrao.');
          }

          payload.add({
            'alocacao_id': alocacaoId,
            'aluno_id': userId,
            'created_by': userId,
            'tipo': 'padrao',
            'lista_atividade_id': listaId,
            'data_registro': todayStr,
            'status': 'pendente_validacao',
          });
        }
      }

      // 2. Atividade Outra (tipo = 'outra', descricao_outra)
      if (outraDescricao != null && outraDescricao.trim().isNotEmpty) {
        payload.add({
          'alocacao_id': alocacaoId,
          'aluno_id': userId,
          'created_by': userId,
          'tipo': 'outra',
          'descricao_outra': outraDescricao.trim(),
          'data_registro': todayStr,
          'status': 'pendente_validacao',
        });
      }

      await supabase.from('atividades').insert(payload);
      await loadAtividades();
    } else {
      throw Exception('Usuário não autenticado no Supabase.');
    }
  }

  void refresh() {
    loadAtividades();
  }
}

final atividadesAlunoProvider =
    StateNotifierProvider<AtividadesAlunoNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return AtividadesAlunoNotifier(ref);
});
