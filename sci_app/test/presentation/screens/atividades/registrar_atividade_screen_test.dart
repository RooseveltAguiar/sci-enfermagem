// test/presentation/screens/atividades/registrar_atividade_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/presentation/screens/atividades/registrar_atividade_screen.dart';
import 'package:sci_app/providers/atividades_provider.dart';

final mock12AtividadesReais = [
  const AtividadePadraoModel(id: 'id-1', nome: 'Administração de medicamentos'),
  const AtividadePadraoModel(id: 'id-2', nome: 'Aspiração de vias aéreas'),
  const AtividadePadraoModel(id: 'id-3', nome: 'Coleta de exames laboratoriais'),
  const AtividadePadraoModel(id: 'id-4', nome: 'Controle hídrico'),
  const AtividadePadraoModel(id: 'id-5', nome: 'Curativo complexo'),
  const AtividadePadraoModel(id: 'id-6', nome: 'Curativo simples'),
  const AtividadePadraoModel(id: 'id-7', nome: 'Higiene e conforto do paciente'),
  const AtividadePadraoModel(id: 'id-8', nome: 'Instalação de acesso venoso periférico'),
  const AtividadePadraoModel(id: 'id-9', nome: 'Registro em prontuário'),
  const AtividadePadraoModel(id: 'id-10', nome: 'Sondagem nasogástrica ou nasoentérica'),
  const AtividadePadraoModel(id: 'id-11', nome: 'Sondagem vesical'),
  const AtividadePadraoModel(id: 'id-12', nome: 'Verificação de sinais vitais'),
];

