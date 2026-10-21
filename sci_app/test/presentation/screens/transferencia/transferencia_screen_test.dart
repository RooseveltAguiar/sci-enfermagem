import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sci_app/presentation/screens/transferencia/transferencia_screen.dart';
import 'package:sci_app/providers/campos_provider.dart';
import 'package:sci_app/providers/transferencia_provider.dart';

class MockCamposNotifier
    extends StateNotifier<AsyncValue<List<CampoEstagio>>>
    implements CamposNotifier {
  MockCamposNotifier(List<CampoEstagio> campos)
      : super(AsyncValue.data(campos));

  MockCamposNotifier.loading() : super(const AsyncValue.loading());

  @override
  Future<void> loadCampos() async {}

  @override
  Future<void> loadCamposDoAluno() async {}

  @override
  Ref get ref => throw UnimplementedError();
}

class MockTransferenciaNotifier extends StateNotifier<TransferenciaState>
    implements TransferenciaController {
  bool transferirCalled = false;
  bool shouldThrow = false;
  String? capturedAlunoId;
  String? capturedCampoId;
  String? capturedTurnoId;

  MockTransferenciaNotifier() : super(const TransferenciaState());

  @override
  Future<void> transferirAluno({
    required String alunoId,
    required String campoDestinoId,
    required String turnoDestinoId,
  }) async {
    transferirCalled = true;
    capturedAlunoId = alunoId;
    capturedCampoId = campoDestinoId;
    capturedTurnoId = turnoDestinoId;
    if (shouldThrow) {
      throw Exception('Vagas esgotadas no turno de destino');
    }
  }
}

