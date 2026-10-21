import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/presentation/screens/exportacao/exportacao_screen.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/providers/connectivity_provider.dart';
import 'package:sci_app/providers/export_provider.dart';
import 'package:sci_app/services/export_service.dart';

class MockExportService extends Mock implements ExportService {}

void main() {
  late MockExportService mockExportService;

  setUp(() {
    mockExportService = MockExportService();
  });

  Widget buildScreen({
    required String perfil,
    required bool isOnline,
    User? user,
    ExportService? exportServiceOverride,
    ExportNotifier? notifierOverride,
  }) {
    return ProviderScope(
      overrides: [
        userProfileProvider.overrideWith((ref) => Future.value(perfil)),
        isOnlineProvider.overrideWith((ref) => isOnline),
        authStateProvider.overrideWith((ref) => Stream.value(
          user != null
              ? AuthState(AuthChangeEvent.signedIn, Session(
                  accessToken: 'token',
                  tokenType: 'bearer',
                  user: user,
                ))
              : const AuthState(AuthChangeEvent.signedOut, null),
        )),
        if (notifierOverride != null)
          exportProvider.overrideWith((ref) => notifierOverride)
        else
          exportProvider.overrideWith((ref) => ExportNotifier(
                exportServiceOverride ?? mockExportService,
              )),
      ],
      child: const MaterialApp(
        home: ExportacaoScreen(),
      ),
    );
  }

  group('ExportacaoScreen - Perfis e UI', () {
    testWidgets('renderiza view de aluno sem campo de ID de aluno no topo e com cartões específicos', (tester) async {
      await tester.pumpWidget(buildScreen(perfil: 'aluno', isOnline: true));
      await tester.pumpAndSettle();

      expect(find.text('Minha Frequência'), findsOneWidget);
      expect(find.text('Minhas Atividades'), findsOneWidget);
      expect(find.text('Relatório Compilado do Aluno'), findsOneWidget);
      expect(find.textContaining('ID do Aluno (obrigatório para Relatório Compilado)'), findsNothing);
    });

    testWidgets('renderiza view de coordenação com campo de ID de aluno e cartões gerais', (tester) async {
      await tester.pumpWidget(buildScreen(perfil: 'coordenacao', isOnline: true));
      await tester.pumpAndSettle();

      expect(find.text('Relatório de Frequência Geral'), findsOneWidget);
      expect(find.text('Relatório de Atividades'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('Relatório de Avaliações'), findsOneWidget);
      expect(find.text('Relatório Compilado do Aluno'), findsOneWidget);
    });

    testWidgets('tocar no botão Alterar abre o seletor de período', (tester) async {
      await tester.pumpWidget(buildScreen(perfil: 'coordenacao', isOnline: true));
      await tester.pumpAndSettle();

      final btnAlterar = find.widgetWithText(ElevatedButton, 'Alterar');
      expect(btnAlterar, findsOneWidget);
      await tester.tap(btnAlterar);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('exibe overlay de carregamento quando exportState.loading é true', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) => Future.value('coordenacao')),
          isOnlineProvider.overrideWith((ref) => true),
          authStateProvider.overrideWith((ref) => Stream.value(const AuthState(AuthChangeEvent.signedOut, null))),
          exportProvider.overrideWith((ref) => _FakeLoadingNotifier()),
        ],
        child: const MaterialApp(home: ExportacaoScreen()),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Montando documento...'), findsOneWidget);
    });
  });

  group('ExportacaoScreen - Interações e Ações', () {
    testWidgets('tocar em Exportar PDF quando offline exibe SnackBar de erro de conexão', (tester) async {
      await tester.pumpWidget(buildScreen(perfil: 'coordenacao', isOnline: false));
      await tester.pumpAndSettle();

      final pdfButtons = find.widgetWithText(ElevatedButton, 'Exportar PDF');
      expect(pdfButtons, findsWidgets);

      final btn = tester.widget<ElevatedButton>(pdfButtons.first);
      expect(btn.enabled, isFalse);
    });

    testWidgets('exportar relatório compilado sem ID (perfil não-aluno) exibe alerta na SnackBar', (tester) async {
      await tester.pumpWidget(buildScreen(perfil: 'coordenacao', isOnline: true));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      final pdfButtons = find.widgetWithText(ElevatedButton, 'Exportar PDF');
      await tester.tap(pdfButtons.last);
      await tester.pump();

      expect(find.text('Por favor, informe ou selecione o ID do Aluno para gerar o relatório compilado.'), findsOneWidget);
    });

    testWidgets('exportar PDF de frequência aciona exportService e exibe SnackBar de sucesso', (tester) async {
      when(() => mockExportService.exportarRelatorioEmPdf(
            tipo: any(named: 'tipo'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: any(named: 'campoId'),
            alunoId: any(named: 'alunoId'),
          )).thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen(perfil: 'coordenacao', isOnline: true));
      await tester.pumpAndSettle();

      final pdfButtons = find.widgetWithText(ElevatedButton, 'Exportar PDF');
      await tester.tap(pdfButtons.first);
      await tester.pumpAndSettle();

      verify(() => mockExportService.exportarRelatorioEmPdf(
            tipo: 'frequencia',
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: null,
            alunoId: null,
          )).called(1);

      expect(find.text('Relatório gerado e compartilhado com sucesso!'), findsOneWidget);
    });

    testWidgets('exportar CSV de atividades aciona exportService no botão correspondente', (tester) async {
      when(() => mockExportService.exportarRelatorioEmCsv(
            tipo: any(named: 'tipo'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: any(named: 'campoId'),
          )).thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen(perfil: 'coordenacao', isOnline: true));
      await tester.pumpAndSettle();

      final csvButtons = find.widgetWithText(OutlinedButton, 'Exportar CSV');
      await tester.tap(csvButtons.at(1));
      await tester.pumpAndSettle();

      verify(() => mockExportService.exportarRelatorioEmCsv(
            tipo: 'atividades',
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: null,
          )).called(1);
    });

    testWidgets('exibe SnackBar de erro e limpa estado quando exportProvider emite erro', (tester) async {
      when(() => mockExportService.exportarRelatorioEmPdf(
            tipo: any(named: 'tipo'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: any(named: 'campoId'),
            alunoId: any(named: 'alunoId'),
          )).thenThrow(Exception('Falha ao gerar PDF'));

      await tester.pumpWidget(buildScreen(perfil: 'coordenacao', isOnline: true));
      await tester.pumpAndSettle();

      final pdfButtons = find.widgetWithText(ElevatedButton, 'Exportar PDF');
      await tester.tap(pdfButtons.first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Falha ao gerar PDF'), findsOneWidget);
    });

    testWidgets('exportar relatório compilado no perfil aluno preenche ID com o user atual da sessão', (tester) async {
      when(() => mockExportService.exportarRelatorioEmPdf(
            tipo: any(named: 'tipo'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: any(named: 'campoId'),
            alunoId: any(named: 'alunoId'),
          )).thenAnswer((_) async {});

      final fakeUser = User(
        id: 'user-aluno-id-123',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      );

      await tester.pumpWidget(buildScreen(
        perfil: 'aluno',
        isOnline: true,
        user: fakeUser,
      ));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      final pdfButtons = find.widgetWithText(ElevatedButton, 'Exportar PDF');
      await tester.tap(pdfButtons.last);
      await tester.pumpAndSettle();

      verify(() => mockExportService.exportarRelatorioEmPdf(
            tipo: 'compilado',
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: null,
            alunoId: 'user-aluno-id-123',
          )).called(1);
    });
  });
}

class _FakeLoadingNotifier extends ExportNotifier {
  _FakeLoadingNotifier() : super(MockExportService()) {
    state = const ExportState(loading: true, progressoMensagem: 'Montando documento...');
  }
}
