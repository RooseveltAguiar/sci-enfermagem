class AvaliacaoModel {
  final String id;
  final String alocacaoId;
  final String tipo; // 'setorial', 'do_interno', 'autoavaliacao'
  final DateTime periodoReferencia;
  final String status; // 'rascunho', 'submetida', 'validada', 'aprovada'
  final int? notaGeral;
  final String? pontosPositivos;
  final String? pontosMelhoria;
  final String? comentarioLivre;
  final String? comentarioValidacao;
  final String avaliadorId;
  final String? avaliadorNome;
  final String? alunoNome;
  final String? campoNome;
  final String? campoId;
  final DateTime? deletedAt;

  const AvaliacaoModel({
    required this.id,
    required this.alocacaoId,
    required this.tipo,
    required this.periodoReferencia,
    required this.status,
    this.notaGeral,
    this.pontosPositivos,
    this.pontosMelhoria,
    this.comentarioLivre,
    this.comentarioValidacao,
    required this.avaliadorId,
    this.avaliadorNome,
    this.alunoNome,
    this.campoNome,
    this.campoId,
    this.deletedAt,
  });

  factory AvaliacaoModel.fromJson(Map<String, dynamic> json) {
    String? cId = json['campo_id']?.toString();
    if (cId == null && json['campos_estagio'] is Map) {
      cId = (json['campos_estagio'] as Map)['id']?.toString();
    } else if (cId == null && json['alocacoes_alunos'] is Map) {
      cId = (json['alocacoes_alunos'] as Map)['campo_id']?.toString();
    }

    return AvaliacaoModel(
      id: json['id'] as String,
      alocacaoId: json['alocacao_id'] as String,
      tipo: json['tipo'] as String,
      periodoReferencia: DateTime.parse(json['periodo_referencia'] as String),
      status: json['status'] as String,
      notaGeral: json['nota_geral'] != null ? (json['nota_geral'] as num).toInt() : null,
      pontosPositivos: json['pontos_positivos'] as String?,
      pontosMelhoria: json['pontos_melhoria'] as String?,
      comentarioLivre: json['comentario_livre'] as String?,
      comentarioValidacao: json['comentario_validacao'] as String?,
      avaliadorId: json['avaliador_id'] as String,
      avaliadorNome: json['avaliador_nome'] as String?,
      alunoNome: json['aluno_nome'] as String?,
      campoNome: json['campo_nome'] as String?,
      campoId: cId,
      deletedAt: json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'alocacao_id': alocacaoId,
      'tipo': tipo,
      'periodo_referencia': '${periodoReferencia.year}-${periodoReferencia.month.toString().padLeft(2, '0')}-01',
      'status': status,
      if (notaGeral != null) 'nota_geral': notaGeral,
      if (pontosPositivos != null) 'pontos_positivos': pontosPositivos,
      if (pontosMelhoria != null) 'pontos_melhoria': pontosMelhoria,
      if (comentarioLivre != null) 'comentario_livre': comentarioLivre,
      if (comentarioValidacao != null) 'comentario_validacao': comentarioValidacao,
      'avaliador_id': avaliadorId,
    };
  }

  AvaliacaoModel copyWith({
    String? id,
    String? alocacaoId,
    String? tipo,
    DateTime? periodoReferencia,
    String? status,
    int? notaGeral,
    String? pontosPositivos,
    String? pontosMelhoria,
    String? comentarioLivre,
    String? comentarioValidacao,
    String? avaliadorId,
    String? avaliadorNome,
    String? alunoNome,
    String? campoNome,
    DateTime? deletedAt,
  }) {
    return AvaliacaoModel(
      id: id ?? this.id,
      alocacaoId: alocacaoId ?? this.alocacaoId,
      tipo: tipo ?? this.tipo,
      periodoReferencia: periodoReferencia ?? this.periodoReferencia,
      status: status ?? this.status,
      notaGeral: notaGeral ?? this.notaGeral,
      pontosPositivos: pontosPositivos ?? this.pontosPositivos,
      pontosMelhoria: pontosMelhoria ?? this.pontosMelhoria,
      comentarioLivre: comentarioLivre ?? this.comentarioLivre,
      comentarioValidacao: comentarioValidacao ?? this.comentarioValidacao,
      avaliadorId: avaliadorId ?? this.avaliadorId,
      avaliadorNome: avaliadorNome ?? this.avaliadorNome,
      alunoNome: alunoNome ?? this.alunoNome,
      campoNome: campoNome ?? this.campoNome,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
