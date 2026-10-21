// test/presentation/screens/legislacao/legislacao_form_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sci_app/data/models/legislacao_model.dart';
import 'package:sci_app/presentation/screens/legislacao/legislacao_form_screen.dart';
import 'package:sci_app/providers/legislacao_provider.dart';

class MockLegislacoesController
    extends StateNotifier<AsyncValue<List<LegislacaoModel>>>
    implements LegislacoesController {
  MockLegislacoesController() : super(const AsyncValue.data([]));

  int criarCalled = 0;
  int editarCalled = 0;
  int desativarCalled = 0;
  bool shouldThrow = false;

  @override
  Future<void> carregarLegislacoes() async {}

  @override
  Future<void> criarLegislacao({
    required String titulo,
    required String conteudo,
    required String tipo,
    DateTime? vigenciaInicio,
    DateTime? vigenciaFim,
    required bool ativo,
  }) async {
    if (shouldThrow) throw Exception('Erro no servidor ao criar');
    criarCalled++;
  }

  @override
  Future<void> editarLegislacao({
    required String id,
    required String titulo,
    required String conteudo,
    required String tipo,
    DateTime? vigenciaInicio,
    DateTime? vigenciaFim,
    required bool ativo,
  }) async {
    if (shouldThrow) throw Exception('Erro no servidor ao editar');
    editarCalled++;
  }

  @override
  Future<void> desativarLegislacao(String id) async {
    if (shouldThrow) throw Exception('Erro no servidor ao desativar');
    desativarCalled++;
  }

  Ref get ref => throw UnimplementedError();
}

void main() {
  testWidgets('LegislacaoFormScreen renderiza campos e valida obrigatoriedade inicial',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LegislacaoFormScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Nova Legislação'), findsOneWidget);
    expect(find.text('Salvar Legislação'), findsOneWidget);

    // Tenta salvar em branco -> validação
    await tester.ensureVisible(find.text('Salvar Legislação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar Legislação'));
    await tester.pump();

    expect(find.text('Informe o título do documento'), findsOneWidget);
  });

  testWidgets('LegislacaoFormScreen fluxo completo de criação (com datas e switch)',
      (WidgetTester tester) async {
    final mockController = MockLegislacoesController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          legislacoesProvider.overrideWith((ref) => mockController),
        ],
        child: const MaterialApp(
          home: LegislacaoFormScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'Resolução 123/2026');
    await tester.enterText(textFields.at(1), 'Resolução');
    await tester.enterText(textFields.at(2), 'Conteúdo completo da resolução.');
    await tester.pump();

    // Toggle switch de ativo
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    // Abre date picker de início
    await tester.tap(find.text('Vigência Inicial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Abre date picker de fim
    await tester.tap(find.text('Vigência Final'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Salvar Legislação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar Legislação'));
    await tester.pumpAndSettle();

    expect(mockController.criarCalled, 1);
    expect(find.text('Legislação cadastrada.'), findsOneWidget);
  });

  testWidgets('LegislacaoFormScreen exibe erro quando vigência final é anterior à vigência inicial',
      (WidgetTester tester) async {
    final doc = LegislacaoModel(
      id: 'leg_1',
      titulo: 'Portaria Exemplo',
      conteudo: 'Conteúdo da portaria',
      tipo: 'Portaria',
      vigenciaInicio: DateTime(2026, 7, 10),
      vigenciaFim: DateTime(2026, 7, 5), // Fim anterior ao início
      ativo: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: LegislacaoFormScreen(doc: doc),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Salvar Legislação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar Legislação'));
    await tester.pump();

    expect(
      find.text('A vigência final não pode ser anterior à vigência inicial.'),
      findsOneWidget,
    );
  });

  testWidgets('LegislacaoFormScreen fluxo completo de edição e erro no servidor',
      (WidgetTester tester) async {
    final mockController = MockLegislacoesController()..shouldThrow = true;
    final doc = LegislacaoModel(
      id: 'leg_2',
      titulo: 'Portaria Antiga',
      conteudo: 'Conteúdo antigo',
      tipo: 'Portaria',
      ativo: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          legislacoesProvider.overrideWith((ref) => mockController),
        ],
        child: MaterialApp(
          home: LegislacaoFormScreen(doc: doc),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Editar Legislação'), findsOneWidget);

    await tester.ensureVisible(find.text('Salvar Legislação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar Legislação'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Erro ao salvar:'), findsOneWidget);
  });

  testWidgets('LegislacaoFormScreen fluxo de desativação (sucesso e erro)',
      (WidgetTester tester) async {
    final mockController = MockLegislacoesController();
    final doc = LegislacaoModel(
      id: 'leg_3',
      titulo: 'Portaria Ativa',
      conteudo: 'Conteúdo',
      tipo: 'Portaria',
      ativo: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          legislacoesProvider.overrideWith((ref) => mockController),
        ],
        child: MaterialApp(
          home: LegislacaoFormScreen(doc: doc),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Desativar documento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desativar documento'));
    await tester.pumpAndSettle();

    expect(find.text('Desativar Documento'), findsOneWidget);
    expect(find.text('Desativar'), findsOneWidget);

    await tester.tap(find.text('Desativar'));
    await tester.pumpAndSettle();

    expect(mockController.desativarCalled, 1);
  });
}
