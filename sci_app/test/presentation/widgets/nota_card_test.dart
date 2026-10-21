import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/presentation/widgets/nota_card.dart';

void main() {
  group('NotaCard Thresholds & Labels', () {
    testWidgets('Exibe Insatisfatório para notas 1 a 3', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: NotaCard(notaGeral: 2))));
      expect(find.text('Insatisfatório'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('Exibe Regular para notas 4 a 6', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: NotaCard(notaGeral: 5))));
      expect(find.text('Regular'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('Exibe Bom para notas 7 a 8', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: NotaCard(notaGeral: 8))));
      expect(find.text('Bom'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('Exibe Excelente para notas 9 a 10', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: NotaCard(notaGeral: 10))));
      expect(find.text('Excelente'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
    });
  });
}
