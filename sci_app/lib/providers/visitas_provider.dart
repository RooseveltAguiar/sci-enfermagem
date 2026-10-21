import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

class VisitaTecnica {
  final String id;
  final String professorId;
  final String? professorNome;
  final String campoId;
  final String? campoNome;
  final String relato;
  final String status; // pendente_validacao | validada | rejeitada
  final double? lat;
  final double? lng;
  final bool gpsDisponivel;
  final double? distanciaMetros;
  final int? nivelConfiancaGps;
  final bool mockLocationDetectado;
  final String? justificativaRejeicao;
  final String? validadoPor;
  final DateTime? validadoEm;
  final DateTime createdAt;

  const VisitaTecnica({
    required this.id,
    required this.professorId,
    this.professorNome,
    required this.campoId,
    this.campoNome,
    required this.relato,
    required this.status,
    this.lat,
    this.lng,
    required this.gpsDisponivel,
    this.distanciaMetros,
    this.nivelConfiancaGps,
    required this.mockLocationDetectado,
    this.justificativaRejeicao,
    this.validadoPor,
    this.validadoEm,
    required this.createdAt,
  });

  factory VisitaTecnica.fromJson(Map<String, dynamic> json) {
    return VisitaTecnica(
      id: (json['id'] ?? '').toString(),
      professorId: (json['professor_id'] ?? '').toString(),
      professorNome: json['nome_professor'] ?? (json['usuarios'] != null ? json['usuarios']['nome'] : null),
      campoId: (json['campo_id'] ?? '').toString(),
      campoNome: json['nome_campo'] ?? (json['campos_estagio'] != null ? json['campos_estagio']['nome'] : null),
      relato: (json['relato'] ?? '').toString(),
      status: (json['status'] ?? 'pendente_validacao').toString(),
      lat: json['lat'] != null ? (json['lat'] as num).toDouble() : null,
      lng: json['lng'] != null ? (json['lng'] as num).toDouble() : null,
      gpsDisponivel: json['gps_disponivel'] ?? false,
      distanciaMetros: json['distancia_metros'] != null ? (json['distancia_metros'] as num).toDouble() : null,
      nivelConfiancaGps: json['nivel_confianca_gps'] != null ? (json['nivel_confianca_gps'] as num).toInt() : null,
      mockLocationDetectado: json['mock_location_detectado'] ?? false,
      justificativaRejeicao: json['justificativa_rejeicao']?.toString(),
      validadoPor: json['validado_por']?.toString(),
      validadoEm: json['validado_em'] != null ? DateTime.tryParse(json['validado_em'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class ProgressoVisitasMensal {
  final String campoId;
  final String campoNome;
  final int realizadas;
  final int minimasRequeridas;

  const ProgressoVisitasMensal({
    required this.campoId,
    required this.campoNome,
    required this.realizadas,
    this.minimasRequeridas = 1,
  });

  bool get atingiuMinimo => realizadas >= minimasRequeridas;
}

class CampoProfessor {
  final String id;
  final String nome;
  final double lat;
  final double lng;
  final double raioMetros;

  const CampoProfessor({
    required this.id,
    required this.nome,
    required this.lat,
    required this.lng,
    this.raioMetros = 300.0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CampoProfessor && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class VisitaEmAndamento {
  final String campoId;
  final String campoNome;
  final String turno;
  final DateTime horaInicio;
  final double latInicio;
  final double lngInicio;
  final double distanciaInicioMetros;

  const VisitaEmAndamento({
    required this.campoId,
    required this.campoNome,
    required this.turno,
    required this.horaInicio,
    required this.latInicio,
    required this.lngInicio,
    required this.distanciaInicioMetros,
  });
}

final visitaEmAndamentoProvider = StateProvider<VisitaEmAndamento?>((ref) => null);

final camposDoProfessorProvider = FutureProvider.autoDispose<List<CampoProfessor>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final meId = supabase.auth.currentUser?.id;
  if (meId == null || meId.isEmpty) return [];

  final result = <CampoProfessor>[];
  final vistos = <String>{};

  try {
    final response = await supabase
        .from('professor_turmas')
        .select('campo_id, campos_estagio(id, nome, lat, lng, raio_metros, deleted_at)')
        .eq('professor_id', meId);

    for (final row in response as List) {
      final campo = row['campos_estagio'] as Map<String, dynamic>?;
      if (campo != null && campo['deleted_at'] == null) {
        final id = campo['id']?.toString();
        final nome = campo['nome']?.toString();
        final lat = campo['lat'] != null ? (campo['lat'] as num).toDouble() : -3.7319;
        final lng = campo['lng'] != null ? (campo['lng'] as num).toDouble() : -38.5267;
        final raio = campo['raio_metros'] != null ? (campo['raio_metros'] as num).toDouble() : 300.0;
        if (id != null && nome != null && vistos.add(id)) {
          result.add(CampoProfessor(id: id, nome: nome, lat: lat, lng: lng, raioMetros: raio));
        }
      }
    }
  } catch (_) {}

  if (result.isNotEmpty) return result;

  // Fallback: busca todos os campos de estágio ativos para que o professor sempre tenha campos disponíveis
  try {
    final allCampos = await supabase
        .from('campos_estagio')
        .select('id, nome, lat, lng, raio_metros')
        .isFilter('deleted_at', null)
        .order('nome');

    for (final row in allCampos as List) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = m['id']?.toString();
      final nome = m['nome']?.toString();
      final lat = m['lat'] != null ? (m['lat'] as num).toDouble() : -3.7319;
      final lng = m['lng'] != null ? (m['lng'] as num).toDouble() : -38.5267;
      final raio = m['raio_metros'] != null ? (m['raio_metros'] as num).toDouble() : 300.0;
      if (id != null && nome != null && vistos.add(id)) {
        result.add(CampoProfessor(id: id, nome: nome, lat: lat, lng: lng, raioMetros: raio));
      }
    }
  } catch (_) {}

  return result;
});

final minhasVisitasProvider = FutureProvider.autoDispose<List<VisitaTecnica>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final meId = supabase.auth.currentUser?.id;

  if (meId == null || meId.isEmpty) return [];

  try {
    final response = await supabase
        .from('visitas_tecnicas')
        .select('*, campos_estagio(nome)')
        .eq('professor_id', meId)
        .order('created_at', ascending: false);

    final list = response as List;
    return list.map((json) => VisitaTecnica.fromJson(json)).toList();
  } catch (_) {
    return [];
  }
});

final progressoVisitasMensalProvider = FutureProvider.family.autoDispose<List<ProgressoVisitasMensal>, String?>((ref, campoIdFiltro) async {
  final supabase = ref.read(supabaseClientProvider);
  final meId = supabase.auth.currentUser?.id;

  if (meId == null || meId.isEmpty) return [];

  try {
    // 1. Busca configuracao de visitas minimas por chave
    int minimas = 1;
    try {
      final configRes = await supabase
          .from('configuracoes')
          .select('valor')
          .eq('chave', 'visitas_minimas_por_mes')
          .maybeSingle();
      if (configRes != null && configRes['valor'] != null) {
        minimas = int.tryParse(configRes['valor'].toString()) ?? 1;
      }
    } catch (_) {}

    // 2. Busca campos vinculados ao professor
    final turmasRes = await supabase
        .from('professor_turmas')
        .select('campo_id, campos_estagio(id, nome)')
        .eq('professor_id', meId);

    final camposMap = <String, String>{};
    for (final row in turmasRes as List) {
      final cId = row['campo_id']?.toString();
      final cNome = row['campos_estagio']?['nome']?.toString() ?? 'Campo de Estágio';
      if (cId != null && cId.isNotEmpty) {
        camposMap[cId] = cNome;
      }
    }

    if (camposMap.isEmpty) return [];

    // 3. Busca visitas validas do mes atual (pendente_validacao ou validada, excluindo rejeitada)
    final agora = DateTime.now();
    final inicioMes = DateTime(agora.year, agora.month, 1).toIso8601String();
    final fimMes = DateTime(agora.year, agora.month + 1, 0, 23, 59, 59).toIso8601String();

    final visitasRes = await supabase
        .from('visitas_tecnicas')
        .select('campo_id, created_at')
        .eq('professor_id', meId)
        .inFilter('status', ['pendente_validacao', 'validada'])
        .gte('created_at', inicioMes)
        .lte('created_at', fimMes);

    final contagemMap = <String, int>{};
    for (final v in visitasRes as List) {
      final cid = v['campo_id']?.toString();
      if (cid != null) {
        contagemMap[cid] = (contagemMap[cid] ?? 0) + 1;
      }
    }

    final result = <ProgressoVisitasMensal>[];
    camposMap.forEach((cId, cNome) {
      if (campoIdFiltro == null || campoIdFiltro == cId) {
        result.add(ProgressoVisitasMensal(
          campoId: cId,
          campoNome: cNome,
          realizadas: contagemMap[cId] ?? 0,
          minimasRequeridas: minimas,
        ));
      }
    });

    return result;
  } catch (_) {
    return [];
  }
});

final visitasPendentesProvider = FutureProvider.autoDispose<List<VisitaTecnica>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);

  try {
    final response = await supabase
        .from('visitas_tecnicas')
        .select('*, campos_estagio(nome), usuarios!visitas_tecnicas_professor_id_fkey(nome)')
        .eq('status', 'pendente_validacao')
        .order('created_at', ascending: false);

    final list = response as List;
    return list.map((json) => VisitaTecnica.fromJson(json)).toList();
  } catch (_) {
    return [];
  }
});

