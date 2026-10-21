import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/sugestao_model.dart';
import '../data/repositories/sugestoes_repository.dart';
import 'auth_provider.dart';

final sugestoesRepositoryProvider = Provider<SugestoesRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return SugestoesRepository(supabase);
});

final sugestoesFiltroPerfilProvider = StateProvider<String>((ref) => 'todos');

final sugestoesControllerProvider = StateNotifierProvider<
    SugestoesController, AsyncValue<List<SugestaoModel>>>((ref) {
  final repo = ref.watch(sugestoesRepositoryProvider);
  return SugestoesController(repo, ref);
});

class SugestoesController
    extends StateNotifier<AsyncValue<List<SugestaoModel>>> {
  final SugestoesRepository _repo;
  final Ref _ref;

  SugestoesController(this._repo, this._ref)
      : super(const AsyncValue.loading()) {
    carregarSugestoes();
  }

  Future<void> carregarSugestoes({bool isCoordenacao = false}) async {
    state = const AsyncValue.loading();
    try {
      if (isCoordenacao) {
        final filtro = _ref.read(sugestoesFiltroPerfilProvider);
        final lista = await _repo.listarTodasSugestoes(perfil: filtro);
        state = AsyncValue.data(lista);
      } else {
        final lista = await _repo.listarMinhasSugestoes();
        state = AsyncValue.data(lista);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> enviarSugestao(String conteudo, {bool isCoordenacao = false}) async {
    await _repo.enviarSugestao(conteudo);
    await carregarSugestoes(isCoordenacao: isCoordenacao);
  }
}