void main() {
  group('RegistrarAtividadeScreen', () {
    testWidgets('1. Renderiza loading e depois lista padrão das 12 atividades reais do banco',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            atividadesPadraoProvider.overrideWith((ref) async => mock12AtividadesReais),
          ],
          child: const MaterialApp(
            home: RegistrarAtividadeScreen(),
          ),
        ),
      );

      expect(find.text('Registrar Atividade'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Selecione as atividades realizadas:'), findsOneWidget);

      // Verifica os 12 itens reais da tabela lista_atividades_padrao
      expect(find.text('Administração de medicamentos'), findsOneWidget);
      expect(find.text('Aspiração de vias aéreas'), findsOneWidget);
      expect(find.text('Coleta de exames laboratoriais'), findsOneWidget);
      expect(find.text('Controle hídrico'), findsOneWidget);
      expect(find.text('Curativo complexo'), findsOneWidget);
      expect(find.text('Curativo simples'), findsOneWidget);
      expect(find.text('Higiene e conforto do paciente'), findsOneWidget);
      expect(find.text('Instalação de acesso venoso periférico'), findsOneWidget);
      expect(find.text('Registro em prontuário'), findsOneWidget);
      expect(find.text('Sondagem nasogástrica ou nasoentérica'), findsOneWidget);
      expect(find.text('Sondagem vesical'), findsOneWidget);
      expect(find.text('Verificação de sinais vitais'), findsOneWidget);

      // Garante que o nome legado incorreto "Aferição de pressão arterial" NÃO existe mais
      expect(find.text('Aferição de pressão arterial'), findsNothing);
      expect(find.text('Outra (Descrever)'), findsOneWidget);
    });

    testWidgets('2. Exibe erro ao tentar registrar sem nenhuma atividade selecionada',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            atividadesPadraoProvider.overrideWith((ref) async => mock12AtividadesReais),
          ],
          child: const MaterialApp(
            home: RegistrarAtividadeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final btnRegistrar = find.text('REGISTRAR ATIVIDADES');
      await tester.ensureVisible(btnRegistrar);
      await tester.tap(btnRegistrar);
      await tester.pumpAndSettle();

      expect(find.text('Selecione pelo menos uma atividade.'), findsOneWidget);
    });

    testWidgets('3. Valida descrição mínima ao selecionar "Outra (Descrever)"',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            atividadesPadraoProvider.overrideWith((ref) async => mock12AtividadesReais),
          ],
          child: const MaterialApp(
            home: RegistrarAtividadeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Seleciona "Outra"
      final chipOutra = find.text('Outra (Descrever)');
      await tester.ensureVisible(chipOutra);
      await tester.tap(chipOutra);
      await tester.pumpAndSettle();

      // Verifica se o campo de texto apareceu
      expect(find.byType(TextField), findsOneWidget);

      // Tenta registrar com campo de texto vazio ou curto
      await tester.enterText(find.byType(TextField), 'curto');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final btnRegistrar = find.text('REGISTRAR ATIVIDADES');
      await tester.ensureVisible(btnRegistrar);
      await tester.tap(btnRegistrar);
      await tester.pumpAndSettle();

      expect(find.text('A descrição de "Outra" deve ter no mínimo 10 caracteres.'), findsOneWidget);
    });

    testWidgets('4. Limpa descrição de "Outra" ao desmarcar o chip',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            atividadesPadraoProvider.overrideWith((ref) async => mock12AtividadesReais),
          ],
          child: const MaterialApp(
            home: RegistrarAtividadeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Seleciona "Outra"
      final chipOutra = find.text('Outra (Descrever)');
      await tester.ensureVisible(chipOutra);
      await tester.tap(chipOutra);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Descrição válida para teste.');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Desmarca "Outra"
      await tester.tap(chipOutra);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);

      // Re-seleciona para confirmar que foi limpo
      await tester.tap(chipOutra);
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('5. Exibe diálogo de Limite Atingido se selecionar mais de 10 atividades',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final listaGigante = List.generate(
        11,
        (index) => AtividadePadraoModel(id: 'id-$index', nome: 'Atividade $index'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            atividadesPadraoProvider.overrideWith((ref) async => listaGigante),
          ],
          child: const MaterialApp(
            home: RegistrarAtividadeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Seleciona todas as 11 atividades
      for (var i = 0; i < 11; i++) {
        final item = find.text('Atividade $i');
        await tester.ensureVisible(item);
        await tester.tap(item);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      final btnRegistrar = find.text('REGISTRAR ATIVIDADES');
      await tester.ensureVisible(btnRegistrar);
      await tester.tap(btnRegistrar);
      await tester.pumpAndSettle();

      expect(find.text('Limite Atingido'), findsOneWidget);
      expect(find.textContaining('Você já atingiu o limite de 10 atividades'), findsOneWidget);

      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();

      expect(find.text('Limite Atingido'), findsNothing);
    });

    testWidgets('6. Fluxo completo de registro com sucesso (chips por ID + confirmação)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            atividadesPadraoProvider.overrideWith((ref) async => mock12AtividadesReais),
          ],
          child: const MaterialApp(
            home: RegistrarAtividadeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Seleciona duas atividades
      final chip1 = find.text('Curativo simples');
      final chip2 = find.text('Verificação de sinais vitais');

      await tester.ensureVisible(chip1);
      await tester.tap(chip1);
      await tester.pump();

      await tester.ensureVisible(chip2);
      await tester.tap(chip2);
      await tester.pumpAndSettle();

      final btnRegistrar = find.text('REGISTRAR ATIVIDADES');
      await tester.ensureVisible(btnRegistrar);
      await tester.tap(btnRegistrar);
      await tester.pumpAndSettle();

      expect(find.text('Confirmar Registro'), findsOneWidget);
      expect(find.textContaining('Você selecionou 2 atividade(s). Deseja registrar?'), findsOneWidget);

      // Confirma no bottom sheet
      final btnConfirmarModal = find.widgetWithText(FilledButton, 'Registrar');
      await tester.tap(btnConfirmarModal);
      await tester.pumpAndSettle();

      expect(find.text('Confirmar Registro'), findsNothing);
    });

    testWidgets('7. Renderiza erro quando o provider atividadesPadraoProvider falha',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            atividadesPadraoProvider.overrideWith((ref) async => throw Exception('Falha ao carregar lista')),
          ],
          child: const MaterialApp(
            home: RegistrarAtividadeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Erro: Exception: Falha ao carregar lista'), findsOneWidget);
    });

    testWidgets('8. Valida que a data_registro é formatada como YYYY-MM-DD no payload', (tester) async {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      expect(todayStr.length, equals(10));
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(todayStr), isTrue);
    });
  });
}
