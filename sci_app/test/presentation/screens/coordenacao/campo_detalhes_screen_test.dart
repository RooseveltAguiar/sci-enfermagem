import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sci_app/presentation/screens/coordenacao/campo_detalhes_screen.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

void main() {
  testWidgets('CampoDetalhesScreen exibe botao Alocar Aluno e lista de alunos',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CampoDetalhesScreen(
            campoId: 'campo-123',
            campoNome: 'Hospital Geral de Teste',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Detalhes do Campo'), findsOneWidget);
    expect(find.text('Hospital Geral de Teste'), findsOneWidget);
    expect(find.text('Alocar Aluno'), findsOneWidget);
    expect(find.textContaining('Alunos Alocados'), findsOneWidget);
  });

  testWidgets('CampoDetalhesScreen abre modal de Alocar Aluno ao clicar no botao',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CampoDetalhesScreen(
            campoId: 'campo-123',
            campoNome: 'Hospital Geral de Teste',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final botaoAlocar = find.text('Alocar Aluno');
    expect(botaoAlocar, findsOneWidget);

    await tester.tap(botaoAlocar);
    await tester.pumpAndSettle();

    expect(find.text('Alocar Aluno no Campo'), findsOneWidget);
    expect(find.text('Selecione o Aluno *'), findsOneWidget);
    expect(find.text('Turno de Estágio *'), findsOneWidget);
    expect(find.text('Data de Início do Estágio *'), findsOneWidget);
    expect(find.text('Confirmar Alocação'), findsOneWidget);
  });
}
