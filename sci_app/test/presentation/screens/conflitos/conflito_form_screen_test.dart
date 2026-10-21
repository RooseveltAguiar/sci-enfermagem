// test/presentation/screens/conflitos/conflito_form_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sci_app/data/models/conflito_model.dart';
import 'package:sci_app/presentation/screens/conflitos/conflito_form_screen.dart';
import 'package:sci_app/providers/campos_provider.dart';
import 'package:sci_app/providers/conflitos_provider.dart';
import 'package:sci_app/presentation/screens/transferencia/transferencia_screen.dart';

class MockCamposNotifier extends StateNotifier<AsyncValue<List<CampoEstagio>>>
    implements CamposNotifier {
  MockCamposNotifier(super.initial);

  @override
  Future<void> loadCampos() async {}

  @override
  Future<void> loadCamposDoAluno() async {}

  @override
  Ref get ref => throw UnimplementedError();
}

class MockConflitosController
    extends StateNotifier<AsyncValue<List<ConflitoModel>>>
    implements ConflitosController {
  MockConflitosController() : super(const AsyncValue.data([]));

  int registrarCalled = 0;
  bool shouldThrow = false;

  @override
  Future<void> carregarConflitos({
    String? campoId,
    DateTime? dataInicio,
    DateTime? dataFim,
  }) async {}

  @override
  Future<void> registrarConflito({
    required String alunoId,
    required String campoId,
    required String descricao,
    required DateTime dataOcorrencia,
  }) async {
    if (shouldThrow) throw Exception('Falha ao registrar ocorrência');
    registrarCalled++;
  }

  Ref get ref => throw UnimplementedError();
}

void main() {
  final alunoMock = const AlunoTransferenciaItem(
    id: 'aln_1',
    nome: 'Aluno Teste',
    campoAtual: 'Hospital A',
    turnoAtual: 'Manhã',
  );
  final campoMock = CampoEstagio(
    id: 'cmp_1',
    nome: 'Hospital A',
    endereco: 'Rua 1',
    ativo: true,
    raioMetros: 150,
    lat: 0,
    lng: 0,
  );

  testWidgets(
      'ConflitoFormScreen valida mínimo de 30 caracteres na descrição e seleção de campos',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alunosParaTransferenciaProvider
              .overrideWith((ref) => Future.value([alunoMock])),
          camposProvider.overrideWith(
              (ref) => MockCamposNotifier(AsyncValue.data([campoMock]))),
        ],
        child: const MaterialApp(
          home: ConflitoFormScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final btnFinder = find.byKey(const Key('btn_registrar_conflito'));
    expect(btnFinder, findsOneWidget);

    ElevatedButton btn = tester.widget(btnFinder);
    expect(btn.onPressed, isNull);

    // Digita menos de 30 caracteres sem selecionar aluno e campo
    await tester.enterText(
        find.byKey(const Key('field_descricao_conflito')), 'Descrição curta.');
    await tester.pump();
    btn = tester.widget(btnFinder);
    expect(btn.onPressed, isNull);

    // Digita >= 30 caracteres sem selecionar aluno e campo
    await tester.enterText(find.byKey(const Key('field_descricao_conflito')),
        'Esta é uma descrição detalhada da ocorrência com mais de trinta caracteres.');
    await tester.pump();
    btn = tester.widget(btnFinder);
    expect(btn.onPressed, isNull);
  });

  testWidgets('ConflitoFormScreen fluxo completo de registro com sucesso (incluindo datepicker e bottom sheet)',
      (WidgetTester tester) async {
    final mockController = MockConflitosController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alunosParaTransferenciaProvider
              .overrideWith((ref) => Future.value([alunoMock])),
          camposProvider.overrideWith(
              (ref) => MockCamposNotifier(AsyncValue.data([campoMock]))),
          conflitosControllerProvider.overrideWith((ref) => mockController),
        ],
        child: const MaterialApp(
          home: ConflitoFormScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Seleciona aluno
    await tester.tap(find.byKey(const Key('dropdown_aluno_conflito')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aluno Teste (Hospital A)').last);
    await tester.pumpAndSettle();

    // Seleciona campo
    await tester.tap(find.byKey(const Key('dropdown_campo_conflito')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hospital A').last);
    await tester.pumpAndSettle();

    // Digita descrição de mais de 30 caracteres
    await tester.enterText(find.byKey(const Key('field_descricao_conflito')),
        'Relato completo da ocorrência com mais de trinta caracteres exigidos pela validação.');
    await tester.pump();

    // Abre date picker
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final btnFinder = find.byKey(const Key('btn_registrar_conflito'));
    await tester.ensureVisible(btnFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(btnFinder).onPressed, isNotNull);

    // Toca em Registrar Ocorrência
    await tester.tap(btnFinder);
    await tester.pumpAndSettle();

    // Verifica Bottom Sheet de confirmação
    expect(find.text('Registrar Ocorrência'), findsNWidgets(2));
    expect(find.text('Registrar'), findsOneWidget);

    // Confirma no Bottom Sheet
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();

    expect(mockController.registrarCalled, 1);
    expect(find.text('Ocorrência registrada com sucesso.'), findsOneWidget);
  });

  testWidgets('ConflitoFormScreen exibe erro quando registrarConflito falha',
      (WidgetTester tester) async {
    final mockController = MockConflitosController()..shouldThrow = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alunosParaTransferenciaProvider
              .overrideWith((ref) => Future.value([alunoMock])),
          camposProvider.overrideWith(
              (ref) => MockCamposNotifier(AsyncValue.data([campoMock]))),
          conflitosControllerProvider.overrideWith((ref) => mockController),
        ],
        child: const MaterialApp(
          home: ConflitoFormScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Seleciona aluno e campo e digita descrição válida
    await tester.tap(find.byKey(const Key('dropdown_aluno_conflito')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aluno Teste (Hospital A)').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dropdown_campo_conflito')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hospital A').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('field_descricao_conflito')),
        'Relato completo da ocorrência com mais de trinta caracteres exigidos pela validação.');
    await tester.pumpAndSettle();

    final btnFinder = find.byKey(const Key('btn_registrar_conflito'));
    await tester.ensureVisible(btnFinder);
    await tester.pumpAndSettle();
    await tester.tap(btnFinder);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Erro ao registrar ocorrência:'), findsOneWidget);
  });

  testWidgets('ConflitoFormScreen renderiza estados de erro dos providers de alunos e campos',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alunosParaTransferenciaProvider.overrideWith(
              (ref) => Future.error(Exception('Erro no provider de alunos'))),
          camposProvider.overrideWith((ref) => MockCamposNotifier(
              AsyncValue.error(Exception('Erro no provider de campos'), StackTrace.current))),
        ],
        child: const MaterialApp(
          home: ConflitoFormScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Erro ao carregar alunos:'), findsOneWidget);
    expect(find.textContaining('Erro ao carregar campos:'), findsOneWidget);
  });
}
