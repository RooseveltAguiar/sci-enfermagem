import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/data/models/usuario_model.dart';

void main() {
  group('UsuarioModel - Cobertura Integral', () {
    test('construtor com valores padrão e getters', () {
      const usuario = UsuarioModel(
        id: 'user-1',
        cpf: '11122233344',
        nome: 'João da Silva',
        perfil: 'aluno',
      );

      expect(usuario.id, 'user-1');
      expect(usuario.cpf, '11122233344');
      expect(usuario.nome, 'João da Silva');
      expect(usuario.email, isNull);
      expect(usuario.perfil, 'aluno');
      expect(usuario.ativo, true);
      expect(usuario.deletedAt, isNull);
      expect(usuario.cpfMascarado, '***.***.*33-44');
    });

    test('cpfMascarado para CPF com formatação diferente ou inválido', () {
      const usuarioInvalido = UsuarioModel(
        id: 'user-2',
        cpf: '12345',
        nome: 'Curto',
        perfil: 'aluno',
      );
      expect(usuarioInvalido.cpfMascarado, '12345');

      const usuarioFormatado = UsuarioModel(
        id: 'user-3',
        cpf: '111.222.333-44',
        nome: 'Formatado',
        perfil: 'supervisor',
      );
      expect(usuarioFormatado.cpfMascarado, '***.***.*33-44');
    });

    test('fromJson e toJson com campos completos', () {
      final json = {
        'id': 'user-100',
        'cpf': '99988877766',
        'nome': 'Maria Souza',
        'email': 'maria@sci.uece.br',
        'perfil': 'professor',
        'ativo': false,
        'deleted_at': '2026-07-16T12:00:00.000Z',
      };

      final usuario = UsuarioModel.fromJson(json);
      expect(usuario.id, 'user-100');
      expect(usuario.cpf, '99988877766');
      expect(usuario.nome, 'Maria Souza');
      expect(usuario.email, 'maria@sci.uece.br');
      expect(usuario.perfil, 'professor');
      expect(usuario.ativo, false);
      expect(usuario.deletedAt, isNotNull);

      final map = usuario.toJson();
      expect(map['id'], 'user-100');
      expect(map['cpf'], '99988877766');
      expect(map['nome'], 'Maria Souza');
      expect(map['email'], 'maria@sci.uece.br');
      expect(map['perfil'], 'professor');
      expect(map['ativo'], false);
      expect(map['deleted_at'], '2026-07-16T12:00:00.000Z');
    });

    test('fromJson e toJson com campos nulos e defaults', () {
      final json = {
        'id': 'user-101',
        'cpf': '00000000000',
        'nome': 'Anônimo',
        'perfil': 'coordenacao',
      };

      final usuario = UsuarioModel.fromJson(json);
      expect(usuario.ativo, true);
      expect(usuario.deletedAt, isNull);

      final map = usuario.toJson();
      expect(map['ativo'], true);
      expect(map['deleted_at'], isNull);
    });

    test('copyWith alterando campos e mantendo originais', () {
      final dataOriginal = DateTime(2026, 1, 1);
      final usuario = UsuarioModel(
        id: 'u-1',
        cpf: '11111111111',
        nome: 'Ana',
        email: 'ana@test.com',
        perfil: 'aluno',
        ativo: true,
        deletedAt: dataOriginal,
      );

      final modificado = usuario.copyWith(
        nome: 'Ana Clara',
        perfil: 'supervisor',
        ativo: false,
      );

      expect(modificado.id, 'u-1');
      expect(modificado.cpf, '11111111111');
      expect(modificado.nome, 'Ana Clara');
      expect(modificado.email, 'ana@test.com');
      expect(modificado.perfil, 'supervisor');
      expect(modificado.ativo, false);
      expect(modificado.deletedAt, dataOriginal);

      final semMudanca = usuario.copyWith();
      expect(semMudanca, equals(usuario));
    });

    test('operator == e hashCode para igualdade e desigualdade', () {
      const u1 = UsuarioModel(
        id: 'u1',
        cpf: '111',
        nome: 'Teste',
        email: 't@t.com',
        perfil: 'aluno',
        ativo: true,
      );
      const u2 = UsuarioModel(
        id: 'u1',
        cpf: '111',
        nome: 'Teste',
        email: 't@t.com',
        perfil: 'aluno',
        ativo: true,
      );
      const u3 = UsuarioModel(
        id: 'u2',
        cpf: '111',
        nome: 'Teste',
        email: 't@t.com',
        perfil: 'aluno',
        ativo: true,
      );

      expect(u1 == u2, isTrue);
      expect(u1.hashCode == u2.hashCode, isTrue);
      expect(u1 == u3, isFalse);
    });
  });
}
