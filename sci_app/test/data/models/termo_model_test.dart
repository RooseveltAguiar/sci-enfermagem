// test/data/models/termo_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/data/models/termo_model.dart';

void main() {
  group('TermoModel', () {
    test('fromJson cria instância corretamente com dados completos e faz parse de datas', () {
      final json = {
        'id': 'termo-1',
        'titulo': 'Termo de Compromisso',
        'conteudo': 'Conteúdo do termo',
        'versao': '2.0',
        'vigencia_inicio': '2026-01-01T00:00:00.000',
        'ativo': true,
        'created_by': 'admin-id',
        'deleted_at': '2026-12-31T00:00:00.000',
        'created_at': '2026-01-01T00:00:00.000',
      };

      final model = TermoModel.fromJson(json);

      expect(model.id, 'termo-1');
      expect(model.titulo, 'Termo de Compromisso');
      expect(model.conteudo, 'Conteúdo do termo');
      expect(model.versao, '2.0');
      expect(model.vigenciaInicio, DateTime(2026, 1, 1));
      expect(model.ativo, true);
      expect(model.createdBy, 'admin-id');
      expect(model.deletedAt, DateTime(2026, 12, 31));
      expect(model.createdAt, DateTime(2026, 1, 1));
    });

    test('fromJson assume valores padrão quando campos opcionais são nulos ou ausentes', () {
      final json = {
        'id': 'termo-2',
      };

      final model = TermoModel.fromJson(json);

      expect(model.id, 'termo-2');
      expect(model.titulo, '');
      expect(model.conteudo, '');
      expect(model.versao, '1.0');
      expect(model.vigenciaInicio, null);
      expect(model.ativo, false);
      expect(model.createdBy, null);
      expect(model.deletedAt, null);
      expect(model.createdAt, null);
    });

    test('toJson serializa todos os campos e formata datas no formato ISO8601', () {
      final model = TermoModel(
        id: 'termo-1',
        titulo: 'Termo Teste',
        conteudo: 'Texto teste',
        versao: '1.5',
        vigenciaInicio: DateTime.utc(2026, 6, 1),
        ativo: true,
        createdBy: 'user-1',
        deletedAt: DateTime.utc(2026, 12, 1),
        createdAt: DateTime.utc(2026, 5, 1),
      );

      final json = model.toJson();

      expect(json['id'], 'termo-1');
      expect(json['titulo'], 'Termo Teste');
      expect(json['conteudo'], 'Texto teste');
      expect(json['versao'], '1.5');
      expect(json['vigencia_inicio'], DateTime.utc(2026, 6, 1).toIso8601String());
      expect(json['ativo'], true);
      expect(json['created_by'], 'user-1');
      expect(json['deleted_at'], DateTime.utc(2026, 12, 1).toIso8601String());
      expect(json['created_at'], DateTime.utc(2026, 5, 1).toIso8601String());
    });

    test('toJson serializa campos de data nulos corretamente como null', () {
      const model = TermoModel(
        id: 'termo-2',
        titulo: 'Título',
        conteudo: 'Conteúdo',
        versao: '1.0',
        ativo: false,
      );

      final json = model.toJson();

      expect(json['vigencia_inicio'], null);
      expect(json['deleted_at'], null);
      expect(json['created_at'], null);
    });

    test('copyWith substitui apenas os campos fornecidos e preserva os originais', () {
      final original = TermoModel(
        id: 'termo-1',
        titulo: 'Original',
        conteudo: 'Conteúdo',
        versao: '1.0',
        vigenciaInicio: DateTime(2026, 1, 1),
        ativo: false,
        createdBy: 'user-1',
        deletedAt: null,
        createdAt: DateTime(2026, 1, 1),
      );

      final modificado = original.copyWith(
        titulo: 'Modificado',
        ativo: true,
        versao: '2.0',
      );

      expect(modificado.id, original.id);
      expect(modificado.titulo, 'Modificado');
      expect(modificado.conteudo, original.conteudo);
      expect(modificado.versao, '2.0');
      expect(modificado.vigenciaInicio, original.vigenciaInicio);
      expect(modificado.ativo, true);
      expect(modificado.createdBy, original.createdBy);
      expect(modificado.createdAt, original.createdAt);
    });
  });
}
