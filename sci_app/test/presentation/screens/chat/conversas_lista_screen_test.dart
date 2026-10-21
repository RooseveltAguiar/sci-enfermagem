import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/presentation/screens/chat/conversas_lista_screen.dart';
import 'package:sci_app/providers/conversas_provider.dart';

void main() {
  group('ConversasListaScreen Widget Tests', () {
    testWidgets('Exibe conversa quando usuário logado é participante_1_id', (tester) async {
      const meId = 'a1000000-0000-0000-0000-000000000001';
      final itemP1 = ConversaItem(
        id: 'conv-p1',
        participante1Id: meId,
        participante2Id: 'a4000000-0000-0000-0000-000000000004',
        outroUsuarioId: 'a4000000-0000-0000-0000-000000000004',
        outroUsuarioNome: 'Coordenação Geral',
        outroUsuarioPerfil: 'coordenacao',
        ultimaMensagemConteudo: 'Olá Aluno, tudo bem?',
        ultimaMensagemData: DateTime.now(),
        mensagensNaoLidas: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue(meId),
            conversasStreamProvider.overrideWith((ref) => Stream.value([itemP1])),
          ],
          child: const MaterialApp(
            home: ConversasListaScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Coordenação Geral'), findsOneWidget);
      expect(find.text('Olá Aluno, tudo bem?'), findsOneWidget);
      expect(find.text('Coordenador'), findsOneWidget);
    });

    testWidgets('Exibe conversa quando usuário logado é participante_2_id', (tester) async {
      const meId = 'a4000000-0000-0000-0000-000000000004';
      final itemP2 = ConversaItem(
        id: 'conv-p2',
        participante1Id: 'a1000000-0000-0000-0000-000000000001',
        participante2Id: meId,
        outroUsuarioId: 'a1000000-0000-0000-0000-000000000001',
        outroUsuarioNome: 'Aluno Teste QA',
        outroUsuarioPerfil: 'aluno',
        ultimaMensagemConteudo: 'Professor, enviei meu relatório.',
        ultimaMensagemData: DateTime.now(),
        mensagensNaoLidas: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue(meId),
            conversasStreamProvider.overrideWith((ref) => Stream.value([itemP2])),
          ],
          child: const MaterialApp(
            home: ConversasListaScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Aluno Teste QA'), findsOneWidget);
      expect(find.text('Professor, enviei meu relatório.'), findsOneWidget);
      expect(find.text('Aluno'), findsOneWidget);
    });
  });
}
