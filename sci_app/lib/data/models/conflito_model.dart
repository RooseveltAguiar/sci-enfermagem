class ConflitoModel {
  final String id;
  final String alunoId;
  final String? alunoNome;
  final String campoId;
  final String? campoNome;
  final String descricao;
  final DateTime? dataOcorrencia;
  final String? createdBy;
  final DateTime? deletedAt;
  final DateTime? createdAt;

  const ConflitoModel({
    required this.id,
    required this.alunoId,
    this.alunoNome,
    required this.campoId,
    this.campoNome,
    required this.descricao,
    this.dataOcorrencia,
    this.createdBy,
    this.deletedAt,
    this.createdAt,
  });

  factory ConflitoModel.fromJson(Map<String, dynamic> json) {
    String? aNome;
    String? cNome;

    if (json['usuarios'] is Map) {
      aNome = (json['usuarios'] as Map<String, dynamic>)['nome'] as String?;
    } else {
      aNome = json['aluno_nome'] as String?;
    }

    if (json['campos_estagio'] is Map) {
      cNome = (json['campos_estagio'] as Map<String, dynamic>)['nome'] as String?;
    } else {
      cNome = json['campo_nome'] as String?;
    }

    return ConflitoModel(
      id: json['id'] as String,
      alunoId: json['aluno_id'] as String,
      alunoNome: aNome,
      campoId: json['campo_id'] as String,
      campoNome: cNome,
      descricao: json['descricao'] as String? ?? '',
      dataOcorrencia: json['data_ocorrencia'] != null
          ? DateTime.tryParse(json['data_ocorrencia'].toString())
          : null,
      createdBy: json['created_by'] as String?,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'aluno_id': alunoId,
      'campo_id': campoId,
      'descricao': descricao,
      'data_ocorrencia': dataOcorrencia?.toIso8601String(),
      'created_by': createdBy,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
