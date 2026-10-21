import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

class Frequencia {
  final String id;
  final String alunoId;
  final String? alunoNome;
  final String? campoNome;
  final String? turnoDescricao;
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
    this.campoNome,
    this.turnoDescricao,
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
      alunoId: json['aluno_id'] ?? json['usuario_id'] ?? '',
      alunoNome: json['nome_aluno'] ?? (json['usuarios'] != null ? json['usuarios']['nome'] : null),
      campoNome: json['nome_campo'] ?? (json['alocacoes_alunos']?['campos_estagio']?['nome']),
      turnoDescricao: json['turno_descricao'] ?? (json['turnos']?['descricao']),
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
  final ref;

  FrequenciaNotifier(this.ref) : super(const AsyncValue.loading());

  Future<void> loadPendentesValidacao() async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('frequencias')
          .select('*, usuarios(nome), alocacoes_alunos(campos_estagio(nome)), turnos(descricao)')
          .eq('status', 'pendente_validacao')
          .isFilter('deleted_at', null)
          .order('data_registro', ascending: false);

      final List<Frequencia> frequencias = (response as List).map((json) => Frequencia.fromJson(json)).toList();
      state = AsyncValue.data(frequencias);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadPendentesRatificacao() async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('frequencias')
          .select('*, usuarios(nome), alocacoes_alunos(campos_estagio(nome)), turnos(descricao)')
          .eq('status', 'abonado_pend_ratificacao')
          .isFilter('deleted_at', null)
          .order('data_registro', ascending: false);

      final List<Frequencia> frequencias = (response as List).map((json) => Frequencia.fromJson(json)).toList();
      state = AsyncValue.data(frequencias);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadHistoricoAluno() async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('vw_percentual_frequencia') // usa a view para historico
          .select('*')
          .order('data_registro', ascending: false);

      final List<Frequencia> frequencias = (response as List).map((json) => Frequencia.fromJson(json)).toList();
      state = AsyncValue.data(frequencias);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> validarFrequencia(String id) async {
    await _atualizarStatus(id, 'validado');
    _removerDaLista(id);
  }

  Future<void> rejeitarFrequencia(String id, String justificativa) async {
    final supabase = ref.read(supabaseClientProvider);
    await supabase.from('rejeicoes').insert({
      'frequencia_id': id,
      'rejeitado_por': supabase.auth.currentUser!.id,
      'etapa': 'validacao',
      'justificativa': justificativa,
    });
    _removerDaLista(id);
  }

  Future<void> ratificarAbono(String id) async {
    final supabase = ref.read(supabaseClientProvider);
    await supabase.from('ratificacoes').insert({
      'frequencia_id': id,
      'ratificado_por': supabase.auth.currentUser!.id,
      'decisao': 'ratificado',
    });
    _removerDaLista(id);
  }

  Future<void> recusarAbono(String id, String justificativa) async {
    final supabase = ref.read(supabaseClientProvider);
    await supabase.from('ratificacoes').insert({
      'frequencia_id': id,
      'ratificado_por': supabase.auth.currentUser!.id,
      'decisao': 'recusado',
      'justificativa': justificativa,
    });
    _removerDaLista(id);
  }

  Future<void> _atualizarStatus(String id, String status) async {
    final supabase = ref.read(supabaseClientProvider);
    await supabase.from('frequencias').update({'status': status}).eq('id', id);
  }

  void _removerDaLista(String id) {
    if (state.hasValue) {
      final atual = state.value!;
      state = AsyncValue.data(atual.where((f) => f.id != id).toList());
    }
  }
}

// Providers instanciados
final pendentesValidacaoProvider = StateNotifierProvider<FrequenciaNotifier, AsyncValue<List<Frequencia>>>((ref) {
  final notifier = FrequenciaNotifier(ref);
  notifier.loadPendentesValidacao();
  return notifier;
});

final pendentesRatificacaoProvider = StateNotifierProvider<FrequenciaNotifier, AsyncValue<List<Frequencia>>>((ref) {
  final notifier = FrequenciaNotifier(ref);
  notifier.loadPendentesRatificacao();
  return notifier;
});

final historicoAlunoProvider = StateNotifierProvider<FrequenciaNotifier, AsyncValue<List<Frequencia>>>((ref) {
  final notifier = FrequenciaNotifier(ref);
  notifier.loadHistoricoAluno();
  return notifier;
});

// Provider para trilha de auditoria
final auditoriaFrequenciaProvider = FutureProvider.family<List<dynamic>, String>((ref, frequenciaId) async {
  final supabase = ref.read(supabaseClientProvider);
  final response = await supabase
      .from('vw_trilha_auditoria_frequencia')
      .select('*')
      .eq('frequencia_id', frequenciaId)
      .order('timestamp_alteracao', ascending: true);
  return response as List;
});
