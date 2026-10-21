import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/presentation/widgets/timeline_avaliacao.dart';

void main() {
  testWidgets('TimelineAvaliacao renderiza todos os passos, ícones e linhas corretamente', (WidgetTester tester) async {
    final steps = [
      TimelineStepData(
        titulo: 'Passo 1 Concluído',
        dataHora: '10/07/2026 10:00',
        responsavel: 'Enfermeiro A',
        concluido: true,
      ),
      TimelineStepData(
        titulo: 'Passo 2 Atual',
        dataHora: '11/07/2026 14:00',
        atual: true,
      ),
      TimelineStepData(
        titulo: 'Passo 3 Futuro',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineAvaliacao(steps: steps),
        ),
      ),
    );

    expect(find.text('Linha do Tempo'), findsOneWidget);
    expect(find.text('Passo 1 Concluído'), findsOneWidget);
    expect(find.text('Enfermeiro A • 10/07/2026 10:00'), findsOneWidget);
    expect(find.text('Passo 2 Atual'), findsOneWidget);
    expect(find.text('11/07/2026 14:00'), findsOneWidget);
    expect(find.text('Passo 3 Futuro'), findsOneWidget);

    // Ícones dos estados:
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.access_time), findsOneWidget);
    expect(find.byIcon(Icons.circle), findsOneWidget);
  });
}
