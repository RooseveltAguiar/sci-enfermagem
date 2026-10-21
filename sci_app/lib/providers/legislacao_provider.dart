import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/legislacao_model.dart';
import '../data/repositories/legislacao_repository.dart';
import 'auth_provider.dart';

final legislacaoRepositoryProvider = Provider<LegislacaoRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return LegislacaoRepository(supabase);
});

final legislacoesProvider =
    StateNotifierProvider<LegislacoesController, AsyncValue<List<LegislacaoModel>>>(
  (ref) {
    final repository = ref.watch(legislacaoRepositoryProvider);
    return LegislacoesController(repository);
  },
);

class LegislacoesController
    extends StateNotifier<AsyncValue<List<LegislacaoModel>>> {
  final LegislacaoRepository _repository;

  LegislacoesController(this._repository) : super(const AsyncValue.loading()) {
    carregarLegislacoes();
  }

  Future<void> carregarLegislacoes() async {
    state = const AsyncValue.loading();
    try {
      final lista = await _repository.listarLegislacoesAtivas();
      state = AsyncValue.data(lista);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> criarLegislacao({
    required String titulo,
    required String conteudo,
    required String tipo,
    DateTime? vigenciaInicio,
    DateTime? vigenciaFim,
    required bool ativo,
  }) async {
    await _repository.criarLegislacao(
      titulo: titulo,
      conteudo: conteudo,
      tipo: tipo,
      vigenciaInicio: vigenciaInicio,
      vigenciaFim: vigenciaFim,
      ativo: ativo,
    );
    await carregarLegislacoes();
  }

  Future<void> editarLegislacao({
    required String id,
    required String titulo,
    required String conteudo,
    required String tipo,
    DateTime? vigenciaInicio,
    DateTime? vigenciaFim,
    required bool ativo,
  }) async {
    await _repository.editarLegislacao(
      id: id,
      titulo: titulo,
      conteudo: conteudo,
      tipo: tipo,
      vigenciaInicio: vigenciaInicio,
      vigenciaFim: vigenciaFim,
      ativo: ativo,
    );
    await carregarLegislacoes();
  }

  Future<void> desativarLegislacao(String id) async {
    await _repository.desativarLegislacao(id);
    await carregarLegislacoes();
  }
}
