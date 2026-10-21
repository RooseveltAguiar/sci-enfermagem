import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/providers/professor_turmas_provider.dart';
import 'package:sci_app/presentation/screens/professor/professor_alunos_screen.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late MockSupabaseClient mockSupabase;

  setUp(() {
    mockSupabase = MockSupabaseClient();
  });

  group('ProfessorAlunosScreen - Busca e Filtro por Campo (DoD)', () {
    final mockAlunos = [
      AlunoTurmaResumo(
        alunoId: 'aluno_1',
        nome: 'Beatriz Costa',
        cpf: '11122233344',
        turnoTipo: 'Manhã',
        campoNome: 'Hospital Infantil',
        campoId: 'campo_infantil',
      ),
      AlunoTurmaResumo(
        alunoId: 'aluno_2',
        nome: 'Gabriel Alves',
        cpf: '55566677788',
        turnoTipo: 'Tarde',
        campoNome: 'Maternidade Escola',
        campoId: 'campo_maternidade',
      ),
    ];

    testWidgets('1. Sem filtro exibe todos os alunos do professor', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
            alunosDoProfessorProvider.overrideWith((ref) async => mockAlunos),
          ],
          child: const MaterialApp(
            home: ProfessorAlunosScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Beatriz Costa'), findsOneWidget);
      expect(find.text('Gabriel Alves'), findsOneWidget);
    });

    testWidgets('2. Filtrar por campo de estágio reduz a lista corretamente', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
            alunosDoProfessorProvider.overrideWith((ref) async => mockAlunos),
          ],
          child: const MaterialApp(
            home: ProfessorAlunosScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Digita "Maternidade" no campo de busca
      await tester.enterText(find.byType(TextField), 'Maternidade');
      await tester.pumpAndSettle();

      expect(find.text('Gabriel Alves'), findsOneWidget);
      expect(find.text('Beatriz Costa'), findsNothing);
    });

    testWidgets('3. Busca sem resultados exibe empty state, não erro', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
            alunosDoProfessorProvider.overrideWith((ref) async => mockAlunos),
          ],
          child: const MaterialApp(
            home: ProfessorAlunosScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Digita um termo sem correspondência
      await tester.enterText(find.byType(TextField), 'CampoInexistente123');
      await tester.pumpAndSettle();

      expect(find.text('Nenhum aluno encontrado para o filtro informado.'), findsOneWidget);
      expect(find.text('Beatriz Costa'), findsNothing);
      expect(find.text('Gabriel Alves'), findsNothing);
    });

    testWidgets('4. Tocar no aluno exibe modal bottom sheet com opção Banco de Horas do Aluno', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
            alunosDoProfessorProvider.overrideWith((ref) async => mockAlunos),
          ],
          child: const MaterialApp(
            home: ProfessorAlunosScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Beatriz Costa'));
      await tester.pumpAndSettle();

      expect(find.text('Banco de Horas do Aluno'), findsOneWidget);
      expect(find.text('Ver Dossiê do Aluno'), findsOneWidget);
    });
  });
}
