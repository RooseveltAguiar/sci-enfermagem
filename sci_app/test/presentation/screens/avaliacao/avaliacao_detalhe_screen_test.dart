import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/data/models/avaliacao_model.dart';
import 'package:sci_app/presentation/screens/avaliacao/avaliacao_detalhe_screen.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/providers/avaliacoes_provider.dart';

void main() {
  final avaliacaoSetorial = AvaliacaoModel(
    id: 'av-1',
    alocacaoId: 'aloc-1',
    avaliadorId: 'prof-1',
    avaliadorNome: 'Prof. Carlos',
    tipo: 'setorial',
    periodoReferencia: DateTime(2026, 7, 1),
    status: 'aprovada',
    notaGeral: 9,
    pontosPositivos: 'Ótima proatividade',
    pontosMelhoria: 'Melhorar pontualidade',
    comentarioLivre: 'Excelente aluno no estágio',
    comentarioValidacao: 'Validado pela coordenação sem ressalvas',
  );

  final avaliacaoInternoRascunho = AvaliacaoModel(
    id: 'av-2',
    alocacaoId: 'aloc-2',
    avaliadorId: 'prof-1',
    tipo: 'do_interno',
    periodoReferencia: DateTime(2026, 6, 1),
    status: 'rascunho',
    pontosPositivos: 'Bom desempenho',
    pontosMelhoria: 'Mais atenção',
  );

  final avaliacaoAuto = AvaliacaoModel(
    id: 'av-3',
    alocacaoId: 'aloc-3',
    avaliadorId: 'aluno-1',
    tipo: 'autoavaliacao',
    periodoReferencia: DateTime(2026, 5, 1),
    status: 'submetida',
  );

  Widget createSubject({
    required String avaliacaoId,
    bool modoValidacao = false,
    required AsyncValue<List<AvaliacaoModel>> avaliacoesState,
    String? profileState = 'professor',
  }) {
    return ProviderScope(
      overrides: [
        avaliacoesProvider.overrideWith(() => _FakeAvaliacoesNotifier(avaliacoesState)),
        userProfileProvider.overrideWith((ref) => profileState),
      ],
      child: MaterialApp(
        home: AvaliacaoDetalheScreen(
          avaliacaoId: avaliacaoId,
          modoValidacao: modoValidacao,
        ),
      ),
    );
  }

  group('AvaliacaoDetalheScreen Widget Tests', () {
    testWidgets('exibe CircularProgressIndicator quando avaliacoesProvider está em loading', (tester) async {
      await tester.pumpWidget(createSubject(
        avaliacaoId: 'av-1',
        avaliacoesState: const AsyncValue.loading(),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('exibe mensagem de erro quando avaliacoesProvider falha', (tester) async {
      await tester.pumpWidget(createSubject(
        avaliacaoId: 'av-1',
        avaliacoesState: AsyncValue.error(Exception('Falha na rede'), StackTrace.empty),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Falha na rede'), findsOneWidget);
    });

    testWidgets('exibe mensagem quando avaliação não é encontrada na lista', (tester) async {
      await tester.pumpWidget(createSubject(
        avaliacaoId: 'inexistente',
        avaliacoesState: AsyncValue.data([avaliacaoSetorial]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Avaliação não encontrada.'), findsOneWidget);
    });

    testWidgets('exibe tela de bloqueio quando aluno tenta ver avaliação do_interno não aprovada', (tester) async {
      await tester.pumpWidget(createSubject(
        avaliacaoId: 'av-2',
        profileState: 'aluno',
        avaliacoesState: AsyncValue.data([avaliacaoInternoRascunho]),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Conteúdo disponível após aprovação da coordenação.'), findsOneWidget);
    });

    testWidgets('exibe todos os campos, nota, comentários, avaliador e timeline de avaliação aprovada', (tester) async {
      await tester.pumpWidget(createSubject(
        avaliacaoId: 'av-1',
        profileState: 'coordenacao',
        avaliacoesState: AsyncValue.data([avaliacaoSetorial]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Avaliação Setorial'), findsOneWidget);
      expect(find.textContaining('Julho de 2026'), findsOneWidget);
      expect(find.text('Avaliador: Prof. Carlos'), findsOneWidget);
      expect(find.text('Pontos Positivos'), findsOneWidget);
      expect(find.text('Ótima proatividade'), findsOneWidget);
      expect(find.text('Pontos a Melhorar'), findsOneWidget);
      expect(find.text('Melhorar pontualidade'), findsOneWidget);
      expect(find.text('Comentário Livre'), findsOneWidget);
      expect(find.text('Excelente aluno no estágio'), findsOneWidget);
      expect(find.text('Comentário da Coordenação'), findsOneWidget);
      expect(find.text('Validado pela coordenação sem ressalvas'), findsOneWidget);
    });

    testWidgets('exibe rótulo correto para autoavaliação e avaliação do interno', (tester) async {
      await tester.pumpWidget(createSubject(
        avaliacaoId: 'av-3',
        profileState: 'professor',
        avaliacoesState: AsyncValue.data([avaliacaoAuto, avaliacaoInternoRascunho]),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Autoavaliação'), findsOneWidget);

      await tester.pumpWidget(createSubject(
        avaliacaoId: 'av-2',
        profileState: 'professor',
        avaliacoesState: AsyncValue.data([avaliacaoAuto, avaliacaoInternoRascunho]),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Avaliação do Interno'), findsOneWidget);
    });
  });
}

class _FakeAvaliacoesNotifier extends AvaliacoesNotifier {
  final AsyncValue<List<AvaliacaoModel>> _initialState;
  _FakeAvaliacoesNotifier(this._initialState);

  @override
  Future<List<AvaliacaoModel>> build() async {
    if (_initialState.hasError) {
      throw _initialState.error!;
    }
    if (_initialState.isLoading) {
      return Completer<List<AvaliacaoModel>>().future;
    }
    return _initialState.value ?? [];
  }
}
