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

final camposDoProfessorProvider = FutureProvider.autoDispose<List<({String id, String nome})>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final meId = supabase.auth.currentUser?.id;
  if (meId == null || meId.isEmpty) return [];

  try {
    final response = await supabase
        .from('professor_turmas')
        .select('campo_id, campos_estagio(id, nome)')
        .eq('professor_id', meId);

    final vistos = <String>{};
    final result = <({String id, String nome})>[];
    for (final row in response as List) {
      final campo = row['campos_estagio'] as Map<String, dynamic>?;
      final id = campo?['id']?.toString();
      final nome = campo?['nome']?.toString();
      if (id != null && nome != null && vistos.add(id)) {
        result.add((id: id, nome: nome));
      }
    }
    return result;
  } catch (_) {
    return [];
  }
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

    await supabase.from('visitas_tecnicas').insert({
      'professor_id': meId,
      'campo_id': campoId,
      'relato': relatoTrim,
      'status': 'pendente_validacao',
      'lat': lat,
      'lng': lng,
      'gps_disponivel': gpsDisponivel,
      'distancia_metros': distanciaMetros,
    });

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
