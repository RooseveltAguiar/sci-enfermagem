import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sci_app/presentation/screens/professor/professor_alunos_screen.dart';

void main() {
  testWidgets('ProfessorAlunosScreen nao exibe mais atalho para Ratificacao (Exclusivo Ator 4)', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ProfessorAlunosScreen(),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Ratificar'), findsNothing);
    expect(find.text('Ratificação de Abonos'), findsNothing);
  });
}
