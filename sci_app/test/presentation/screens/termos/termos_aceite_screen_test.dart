// test/presentation/screens/termos/termos_aceite_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sci_app/data/models/termo_model.dart';
import 'package:sci_app/data/repositories/termos_repository.dart';
import 'package:sci_app/presentation/screens/termos/termos_aceite_screen.dart';
import 'package:sci_app/providers/termos_provider.dart';

class MockTermosRepository extends Mock implements TermosRepository {}
class MockRef extends Mock implements Ref<AsyncValue<List<TermoModel>>> {}

class MockTermosListaController extends TermosListaController {
  bool shouldThrow = false;
  int aceitarCalled = 0;
  String? lastVersaoAceita;

  MockTermosListaController() : super(MockTermosRepository(), MockRef());

  @override
  Future<void> aceitarTermo(String versao) async {
    aceitarCalled++;
    lastVersaoAceita = versao;
    if (shouldThrow) {
      throw Exception('Falha na API ao aceitar');
    }
  }
}

void main() {
  final termoMock = TermoModel(
    id: 'term_1',
    titulo: 'Termos Institucionais',
    versao: '2025.1',
    conteudo: 'Conteúdo obrigatório dos termos.',
    ativo: true,
  );

  group('TermosAceiteScreen', () {
    testWidgets('1. Desabilita botão de aceite até que checkbox seja marcado',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            termoAtivoProvider.overrideWith((ref) => Future.value(termoMock)),
          ],
          child: const MaterialApp(
            home: TermosAceiteScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Termos Institucionais'), findsWidgets);
      expect(find.text('Li e concordo com os termos acima'), findsOneWidget);

      final btnFinder = find.widgetWithText(ElevatedButton, 'Aceitar e continuar');
      expect(btnFinder, findsOneWidget);

      ElevatedButton btn = tester.widget(btnFinder);
      expect(btn.onPressed, isNull);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      btn = tester.widget(btnFinder);
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('2. Aceitar termo com sucesso chama aceitarTermo no controller',
        (WidgetTester tester) async {
      final mockController = MockTermosListaController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            termoAtivoProvider.overrideWith((ref) => Future.value(termoMock)),
            termosListaProvider.overrideWith((ref) => mockController),
          ],
          child: const MaterialApp(
            home: TermosAceiteScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Marca o checkbox
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      // Clica em aceitar
      await tester.tap(find.widgetWithText(ElevatedButton, 'Aceitar e continuar'));
      await tester.pump();

      expect(mockController.aceitarCalled, 1);
      expect(mockController.lastVersaoAceita, '2025.1');
    });

    testWidgets('3. Falha ao aceitar termo exibe SnackBar e reabilita botão',
        (WidgetTester tester) async {
      final mockController = MockTermosListaController()..shouldThrow = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            termoAtivoProvider.overrideWith((ref) => Future.value(termoMock)),
            termosListaProvider.overrideWith((ref) => mockController),
          ],
          child: const MaterialApp(
            home: TermosAceiteScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Aceitar e continuar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Erro ao aceitar termos: Exception: Falha na API ao aceitar'), findsOneWidget);

      // Botão deve continuar habilitado/reativado
      final btn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Aceitar e continuar'));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('4. Renderiza tela de termo nulo e permite clicar em Continuar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            termoAtivoProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: const MaterialApp(
            home: TermosAceiteScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nenhum termo ativo no momento.'), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    });

    testWidgets('5. Renderiza loading e error de termoAtivoProvider',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            termoAtivoProvider.overrideWith((ref) => Future.error('Falha de rede')),
          ],
          child: const MaterialApp(
            home: TermosAceiteScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Erro ao carregar termos: Falha de rede'), findsOneWidget);
    });
  });
}
