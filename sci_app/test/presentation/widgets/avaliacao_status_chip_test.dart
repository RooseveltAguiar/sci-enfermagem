import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/presentation/widgets/avaliacao_status_chip.dart';

void main() {
  group('AvaliacaoStatusChip', () {
    testWidgets('Exibe Rascunho quando status é rascunho sem comentário de devolução', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvaliacaoStatusChip.fromString('rascunho'),
          ),
        ),
      );
      expect(find.text('Rascunho'), findsOneWidget);
    });

    testWidgets('Exibe Devolvida quando status é rascunho com comentário de devolução', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvaliacaoStatusChip.fromString(
              'rascunho',
              comentarioValidacao: 'Ajustar pontos de melhoria relatados',
            ),
          ),
        ),
      );
      expect(find.text('Devolvida'), findsOneWidget);
    });

    testWidgets('Exibe Submetida, Validada e Aprovada corretamente', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AvaliacaoStatusChip.fromString('submetida'),
                AvaliacaoStatusChip.fromString('validada'),
                AvaliacaoStatusChip.fromString('aprovada'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Submetida'), findsOneWidget);
      expect(find.text('Validada'), findsOneWidget);
      expect(find.text('Aprovada'), findsOneWidget);
    });
  });
}
