import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/avaliacao_model.dart';
import '../data/repositories/avaliacao_repository.dart';
import 'auth_provider.dart';

final avaliacaoRepositoryProvider = Provider<AvaliacaoRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AvaliacaoRepository(supabase);
});

class AvaliacoesNotifier extends AsyncNotifier<List<AvaliacaoModel>> {
  @override
  Future<List<AvaliacaoModel>> build() async {
    return _fetchAvaliacoes();
  }

  Future<List<AvaliacaoModel>> _fetchAvaliacoes() async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return [];

    return ref.read(avaliacaoRepositoryProvider).listar();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchAvaliacoes());
  }

  Future<AvaliacaoModel> salvarRascunho(Map<String, dynamic> data) async {
    final result = await ref.read(avaliacaoRepositoryProvider).salvarRascunho(data);
    await refresh();
    return result;
  }

  Future<void> submitAvaliacao(String id) async {
    await ref.read(avaliacaoRepositoryProvider).submeter(id);
    await refresh();
  }

  Future<void> validarAvaliacao(String id, {String? comentario}) async {
    await ref.read(avaliacaoRepositoryProvider).validar(id, comentario: comentario);
    await refresh();
  }

  Future<void> aprovarAvaliacao(String id, {String? comentario}) async {
    await ref.read(avaliacaoRepositoryProvider).aprovar(id, comentario: comentario);
    await refresh();
  }

  Future<void> devolverAvaliacao(String id, String comentario) async {
    await ref.read(avaliacaoRepositoryProvider).devolver(id, comentario);
    await refresh();
  }

  Future<void> excluirRascunho(String id) async {
    await ref.read(avaliacaoRepositoryProvider).excluirRascunho(id);
    await refresh();
  }
}

final avaliacoesProvider =
    AsyncNotifierProvider<AvaliacoesNotifier, List<AvaliacaoModel>>(
  AvaliacoesNotifier.new,
);

final pendentesValidacaoProvider = Provider<AsyncValue<List<AvaliacaoModel>>>((ref) {
  final asyncLista = ref.watch(avaliacoesProvider);
  return asyncLista.whenData((list) =>
      list.where((a) => a.status == 'submetida').toList());
});
