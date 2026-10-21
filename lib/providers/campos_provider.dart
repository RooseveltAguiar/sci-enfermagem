import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

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
    return CampoEstagio(
      id: json['id'],
      nome: json['nome'],
      endereco: json['endereco'],
      ativo: json['ativo'] ?? true,
      raioMetros: json['raio_metros'] != null ? (json['raio_metros'] as num).toDouble() : 150.0,
      lat: json['lat_centro'] != null ? (json['lat_centro'] as num).toDouble() : 0.0,
      lng: json['lng_centro'] != null ? (json['lng_centro'] as num).toDouble() : 0.0,
    );
  }
}

class CamposNotifier extends StateNotifier<AsyncValue<List<CampoEstagio>>> {
  final ref;

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
      final userId = supabase.auth.currentUser!.id;

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
