import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/presentation/widgets/chat_bubble.dart';

void main() {
  testWidgets('ChatBubble exibe mensagem do proprio usuario à direita com background verde', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            conteudo: 'Mensagem de teste enviada',
            isMe: true,
            timestamp: DateTime(2026, 8, 22, 14, 30),
            lida: true,
          ),
        ),
      ),
    );

    expect(find.text('Mensagem de teste enviada'), findsOneWidget);
    expect(find.text('14:30'), findsOneWidget);
    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
  });

  testWidgets('ChatBubble exibe mensagem recebida à esquerda com background cinza', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            conteudo: 'Resposta recebida do supervisor',
            isMe: false,
            timestamp: DateTime(2026, 8, 22, 14, 32),
            lida: false,
          ),
        ),
      ),
    );

    expect(find.text('Resposta recebida do supervisor'), findsOneWidget);
    expect(find.text('14:32'), findsOneWidget);
    expect(find.byIcon(Icons.done_all_rounded), findsNothing);
  });
}
