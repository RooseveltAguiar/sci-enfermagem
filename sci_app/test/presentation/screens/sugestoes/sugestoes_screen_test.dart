import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sci_app/data/models/sugestao_model.dart';
import 'package:sci_app/presentation/screens/sugestoes/sugestoes_screen.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/providers/sugestoes_provider.dart';

class MockSugestoesNotifier
    extends StateNotifier<AsyncValue<List<SugestaoModel>>>
    implements SugestoesController {
  bool carregarCalled = false;
  bool enviarCalled = false;
  bool shouldThrowOnEnviar = false;
  String? capturedTexto;
  bool? capturedIsCoordenacao;

  MockSugestoesNotifier({AsyncValue<List<SugestaoModel>> initial = const AsyncValue.data([])})
      : super(initial);

  @override
  Future<void> carregarSugestoes({bool isCoordenacao = false}) async {
    carregarCalled = true;
  }

  @override
  Future<void> enviarSugestao(String conteudo, {bool isCoordenacao = false}) async {
    enviarCalled = true;
    capturedTexto = conteudo;
    capturedIsCoordenacao = isCoordenacao;
    if (shouldThrowOnEnviar) {
      throw Exception('Erro simulado de envio');
    }
  }
}

void main() {
  group('SugestoesScreen Widget Tests - Cobertura Integral', () {
    testWidgets('1. Valida mínimo de 20 caracteres antes de habilitar envio (perfil aluno)', (tester) async {
      final mockNotifier = MockSugestoesNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Future.value('aluno')),
            sugestoesControllerProvider.overrideWith((ref) => mockNotifier),
          ],
          child: const MaterialApp(home: SugestoesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final btnFinder = find.byKey(const Key('btn_enviar_sugestao'));
      expect(tester.widget<ElevatedButton>(btnFinder).onPressed, isNull);

      await tester.enterText(find.byType(TextFormField), 'Texto curto');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(btnFinder).onPressed, isNull);

      await tester.enterText(find.byType(TextFormField), 'Esta é uma sugestão completa com mais de 20 caracteres.');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(btnFinder).onPressed, isNotNull);
    });

    testWidgets('2. Perfil Coordenação: exibe filtros por perfil, troca de abas e cartões com autor/perfil', (tester) async {
      final item = SugestaoModel(
        id: '1',
        autorId: 'user-123',
        conteudo: 'Sugestão de teste com autor e data',
        autorNome: 'Enf. João',
        autorPerfil: 'supervisor',
        createdAt: DateTime(2026, 7, 16, 14, 30),
      );
      final mockNotifier = MockSugestoesNotifier(initial: AsyncValue.data([item]));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Future.value('coordenacao')),
            sugestoesControllerProvider.overrideWith((ref) => mockNotifier),
          ],
          child: const MaterialApp(home: SugestoesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica títulos de coordenação e chips
      expect(find.text('Filtrar sugestões por perfil:'), findsOneWidget);
      expect(find.text('Todas as Sugestões Recebidas'), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Alunos'), findsOneWidget);
      expect(find.text('Supervisores'), findsOneWidget);
      expect(find.text('Professores'), findsOneWidget);

      // Verifica o card da sugestão
      expect(find.text('Sugestão de teste com autor e data'), findsOneWidget);
      expect(find.text('Enf. João'), findsOneWidget);
      expect(find.text('SUPERVISOR'), findsOneWidget);
      expect(find.text('Enviado em 16/07/2026 14:30'), findsOneWidget);

      // Toca em cada filtro e confirma carregarSugestoes
      await tester.tap(find.text('Alunos'));
      await tester.pump();
      await tester.tap(find.text('Supervisores'));
      await tester.pump();
      await tester.tap(find.text('Professores'));
      await tester.pump();
      await tester.tap(find.text('Todos'));
      await tester.pump();
      expect(mockNotifier.carregarCalled, isTrue);
    });

    testWidgets('3. Estado Async Loading em sugestoesControllerProvider', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Future.value('aluno')),
            sugestoesControllerProvider.overrideWith((ref) => MockSugestoesNotifier(initial: const AsyncValue.loading())),
          ],
          child: const MaterialApp(home: SugestoesScreen()),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('4. Estado Async Error em sugestoesControllerProvider', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Future.value('aluno')),
            sugestoesControllerProvider.overrideWith((ref) => MockSugestoesNotifier(initial: AsyncValue.error('Falha na rede', StackTrace.empty))),
          ],
          child: const MaterialApp(home: SugestoesScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Erro ao carregar sugestões: Falha na rede'), findsOneWidget);
    });

    testWidgets('5. Fluxo de Envio com sucesso: modal de confirmação + SnackBar', (tester) async {
      final mockNotifier = MockSugestoesNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Future.value('aluno')),
            sugestoesControllerProvider.overrideWith((ref) => mockNotifier),
          ],
          child: const MaterialApp(home: SugestoesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      const textoValido = 'Sugestão detalhada com no mínimo 20 caracteres para envio.';
      await tester.enterText(find.byType(TextFormField), textoValido);
      await tester.pump();

      await tester.tap(find.byKey(const Key('btn_enviar_sugestao')));
      await tester.pumpAndSettle();

      // Modal aberto
      expect(find.text('Enviar Sugestão'), findsOneWidget);
      expect(find.text('Enviar esta sugestão para a coordenação?'), findsOneWidget);

      // Confirmar envio (utiliza FilledButton no ConfirmationBottomSheet)
      await tester.tap(find.widgetWithText(FilledButton, 'Enviar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(mockNotifier.enviarCalled, isTrue);
      expect(mockNotifier.capturedTexto, textoValido);
      expect(mockNotifier.capturedIsCoordenacao, isFalse);
      expect(find.text('Sugestão enviada com sucesso.'), findsOneWidget);
    });

    testWidgets('6. Fluxo de Envio com erro: exibe SnackBar com mensagem de falha', (tester) async {
      final mockNotifier = MockSugestoesNotifier()..shouldThrowOnEnviar = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Future.value('aluno')),
            sugestoesControllerProvider.overrideWith((ref) => mockNotifier),
          ],
          child: const MaterialApp(home: SugestoesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Sugestão que vai gerar erro no servidor na hora de salvar.');
      await tester.pump();

      await tester.tap(find.byKey(const Key('btn_enviar_sugestao')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Enviar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Erro ao enviar sugestão: Exception: Erro simulado de envio'), findsOneWidget);
    });

    testWidgets('7. RefreshIndicator: puxar para atualizar aciona carregarSugestoes', (tester) async {
      final mockNotifier = MockSugestoesNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Future.value('aluno')),
            sugestoesControllerProvider.overrideWith((ref) => mockNotifier),
          ],
          child: const MaterialApp(home: SugestoesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.fling(find.byType(SingleChildScrollView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(mockNotifier.carregarCalled, isTrue);
    });
  });
}
