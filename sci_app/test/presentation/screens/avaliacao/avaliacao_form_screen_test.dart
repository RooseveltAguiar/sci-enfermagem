// test/presentation/screens/avaliacao/avaliacao_form_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/data/models/avaliacao_model.dart';
import 'package:sci_app/presentation/screens/avaliacao/avaliacao_form_screen.dart';
import 'package:sci_app/presentation/widgets/confirmation_bottom_sheet.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/providers/avaliacoes_provider.dart';

class MockAvaliacoesNotifier extends AsyncNotifier<List<AvaliacaoModel>>
    implements AvaliacoesNotifier {
  MockAvaliacoesNotifier(this.initialList);

  final List<AvaliacaoModel> initialList;
  int salvarCalled = 0;
  int submitCalled = 0;
  int excluirCalled = 0;
  bool shouldThrow = false;

  @override
  Future<List<AvaliacaoModel>> build() async {
    return initialList;
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<AvaliacaoModel> salvarRascunho(Map<String, dynamic> data) async {
    if (shouldThrow) throw Exception('Falha ao salvar rascunho');
    salvarCalled++;
    return AvaliacaoModel(
      id: data['id'] ?? 'aval_novo',
      alocacaoId: data['alocacao_id'] ?? 'aloc_123',
      avaliadorId: data['avaliador_id'] ?? 'user_123',
      tipo: data['tipo'] ?? 'setorial',
      periodoReferencia: DateTime.parse(data['periodo_referencia']),
      status: 'rascunho',
      notaGeral: data['nota_geral'],
      pontosPositivos: data['pontos_positivos'],
      pontosMelhoria: data['pontos_melhoria'],
      comentarioLivre: data['comentario_livre'],
    );
  }

  @override
  Future<void> submitAvaliacao(String id) async {
    if (shouldThrow) throw Exception('Falha ao submeter');
    submitCalled++;
  }

  @override
  Future<void> excluirRascunho(String id) async {
    if (shouldThrow) throw Exception('Falha ao excluir');
    excluirCalled++;
  }

  @override
  Future<void> validarAvaliacao(String id, {String? comentario}) async {}

  @override
  Future<void> aprovarAvaliacao(String id, {String? comentario}) async {}

  @override
  Future<void> devolverAvaliacao(String id, String comentario) async {}
}

void main() {
  group('AvaliacaoFormScreen Completo', () {
    testWidgets('1. Renderiza campos e botões (Salvar rascunho e Submeter)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => 'aluno'),
          ],
          child: const MaterialApp(
            home: AvaliacaoFormScreen(tipoInicial: 'setorial'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nova Avaliação'), findsOneWidget);
      expect(find.text('Salvar rascunho'), findsOneWidget);
      expect(find.text('Submeter'), findsOneWidget);
    });

    testWidgets(
        '2. Submeter com campos vazios ou curtos exibe erros de validação',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => 'aluno'),
          ],
          child: const MaterialApp(
            home: AvaliacaoFormScreen(tipoInicial: 'setorial'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final btnSubmeter = find.text('Submeter');
      await tester.ensureVisible(btnSubmeter);
      await tester.tap(btnSubmeter);
      await tester.pumpAndSettle();

      expect(find.text('Informe no mínimo 20 caracteres'), findsNWidgets(2));
    });

    testWidgets('3. Fluxo completo de salvar rascunho com sucesso',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockNotifier = MockAvaliacoesNotifier([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => 'aluno'),
            avaliacoesProvider.overrideWith(() => mockNotifier),
          ],
          child: const MaterialApp(
            home: AvaliacaoFormScreen(tipoInicial: 'setorial'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Pontos positivos válidos com mais de vinte caracteres.');
      await tester.enterText(textFields.at(1), 'Pontos de melhoria válidos com mais de vinte caracteres.');
      await tester.pumpAndSettle();

      final btnSalvar = find.text('Salvar rascunho');
      await tester.ensureVisible(btnSalvar);
      await tester.tap(btnSalvar);
      await tester.pumpAndSettle();

      expect(mockNotifier.salvarCalled, 1);
      expect(find.text('Rascunho salvo com sucesso!'), findsOneWidget);
    });

    testWidgets('4. Fluxo completo de submeter avaliação (incluindo bottom sheet)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockNotifier = MockAvaliacoesNotifier([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => 'aluno'),
            avaliacoesProvider.overrideWith(() => mockNotifier),
          ],
          child: const MaterialApp(
            home: AvaliacaoFormScreen(tipoInicial: 'setorial'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0),
          'Pontos positivos detalhados com mais de 20 caracteres.');
      await tester.enterText(textFields.at(1),
          'Pontos de melhoria detalhados com mais de 20 caracteres.');
      await tester.pumpAndSettle();

      final btnSubmeter = find.text('Submeter');
      await tester.ensureVisible(btnSubmeter);
      await tester.tap(btnSubmeter);
      await tester.pumpAndSettle();

      expect(find.text('Submeter avaliação?'), findsOneWidget);

      final btnConfirmar = find.descendant(
        of: find.byType(ConfirmationBottomSheet),
        matching: find.widgetWithText(FilledButton, 'Submeter'),
      );
      await tester.tap(btnConfirmar);
      await tester.pumpAndSettle();

      expect(mockNotifier.salvarCalled, 1);
      expect(mockNotifier.submitCalled, 1);
      expect(find.text('Avaliação submetida com sucesso!'), findsOneWidget);
    });

    testWidgets('5. Exibe erro ao tentar salvar rascunho que falha no servidor',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockNotifier = MockAvaliacoesNotifier([])..shouldThrow = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => 'aluno'),
            avaliacoesProvider.overrideWith(() => mockNotifier),
          ],
          child: const MaterialApp(
            home: AvaliacaoFormScreen(tipoInicial: 'setorial'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Pontos positivos válidos com mais de vinte caracteres.');
      await tester.enterText(textFields.at(1), 'Pontos de melhoria válidos com mais de vinte caracteres.');
      await tester.pumpAndSettle();

      final btnSalvar = find.text('Salvar rascunho');
      await tester.ensureVisible(btnSalvar);
      await tester.tap(btnSalvar);
      await tester.pumpAndSettle();

      expect(find.text('Erro ao salvar rascunho: Exception: Falha ao salvar rascunho'), findsOneWidget);
    });

    testWidgets('6. Exibe erro ao tentar submeter avaliação que falha no servidor',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockNotifier = MockAvaliacoesNotifier([])..shouldThrow = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => 'aluno'),
            avaliacoesProvider.overrideWith(() => mockNotifier),
          ],
          child: const MaterialApp(
            home: AvaliacaoFormScreen(tipoInicial: 'setorial'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0),
          'Pontos positivos detalhados com mais de 20 caracteres.');
      await tester.enterText(textFields.at(1),
          'Pontos de melhoria detalhados com mais de 20 caracteres.');
      await tester.pumpAndSettle();

      final btnSubmeter = find.text('Submeter');
      await tester.ensureVisible(btnSubmeter);
      await tester.tap(btnSubmeter);
      await tester.pumpAndSettle();

      final btnConfirmar = find.descendant(
        of: find.byType(ConfirmationBottomSheet),
        matching: find.widgetWithText(FilledButton, 'Submeter'),
      );
      await tester.tap(btnConfirmar);
      await tester.pumpAndSettle();

      expect(find.text('Erro ao submeter avaliação: Exception: Falha ao salvar rascunho'), findsOneWidget);
    });

    testWidgets('7. Carrega rascunho existente e permite excluir',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final rascunhoExistente = AvaliacaoModel(
        id: 'aval_123',
        alocacaoId: 'aloc_123',
        avaliadorId: 'user_123',
        tipo: 'setorial',
        periodoReferencia: DateTime(2026, 2, 1),
        status: 'rascunho',
        notaGeral: 8,
        pontosPositivos: 'Pontos positivos prévios.',
        pontosMelhoria: 'Pontos de melhoria prévios.',
        comentarioLivre: 'Comentário prévio.',
      );

      final mockNotifier = MockAvaliacoesNotifier([rascunhoExistente]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => 'aluno'),
            avaliacoesProvider.overrideWith(() => mockNotifier),
          ],
          child: const MaterialApp(
            home: AvaliacaoFormScreen(
              tipoInicial: 'setorial',
              avaliacaoId: 'aval_123',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pontos positivos prévios.'), findsOneWidget);
      expect(find.text('Excluir rascunho'), findsOneWidget);

      final btnExcluir = find.text('Excluir rascunho');
      await tester.ensureVisible(btnExcluir);
      await tester.tap(btnExcluir);
      await tester.pumpAndSettle();

      final btnConfirmarExcluir = find.widgetWithText(FilledButton, 'Excluir');
      await tester.tap(btnConfirmarExcluir);
      await tester.pumpAndSettle();

      expect(mockNotifier.excluirCalled, 1);
      expect(find.text('Rascunho excluído.'), findsOneWidget);
    });

    testWidgets('8. Alterar slider de nota atualiza valor no label',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => 'aluno'),
          ],
          child: const MaterialApp(
            home: AvaliacaoFormScreen(tipoInicial: 'setorial'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nota Geral: 7 — Bom'), findsOneWidget);

      final slider = find.byType(Slider);
      await tester.drag(slider, const Offset(100, 0));
      await tester.pumpAndSettle();

      expect(find.text('Nota Geral: 7 — Bom'), findsNothing);
    });

    testWidgets('9. Perfil ator_1 (aluno) NÃO possui opção do_interno no Dropdown',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) async => 'aluno'),
          ],
          child: const MaterialApp(
            home: AvaliacaoFormScreen(tipoInicial: 'setorial'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dropdown = find.byType(DropdownButtonFormField<String>);
      expect(dropdown, findsOneWidget);

      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      expect(find.text('Avaliação do Interno'), findsNothing);
      expect(find.text('Avaliação Setorial'), findsWidgets);
      expect(find.text('Autoavaliação'), findsWidgets);
    });

    testWidgets('10. Perfil ator_2 (supervisor) possui apenas do_interno e setorial no Dropdown',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => 'ator_2'),
          ],
          child: const MaterialApp(
            home: AvaliacaoFormScreen(tipoInicial: 'do_interno'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dropdown = find.byType(DropdownButtonFormField<String>);
      expect(dropdown, findsOneWidget);

      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      expect(find.text('Avaliação do Interno'), findsWidgets);
      expect(find.text('Avaliação Setorial'), findsWidgets);
      expect(find.text('Autoavaliação'), findsNothing);
    });
  });
}
