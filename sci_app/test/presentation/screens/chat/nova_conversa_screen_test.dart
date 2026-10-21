import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/presentation/screens/chat/nova_conversa_screen.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/providers/conversas_provider.dart';

void main() {
  group('NovaConversaScreen Widget Tests (BUG-CHAT-002)', () {
    testWidgets('Exibe apenas contatos permitidos reais e nenhum mock (Carlos Souza / Marina Luz)', (tester) async {
      final contatosReais = [
        const ContatoPermitido(
          id: 'a4000000-0000-0000-0000-000000000004',
          nome: 'Coordenação Teste QA',
          perfil: 'coordenacao',
          email: '44444477700@sci.uece.br',
        ),
        const ContatoPermitido(
          id: 'a3000000-0000-0000-0000-000000000003',
          nome: 'Professor Teste QA',
          perfil: 'professor',
          email: '33344477782@sci.uece.br',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('a1000000-0000-0000-0000-000000000001'),
            userProfileProvider.overrideWith((ref) => Future.value('aluno')),
            contatosPermitidosProvider.overrideWith((ref) => Future.value(contatosReais)),
          ],
          child: const MaterialApp(
            home: NovaConversaScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Confirma que os contatos reais aparecem
      expect(find.text('Coordenação Teste QA'), findsOneWidget);
      expect(find.text('Professor Teste QA'), findsOneWidget);

      // Confirma que os contatos mock removidos não aparecem
      expect(find.text('Carlos Souza (Aluno)'), findsNothing);
      expect(find.text('Marina Luz (Aluno)'), findsNothing);
      expect(find.text('Aluno Teste QA'), findsNothing);
    });

    testWidgets('Filtra contatos dinamicamente pelo campo de busca', (tester) async {
      final contatosReais = [
        const ContatoPermitido(
          id: 'a4000000-0000-0000-0000-000000000004',
          nome: 'Coordenação Teste QA',
          perfil: 'coordenacao',
          email: '44444477700@sci.uece.br',
        ),
        const ContatoPermitido(
          id: 'a3000000-0000-0000-0000-000000000003',
          nome: 'Professor Teste QA',
          perfil: 'professor',
          email: '33344477782@sci.uece.br',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('a1000000-0000-0000-0000-000000000001'),
            userProfileProvider.overrideWith((ref) => Future.value('aluno')),
            contatosPermitidosProvider.overrideWith((ref) => Future.value(contatosReais)),
          ],
          child: const MaterialApp(
            home: NovaConversaScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Digita 'Coordenação' no campo de busca
      await tester.enterText(find.byType(TextField), 'Coordenação');
      await tester.pumpAndSettle();

      expect(find.text('Coordenação Teste QA'), findsOneWidget);
      expect(find.text('Professor Teste QA'), findsNothing);
    });
  });
}
