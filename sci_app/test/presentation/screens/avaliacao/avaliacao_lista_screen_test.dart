import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/providers/avaliacoes_provider.dart';
import 'package:sci_app/providers/campos_provider.dart';
import 'package:sci_app/data/models/avaliacao_model.dart';
import 'package:sci_app/presentation/screens/avaliacao/avaliacao_lista_screen.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAvaliacoesNotifier extends AvaliacoesNotifier {
  final List<AvaliacaoModel> _list;
  MockAvaliacoesNotifier(this._list);

  @override
  Future<List<AvaliacaoModel>> build() async => _list;
}

void main() {
  late MockSupabaseClient mockSupabase;

  setUp(() {
    mockSupabase = MockSupabaseClient();
  });

  group('AvaliacaoListaScreen - Filtro por Campo de Estágio (Ator 4 DoD)', () {
    final mockCampos = [
      CampoEstagio(
        id: 'campo_1',
        nome: 'Hospital Central',
        endereco: 'Rua A',
        ativo: true,
        raioMetros: 150,
        lat: 0,
        lng: 0,
      ),
      CampoEstagio(
        id: 'campo_2',
        nome: 'UPA Zonal',
        endereco: 'Rua B',
        ativo: true,
        raioMetros: 150,
        lat: 0,
        lng: 0,
      ),
    ];

    final mockAvaliacoes = [
      AvaliacaoModel(
        id: 'av_1',
        alocacaoId: 'aloc_1',
        tipo: 'setorial',
        periodoReferencia: DateTime(2026, 2, 1),
        status: 'submetida',
        avaliadorId: 'prof_1',
        alunoNome: 'Carlos Eduardo',
        campoNome: 'Hospital Central',
        campoId: 'campo_1',
      ),
      AvaliacaoModel(
        id: 'av_2',
        alocacaoId: 'aloc_2',
        tipo: 'do_interno',
        periodoReferencia: DateTime(2026, 2, 1),
        status: 'submetida',
        avaliadorId: 'prof_1',
        alunoNome: 'Mariana Souza',
        campoNome: 'UPA Zonal',
        campoId: 'campo_2',
      ),
    ];

    testWidgets('1. Filtro "Todos os campos" mostra todas as avaliações', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
            userProfileProvider.overrideWith((ref) async => 'coordenacao'),
            camposProvider.overrideWith((ref) {
              final n = CamposNotifier(ref);
              n.state = AsyncValue.data(mockCampos);
              return n;
            }),
            avaliacoesProvider.overrideWith(() => MockAvaliacoesNotifier(mockAvaliacoes)),
          ],
          child: const MaterialApp(
            home: AvaliacaoListaScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Todos os campos'), findsOneWidget);
      expect(find.textContaining('Carlos Eduardo'), findsOneWidget);
      expect(find.textContaining('Mariana Souza'), findsOneWidget);
    });

    testWidgets('2. Selecionar campo específico reduz a lista corretamente', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
            userProfileProvider.overrideWith((ref) async => 'coordenacao'),
            camposProvider.overrideWith((ref) {
              final n = CamposNotifier(ref);
              n.state = AsyncValue.data(mockCampos);
              return n;
            }),
            avaliacoesProvider.overrideWith(() => MockAvaliacoesNotifier(mockAvaliacoes)),
          ],
          child: const MaterialApp(
            home: AvaliacaoListaScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Clica no dropdown de campos
      await tester.tap(find.text('Todos os campos'));
      await tester.pumpAndSettle();

      // Seleciona "Hospital Central"
      await tester.tap(find.text('Hospital Central').last);
      await tester.pumpAndSettle();

      // Deve mostrar apenas a avaliação do Hospital Central (Carlos Eduardo)
      expect(find.textContaining('Carlos Eduardo'), findsOneWidget);
      expect(find.textContaining('Mariana Souza'), findsNothing);
    });

    testWidgets('3. Campo sem nenhum resultado mostra empty state, não erro', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final camposComSemResultados = [
        ...mockCampos,
        CampoEstagio(
          id: 'campo_3',
          nome: 'Posto Sem Avaliações',
          endereco: 'Rua C',
          ativo: true,
          raioMetros: 150,
          lat: 0,
          lng: 0,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
            userProfileProvider.overrideWith((ref) async => 'coordenacao'),
            camposProvider.overrideWith((ref) {
              final n = CamposNotifier(ref);
              n.state = AsyncValue.data(camposComSemResultados);
              return n;
            }),
            avaliacoesProvider.overrideWith(() => MockAvaliacoesNotifier(mockAvaliacoes)),
          ],
          child: const MaterialApp(
            home: AvaliacaoListaScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Todos os campos'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Posto Sem Avaliações').last);
      await tester.pumpAndSettle();

      // Exibe mensagem de empty state sem estourar exceção
      expect(find.text('Nenhuma avaliação encontrada para o campo selecionado.'), findsOneWidget);
      expect(find.textContaining('Carlos Eduardo'), findsNothing);
      expect(find.textContaining('Mariana Souza'), findsNothing);
    });
  });
}
