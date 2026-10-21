import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/export_service.dart';
import 'auth_provider.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ExportService(supabase);
});

class ExportState {
  final bool loading;
  final String? progressoMensagem;
  final String? erro;
  final bool sucesso;

  const ExportState({
    this.loading = false,
    this.progressoMensagem,
    this.erro,
    this.sucesso = false,
  });

  ExportState copyWith({
    bool? loading,
    String? progressoMensagem,
    String? erro,
    bool? sucesso,
    bool clearErro = false,
  }) {
    return ExportState(
      loading: loading ?? this.loading,
      progressoMensagem: progressoMensagem ?? this.progressoMensagem,
      erro: clearErro ? null : (erro ?? this.erro),
      sucesso: sucesso ?? this.sucesso,
    );
  }
}

class ExportNotifier extends StateNotifier<ExportState> {
  final ExportService _exportService;

  ExportNotifier(this._exportService) : super(const ExportState());

  Future<void> gerarPdf({
    required String tipo,
    required DateTime dataInicio,
    required DateTime dataFim,
    String? campoId,
    String? alunoId,
  }) async {
    state = state.copyWith(loading: true, progressoMensagem: 'Gerando PDF...', clearErro: true, sucesso: false);
    try {
      await _exportService.exportarRelatorioEmPdf(
        tipo: tipo,
        dataInicio: dataInicio,
        dataFim: dataFim,
        campoId: campoId,
        alunoId: alunoId,
      );
      state = state.copyWith(loading: false, progressoMensagem: null, sucesso: true);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        progressoMensagem: null,
        erro: e.toString().replaceAll('Exception: ', ''),
        sucesso: false,
      );
    }
  }

  Future<void> gerarCsv({
    required String tipo,
    required DateTime dataInicio,
    required DateTime dataFim,
    String? campoId,
  }) async {
    state = state.copyWith(loading: true, progressoMensagem: 'Gerando CSV...', clearErro: true, sucesso: false);
    try {
      await _exportService.exportarRelatorioEmCsv(
        tipo: tipo,
        dataInicio: dataInicio,
        dataFim: dataFim,
        campoId: campoId,
      );
      state = state.copyWith(loading: false, progressoMensagem: null, sucesso: true);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        progressoMensagem: null,
        erro: e.toString().replaceAll('Exception: ', ''),
        sucesso: false,
      );
    }
  }

  void reset() {
    state = const ExportState();
  }
}

final exportProvider = StateNotifierProvider<ExportNotifier, ExportState>((ref) {
  final service = ref.watch(exportServiceProvider);
  return ExportNotifier(service);
});
