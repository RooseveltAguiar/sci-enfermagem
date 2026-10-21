import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/presentation/screens/aluno/dossie_aluno_screen.dart';
import 'package:sci_app/providers/dossie_provider.dart';
import 'package:sci_app/providers/banco_horas_provider.dart';
import 'package:sci_app/data/models/conflito_model.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late MockSupabaseClient mockSupabase;

  setUp(() {
    mockSupabase = MockSupabaseClient();
  });

  group('DossieAlunoScreen Widget Tests (Sprint 13 DoD)', () {
    testWidgets('exibe as 5 seções do dossiê corretamente em tela quando os dados são carregados', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyDossie = DossieAlunoData(
        alunoId: 'aluno_test_1',
        nome: 'Lucas Santos Silveira',
        cpf: '12345678901',
        status: 'Ativo',
        campoAtual: 'Hospital Maternidade Escola',
        turnoAtual: 'Manhã',
        resumoAcademico: const ResumoAcademicoData(
          percentualFrequencia: 96.5,
          atividadesRegistradas: 15,
          atividadesValidadas: 14,
          notaMediaDoInterno: 9.5,
          notaAutoavaliacao: 9.0,
          termosAceitos: true,
        ),
        bancoHoras: const BancoHorasAluno(
          alunoId: 'aluno_test_1',
          saldoMinutos: 180,
          saldoHoras: 3.0,
          isCredito: true,
          isDeficit: false,
        ),
        historicoAlocacoes: [
          AlocacaoHistoricoItem(
            id: 'h1',
            campoNome: 'Hospital Maternidade Escola',
            turnoTipo: 'Manhã',
            dataInicio: DateTime(2026, 1, 15),
            isVigente: true,
          ),
        ],
        ocorrencias: [
          ConflitoModel(
            id: 'c1',
            alunoId: 'aluno_test_1',
            campoId: 'campo_1',
            campoNome: 'Hospital Maternidade Escola',
            descricao: 'Falta justificada com atestado',
            dataOcorrencia: DateTime(2026, 2, 10),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
            dossieAlunoProvider.overrideWith((ref, param) async => dummyDossie),
          ],
          child: const MaterialApp(
            home: DossieAlunoScreen(alunoId: 'aluno_test_1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Cabeçalho
      expect(find.text('Lucas Santos Silveira'), findsOneWidget);
      expect(find.text('CPF: ***.***.*89-01'), findsOneWidget);
      expect(find.text('Ativo'), findsOneWidget);
      expect(find.text('Hospital Maternidade Escola'), findsNWidgets(2));

      // 2. Resumo Acadêmico
      expect(find.text('Resumo Acadêmico'), findsOneWidget);
      expect(find.text('96.5%'), findsOneWidget);
      expect(find.text('14/15'), findsOneWidget);
      expect(find.text('9.5'), findsOneWidget);
      expect(find.text('Termos de Estágio Aceitos'), findsOneWidget);

      // 3. Banco de Horas
      expect(find.text('Crédito Disponível'), findsOneWidget);
      expect(find.text('+3.0h 0min'), findsOneWidget);

      // 4. Histórico de Alocações
      expect(find.text('Histórico de Alocações'), findsOneWidget);
      expect(find.text('Vigente'), findsOneWidget);

      // 5. Ocorrências / Conflitos
      expect(find.text('Ocorrências e Registros'), findsOneWidget);
      expect(find.text('Falta justificada com atestado'), findsOneWidget);
    });

    testWidgets('exibe "Sem avaliação no período" quando notas são nulas', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyDossie = DossieAlunoData(
        alunoId: 'aluno_test_2',
        nome: 'Amanda Lima',
        cpf: '98765432100',
        status: 'Ativo',
        campoAtual: 'Posto de Saúde Central',
        turnoAtual: 'Tarde',
        resumoAcademico: const ResumoAcademicoData(
          percentualFrequencia: 100.0,
          atividadesRegistradas: 0,
          atividadesValidadas: 0,
          notaMediaDoInterno: null,
          notaAutoavaliacao: null,
          termosAceitos: true,
        ),
        bancoHoras: const BancoHorasAluno(
          alunoId: 'aluno_test_2',
          saldoMinutos: 0,
          saldoHoras: 0.0,
          isCredito: false,
          isDeficit: false,
        ),
        historicoAlocacoes: [],
        ocorrencias: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
            dossieAlunoProvider.overrideWith((ref, param) async => dummyDossie),
          ],
          child: const MaterialApp(
            home: DossieAlunoScreen(alunoId: 'aluno_test_2'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sem avaliação no período'), findsNWidgets(2));
      expect(find.text('Nenhuma ocorrência registrada.'), findsOneWidget);
    });

    testWidgets('exibe tela de erro amigável quando bloqueado por RLS', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
            dossieAlunoProvider.overrideWith((ref, param) async {
              throw Exception('Você não possui permissão (RLS) para visualizar as informações deste aluno.');
            }),
          ],
          child: const MaterialApp(
            home: DossieAlunoScreen(alunoId: 'aluno_bloqueado'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Acesso Não Autorizado ao Dossiê'), findsOneWidget);
      expect(find.textContaining('Você não possui permissão (RLS)'), findsOneWidget);
    });
  });
}
