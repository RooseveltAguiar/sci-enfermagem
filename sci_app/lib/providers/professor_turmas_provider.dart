import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

class AlunoTurmaResumo {
  final String alunoId;
  final String nome;
  final String cpf;
  final String? turnoTipo;
  final String? campoNome;
  final String? campoId;

  AlunoTurmaResumo({
    required this.alunoId,
    required this.nome,
    required this.cpf,
    this.turnoTipo,
    this.campoNome,
    this.campoId,
  });
}

final alunosDoProfessorProvider = FutureProvider<List<AlunoTurmaResumo>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  // 1. Tenta buscar via professor_turmas (tentando turmas ou alocacoes_alunos)
  try {
    final response = await supabase
        .from('professor_turmas')
        .select('*, turmas(nome), alocacoes_alunos(aluno_id, campos_estagio(nome), turnos(tipo), usuarios(nome, cpf))')
        .eq('professor_id', user.id)
        .isFilter('deleted_at', null);

    final mapAlunos = <String, AlunoTurmaResumo>{};
    for (final item in response as List<dynamic>) {
      final alocacoes = (item['alocacoes_alunos'] as List<dynamic>?) ??
          (item['turnos'] is Map ? item['turnos']['alocacoes_alunos'] as List<dynamic>? : null) ??
          [];
      for (final aloc in alocacoes) {
        final alunoId = aloc['aluno_id']?.toString();
        final usuario = aloc['usuarios'] as Map<String, dynamic>?;
        final campo = (aloc['campos_estagio'] as Map<String, dynamic>?) ??
            (item['turnos'] is Map ? item['turnos']['campos_estagio'] as Map<String, dynamic>? : null);
        final turno = (aloc['turnos'] as Map<String, dynamic>?) ??
            (item['turnos'] is Map ? item['turnos'] as Map<String, dynamic>? : null);
        if (alunoId != null && usuario != null) {
          mapAlunos[alunoId] = AlunoTurmaResumo(
            alunoId: alunoId,
            nome: usuario['nome']?.toString() ?? 'Aluno $alunoId',
            cpf: usuario['cpf']?.toString() ?? '',
            turnoTipo: turno?['tipo']?.toString(),
            campoNome: campo?['nome']?.toString(),
            campoId: campo?['id']?.toString() ?? aloc['campo_id']?.toString(),
          );
        }
      }
    }
    if (mapAlunos.isNotEmpty) {
      final list = mapAlunos.values.toList()..sort((a, b) => a.nome.compareTo(b.nome));
      return list;
    }
  } catch (_) {}

  // 2. Fallback: Buscar alocações de alunos diretamente da tabela alocacoes_alunos ou alocacoes
  try {
    final response = await supabase
        .from('alocacoes_alunos')
        .select('aluno_id, campo_id, campos_estagio(id, nome), turnos(tipo), usuarios(nome, cpf)')
        .isFilter('deleted_at', null);

    final mapAlunos = <String, AlunoTurmaResumo>{};
    for (final aloc in response as List<dynamic>) {
      final alunoId = aloc['aluno_id']?.toString();
      final usuario = aloc['usuarios'] as Map<String, dynamic>?;
      final campo = aloc['campos_estagio'] as Map<String, dynamic>?;
      final turno = aloc['turnos'] as Map<String, dynamic>?;
      if (alunoId != null && usuario != null) {
        mapAlunos[alunoId] = AlunoTurmaResumo(
          alunoId: alunoId,
          nome: usuario['nome']?.toString() ?? 'Aluno $alunoId',
          cpf: usuario['cpf']?.toString() ?? '',
          turnoTipo: turno?['tipo']?.toString(),
          campoNome: campo?['nome']?.toString(),
          campoId: campo?['id']?.toString() ?? aloc['campo_id']?.toString(),
        );
      }
    }
    if (mapAlunos.isNotEmpty) {
      final list = mapAlunos.values.toList()..sort((a, b) => a.nome.compareTo(b.nome));
      return list;
    }
  } catch (_) {}

  // 3. Fallback Resiliente: Buscar todos os usuários cadastrados com perfil = 'aluno'
  try {
    final response = await supabase
        .from('usuarios')
        .select('id, nome, cpf')
        .eq('perfil', 'aluno')
        .isFilter('deleted_at', null);

    final list = (response as List<dynamic>).map((u) {
      return AlunoTurmaResumo(
        alunoId: u['id'].toString(),
        nome: u['nome']?.toString() ?? 'Aluno',
        cpf: u['cpf']?.toString() ?? '',
        turnoTipo: 'Manhã',
        campoNome: 'Campo de Estágio',
        campoId: null,
      );
    }).toList();
    list.sort((a, b) => a.nome.compareTo(b.nome));
    return list;
  } catch (_) {}

  return [];
});
