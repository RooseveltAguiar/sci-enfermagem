import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sci_app/data/models/legislacao_model.dart';
import 'package:sci_app/presentation/screens/legislacao/legislacao_detalhe_screen.dart';
import 'package:sci_app/providers/auth_provider.dart';

void main() {
  testWidgets('LegislacaoDetalheScreen exibe dados e card de anexo quando presente',
      (WidgetTester tester) async {
    final docComAnexo = const LegislacaoModel(
      id: 'leg_pdf_1',
      titulo: 'Resolução COFEN 564/2017',
      conteudo: 'Conteúdo descritivo da resolução.',
      tipo: 'Resolução',
      ativo: true,
      arquivoNome: 'resolucao_cofen_564.pdf',
      arquivoBase64: 'JVBERi0xLjQK',
      arquivoTamanho: 1048576, // 1.0 MB
      arquivoExtensao: 'pdf',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) => 'aluno'),
        ],
        child: MaterialApp(
          home: LegislacaoDetalheScreen(doc: docComAnexo),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Resolução COFEN 564/2017'), findsOneWidget);
    expect(find.text('Conteúdo descritivo da resolução.'), findsOneWidget);
    expect(find.text('resolucao_cofen_564.pdf'), findsOneWidget);
    expect(find.text('Baixar / Visualizar Documento'), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
  });

  testWidgets('LegislacaoDetalheScreen exibe apenas texto quando não há anexo',
      (WidgetTester tester) async {
    final docSemAnexo = const LegislacaoModel(
      id: 'leg_txt_1',
      titulo: 'Portaria Interna 001',
      conteudo: 'Regras de conduta nos campos clínicos.',
      tipo: 'Portaria',
      ativo: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) => 'professor'),
        ],
        child: MaterialApp(
          home: LegislacaoDetalheScreen(doc: docSemAnexo),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Portaria Interna 001'), findsOneWidget);
    expect(find.text('Regras de conduta nos campos clínicos.'), findsOneWidget);
    expect(find.text('Baixar / Visualizar Documento'), findsNothing);
    expect(find.byIcon(Icons.edit), findsOneWidget); // Professor pode editar
  });
}
