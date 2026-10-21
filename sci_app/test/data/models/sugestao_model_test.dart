// test/data/models/sugestao_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/data/models/sugestao_model.dart';

void main() {
  group('SugestaoModel', () {
    test('fromJson faz parsing de nome e perfil a partir de mapa aninhado (usuarios join)', () {
      final json = {
        'id': 'sug-1',
        'autor_id': 'autor-123',
        'usuarios': {
          'nome': 'Mariana Souza',
          'perfil': 'aluno',
        },
        'conteudo': 'Sugerir inclusão de novos campos de estágio em pediatria.',
        'created_at': '2026-07-15T10:00:00.000',
        'deleted_at': '2026-12-31T00:00:00.000',
      };

      final model = SugestaoModel.fromJson(json);

      expect(model.id, 'sug-1');
      expect(model.autorId, 'autor-123');
      expect(model.autorNome, 'Mariana Souza');
      expect(model.autorPerfil, 'aluno');
      expect(model.conteudo, 'Sugerir inclusão de novos campos de estágio em pediatria.');
      expect(model.createdAt, DateTime.parse('2026-07-15T10:00:00.000'));
      expect(model.deletedAt, DateTime.parse('2026-12-31T00:00:00.000'));
    });

    test('fromJson faz parsing de autor_nome e autor_perfil diretamente (sem mapa aninhado)', () {
      final json = {
        'id': 'sug-2',
        'autor_id': 'autor-456',
        'autor_nome': 'Prof. Ricardo',
        'autor_perfil': 'professor',
        'conteudo': 'Aumentar carga horária prática.',
      };

      final model = SugestaoModel.fromJson(json);

      expect(model.id, 'sug-2');
      expect(model.autorId, 'autor-456');
      expect(model.autorNome, 'Prof. Ricardo');
      expect(model.autorPerfil, 'professor');
      expect(model.conteudo, 'Aumentar carga horária prática.');
      expect(model.createdAt, null);
      expect(model.deletedAt, null);
    });

    test('fromJson assume string vazia para conteudo quando null', () {
      final json = {
        'id': 'sug-3',
        'autor_id': 'autor-1',
      };

      final model = SugestaoModel.fromJson(json);

      expect(model.conteudo, '');
      expect(model.autorNome, null);
      expect(model.autorPerfil, null);
    });

    test('toJson serializa todos os campos adequadamente com ISO8601 para datas', () {
      final model = SugestaoModel(
        id: 'sug-1',
        autorId: 'autor-123',
        autorNome: 'Mariana Souza',
        autorPerfil: 'aluno',
        conteudo: 'Sugestão teste',
        createdAt: DateTime.utc(2026, 7, 15),
        deletedAt: DateTime.utc(2026, 12, 1),
      );

      final json = model.toJson();

      expect(json['id'], 'sug-1');
      expect(json['autor_id'], 'autor-123');
      expect(json['conteudo'], 'Sugestão teste');
      expect(json['created_at'], DateTime.utc(2026, 7, 15).toIso8601String());
      expect(json['deleted_at'], DateTime.utc(2026, 12, 1).toIso8601String());
    });

    test('toJson serializa datas nulas como null', () {
      const model = SugestaoModel(
        id: 'sug-2',
        autorId: 'a1',
        conteudo: 'c1',
      );

      final json = model.toJson();

      expect(json['created_at'], null);
      expect(json['deleted_at'], null);
    });
  });
}
