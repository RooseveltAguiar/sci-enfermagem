import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

class Notificacao {
  final String id;
  final String mensagem;
  final String? tipo;
  final String? frequenciaId;
  final String dataCriacao;
  final bool lida;

  Notificacao({
    required this.id,
    required this.mensagem,
    this.tipo,
    this.frequenciaId,
    required this.dataCriacao,
    required this.lida,
  });

  factory Notificacao.fromJson(Map<String, dynamic> json) {
    return Notificacao(
      id: json['id'],
      mensagem: json['mensagem'],
      tipo: json['tipo_notificacao'],
      frequenciaId: json['frequencia_id'],
      dataCriacao: json['created_at'],
      lida: json['lida'] ?? false,
    );
  }
}

class NotificacoesNotifier extends StateNotifier<AsyncValue<List<Notificacao>>> {
  final ref;

  NotificacoesNotifier(this.ref) : super(const AsyncValue.loading());

  Future<void> loadNotificacoes() async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('notificacoes')
          .select('*')
          .order('created_at', ascending: false);

      final notificacoes = (response as List).map((n) => Notificacao.fromJson(n)).toList();
      state = AsyncValue.data(notificacoes);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> marcarComoLida(String id) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.rpc('fn_marcar_notificacao_lida', params: {'p_id': id});
      
      if (state.hasValue) {
        final atual = state.value!;
        state = AsyncValue.data(
          atual.map((n) => n.id == id ? Notificacao(
            id: n.id, 
            mensagem: n.mensagem, 
            dataCriacao: n.dataCriacao, 
            lida: true, 
            frequenciaId: n.frequenciaId, 
            tipo: n.tipo
          ) : n).toList()
        );
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> marcarTodasComoLidas() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.rpc('fn_marcar_todas_notificacoes_lidas');
      
      if (state.hasValue) {
        final atual = state.value!;
        state = AsyncValue.data(
          atual.map((n) => Notificacao(
            id: n.id, 
            mensagem: n.mensagem, 
            dataCriacao: n.dataCriacao, 
            lida: true, 
            frequenciaId: n.frequenciaId, 
            tipo: n.tipo
          )).toList()
        );
      }
    } catch (e) {
      // ignore
    }
  }
}

final notificacoesProvider = StateNotifierProvider<NotificacoesNotifier, AsyncValue<List<Notificacao>>>((ref) {
  final notifier = NotificacoesNotifier(ref);
  notifier.loadNotificacoes();
  return notifier;
});

final notificacoesNaoLidasCountProvider = Provider<int>((ref) {
  final asyncState = ref.watch(notificacoesProvider);
  return asyncState.maybeWhen(
    data: (notificacoes) => notificacoes.where((n) => !n.lida).length,
    orElse: () => 0,
  );
});
