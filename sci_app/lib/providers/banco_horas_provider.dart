import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

class BancoHorasAluno {
  final String alunoId;
  final int saldoMinutos;
  final double saldoHoras;
  final bool isCredito;
  final bool isDeficit;
  final DateTime? updatedAt;

  const BancoHorasAluno({
    required this.alunoId,
    required this.saldoMinutos,
    required this.saldoHoras,
    required this.isCredito,
    required this.isDeficit,
    this.updatedAt,
  });

  factory BancoHorasAluno.fromJson(Map<String, dynamic> json) {
    final minutos = json['saldo_minutos'] != null
        ? (json['saldo_minutos'] as num).toInt()
        : (json['saldo_horas'] != null ? ((json['saldo_horas'] as num) * 60).toInt() : 0);
    final horas = minutos / 60.0;

    return BancoHorasAluno(
      alunoId: (json['aluno_id'] ?? '').toString(),
      saldoMinutos: minutos,
      saldoHoras: horas,
      isCredito: minutos > 0,
      isDeficit: minutos < 0,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }
}

class BancoHorasLancamento {
  final String id;
  final String alunoId;
  final String dataLancamento;
  final String tipo; // 'credito' | 'debito'
  final int minutos;
  final double horas;
  final String motivo;
  final int saldoResultanteMinutos;

  const BancoHorasLancamento({
    required this.id,
    required this.alunoId,
    required this.dataLancamento,
    required this.tipo,
    required this.minutos,
    required this.horas,
    required this.motivo,
    required this.saldoResultanteMinutos,
  });

  factory BancoHorasLancamento.fromJson(Map<String, dynamic> json) {
    final m = json['minutos'] != null ? (json['minutos'] as num).toInt() : 0;
    return BancoHorasLancamento(
      id: (json['id'] ?? '').toString(),
      alunoId: (json['aluno_id'] ?? '').toString(),
      dataLancamento: (json['data_lancamento'] ?? json['created_at'] ?? '').toString(),
      tipo: (json['tipo'] ?? 'credito').toString(),
      minutos: m,
      horas: m / 60.0,
      motivo: (json['motivo'] ?? json['descricao'] ?? 'Lançamento de horas').toString(),
      saldoResultanteMinutos: json['saldo_resultante_minutos'] != null
          ? (json['saldo_resultante_minutos'] as num).toInt()
          : 0,
    );
  }
}

final saldoBancoHorasProvider = FutureProvider.family.autoDispose<BancoHorasAluno, String?>((ref, alunoIdTarget) async {
  final supabase = ref.read(supabaseClientProvider);
  final userId = alunoIdTarget ?? supabase.auth.currentUser?.id;

  if (userId == null || userId.trim().isEmpty) {
    return const BancoHorasAluno(
      alunoId: '',
      saldoMinutos: 0,
      saldoHoras: 0.0,
      isCredito: false,
      isDeficit: false,
    );
  }

  try {
    final response = await supabase
        .from('banco_horas_aluno')
        .select('*')
        .eq('aluno_id', userId)
        .maybeSingle();

    if (response != null) {
      return BancoHorasAluno.fromJson(response);
    }
  } catch (_) {}

  // Fallback seguro caso ainda não haja registro consolidado
  return BancoHorasAluno(
    alunoId: userId,
    saldoMinutos: 0,
    saldoHoras: 0.0,
    isCredito: false,
    isDeficit: false,
  );
});

final lancamentosBancoHorasProvider = FutureProvider.family.autoDispose<List<BancoHorasLancamento>, String?>((ref, alunoIdTarget) async {
  final supabase = ref.read(supabaseClientProvider);
  final userId = alunoIdTarget ?? supabase.auth.currentUser?.id;

  if (userId == null || userId.trim().isEmpty) {
    return [];
  }

  try {
    final response = await supabase
        .from('banco_horas_lancamentos')
        .select('*')
        .eq('aluno_id', userId)
        .order('data_lancamento', ascending: false);

    final list = response as List;
    return list.map((json) => BancoHorasLancamento.fromJson(json)).toList();
  } catch (_) {
    return [];
  }
});

class ConfiguracaoJornada {
  final double cargaHorariaDiariaHoras;
  final double cargaHorariaExtraMaxHoras;

  const ConfiguracaoJornada({
    this.cargaHorariaDiariaHoras = 6.0,
    this.cargaHorariaExtraMaxHoras = 2.0,
  });
}

final configuracoesJornadaProvider = FutureProvider.autoDispose<ConfiguracaoJornada>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  try {
    final response = await supabase
        .from('configuracoes')
        .select('*')
        .maybeSingle();

    if (response != null) {
      final diaria = (response['carga_horaria_diaria_horas'] as num?)?.toDouble() ?? 6.0;
      final extra = (response['carga_horaria_extra_max_horas'] as num?)?.toDouble() ?? 2.0;
      return ConfiguracaoJornada(
        cargaHorariaDiariaHoras: diaria,
        cargaHorariaExtraMaxHoras: extra,
      );
    }
  } catch (_) {}

  return const ConfiguracaoJornada();
});
