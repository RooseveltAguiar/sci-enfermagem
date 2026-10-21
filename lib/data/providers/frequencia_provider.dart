import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Dependência do Supabase Client
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Modelo simples para Frequencia (pode ser movido para lib/data/models futuramente)
class Frequencia {
  final String id;
  final String alunoId;
  final String? alunoNome;
  final String dataRegistro;
  final String status;
  final double? lat;
  final double? lng;
  final bool gpsDisponivel;
  final double? distanciaMetros;
  final bool mockLocationDetectado;
  final double? velocidadeMs;

  Frequencia({
    required this.id,
    required this.alunoId,
    this.alunoNome,
    required this.dataRegistro,
    required this.status,
    this.lat,
    this.lng,
    required this.gpsDisponivel,
    this.distanciaMetros,
    required this.mockLocationDetectado,
    this.velocidadeMs,
  });

  factory Frequencia.fromJson(Map<String, dynamic> json) {
    return Frequencia(
      id: json['id'],
      alunoId: json['aluno_id'],
      alunoNome: json['usuarios'] != null ? json['usuarios']['nome'] : null,
      dataRegistro: json['data_registro'],
      status: json['status'],
      lat: json['lat_registro'] != null ? (json['lat_registro'] as num).toDouble() : null,
      lng: json['lng_registro'] != null ? (json['lng_registro'] as num).toDouble() : null,
      gpsDisponivel: json['gps_disponivel'] ?? false,
      distanciaMetros: json['distancia_metros'] != null ? (json['distancia_metros'] as num).toDouble() : null,
      mockLocationDetectado: json['mock_location_detectado'] ?? false,
      velocidadeMs: json['velocidade_ms'] != null ? (json['velocidade_ms'] as num).toDouble() : null,
    );
  }
}

class FrequenciaNotifier extends StateNotifier<AsyncValue<List<Frequencia>>> {
  final SupabaseClient _supabase;

  FrequenciaNotifier(this._supabase) : super(const AsyncValue.loading());

  Future<void> loadPendentesValidacao() async {
    state = const AsyncValue.loading();
    try {
      // Como o RLS já filtra os campos que o supervisor (Ator 2) tem acesso, 
      // basta buscar as frequências com status pendente.
      final response = await _supabase
          .from('frequencias')
          .select('*, usuarios(nome)')
          .eq('status', 'pendente_validacao')
          .isFilter('deleted_at', null)
          .order('data_registro', ascending: false);

      final List<Frequencia> frequencias = (response as List)
          .map((json) => Frequencia.fromJson(json))
          .toList();
      state = AsyncValue.data(frequencias);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadPendentesRatificacao() async {
    state = const AsyncValue.loading();
    try {
      final response = await _supabase
          .from('frequencias')
          .select('*, usuarios(nome)')
          .eq('status', 'abonado_pend_ratificacao')
          .isFilter('deleted_at', null)
          .order('data_registro', ascending: false);

      final List<Frequencia> frequencias = (response as List)
          .map((json) => Frequencia.fromJson(json))
          .toList();
      state = AsyncValue.data(frequencias);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> validarFrequencia(String id) async {
    await _atualizarStatus(id, 'validado');
    // Remove da lista local se estivermos exibindo pendentes
    _removerDaLista(id);
  }

  Future<void> rejeitarFrequencia(String id, String justificativa) async {
    // 1. Inserir rejeição (isso disparará o trigger que muda status e notifica)
    await _supabase.from('rejeicoes').insert({
      'frequencia_id': id,
      'rejeitado_por': _supabase.auth.currentUser!.id,
      'etapa': 'validacao',
      'justificativa': justificativa,
    });
    _removerDaLista(id);
  }

  Future<void> ratificarAbono(String id) async {
    await _supabase.from('ratificacoes').insert({
      'frequencia_id': id,
      'ratificado_por': _supabase.auth.currentUser!.id,
      'decisao': 'ratificado',
    });
    _removerDaLista(id);
  }

  Future<void> recusarAbono(String id, String justificativa) async {
    await _supabase.from('ratificacoes').insert({
      'frequencia_id': id,
      'ratificado_por': _supabase.auth.currentUser!.id,
      'decisao': 'recusado',
      'justificativa': justificativa,
    });
    _removerDaLista(id);
  }

  Future<void> _atualizarStatus(String id, String status) async {
    await _supabase.from('frequencias').update({
      'status': status,
    }).eq('id', id);
  }

  void _removerDaLista(String id) {
    if (state.hasValue) {
      final atual = state.value!;
      state = AsyncValue.data(atual.where((f) => f.id != id).toList());
    }
  }
}

// Provider para o Supervisor (Ator 2)
final pendentesValidacaoProvider = StateNotifierProvider<FrequenciaNotifier, AsyncValue<List<Frequencia>>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final notifier = FrequenciaNotifier(supabase);
  notifier.loadPendentesValidacao();
  return notifier;
});

// Provider para o Professor (Ator 3)
final pendentesRatificacaoProvider = StateNotifierProvider<FrequenciaNotifier, AsyncValue<List<Frequencia>>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final notifier = FrequenciaNotifier(supabase);
  notifier.loadPendentesRatificacao();
  return notifier;
});
