import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/providers/mensagens_provider.dart';

void main() {
  group('Mensagens Model & Validation Tests (Sprint 11)', () {
    test('MensagemChat.fromJson deserializa campos de mensagem', () {
      final json = {
        'id': 'msg-001',
        'conversa_id': 'conv-10',
        'remetente_id': 'user-A',
        'conteudo': 'Relatório assinado!',
        'lida': true,
        'created_at': '2026-08-22T11:30:00.000',
      };

      final msg = MensagemChat.fromJson(json);

      expect(msg.id, equals('msg-001'));
      expect(msg.conversaId, equals('conv-10'));
      expect(msg.remetenteId, equals('user-A'));
      expect(msg.conteudo, equals('Relatório assinado!'));
      expect(msg.lida, isTrue);
    });
  });
}
