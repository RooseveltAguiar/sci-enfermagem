import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sci_app/data/models/avaliacao_model.dart';
import 'package:sci_app/presentation/screens/avaliacao/avaliacao_validar_screen.dart';
import 'package:sci_app/providers/avaliacoes_provider.dart';

class FakeAvaliacoesNotifier extends AvaliacoesNotifier {
  bool devolverCalled = false;
  bool validarCalled = false;
  bool aprovarCalled = false;
  String? capturedId;
  String? capturedComentario;

  @override
  Future<List<AvaliacaoModel>> build() async => [];

  @override
  Future<void> devolverAvaliacao(String id, String comentario) async {
    devolverCalled = true;
    capturedId = id;
    capturedComentario = comentario;
  }

  @override
  Future<void> validarAvaliacao(String id, {String? comentario}) async {
    validarCalled = true;
    capturedId = id;
    capturedComentario = comentario;
  }

  @override
  Future<void> aprovarAvaliacao(String id, {String? comentario}) async {
    aprovarCalled = true;
    capturedId = id;
    capturedComentario = comentario;
  }
}

void main() {
  group('AvaliacaoValidarScreen Widget Tests', () {
    testWidgets('1. Renderiza botões Validar, Aprovar e Devolver', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AvaliacaoValidarScreen(avaliacaoId: 'test-id-123'),
          ),
        ),
      );

      expect(find.text('Validar'), findsOneWidget);
      expect(find.text('Aprovar'), findsOneWidget);
      expect(find.text('Devolver'), findsOneWidget);
    });

    testWidgets('2. Devolver sem comentário (< 20 caracteres) exibe erro de validação', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AvaliacaoValidarScreen(avaliacaoId: 'test-id-123'),
          ),
        ),
      );

      await tester.tap(find.text('Devolver'));
      await tester.pumpAndSettle();

      // Tenta confirmar a devolução no modal sem digitar comentário
      final confirmarBtn = find.widgetWithText(FilledButton, 'Devolver');
      await tester.tap(confirmarBtn);
      await tester.pump();

      expect(find.text('Informe pelo menos 20 caracteres.'), findsOneWidget);
    });

    testWidgets('3. Devolver com comentário >= 20 caracteres -> modal fecha e ação é enviada ao provider', (tester) async {
      final fakeNotifier = FakeAvaliacoesNotifier();
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/validar',
            builder: (context, state) => const AvaliacaoValidarScreen(avaliacaoId: 'test-id-123'),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            avaliacoesProvider.overrideWith(() => fakeNotifier),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      router.push('/validar');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Devolver'));
      await tester.pumpAndSettle();

      const comentarioValido = 'Justificativa da devolução devidamente detalhada com mais de 20 caracteres';
      await tester.enterText(find.byType(TextField), comentarioValido);
      await tester.pump();

      final confirmarBtn = find.widgetWithText(FilledButton, 'Devolver');
      await tester.tap(confirmarBtn);
      await tester.pumpAndSettle();

      expect(find.text('Informe pelo menos 20 caracteres.'), findsNothing);
      expect(fakeNotifier.devolverCalled, isTrue);
      expect(fakeNotifier.capturedId, 'test-id-123');
      expect(fakeNotifier.capturedComentario, comentarioValido);
    });

    testWidgets('4. Clicar em Validar e confirmar chama validarAvaliacao',
        (tester) async {
      final fakeNotifier = FakeAvaliacoesNotifier();
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/validar',
            builder: (context, state) => const AvaliacaoValidarScreen(avaliacaoId: 'test-id-123'),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            avaliacoesProvider.overrideWith(() => fakeNotifier),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      router.push('/validar');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Validar'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Validar').last);
      await tester.pumpAndSettle();

      expect(fakeNotifier.validarCalled, true);
      expect(fakeNotifier.capturedId, 'test-id-123');
    });

    testWidgets('5. Clicar em Aprovar e confirmar chama aprovarAvaliacao',
        (tester) async {
      final fakeNotifier = FakeAvaliacoesNotifier();
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/validar',
            builder: (context, state) => const AvaliacaoValidarScreen(avaliacaoId: 'test-id-123'),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            avaliacoesProvider.overrideWith(() => fakeNotifier),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      router.push('/validar');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aprovar'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Aprovar').last);
      await tester.pumpAndSettle();

      expect(fakeNotifier.aprovarCalled, true);
      expect(fakeNotifier.capturedId, 'test-id-123');
    });
  });
}