class VisitasService {
  final Ref ref;

  VisitasService(this.ref);

  Future<void> registrarVisita({
    required String campoId,
    required String relato,
    required double? lat,
    required double? lng,
    required bool gpsDisponivel,
    double? distanciaMetros,
    DateTime? horaInicio,
    DateTime? horaFim,
    String? turno,
    double? latSaida,
    double? lngSaida,
    double? distanciaSaidaMetros,
  }) async {
    final relatoTrim = relato.trim();
    if (relatoTrim.length < 30) {
      throw ArgumentError('O relato da visita deve ter no mínimo 30 caracteres.');
    }

    final supabase = ref.read(supabaseClientProvider);
    final meId = supabase.auth.currentUser?.id;

    if (meId == null || meId.isEmpty) {
      throw Exception('Usuário não autenticado');
    }

    String relatoFinal = relatoTrim;
    if (horaInicio != null && horaFim != null) {
      final duracao = horaFim.difference(horaInicio);
      final duracaoStr = '${duracao.inHours}h ${duracao.inMinutes.remainder(60).toString().padLeft(2, '0')}min';
      final hInicioStr = '${horaInicio.hour.toString().padLeft(2, '0')}:${horaInicio.minute.toString().padLeft(2, '0')}:${horaInicio.second.toString().padLeft(2, '0')}';
      final hFimStr = '${horaFim.hour.toString().padLeft(2, '0')}:${horaFim.minute.toString().padLeft(2, '0')}:${horaFim.second.toString().padLeft(2, '0')}';

      relatoFinal = '[REGISTRO ELETRÔNICO DE VISITA TÉCNICA]\n'
          'Turno: ${turno ?? 'Manhã'}\n'
          'Entrada (Início): $hInicioStr\n'
          'Saída (Término): $hFimStr\n'
          'Tempo de Permanência em Campo: $duracaoStr\n'
          '--------------------------------------------------\n'
          'RELATÓRIO DA VISITA:\n$relatoTrim';
    }

    await supabase.from('visitas_tecnicas').insert({
      'professor_id': meId,
      'campo_id': campoId,
      'relato': relatoFinal,
      'status': 'pendente_validacao',
      'lat': lat,
      'lng': lng,
      'gps_disponivel': gpsDisponivel,
      'distancia_metros': distanciaMetros,
    });

    ref.read(visitaEmAndamentoProvider.notifier).state = null;
    ref.invalidate(minhasVisitasProvider);
    ref.invalidate(progressoVisitasMensalProvider);
  }

  Future<void> validarVisita(String visitaId) async {
    final supabase = ref.read(supabaseClientProvider);
    final meId = supabase.auth.currentUser?.id;

    await supabase.from('visitas_tecnicas').update({
      'status': 'validada',
      'validado_por': meId,
      'validado_em': DateTime.now().toIso8601String(),
    }).eq('id', visitaId);

    ref.invalidate(visitasPendentesProvider);
  }

  Future<void> rejeitarVisita(String visitaId, String justificativa) async {
    final justTrim = justificativa.trim();
    if (justTrim.length < 20) {
      throw ArgumentError('A justificativa de rejeição deve ter no mínimo 20 caracteres.');
    }

    final supabase = ref.read(supabaseClientProvider);
    final meId = supabase.auth.currentUser?.id;

    await supabase.from('visitas_tecnicas').update({
      'status': 'rejeitada',
      'justificativa_rejeicao': justTrim,
      'validado_por': meId,
      'validado_em': DateTime.now().toIso8601String(),
    }).eq('id', visitaId);

    ref.invalidate(visitasPendentesProvider);
  }
}

final visitasServiceProvider = Provider<VisitasService>((ref) => VisitasService(ref));
