import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/data/models/legislacao_model.dart';

void main() {
  group('LegislacaoModel - Cobertura Integral', () {
    final now = DateTime.now();
    final past = now.subtract(const Duration(days: 10));
    final future = now.add(const Duration(days: 10));

    test('1. Construtor e getter isVigente cobrem todos os cenários', () {
      // Ativo = false -> isVigente deve ser false
      final inativo = LegislacaoModel(
        id: '1',
        titulo: 'Lei Inativa',
        conteudo: 'Conteudo',
        tipo: 'Estágio',
        ativo: false,
        vigenciaFim: future,
      );
      expect(inativo.isVigente, isFalse);

      // Ativo = true mas vigenciaFim no passado -> isVigente deve ser false
      final expirado = LegislacaoModel(
        id: '2',
        titulo: 'Lei Expirada',
        conteudo: 'Conteudo',
        tipo: 'Geral',
        ativo: true,
        vigenciaFim: past,
      );
      expect(expirado.isVigente, isFalse);

      // Ativo = true com vigenciaFim no futuro -> isVigente deve ser true
      final vigenteFuturo = LegislacaoModel(
        id: '3',
        titulo: 'Lei Vigente Futura',
        conteudo: 'Conteudo',
        tipo: 'COFEN',
        ativo: true,
        vigenciaFim: future,
      );
      expect(vigenteFuturo.isVigente, isTrue);

      // Ativo = true e vigenciaFim nulo -> isVigente deve ser true
      final vigenteIndefinido = const LegislacaoModel(
        id: '4',
        titulo: 'Lei Indefinida',
        conteudo: 'Conteudo',
        tipo: 'COREN',
        ativo: true,
      );
      expect(vigenteIndefinido.isVigente, isTrue);
    });

    test('2. fromJson e toJson com campos completos', () {
      final jsonCompleto = {
        'id': 'leg-100',
        'titulo': 'Resolução 564/2017',
        'conteudo': 'Código de Ética dos Profissionais de Enfermagem',
        'tipo': 'COFEN',
        'vigencia_inicio': past.toIso8601String(),
        'vigencia_fim': future.toIso8601String(),
        'ativo': true,
        'created_by': 'admin-uuid',
        'deleted_at': past.toIso8601String(),
        'created_at': past.toIso8601String(),
      };

      final model = LegislacaoModel.fromJson(jsonCompleto);
      expect(model.id, 'leg-100');
      expect(model.titulo, 'Resolução 564/2017');
      expect(model.conteudo, 'Código de Ética dos Profissionais de Enfermagem');
      expect(model.tipo, 'COFEN');
      expect(model.vigenciaInicio, isNotNull);
      expect(model.vigenciaFim, isNotNull);
      expect(model.ativo, isTrue);
      expect(model.createdBy, 'admin-uuid');
      expect(model.deletedAt, isNotNull);
      expect(model.createdAt, isNotNull);

      final jsonOut = model.toJson();
      expect(jsonOut['id'], 'leg-100');
      expect(jsonOut['titulo'], 'Resolução 564/2017');
      expect(jsonOut['vigencia_inicio'], past.toIso8601String());
      expect(jsonOut['vigencia_fim'], future.toIso8601String());
      expect(jsonOut['created_by'], 'admin-uuid');
      expect(jsonOut['deleted_at'], past.toIso8601String());
      expect(jsonOut['created_at'], past.toIso8601String());
    });

    test('3. fromJson e toJson com campos nulos / defaults', () {
      final jsonMinimo = {
        'id': 'leg-min',
      };

      final model = LegislacaoModel.fromJson(jsonMinimo);
      expect(model.id, 'leg-min');
      expect(model.titulo, '');
      expect(model.conteudo, '');
      expect(model.tipo, 'Geral');
      expect(model.vigenciaInicio, isNull);
      expect(model.vigenciaFim, isNull);
      expect(model.ativo, isTrue);
      expect(model.createdBy, isNull);
      expect(model.deletedAt, isNull);
      expect(model.createdAt, isNull);

      final jsonOut = model.toJson();
      expect(jsonOut['id'], 'leg-min');
      expect(jsonOut['vigencia_inicio'], isNull);
      expect(jsonOut['vigencia_fim'], isNull);
      expect(jsonOut['created_by'], isNull);
      expect(jsonOut['deleted_at'], isNull);
      expect(jsonOut['created_at'], isNull);
    });

    test('4. fromJson com datas em formato string inválido (tryParse retorna null)', () {
      final jsonInvalido = {
        'id': 'leg-inv',
        'vigencia_inicio': 'data-invalida',
        'vigencia_fim': 'outra-invalida',
        'deleted_at': 'nao-e-data',
        'created_at': 'xxx',
      };

      final model = LegislacaoModel.fromJson(jsonInvalido);
      expect(model.vigenciaInicio, isNull);
      expect(model.vigenciaFim, isNull);
      expect(model.deletedAt, isNull);
      expect(model.createdAt, isNull);
    });

    test('5. copyWith alterando campos e mantendo originais', () {
      final base = LegislacaoModel(
        id: '1',
        titulo: 'Titulo 1',
        conteudo: 'Conteudo 1',
        tipo: 'Geral',
        vigenciaInicio: past,
        vigenciaFim: future,
        ativo: true,
        createdBy: 'user-1',
        deletedAt: null,
        createdAt: past,
      );

      final modificado = base.copyWith(
        id: '2',
        titulo: 'Titulo Alterado',
        conteudo: 'Conteudo Alterado',
        tipo: 'Especifico',
        vigenciaInicio: now,
        vigenciaFim: now.add(const Duration(days: 100)),
        ativo: false,
        createdBy: 'user-2',
        deletedAt: now,
        createdAt: now,
      );

      expect(modificado.id, '2');
      expect(modificado.titulo, 'Titulo Alterado');
      expect(modificado.conteudo, 'Conteudo Alterado');
      expect(modificado.tipo, 'Especifico');
      expect(modificado.vigenciaInicio, now);
      expect(modificado.vigenciaFim, now.add(const Duration(days: 100)));
      expect(modificado.ativo, isFalse);
      expect(modificado.createdBy, 'user-2');
      expect(modificado.deletedAt, now);
      expect(modificado.createdAt, now);

      // copyWith vazio mantendo os valores originais
      final semMudanca = base.copyWith();
      expect(semMudanca.id, base.id);
      expect(semMudanca.titulo, base.titulo);
      expect(semMudanca.conteudo, base.conteudo);
      expect(semMudanca.tipo, base.tipo);
      expect(semMudanca.vigenciaInicio, base.vigenciaInicio);
      expect(semMudanca.vigenciaFim, base.vigenciaFim);
      expect(semMudanca.ativo, base.ativo);
      expect(semMudanca.createdBy, base.createdBy);
      expect(semMudanca.deletedAt, base.deletedAt);
      expect(semMudanca.createdAt, base.createdAt);
    });

    test('6. Suporte completo a anexo de arquivo (PDF, DOC e Base64)', () {
      final docPdf = const LegislacaoModel(
        id: 'leg-pdf',
        titulo: 'Portaria com PDF',
        conteudo: 'Texto breve',
        tipo: 'Portaria',
        ativo: true,
        arquivoNome: 'resolucao_cofen.pdf',
        arquivoBase64: 'JVBERi0xLjQK...',
        arquivoTamanho: 204800,
        arquivoExtensao: 'pdf',
      );

      expect(docPdf.temAnexo, isTrue);
      expect(docPdf.isPdf, isTrue);
      expect(docPdf.isDoc, isFalse);

      final docDocx = const LegislacaoModel(
        id: 'leg-doc',
        titulo: 'Regimento com Word',
        conteudo: '',
        tipo: 'Regimento',
        ativo: true,
        arquivoNome: 'regimento_interno.docx',
        arquivoUrl: 'https://exemplo.com/doc.docx',
        arquivoTamanho: 102400,
        arquivoExtensao: 'docx',
      );

      expect(docDocx.temAnexo, isTrue);
      expect(docDocx.isPdf, isFalse);
      expect(docDocx.isDoc, isTrue);

      final docSemAnexo = const LegislacaoModel(
        id: 'leg-sem',
        titulo: 'Sem anexo',
        conteudo: 'Apenas texto',
        tipo: 'Geral',
        ativo: true,
      );

      expect(docSemAnexo.temAnexo, isFalse);
    });

    test('7. fromJson decodifica payload estruturado __is_documento__ e toJson serializa corretamente', () {
      final jsonComCorpoEstruturado = {
        'id': 'leg-anexo',
        'titulo': 'Diretriz Acadêmica',
        'corpo': '{"__is_documento__":true,"texto":"Texto explicativo","arquivo_nome":"diretriz.pdf","arquivo_url":"https://storage/diretriz.pdf","arquivo_base64":"abc123base64","arquivo_tamanho":512000,"arquivo_extensao":"pdf"}',
        'tipo': 'Diretriz',
        'ativo': true,
      };

      final model = LegislacaoModel.fromJson(jsonComCorpoEstruturado);
      expect(model.id, 'leg-anexo');
      expect(model.titulo, 'Diretriz Acadêmica');
      expect(model.conteudo, 'Texto explicativo');
      expect(model.arquivoNome, 'diretriz.pdf');
      expect(model.arquivoUrl, 'https://storage/diretriz.pdf');
      expect(model.arquivoBase64, 'abc123base64');
      expect(model.arquivoTamanho, 512000);
      expect(model.arquivoExtensao, 'pdf');
      expect(model.temAnexo, isTrue);
      expect(model.isPdf, isTrue);

      final jsonSaida = model.toJson();
      expect(jsonSaida['arquivo_nome'], 'diretriz.pdf');
      expect(jsonSaida['arquivo_url'], 'https://storage/diretriz.pdf');
      expect(jsonSaida['arquivo_tamanho'], 512000);
    });
  });
}
