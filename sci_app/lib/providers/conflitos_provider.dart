import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/conflito_model.dart';
import '../data/repositories/conflitos_repository.dart';
import 'auth_provider.dart';

final conflitosRepositoryProvider = Provider<ConflitosRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ConflitosRepository(supabase);
});

final conflitosFiltroCampoProvider = StateProvider<String?>((ref) => null);

final conflitosControllerProvider = StateNotifierProvider<
    ConflitosController, AsyncValue<List<ConflitoModel>>>((ref) {
  final repo = ref.watch(conflitosRepositoryProvider);
  return ConflitosController(repo, ref);
});

class ConflitosController
    extends StateNotifier<AsyncValue<List<ConflitoModel>>> {
  final ConflitosRepository _repo;
  final Ref _ref;

  ConflitosController(this._repo, this._ref)
      : super(const AsyncValue.loading()) {
    carregarConflitos();
  }

  Future<void> carregarConflitos({
    String? campoId,
    DateTime? dataInicio,
    DateTime? dataFim,
  }) async {
    state = const AsyncValue.loading();
    try {
      final filtroCampo = campoId ?? _ref.read(conflitosFiltroCampoProvider);
      final lista = await _repo.listarConflitos(
        campoId: filtroCampo,
        dataInicio: dataInicio,
        dataFim: dataFim,
      );
      state = AsyncValue.data(lista);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> registrarConflito({
    required String alunoId,
    required String campoId,
    required String descricao,
    required DateTime dataOcorrencia,
  }) async {
    await _repo.registrarConflito(
      alunoId: alunoId,
      campoId: campoId,
      descricao: descricao,
      dataOcorrencia: dataOcorrencia,
    );
    await carregarConflitos();
  }
}
