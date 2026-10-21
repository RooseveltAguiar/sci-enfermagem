import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'banco_horas_provider.dart';
import '../data/models/conflito_model.dart';

class ResumoAcademicoData {
  final double percentualFrequencia;
  final int atividadesRegistradas;
  final int atividadesValidadas;
  final double? notaMediaDoInterno;
  final double? notaAutoavaliacao;
  final bool termosAceitos;

  const ResumoAcademicoData({
    required this.percentualFrequencia,
    required this.atividadesRegistradas,
    required this.atividadesValidadas,
    this.notaMediaDoInterno,
    this.notaAutoavaliacao,
    required this.termosAceitos,
  });

  factory ResumoAcademicoData.fromJson(Map<String, dynamic> json) {
    return ResumoAcademicoData(
      percentualFrequencia: (json['percentual_frequencia'] as num?)?.toDouble() ?? 0.0,
      atividadesRegistradas: (json['atividades_registradas'] as num?)?.toInt() ?? 0,
      atividadesValidadas: (json['atividades_validadas'] as num?)?.toInt() ?? 0,
      notaMediaDoInterno: json['nota_media_do_interno'] != null
          ? (json['nota_media_do_interno'] as num).toDouble()
          : null,
      notaAutoavaliacao: json['nota_autoavaliacao'] != null
          ? (json['nota_autoavaliacao'] as num).toDouble()
          : null,
      termosAceitos: json['termos_aceitos'] as bool? ?? false,
    );
  }
}

class AlocacaoHistoricoItem {
  final String id;
  final String campoNome;
  final String turnoTipo;
  final DateTime dataInicio;
  final DateTime? dataFim;
  final bool isVigente;

  const AlocacaoHistoricoItem({
    required this.id,
    required this.campoNome,
    required this.turnoTipo,
    required this.dataInicio,
    this.dataFim,
    required this.isVigente,
  });

  factory AlocacaoHistoricoItem.fromJson(Map<String, dynamic> json) {
    String cNome = 'Campo de Estágio';
    if (json['campos_estagio'] is Map) {
      cNome = (json['campos_estagio'] as Map)['nome']?.toString() ?? cNome;
    } else if (json['campo_nome'] != null) {
      cNome = json['campo_nome'].toString();
    }

    String tTipo = 'Manhã';
    if (json['turnos'] is Map) {
      tTipo = (json['turnos'] as Map)['tipo']?.toString() ?? tTipo;
    } else if (json['turno_tipo'] != null) {
      tTipo = json['turno_tipo'].toString();
    }

    final dInicio = json['data_inicio'] != null
        ? DateTime.tryParse(json['data_inicio'].toString()) ?? DateTime.now()
        : DateTime.now();
    final dFim = json['data_fim'] != null
        ? DateTime.tryParse(json['data_fim'].toString())
        : null;

    final vigente = dFim == null || dFim.isAfter(DateTime.now());

    return AlocacaoHistoricoItem(
      id: (json['id'] ?? '').toString(),
      campoNome: cNome,
      turnoTipo: tTipo,
      dataInicio: dInicio,
      dataFim: dFim,
      isVigente: vigente,
    );
  }
}

class DossieAlunoData {
  final String alunoId;
  final String nome;
  final String cpf;
  final String status;
  final String? campoAtual;
  final String? turnoAtual;
  final ResumoAcademicoData resumoAcademico;
  final BancoHorasAluno bancoHoras;
  final List<AlocacaoHistoricoItem> historicoAlocacoes;
  final List<ConflitoModel> ocorrencias;

  const DossieAlunoData({
    required this.alunoId,
    required this.nome,
    required this.cpf,
    required this.status,
    this.campoAtual,
    this.turnoAtual,
    required this.resumoAcademico,
    required this.bancoHoras,
    required this.historicoAlocacoes,
    required this.ocorrencias,
  });

  String get cpfMascarado {
    if (cpf.isEmpty) return '***.***.***-**';
    final digits = cpf.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11) {
      final p89 = digits.substring(7, 9);
      final p1011 = digits.substring(9, 11);
      return '***.***.*$p89-$p1011';
    }
    return cpf;
  }
}

typedef DossieParam = ({String alunoId, DateTime dataInicio, DateTime dataFim});

