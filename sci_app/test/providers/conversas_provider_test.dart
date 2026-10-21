import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/providers/conversas_provider.dart';

void main() {
  group('Conversas & Contatos Models (Sprint 11)', () {
    test('ContatoPermitido.fromJson deserializa corretamente os campos', () {
      final json = {
        'id': 'user-123',
        'nome': 'Dra. Ana Silva',
        'perfil': 'professor',
        'email': 'ana@ufc.br',
      };

      final contato = ContatoPermitido.fromJson(json);

      expect(contato.id, equals('user-123'));
      expect(contato.nome, equals('Dra. Ana Silva'));
      expect(contato.perfil, equals('professor'));
      expect(contato.email, equals('ana@ufc.br'));
    });

    test('ConversaItem.fromJson identifica o outro participante e conta nao lidas', () {
      final meId = 'aluno-001';
      final json = {
        'id': 'conv-99',
        'participante_1_id': 'aluno-001',
        'participante_2_id': 'prof-002',
        'participante_2': {
          'id': 'prof-002',
          'nome': 'Prof. Carlos',
          'perfil': 'professor',
        },
        'mensagens': [
          {
            'id': 'm1',
            'conteudo': 'Olá aluno',
            'remetente_id': 'prof-002',
            'lida': false,
            'created_at': '2026-08-22T10:00:00.000',
          },
          {
            'id': 'm2',
            'conteudo': 'Tudo bem?',
            'remetente_id': 'prof-002',
            'lida': false,
            'created_at': '2026-08-22T10:01:00.000',
          },
        ],
      };

      final conversa = ConversaItem.fromJson(json, meId);

      expect(conversa.id, equals('conv-99'));
      expect(conversa.outroUsuarioId, equals('prof-002'));
      expect(conversa.outroUsuarioNome, equals('Prof. Carlos'));
      expect(conversa.outroUsuarioPerfil, equals('professor'));
      expect(conversa.ultimaMensagemConteudo, equals('Tudo bem?'));
      expect(conversa.mensagensNaoLidas, equals(2));
    });

    test('Isolamento de Conversas por Participante (P1 e P2)', () {
      final meId = 'user-A';

      final conversaPropriaP1 = {
        'id': 'c1',
        'participante_1_id': 'user-A',
        'participante_2_id': 'user-B',
      };

      final conversaPropriaP2 = {
        'id': 'c2',
        'participante_1_id': 'user-X',
        'participante_2_id': 'user-A',
      };

      final conversaDeTerceiros = {
        'id': 'c3',
        'participante_1_id': 'user-C',
        'participante_2_id': 'user-D',
      };

      final itemP1 = ConversaItem.fromJson(conversaPropriaP1, meId);
      final itemP2 = ConversaItem.fromJson(conversaPropriaP2, meId);
      final itemTerceiros = ConversaItem.fromJson(conversaDeTerceiros, meId);

      expect(itemP1.outroUsuarioId, equals('user-B'));
      expect(itemP2.outroUsuarioId, equals('user-X'));
      // Em terceiros, user-A nao e participante
      expect(itemTerceiros.participante1Id != meId && itemTerceiros.participante2Id != meId, isTrue);
    });
  });
}
