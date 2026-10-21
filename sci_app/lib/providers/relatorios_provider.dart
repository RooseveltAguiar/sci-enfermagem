import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/relatorios_repository.dart';
import 'auth_provider.dart';

final relatoriosRepositoryProvider = Provider<RelatoriosRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return RelatoriosRepository(supabase);
});

class RelatorioState {
  final String tipo;
  final DateTime dataInicio;
  final DateTime dataFim;
  final String? campoId;
  final bool loading;
  final List<Map<String, dynamic>> dados;
  final String? erro;

  const RelatorioState({
    required this.tipo,
    required this.dataInicio,
    required this.dataFim,
    this.campoId,
    this.loading = false,
    this.dados = const [],
    this.erro,
  });

  RelatorioState copyWith({
    String? tipo,
    DateTime? dataInicio,
    DateTime? dataFim,
    String? campoId,
    bool? loading,
    List<Map<String, dynamic>>? dados,
    String? erro,
    bool clearErro = false,
  }) {
    return RelatorioState(
      tipo: tipo ?? this.tipo,
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
      campoId: campoId ?? this.campoId,
      loading: loading ?? this.loading,
      dados: dados ?? this.dados,
      erro: clearErro ? null : (erro ?? this.erro),
    );
  }
}

class RelatorioNotifier extends StateNotifier<RelatorioState> {
  final RelatoriosRepository _repository;

  RelatorioNotifier(String tipo, this._repository)
      : super(
          RelatorioState(
            tipo: tipo,
            dataInicio: DateTime(
              DateTime.now().year,
              1,
              1,
            ),
            dataFim: DateTime.now(),
          ),
        ) {
    carregar();
  }

  Future<void> carregar() async {
    state = state.copyWith(loading: true, clearErro: true);
    try {
      final dados = await _repository.gerarRelatorio(
        tipo: state.tipo,
        dataInicio: state.dataInicio,
        dataFim: state.dataFim,
        campoId: state.campoId,
      );
      state = state.copyWith(loading: false, dados: dados);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        erro: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> aplicarFiltros({
    required DateTime dataInicio,
    required DateTime dataFim,
    String? campoId,
  }) async {
    state = state.copyWith(
      dataInicio: dataInicio,
      dataFim: dataFim,
      campoId: campoId,
    );
    await carregar();
  }
}

final relatorioProvider = StateNotifierProvider.autoDispose
    .family<RelatorioNotifier, RelatorioState, String>((ref, tipo) {
  final repository = ref.read(relatoriosRepositoryProvider);
  return RelatorioNotifier(tipo, repository);
});

double extrairPercentualFrequencia(Map<String, dynamic> row) {
  final raw = (row['percentual'] ?? row['frequencia'] ?? row['taxa_presenca'] ?? '100').toString();
  final clean = raw.replaceAll('%', '').replaceAll(',', '.').trim();
  return double.tryParse(clean) ?? 100.0;
}

String _formatarTurnoLabel(String t) {
  switch (t.toLowerCase().trim()) {
    case 'manha':
    case 'manhã':
      return 'Manhã';
    case 'tarde':
      return 'Tarde';
    case 'noite':
      return 'Noite';
    case 'integral':
      return 'Integral';
    default:
      return t.isNotEmpty ? '${t[0].toUpperCase()}${t.substring(1)}' : t;
  }
}

/// Agrupa registros diários de frequência do banco por usuário (aluno),
/// aplicando a mesma regra de cálculo do painel do aluno:
/// Pendentes, Validadas, Ratificadas, Ausentes e Frequência (%).
List<Map<String, dynamic>> agruparFrequenciaPorUsuario(
  List<Map<String, dynamic>> rawDados,
) {
  if (rawDados.isEmpty) return [];

  final Map<String, List<Map<String, dynamic>>> porAluno = {};
  for (final row in rawDados) {
    final id = (row['aluno_id'] ?? row['usuario_id'] ?? row['id'] ?? '').toString().trim();
    final nome = (row['aluno_nome'] ?? row['aluno'] ?? row['nome'] ?? 'Aluno').toString().trim();
    final key = id.isNotEmpty ? id : nome.toLowerCase();
    porAluno.putIfAbsent(key, () => []).add(row);
  }

  final List<Map<String, dynamic>> resultado = [];

  for (final entry in porAluno.entries) {
    final registros = entry.value;
    final first = registros.first;

    if (registros.length == 1 &&
        first.containsKey('percentual') &&
        first.containsKey('validadas') &&
        first.containsKey('ratificadas')) {
      resultado.add(Map<String, dynamic>.from(first));
      continue;
    }

    final alunoId = (first['aluno_id'] ?? first['usuario_id'] ?? first['id'] ?? '').toString();
    final alunoNome = (first['aluno_nome'] ?? first['aluno'] ?? first['nome'] ?? 'Aluno').toString();

    final camposSet = <String>{};
    final turnosSet = <String>{};
    int totalRegistros = 0;
    int pendentes = 0;
    int validadas = 0;
    int ratificadas = 0;
    int ausentes = 0;
    DateTime? minData;
    DateTime? maxData;

    for (final r in registros) {
      final c = (r['campo_nome'] ?? '').toString().trim();
      if (c.isNotEmpty) camposSet.add(c);

      final t = (r['turno_tipo'] ?? r['turno'] ?? '').toString().trim();
      if (t.isNotEmpty) {
        turnosSet.add(_formatarTurnoLabel(t));
      }

      totalRegistros += 1;
      final st = (r['status'] ?? '').toString().toLowerCase().trim();
      if (st == 'pendente' || st == 'pendente_validacao' || st == 'abonado_pend_ratificacao' || st == 'abono_pendente') {
        pendentes += 1;
      } else if (st == 'validado') {
        validadas += 1;
      } else if (st == 'ratificado') {
        ratificadas += 1;
      } else if (st == 'ausente' || st == 'falta' || st == 'rejeitado' || st == 'recusado') {
        ausentes += 1;
      } else {
        validadas += 1;
      }

      final dtRaw = (r['data_registro'] ?? r['data_inicio'] ?? '').toString().trim();
      if (dtRaw.isNotEmpty) {
        final dt = DateTime.tryParse(dtRaw);
        if (dt != null) {
          if (minData == null || dt.isBefore(minData)) minData = dt;
          if (maxData == null || dt.isAfter(maxData)) maxData = dt;
        }
      }
    }

    final int presentes = validadas + ratificadas;
    final int totalAvaliadas = presentes + ausentes;
    final double pct = totalAvaliadas == 0 ? 100.0 : (presentes / totalAvaliadas) * 100.0;
    final String pctStr = '${pct.toStringAsFixed(0)}%';
    final String situacao = pct < 75.0 ? 'Atenção < 75%' : 'Regular ≥ 75%';

    resultado.add({
      'aluno_id': alunoId,
      'aluno_nome': alunoNome,
      'campo_nome': camposSet.isNotEmpty ? camposSet.join(', ') : '-',
      'turno_tipo': turnosSet.isNotEmpty ? turnosSet.join(' / ') : '-',
      'total_dias': totalRegistros,
      'pendentes': pendentes,
      'validadas': validadas,
      'ratificadas': ratificadas,
      'faltas': ausentes,
      'percentual': pctStr,
      'status': situacao,
      '_resumo_validados': '$presentes de $totalAvaliadas validados',
      if (minData != null) 'data_inicio': minData.toIso8601String().split('T').first,
      if (maxData != null) 'data_fim': maxData.toIso8601String().split('T').first,
      '_registros_detalhe': registros,
    });
  }

  return resultado;
}