final dossieAlunoProvider = FutureProvider.family.autoDispose<DossieAlunoData, DossieParam>((ref, param) async {
  final supabase = ref.read(supabaseClientProvider);
  final alunoId = param.alunoId;

  // 0: Dados cadastrais do aluno (Obrigatório)
  Map<String, dynamic>? usuarioMap;
  try {
    usuarioMap = await supabase.from('usuarios').select('*').eq('id', alunoId).maybeSingle();
  } catch (e) {
    throw Exception('Aluno não encontrado ou acesso bloqueado por RLS.');
  }

  if (usuarioMap == null) {
    throw Exception('Aluno não encontrado ou acesso bloqueado por RLS.');
  }

  final nomeStr = (usuarioMap['nome'] ?? 'Aluno').toString();
  final cpfStr = (usuarioMap['cpf'] ?? '').toString();
  final ativoBool = usuarioMap['ativo'] as bool? ?? true;
  final statusStr = ativoBool ? 'Ativo' : 'Inativo';

  // 1-4: Requisições secundárias resilientes com try-catch assíncrono isolado
  final results = await Future.wait([
    // 1: RPC fn_compilar_dados_aluno (Resumo Acadêmico)
    () async {
      try {
        final res = await supabase.rpc('fn_compilar_dados_aluno', params: {
          'p_aluno_id': alunoId,
          'p_data_inicio': param.dataInicio.toIso8601String().split('T').first,
          'p_data_fim': param.dataFim.toIso8601String().split('T').first,
        }).maybeSingle();
        return res != null ? Map<String, dynamic>.from(res as Map) : null;
      } catch (_) {
        return null;
      }
    }(),

    // 2: Banco de Horas do Aluno
    () async {
      try {
        final res = await supabase.from('banco_horas_aluno').select('*').eq('aluno_id', alunoId).maybeSingle();
        return res != null ? Map<String, dynamic>.from(res as Map) : null;
      } catch (_) {
        return null;
      }
    }(),

    // 3: Histórico Completo de Alocações
    () async {
      try {
        final res = await supabase
            .from('alocacoes_alunos')
            .select('*, campos_estagio(nome), turnos(tipo)')
            .eq('aluno_id', alunoId)
            .order('data_inicio', ascending: false);
        return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }(),

    // 4: Ocorrências / Conflitos do Aluno
    () async {
      try {
        final res = await supabase
            .from('conflitos')
            .select('*, usuarios(nome), campos_estagio(nome)')
            .eq('aluno_id', alunoId)
            .isFilter('deleted_at', null)
            .order('data_ocorrencia', ascending: false);
        return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }(),
  ]);

  final rpcRes = results[0] as Map<String, dynamic>?;
  final bancoMap = results[1] as Map<String, dynamic>?;
  final alocListRaw = results[2] as List? ?? [];
  final conflitosListRaw = results[3] as List? ?? [];

  // 1: Resumo Acadêmico
  final resumoData = rpcRes != null
      ? ResumoAcademicoData.fromJson(rpcRes)
      : const ResumoAcademicoData(
          percentualFrequencia: 100.0,
          atividadesRegistradas: 0,
          atividadesValidadas: 0,
          notaMediaDoInterno: null,
          notaAutoavaliacao: null,
          termosAceitos: true,
        );

  // 2: Banco de Horas
  final bancoHorasData = bancoMap != null
      ? BancoHorasAluno.fromJson(bancoMap)
      : BancoHorasAluno(
          alunoId: alunoId,
          saldoMinutos: 0,
          saldoHoras: 0.0,
          isCredito: false,
          isDeficit: false,
        );

  // 3: Histórico de Alocações
  final alocacoes = alocListRaw.map((json) => AlocacaoHistoricoItem.fromJson(json as Map<String, dynamic>)).toList();

  String? cAtual;
  String? tAtual;
  if (alocacoes.isNotEmpty) {
    final vigente = alocacoes.firstWhere((a) => a.isVigente, orElse: () => alocacoes.first);
    cAtual = vigente.campoNome;
    tAtual = vigente.turnoTipo;
  }

  // 4: Ocorrências / Conflitos
  final ocorrencias = conflitosListRaw.map((json) => ConflitoModel.fromJson(json as Map<String, dynamic>)).toList();

  return DossieAlunoData(
    alunoId: alunoId,
    nome: nomeStr,
    cpf: cpfStr,
    status: statusStr,
    campoAtual: cAtual,
    turnoAtual: tAtual,
    resumoAcademico: resumoData,
    bancoHoras: bancoHorasData,
    historicoAlocacoes: alocacoes,
    ocorrencias: ocorrencias,
  );
});
