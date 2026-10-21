// test/data/models/conflito_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/data/models/conflito_model.dart';

void main() {
  group('ConflitoModel', () {
    test('fromJson faz parsing de nome do aluno e campo a partir de mapas aninhados (join Supabase)', () {
      final json = {
        'id': 'conf-1',
        'aluno_id': 'aluno-123',
        'usuarios': {'nome': 'Carlos Eduardo'},
        'campo_id': 'campo-456',
        'campos_estagio': {'nome': 'UBS Parque Sul'},
        'descricao': 'Conflito de horários de plantão',
        'data_ocorrencia': '2026-07-10T14:30:00.000',
        'created_by': 'coordenador-id',
        'deleted_at': '2026-12-31T00:00:00.000',
        'created_at': '2026-07-10T15:00:00.000',
      };

      final model = ConflitoModel.fromJson(json);

      expect(model.id, 'conf-1');
      expect(model.alunoId, 'aluno-123');
      expect(model.alunoNome, 'Carlos Eduardo');
      expect(model.campoId, 'campo-456');
      expect(model.campoNome, 'UBS Parque Sul');
      expect(model.descricao, 'Conflito de horários de plantão');
      expect(model.dataOcorrencia, DateTime.parse('2026-07-10T14:30:00.000'));
      expect(model.createdBy, 'coordenador-id');
      expect(model.deletedAt, DateTime.parse('2026-12-31T00:00:00.000'));
      expect(model.createdAt, DateTime.parse('2026-07-10T15:00:00.000'));
    });

    test('fromJson faz parsing de aluno_nome e campo_nome diretamente (sem mapas aninhados)', () {
      final json = {
        'id': 'conf-2',
        'aluno_id': 'aluno-789',
        'aluno_nome': 'Fernanda Lima',
        'campo_id': 'campo-101',
        'campo_nome': 'Hospital Universitário',
        'descricao': 'Desentendimento sobre escala',
      };

      final model = ConflitoModel.fromJson(json);

      expect(model.id, 'conf-2');
      expect(model.alunoId, 'aluno-789');
      expect(model.alunoNome, 'Fernanda Lima');
      expect(model.campoId, 'campo-101');
      expect(model.campoNome, 'Hospital Universitário');
      expect(model.descricao, 'Desentendimento sobre escala');
      expect(model.dataOcorrencia, null);
      expect(model.createdBy, null);
      expect(model.deletedAt, null);
      expect(model.createdAt, null);
    });

    test('fromJson assume string vazia quando descricao é null', () {
      final json = {
        'id': 'conf-3',
        'aluno_id': 'aluno-1',
        'campo_id': 'campo-1',
      };

      final model = ConflitoModel.fromJson(json);

      expect(model.descricao, '');
      expect(model.alunoNome, null);
      expect(model.campoNome, null);
    });

    test('toJson serializa todos os campos corretamente com formatações ISO8601 para datas', () {
      final model = ConflitoModel(
        id: 'conf-1',
        alunoId: 'aluno-123',
        alunoNome: 'Carlos Eduardo',
        campoId: 'campo-456',
        campoNome: 'UBS Parque Sul',
        descricao: 'Problema resolvido',
        dataOcorrencia: DateTime.utc(2026, 7, 10),
        createdBy: 'admin',
        deletedAt: DateTime.utc(2026, 12, 1),
        createdAt: DateTime.utc(2026, 7, 11),
      );

      final json = model.toJson();

      expect(json['id'], 'conf-1');
      expect(json['aluno_id'], 'aluno-123');
      expect(json['campo_id'], 'campo-456');
      expect(json['descricao'], 'Problema resolvido');
      expect(json['data_ocorrencia'], DateTime.utc(2026, 7, 10).toIso8601String());
      expect(json['created_by'], 'admin');
      expect(json['deleted_at'], DateTime.utc(2026, 12, 1).toIso8601String());
      expect(json['created_at'], DateTime.utc(2026, 7, 11).toIso8601String());
    });

    test('toJson serializa campos de data nulos corretamente', () {
      const model = ConflitoModel(
        id: 'conf-2',
        alunoId: 'a1',
        campoId: 'c1',
        descricao: 'desc',
      );

      final json = model.toJson();

      expect(json['data_ocorrencia'], null);
      expect(json['deleted_at'], null);
      expect(json['created_at'], null);
    });
  });
}
