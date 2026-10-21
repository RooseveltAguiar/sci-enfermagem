class SugestaoModel {
  final String id;
  final String autorId;
  final String? autorNome;
  final String? autorPerfil;
  final String conteudo;
  final DateTime? createdAt;
  final DateTime? deletedAt;

  const SugestaoModel({
    required this.id,
    required this.autorId,
    this.autorNome,
    this.autorPerfil,
    required this.conteudo,
    this.createdAt,
    this.deletedAt,
  });

  factory SugestaoModel.fromJson(Map<String, dynamic> json) {
    // Pode vir com join do Supabase em 'usuarios' ou flatten
    String? nome;
    String? perfil;
    if (json['usuarios'] is Map) {
      final userMap = json['usuarios'] as Map<String, dynamic>;
      nome = userMap['nome'] as String?;
      perfil = userMap['perfil'] as String?;
    } else {
      nome = json['autor_nome'] as String?;
      perfil = json['autor_perfil'] as String?;
    }

    return SugestaoModel(
      id: json['id'] as String,
      autorId: json['autor_id'] as String,
      autorNome: nome,
      autorPerfil: perfil,
      conteudo: json['conteudo'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'autor_id': autorId,
      'conteudo': conteudo,
      'created_at': createdAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}
