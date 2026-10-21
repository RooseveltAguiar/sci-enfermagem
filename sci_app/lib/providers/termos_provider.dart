import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/termo_model.dart';
import '../data/repositories/termos_repository.dart';
import 'auth_provider.dart';

final termosRepositoryProvider = Provider<TermosRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return TermosRepository(supabase);
});

final termoAtivoProvider = FutureProvider<TermoModel?>((ref) async {
  final repo = ref.read(termosRepositoryProvider);
  return await repo.buscarTermoAtivo();
});

final termoPendenteProvider = FutureProvider<bool>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return false;

  final repo = ref.read(termosRepositoryProvider);
  return await repo.verificarTermoPendente(userId);
});

final termosListaProvider =
    StateNotifierProvider<TermosListaController, AsyncValue<List<TermoModel>>>(
  (ref) {
    final repo = ref.watch(termosRepositoryProvider);
    return TermosListaController(repo, ref);
  },
);

class TermosListaController
    extends StateNotifier<AsyncValue<List<TermoModel>>> {
  final TermosRepository _repo;
  final Ref _ref;

  TermosListaController(this._repo, this._ref)
      : super(const AsyncValue.loading()) {
    carregarTermos();
  }

  Future<void> carregarTermos() async {
    state = const AsyncValue.loading();
    try {
      final lista = await _repo.listarTodasVersoes();
      state = AsyncValue.data(lista);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> criarTermo({
    required String titulo,
    required String versao,
    required String conteudo,
    required DateTime vigenciaInicio,
    required bool ativar,
  }) async {
    await _repo.criarTermo(
      titulo: titulo,
      versao: versao,
      conteudo: conteudo,
      vigenciaInicio: vigenciaInicio,
      ativar: ativar,
    );
    _ref.invalidate(termoAtivoProvider);
    _ref.invalidate(termoPendenteProvider);
    await carregarTermos();
  }

  Future<void> ativarVersao(String id) async {
    await _repo.ativarVersao(id);
    _ref.invalidate(termoAtivoProvider);
    _ref.invalidate(termoPendenteProvider);
    await carregarTermos();
  }

  Future<void> aceitarTermo(String versao) async {
    await _repo.aceitarTermo(versao);
    _ref.invalidate(termoPendenteProvider);
  }
}
