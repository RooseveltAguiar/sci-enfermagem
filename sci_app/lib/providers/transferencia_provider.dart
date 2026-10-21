import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/transferencia_repository.dart';
import 'auth_provider.dart';

final transferenciaRepositoryProvider =
    Provider<TransferenciaRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return TransferenciaRepository(supabase);
});

class TransferenciaState {
  final bool isLoading;
  final String? erro;
  final bool sucesso;

  const TransferenciaState({
    this.isLoading = false,
    this.erro,
    this.sucesso = false,
  });

  TransferenciaState copyWith({
    bool? isLoading,
    String? erro,
    bool? sucesso,
  }) {
    return TransferenciaState(
      isLoading: isLoading ?? this.isLoading,
      erro: erro,
      sucesso: sucesso ?? this.sucesso,
    );
  }
}

final transferenciaControllerProvider =
    StateNotifierProvider<TransferenciaController, TransferenciaState>((ref) {
  final repo = ref.watch(transferenciaRepositoryProvider);
  return TransferenciaController(repo);
});

class TransferenciaController extends StateNotifier<TransferenciaState> {
  final TransferenciaRepository _repo;

  TransferenciaController(this._repo) : super(const TransferenciaState());

  Future<void> transferirAluno({
    required String alunoId,
    required String campoDestinoId,
    required String turnoDestinoId,
  }) async {
    state = state.copyWith(isLoading: true, erro: null, sucesso: false);
    try {
      await _repo.transferirAluno(
        alunoId: alunoId,
        campoDestinoId: campoDestinoId,
        turnoDestinoId: turnoDestinoId,
      );
      state = const TransferenciaState(isLoading: false, sucesso: true);
    } catch (e) {
      state = TransferenciaState(
        isLoading: false,
        erro: e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }
}
