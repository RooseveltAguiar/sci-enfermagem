// test/data/models/avaliacao_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/data/models/avaliacao_model.dart';

void main() {
  group('AvaliacaoModel', () {
    test('fromJson cria instância corretamente com todos os campos preenchidos', () {
      final json = {
        'id': 'aval-1',
        'alocacao_id': 'aloc-123',
        'tipo': 'setorial',
        'periodo_referencia': '2026-07-01T00:00:00.000',
        'status': 'validada',
        'nota_geral': 9,
        'pontos_positivos': 'Ótimo desempenho',
        'pontos_melhoria': 'Atenção aos horários',
        'comentario_livre': 'Comentário teste',
        'comentario_validacao': 'Aprovado pelo professor',
        'avaliador_id': 'user-prof',
        'avaliador_nome': 'Prof. Roosevelt',
        'aluno_nome': 'Ana Silva',
        'campo_nome': 'Hospital Central',
        'deleted_at': '2026-12-31T00:00:00.000',
      };

      final model = AvaliacaoModel.fromJson(json);

      expect(model.id, 'aval-1');
      expect(model.alocacaoId, 'aloc-123');
      expect(model.tipo, 'setorial');
      expect(model.periodoReferencia, DateTime.parse('2026-07-01T00:00:00.000'));
      expect(model.status, 'validada');
      expect(model.notaGeral, 9);
      expect(model.pontosPositivos, 'Ótimo desempenho');
      expect(model.pontosMelhoria, 'Atenção aos horários');
      expect(model.comentarioLivre, 'Comentário teste');
      expect(model.comentarioValidacao, 'Aprovado pelo professor');
      expect(model.avaliadorId, 'user-prof');
      expect(model.avaliadorNome, 'Prof. Roosevelt');
      expect(model.alunoNome, 'Ana Silva');
      expect(model.campoNome, 'Hospital Central');
      expect(model.deletedAt, DateTime.parse('2026-12-31T00:00:00.000'));
    });

    test('fromJson lida com campos opcionais nulos adequadamente', () {
      final json = {
        'id': 'aval-2',
        'alocacao_id': 'aloc-456',
        'tipo': 'do_interno',
        'periodo_referencia': '2026-06-01',
        'status': 'rascunho',
        'avaliador_id': 'user-int',
      };

      final model = AvaliacaoModel.fromJson(json);

      expect(model.id, 'aval-2');
      expect(model.notaGeral, null);
      expect(model.pontosPositivos, null);
      expect(model.pontosMelhoria, null);
      expect(model.comentarioLivre, null);
      expect(model.comentarioValidacao, null);
      expect(model.avaliadorNome, null);
      expect(model.alunoNome, null);
      expect(model.campoNome, null);
      expect(model.deletedAt, null);
    });

    test('toJson serializa campos obrigatórios e formata periodo_referencia corretamente', () {
      final model = AvaliacaoModel(
        id: 'aval-1',
        alocacaoId: 'aloc-101',
        tipo: 'autoavaliacao',
        periodoReferencia: DateTime(2026, 5, 15),
        status: 'submetida',
        avaliadorId: 'user-aluno',
      );

      final json = model.toJson();

      expect(json['id'], 'aval-1');
      expect(json['alocacao_id'], 'aloc-101');
      expect(json['tipo'], 'autoavaliacao');
      expect(json['periodo_referencia'], '2026-05-01');
      expect(json['status'], 'submetida');
      expect(json['avaliador_id'], 'user-aluno');
      expect(json.containsKey('nota_geral'), false);
      expect(json.containsKey('pontos_positivos'), false);
    });

    test('toJson inclui campos opcionais quando preenchidos', () {
      final model = AvaliacaoModel(
        id: 'aval-1',
        alocacaoId: 'aloc-101',
        tipo: 'autoavaliacao',
        periodoReferencia: DateTime(2026, 5, 1),
        status: 'submetida',
        avaliadorId: 'user-aluno',
        notaGeral: 10,
        pontosPositivos: 'Positivo',
        pontosMelhoria: 'Melhoria',
        comentarioLivre: 'Livre',
        comentarioValidacao: 'Validacao',
      );

      final json = model.toJson();

      expect(json['nota_geral'], 10);
      expect(json['pontos_positivos'], 'Positivo');
      expect(json['pontos_melhoria'], 'Melhoria');
      expect(json['comentario_livre'], 'Livre');
      expect(json['comentario_validacao'], 'Validacao');
    });

    test('copyWith substitui os campos especificados e mantém o restante inalterado', () {
      final original = AvaliacaoModel(
        id: 'aval-1',
        alocacaoId: 'aloc-1',
        tipo: 'setorial',
        periodoReferencia: DateTime(2026, 1, 1),
        status: 'rascunho',
        avaliadorId: 'prof-1',
        notaGeral: 7,
      );

      final modificado = original.copyWith(
        status: 'validada',
        notaGeral: 9,
        pontosPositivos: 'Excelente avanço',
      );

      expect(modificado.id, original.id);
      expect(modificado.alocacaoId, original.alocacaoId);
      expect(modificado.status, 'validada');
      expect(modificado.notaGeral, 9);
      expect(modificado.pontosPositivos, 'Excelente avanço');
    });
  });
}
