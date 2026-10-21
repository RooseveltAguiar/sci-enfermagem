class TermoModel {
  final String id;
  final String titulo;
  final String conteudo;
  final String versao;
  final DateTime? vigenciaInicio;
  final bool ativo;
  final String? createdBy;
  final DateTime? deletedAt;
  final DateTime? createdAt;

  const TermoModel({
    required this.id,
    required this.titulo,
    required this.conteudo,
    required this.versao,
    this.vigenciaInicio,
    required this.ativo,
    this.createdBy,
    this.deletedAt,
    this.createdAt,
  });

  factory TermoModel.fromJson(Map<String, dynamic> json) {
    return TermoModel(
      id: json['id'] as String,
      titulo: json['titulo'] as String? ?? '',
      conteudo: json['conteudo'] as String? ?? '',
      versao: json['versao'] as String? ?? '1.0',
      vigenciaInicio: json['vigencia_inicio'] != null
          ? DateTime.tryParse(json['vigencia_inicio'].toString())
          : null,
      ativo: json['ativo'] as bool? ?? false,
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
      'titulo': titulo,
      'conteudo': conteudo,
      'versao': versao,
      'vigencia_inicio': vigenciaInicio?.toIso8601String(),
      'ativo': ativo,
      'created_by': createdBy,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  TermoModel copyWith({
    String? id,
    String? titulo,
    String? conteudo,
    String? versao,
    DateTime? vigenciaInicio,
    bool? ativo,
    String? createdBy,
    DateTime? deletedAt,
    DateTime? createdAt,
  }) {
    return TermoModel(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      conteudo: conteudo ?? this.conteudo,
      versao: versao ?? this.versao,
      vigenciaInicio: vigenciaInicio ?? this.vigenciaInicio,
      ativo: ativo ?? this.ativo,
      createdBy: createdBy ?? this.createdBy,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
