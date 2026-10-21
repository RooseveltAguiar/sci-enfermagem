import 'dart:convert';

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
  final String? arquivoNome;
  final String? arquivoUrl;
  final String? arquivoBase64;
  final int? arquivoTamanho;
  final String? arquivoExtensao;

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
    this.arquivoNome,
    this.arquivoUrl,
    this.arquivoBase64,
    this.arquivoTamanho,
    this.arquivoExtensao,
  });

  bool get isVigente {
    if (!ativo) return false;
    final now = DateTime.now();
    if (vigenciaFim != null && vigenciaFim!.isBefore(now)) {
      return false;
    }
    return true;
  }

  bool get temAnexo =>
      arquivoNome != null &&
      arquivoNome!.isNotEmpty &&
      ((arquivoUrl != null && arquivoUrl!.isNotEmpty) ||
          (arquivoBase64 != null && arquivoBase64!.isNotEmpty));

  bool get isPdf {
    final ext = (arquivoExtensao ??
            (arquivoNome != null && arquivoNome!.contains('.')
                ? arquivoNome!.split('.').last
                : ''))
        .toLowerCase();
    return ext == 'pdf';
  }

  bool get isDoc {
    final ext = (arquivoExtensao ??
            (arquivoNome != null && arquivoNome!.contains('.')
                ? arquivoNome!.split('.').last
                : ''))
        .toLowerCase();
    return ext == 'doc' || ext == 'docx';
  }

  factory LegislacaoModel.fromJson(Map<String, dynamic> json) {
    final rawCorpo = json['corpo'] as String? ?? json['conteudo'] as String? ?? '';
    String parsedConteudo = rawCorpo;
    String? arquivoNome = json['arquivo_nome'] as String?;
    String? arquivoUrl = json['arquivo_url'] as String?;
    String? arquivoBase64 = json['arquivo_base64'] as String?;
    int? arquivoTamanho = json['arquivo_tamanho'] as int?;
    String? arquivoExtensao = json['arquivo_extensao'] as String?;

    if (rawCorpo.trim().startsWith('{"__is_documento__":true')) {
      try {
        final Map<String, dynamic> docData =
            jsonDecode(rawCorpo) as Map<String, dynamic>;
        parsedConteudo = docData['texto'] as String? ?? '';
        arquivoNome ??= docData['arquivo_nome'] as String?;
        arquivoUrl ??= docData['arquivo_url'] as String?;
        arquivoBase64 ??= docData['arquivo_base64'] as String?;
        arquivoTamanho ??= docData['arquivo_tamanho'] as int?;
        arquivoExtensao ??= docData['arquivo_extensao'] as String?;
      } catch (_) {
        parsedConteudo = rawCorpo;
      }
    }

    return LegislacaoModel(
      id: json['id'] as String,
      titulo: json['titulo'] as String? ?? '',
      conteudo: parsedConteudo,
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
      arquivoNome: arquivoNome,
      arquivoUrl: arquivoUrl,
      arquivoBase64: arquivoBase64,
      arquivoTamanho: arquivoTamanho,
      arquivoExtensao: arquivoExtensao,
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
      'arquivo_nome': arquivoNome,
      'arquivo_url': arquivoUrl,
      'arquivo_base64': arquivoBase64,
      'arquivo_tamanho': arquivoTamanho,
      'arquivo_extensao': arquivoExtensao,
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
    String? arquivoNome,
    String? arquivoUrl,
    String? arquivoBase64,
    int? arquivoTamanho,
    String? arquivoExtensao,
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
      arquivoNome: arquivoNome ?? this.arquivoNome,
      arquivoUrl: arquivoUrl ?? this.arquivoUrl,
      arquivoBase64: arquivoBase64 ?? this.arquivoBase64,
      arquivoTamanho: arquivoTamanho ?? this.arquivoTamanho,
      arquivoExtensao: arquivoExtensao ?? this.arquivoExtensao,
    );
  }
}