void main() {
  group('AlunoTransferenciaItem & TurnoItem Models', () {
    test('AlunoTransferenciaItem.fromJson converte com alocação ativa', () {
      final json = {
        'id': 'aluno-1',
        'nome': 'João Aluno',
        'alocacoes_alunos': [
          {
            'campos_estagio': {'nome': 'Hospital Central'},
            'turnos': {'descricao': 'Manhã'},
          }
        ],
      };
      final item = AlunoTransferenciaItem.fromJson(json);
      expect(item.id, 'aluno-1');
      expect(item.nome, 'João Aluno');
      expect(item.campoAtual, 'Hospital Central');
      expect(item.turnoAtual, 'Manhã');
    });

    test('AlunoTransferenciaItem.fromJson converte sem alocação (Não alocado)', () {
      final json = {
        'id': 'aluno-2',
        'alocacoes_alunos': [],
      };
      final item = AlunoTransferenciaItem.fromJson(json);
      expect(item.id, 'aluno-2');
      expect(item.nome, 'Sem nome');
      expect(item.campoAtual, 'Não alocado');
      expect(item.turnoAtual, '-');
    });

    test('TurnoItem.fromJson converte campos com valores padrão se nulos', () {
      final json = {
        'id': 'turno-1',
        'tipo': 'Noite',
        'hora_inicio': '19:00',
        'hora_fim': '23:00',
        'ativo': true,
      };
      final item = TurnoItem.fromJson(json);
      expect(item.id, 'turno-1');
      expect(item.tipo, 'Noite');
      expect(item.horaInicio, '19:00');
      expect(item.horaFim, '23:00');
      expect(item.ativo, isTrue);

      final itemPadrao = TurnoItem.fromJson({'id': 'turno-2'});
      expect(itemPadrao.tipo, 'Turno');
      expect(itemPadrao.ativo, isTrue);
    });
  });

  group('TransferenciaScreen Widget Tests', () {
    final aluno1 = const AlunoTransferenciaItem(
      id: 'aln_1',
      nome: 'Maria Aluna',
      campoAtual: 'Hospital B',
      turnoAtual: 'Tarde',
    );

    final campo1 = CampoEstagio(
      id: 'campo_1',
      nome: 'Hospital Geral de Destino',
      endereco: 'Rua A, 123',
      ativo: true,
      raioMetros: 150.0,
      lat: -3.71,
      lng: -38.54,
    );

    final campoInativo = CampoEstagio(
      id: 'campo_inativo',
      nome: 'Hospital Fechado',
      endereco: 'Rua B, 456',
      ativo: false,
      raioMetros: 150.0,
      lat: -3.71,
      lng: -38.54,
    );

    final turno1 = const TurnoItem(
      id: 'turno_1',
      tipo: 'Turno Matutino',
      horaInicio: '07:00',
      horaFim: '13:00',
      ativo: true,
    );

    testWidgets('1. Inicia com botão Confirmar Transferência desabilitado', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alunosParaTransferenciaProvider.overrideWith((ref) => Future.value([aluno1])),
            camposProvider.overrideWith((ref) => MockCamposNotifier([])),
          ],
          child: const MaterialApp(home: TransferenciaScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transferência de Aluno'), findsOneWidget);
      final btnFinder = find.byKey(const Key('btn_transferir'));
      expect(tester.widget<ElevatedButton>(btnFinder).onPressed, isNull);
    });

    testWidgets('2. Exibe estados de loading para alunos e campos', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alunosParaTransferenciaProvider.overrideWith((ref) => Future<List<AlunoTransferenciaItem>>.delayed(const Duration(seconds: 10))),
            camposProvider.overrideWith((ref) => MockCamposNotifier.loading()),
          ],
          child: const MaterialApp(home: TransferenciaScreen()),
        ),
      );
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('3. Exibe mensagens de erro quando providers falham', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alunosParaTransferenciaProvider.overrideWith((ref) => Future.error('Falha na consulta do Supabase')),
            camposProvider.overrideWith((ref) => MockCamposNotifier([])),
          ],
          child: const MaterialApp(home: TransferenciaScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Erro ao listar alunos: Falha na consulta do Supabase'), findsOneWidget);
    });

    testWidgets('4. Fluxo completo: Seleção de Aluno, Campo e Turno + Transferência com Sucesso', (tester) async {
      final mockNotifier = MockTransferenciaNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alunosParaTransferenciaProvider.overrideWith((ref) => Future.value([aluno1])),
            camposProvider.overrideWith((ref) => MockCamposNotifier([campo1, campoInativo])),
            turnosDoCampoProvider('campo_1').overrideWith((ref) => Future.value([turno1])),
            transferenciaControllerProvider.overrideWith((ref) => mockNotifier),
          ],
          child: const MaterialApp(home: TransferenciaScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica que campo inativo foi filtrado
      expect(find.text('Selecione um campo de destino primeiro para carregar os turnos.'), findsOneWidget);

      // 1. Selecionar Aluno no Dropdown
      await tester.tap(find.byKey(const Key('dropdown_aluno')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maria Aluna — Hospital B (Tarde)').last);
      await tester.pumpAndSettle();

      // 2. Selecionar Campo de Destino no Dropdown
      await tester.tap(find.byKey(const Key('dropdown_campo_destino')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hospital Geral de Destino').last);
      await tester.pumpAndSettle();

      // 3. Selecionar Turno de Destino no Dropdown
      await tester.tap(find.byKey(const Key('dropdown_turno_destino')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turno Matutino (07:00 - 13:00)').last);
      await tester.pumpAndSettle();

      // 4. Botão de transferência agora deve estar habilitado
      final btnFinder = find.byKey(const Key('btn_transferir'));
      expect(tester.widget<ElevatedButton>(btnFinder).onPressed, isNotNull);

      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      // Verifica o ConfirmationBottomSheet
      expect(find.text('Confirmar Transferência'), findsOneWidget);
      expect(find.textContaining('O histórico de frequência e atividades do campo anterior será preservado'), findsOneWidget);

      // Confirma no modal (usa FilledButton no ConfirmationBottomSheet)
      await tester.tap(find.widgetWithText(FilledButton, 'Transferir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(mockNotifier.transferirCalled, isTrue);
      expect(mockNotifier.capturedAlunoId, 'aln_1');
      expect(mockNotifier.capturedCampoId, 'campo_1');
      expect(mockNotifier.capturedTurnoId, 'turno_1');
      expect(find.text('Aluno transferido com sucesso.'), findsOneWidget);
    });

    testWidgets('5. Exibe mensagem quando campo selecionado não possui turnos ativos', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alunosParaTransferenciaProvider.overrideWith((ref) => Future.value([aluno1])),
            camposProvider.overrideWith((ref) => MockCamposNotifier([campo1])),
            turnosDoCampoProvider('campo_1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(home: TransferenciaScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dropdown_campo_destino')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hospital Geral de Destino').last);
      await tester.pumpAndSettle();

      expect(find.text('Nenhum turno ativo cadastrado neste campo.'), findsOneWidget);
    });

    testWidgets('6. Exibe SnackBar de erro em caso de falha na transferência', (tester) async {
      final mockNotifier = MockTransferenciaNotifier()..shouldThrow = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alunosParaTransferenciaProvider.overrideWith((ref) => Future.value([aluno1])),
            camposProvider.overrideWith((ref) => MockCamposNotifier([campo1])),
            turnosDoCampoProvider('campo_1').overrideWith((ref) => Future.value([turno1])),
            transferenciaControllerProvider.overrideWith((ref) => mockNotifier),
          ],
          child: const MaterialApp(home: TransferenciaScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dropdown_aluno')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maria Aluna — Hospital B (Tarde)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dropdown_campo_destino')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hospital Geral de Destino').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dropdown_turno_destino')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turno Matutino (07:00 - 13:00)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_transferir')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Transferir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Vagas esgotadas no turno de destino'), findsOneWidget);
    });
  });
}
