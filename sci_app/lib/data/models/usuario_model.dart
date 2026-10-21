class UsuarioModel {
  final String id;
  final String cpf;
  final String nome;
  final String? email;
  final String perfil;
  final bool ativo;
  final DateTime? deletedAt;
  final DateTime? createdAt;

  const UsuarioModel({
    required this.id,
    required this.cpf,
    required this.nome,
    this.email,
    required this.perfil,
    this.ativo = true,
    this.deletedAt,
    this.createdAt,
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

  factory UsuarioModel.fromJson(Map<String, dynamic> json) {
    return UsuarioModel(
      id: (json['id'] ?? '').toString(),
      cpf: (json['cpf'] ?? '').toString(),
      nome: (json['nome'] ?? json['nome_usuario'] ?? 'Sem nome').toString(),
      email: json['email']?.toString(),
      perfil: (json['perfil'] ?? 'aluno').toString(),
      ativo: json['ativo'] as bool? ?? true,
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
      'cpf': cpf,
      'nome': nome,
      'email': email,
      'perfil': perfil,
      'ativo': ativo,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  UsuarioModel copyWith({
    String? id,
    String? cpf,
    String? nome,
    String? email,
    String? perfil,
    bool? ativo,
    DateTime? deletedAt,
    DateTime? createdAt,
  }) {
    return UsuarioModel(
      id: id ?? this.id,
      cpf: cpf ?? this.cpf,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      perfil: perfil ?? this.perfil,
      ativo: ativo ?? this.ativo,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UsuarioModel &&
        other.id == id &&
        other.cpf == cpf &&
        other.nome == nome &&
        other.email == email &&
        other.perfil == perfil &&
        other.ativo == ativo &&
        other.deletedAt == deletedAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, cpf, nome, email, perfil, ativo, deletedAt);
  }
}
