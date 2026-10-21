class LegislacaoModel {
  final String id;
  final String titulo;
  final String conteudo;
  final String tipo;
  final DateTime? vigenciaInicio;
  final DateTime? vigenciaFim;
  final bool ativo;
  final String? createdBy;
  final DateTime? deletedAt;
  final DateTime? createdAt;

  const LegislacaoModel({
    required this.id,
    required this.titulo,
    required this.conteudo,
    required this.tipo,
    this.vigenciaInicio,
    this.vigenciaFim,
    required this.ativo,
    this.createdBy,
    this.deletedAt,
    this.createdAt,
  });

  bool get isVigente {
    if (!ativo) return false;
    final now = DateTime.now();
    if (vigenciaFim != null && vigenciaFim!.isBefore(now)) {
      return false;
    }
    return true;
  }

  factory LegislacaoModel.fromJson(Map<String, dynamic> json) {
    return LegislacaoModel(
      id: json['id'] as String,
      titulo: json['titulo'] as String? ?? '',
      conteudo: json['conteudo'] as String? ?? '',
      tipo: json['tipo'] as String? ?? 'Geral',
      vigenciaInicio: json['vigencia_inicio'] != null
          ? DateTime.tryParse(json['vigencia_inicio'].toString())
          : null,
      vigenciaFim: json['vigencia_fim'] != null
          ? DateTime.tryParse(json['vigencia_fim'].toString())
          : null,
      ativo: json['ativo'] as bool? ?? true,
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
      'tipo': tipo,
      'vigencia_inicio': vigenciaInicio?.toIso8601String(),
      'vigencia_fim': vigenciaFim?.toIso8601String(),
      'ativo': ativo,
      'created_by': createdBy,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  LegislacaoModel copyWith({
    String? id,
    String? titulo,
    String? conteudo,
    String? tipo,
    DateTime? vigenciaInicio,
    DateTime? vigenciaFim,
    bool? ativo,
    String? createdBy,
    DateTime? deletedAt,
    DateTime? createdAt,
  }) {
    return LegislacaoModel(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      conteudo: conteudo ?? this.conteudo,
      tipo: tipo ?? this.tipo,
      vigenciaInicio: vigenciaInicio ?? this.vigenciaInicio,
      vigenciaFim: vigenciaFim ?? this.vigenciaFim,
      ativo: ativo ?? this.ativo,
      createdBy: createdBy ?? this.createdBy,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
