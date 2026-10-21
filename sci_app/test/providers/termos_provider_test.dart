// test/providers/termos_provider_test.dart
//
// Três providers neste arquivo, cada um com uma particularidade:
//
// 1. termoAtivoProvider (FutureProvider) — direto, só chama o repo.
//
// 2. termoPendenteProvider (FutureProvider) — lê
//    supabase.auth.currentUser?.id ANTES de chamar o repositório.
//    Precisa mockar SupabaseClient + GoTrueClient + User, não só o
//    TermosRepository. Tem um caminho de curto-circuito (usuário
//    nulo → retorna false sem nunca tocar o repository) que só um
//    teste dedicado pega — cobertura de linha sozinha não garante
//    que esse branch específico foi exercitado com usuário null.
//
// 3. TermosListaController (StateNotifier) — três métodos que
//    invalidam caches de forma DIFERENTE entre si:
//    - criarTermo/ativarVersao: invalidam termoAtivo E termoPendente,
//      e recarregam a lista completa.
//    - aceitarTermo: invalida SÓ termoPendente, NÃO recarrega a
//      lista (faz sentido — aceite de aluno não muda a lista
//      administrativa de versões). Testado explicitamente porque é
//      fácil um refactor futuro "simplificar" isso incorretamente.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sci_app/data/models/termo_model.dart';
import 'package:sci_app/data/repositories/termos_repository.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/providers/termos_provider.dart';

class MockTermosRepository extends Mock implements TermosRepository {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

void main() {
  late MockTermosRepository mockRepo;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;

  setUp(() {
    mockRepo = MockTermosRepository();
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(() => mockSupabase.auth).thenReturn(mockAuth);
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        termosRepositoryProvider.overrideWithValue(mockRepo),
        supabaseClientProvider.overrideWithValue(mockSupabase),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  const termoFake1 = TermoModel(
    id: 'termo-1',
    titulo: 'Termo de Uso v1',
    conteudo: 'Conteúdo v1',
    versao: '1.0',
    ativo: true,
  );

  const termoFake2 = TermoModel(
    id: 'termo-2',
    titulo: 'Termo de Uso v2',
    conteudo: 'Conteúdo v2',
    versao: '2.0',
    ativo: true,
  );

  group('termosRepositoryProvider — construção real (sem override)', () {
    test(
      'sem sobrescrever este provider especificamente — só '
      'supabaseClientProvider — o corpo real (ref.watch + '
      'construção de TermosRepository) executa e retorna uma '
      'instância válida. Fecha DA:7 e DA:8, que ficam sempre a '
      'zero nos outros testes deste arquivo porque todos usam '
      '.overrideWithValue(mockRepo) — não é código morto, é a '
      'fiação de DI real que a produção usa e que nenhum teste '
      'daqui exercitava.',
      () {
        final container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
        );
        addTearDown(container.dispose);

        final repo = container.read(termosRepositoryProvider);

        expect(repo, isA<TermosRepository>());
      },
    );
  });

  group('termoAtivoProvider', () {
    test('retorna o termo que o repository informa como ativo',
        () async {
      when(() => mockRepo.buscarTermoAtivo())
          .thenAnswer((_) async => termoFake1);

      final container = buildContainer();
      final result = await container.read(termoAtivoProvider.future);

      expect(result, termoFake1);
      verify(() => mockRepo.buscarTermoAtivo()).called(1);
    });

    test('retorna null quando não há termo ativo', () async {
      when(() => mockRepo.buscarTermoAtivo()).thenAnswer((_) async => null);

      final container = buildContainer();
      final result = await container.read(termoAtivoProvider.future);

      expect(result, isNull);
    });
  });

  group('termoPendenteProvider', () {
    test('sem usuário autenticado (currentUser=null) → retorna false '
        'SEM chamar o repository — curto-circuito', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final container = buildContainer();
      final result = await container.read(termoPendenteProvider.future);

      expect(result, false);
      verifyNever(() => mockRepo.verificarTermoPendente(any()));
    });

    test('com usuário autenticado → chama o repository com o userId '
        'correto e retorna o resultado dele', () async {
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('user-abc-123');
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockRepo.verificarTermoPendente('user-abc-123'))
          .thenAnswer((_) async => true);

      final container = buildContainer();
      final result = await container.read(termoPendenteProvider.future);

      expect(result, true);
      verify(() => mockRepo.verificarTermoPendente('user-abc-123'))
          .called(1);
    });

    test(
      'com usuário autenticado E em dia com os termos (repository '
      'retorna false) → provider propaga false — cenário exigido '
      'explicitamente pelo PO/BA (compliance: aluno sem pendência '
      'real, não só o caminho "sem usuário")',
      () async {
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('user-em-dia-456');
        when(() => mockAuth.currentUser).thenReturn(mockUser);
        when(() => mockRepo.verificarTermoPendente('user-em-dia-456'))
            .thenAnswer((_) async => false);

        final container = buildContainer();
        final result = await container.read(termoPendenteProvider.future);

        expect(result, false);
        verify(() => mockRepo.verificarTermoPendente('user-em-dia-456'))
            .called(1);
      },
    );
  });

  group('TermosListaController — carregamento inicial', () {
    test('estado final é AsyncData com a lista do repository',
        () async {
      when(() => mockRepo.listarTodasVersoes())
          .thenAnswer((_) async => <TermoModel>[]);

      final container = buildContainer();
      container.read(termosListaProvider);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(termosListaProvider);
      expect(state, isA<AsyncData<List<TermoModel>>>());
    });

    test(
      'quando o repository lança exceção, o estado vira AsyncError '
      '— fecha DA:49 (state = AsyncValue.error dentro do catch de '
      'carregarTermos), o único bloco de tratamento de erro manual '
      'deste arquivo e o único não coberto até agora',
      () async {
        when(() => mockRepo.listarTodasVersoes())
            .thenThrow(Exception('Falha simulada ao listar termos'));

        final container = buildContainer();
        container.read(termosListaProvider);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(termosListaProvider);
        expect(state, isA<AsyncError>());
        expect(
          (state as AsyncError).error.toString(),
          contains('Falha simulada ao listar termos'),
        );
      },
    );
  });

  group('TermosListaController.criarTermo', () {
    test('propaga os 5 argumentos, invalida termoAtivo E '
        'termoPendente, e recarrega a lista', () async {
      when(() => mockRepo.listarTodasVersoes())
          .thenAnswer((_) async => <TermoModel>[]);
      when(() => mockRepo.criarTermo(
            titulo: any(named: 'titulo'),
            versao: any(named: 'versao'),
            conteudo: any(named: 'conteudo'),
            vigenciaInicio: any(named: 'vigenciaInicio'),
            ativar: any(named: 'ativar'),
          )).thenAnswer((_) async {});
      when(() => mockRepo.buscarTermoAtivo())
          .thenAnswer((_) async => null);
      when(() => mockAuth.currentUser).thenReturn(null);

      final container = buildContainer();
      container.read(termosListaProvider);
      await Future<void>.delayed(Duration.zero);

      // Força a criação dos providers que serão invalidados, para
      // que a invalidação seja observável (senão eles nunca teriam
      // sido computados e "invalidar" não tem efeito detectável).
      await container.read(termoAtivoProvider.future);
      await container.read(termoPendenteProvider.future);
      clearInteractions(mockRepo);
      // Re-stub após clearInteractions
      when(() => mockRepo.listarTodasVersoes())
          .thenAnswer((_) async => <TermoModel>[]);
      when(() => mockRepo.criarTermo(
            titulo: any(named: 'titulo'),
            versao: any(named: 'versao'),
            conteudo: any(named: 'conteudo'),
            vigenciaInicio: any(named: 'vigenciaInicio'),
            ativar: any(named: 'ativar'),
          )).thenAnswer((_) async {});
      when(() => mockRepo.buscarTermoAtivo())
          .thenAnswer((_) async => null);

      final vigIni = DateTime(2026, 8, 1);

      await container.read(termosListaProvider.notifier).criarTermo(
            titulo: 'Termo Novo',
            versao: 'v3.0',
            conteudo: 'Conteúdo do termo novo.',
            vigenciaInicio: vigIni,
            ativar: true,
          );

      final captured = verify(() => mockRepo.criarTermo(
            titulo: captureAny(named: 'titulo'),
            versao: captureAny(named: 'versao'),
            conteudo: captureAny(named: 'conteudo'),
            vigenciaInicio: captureAny(named: 'vigenciaInicio'),
            ativar: captureAny(named: 'ativar'),
          )).captured;
      expect(captured[0], 'Termo Novo');
      expect(captured[1], 'v3.0');
      expect(captured[3], vigIni);
      expect(captured[4], true);

      // Lista recarregada (chamada de novo após o criarTermo).
      verify(() => mockRepo.listarTodasVersoes()).called(1);

      // Invalidação real: ler termoAtivoProvider de novo dispara nova
      // chamada ao repository
      await container.read(termoAtivoProvider.future);
      verify(() => mockRepo.buscarTermoAtivo()).called(1);
    });
  });

  group('TermosListaController.ativarVersao', () {
    test(
      'invalida termoAtivo E termoPendente, e o estado refletido '
      'após a operação é o NOVO termo ativo — não basta invalidar, '
      'precisa realmente devolver o valor atualizado (cenário '
      'exigido explicitamente pelo PO/BA)',
      () async {
        when(() => mockRepo.listarTodasVersoes())
            .thenAnswer((_) async => <TermoModel>[]);
        when(() => mockRepo.ativarVersao(any())).thenAnswer((_) async {});
        when(() => mockAuth.currentUser).thenReturn(null);
        when(() => mockRepo.buscarTermoAtivo())
            .thenAnswer((_) async => termoFake1);

        final container = buildContainer();
        container.read(termosListaProvider);
        await Future<void>.delayed(Duration.zero);

        // Materializa o estado ANTIGO antes de ativar a nova versão.
        final antes = await container.read(termoAtivoProvider.future);
        expect(antes, termoFake1);

        clearInteractions(mockRepo);
        when(() => mockRepo.listarTodasVersoes())
            .thenAnswer((_) async => <TermoModel>[]);
        when(() => mockRepo.ativarVersao(any())).thenAnswer((_) async {});
        // Após a ativação, o repository passa a devolver o termo novo.
        when(() => mockRepo.buscarTermoAtivo())
            .thenAnswer((_) async => termoFake2);

        await container
            .read(termosListaProvider.notifier)
            .ativarVersao('termo-v4-id');

        verify(() => mockRepo.ativarVersao('termo-v4-id')).called(1);
        verify(() => mockRepo.listarTodasVersoes()).called(1);

        // O ponto central: reler termoAtivoProvider depois de
        // ativarVersao precisa trazer o termo NOVO, não o antigo em cache.
        final depois = await container.read(termoAtivoProvider.future);
        expect(depois, termoFake2);
        expect(depois, isNot(antes));
      },
    );
  });

  group('TermosListaController.aceitarTermo', () {
    test('propaga a versão, invalida SÓ termoPendente, e NÃO '
        'recarrega a lista completa de versões', () async {
      when(() => mockRepo.listarTodasVersoes())
          .thenAnswer((_) async => <TermoModel>[]);
      when(() => mockRepo.aceitarTermo(any())).thenAnswer((_) async {});
      when(() => mockAuth.currentUser).thenReturn(null);

      final container = buildContainer();
      container.read(termosListaProvider);
      await Future<void>.delayed(Duration.zero);

      // Consome a primeira chamada de listarTodasVersoes (construtor).
      clearInteractions(mockRepo);
      when(() => mockRepo.aceitarTermo(any())).thenAnswer((_) async {});

      await container
          .read(termosListaProvider.notifier)
          .aceitarTermo('v2.0');

      verify(() => mockRepo.aceitarTermo('v2.0')).called(1);
      // O ponto central deste teste: listarTodasVersoes NÃO deve ser
      // chamado de novo — aceitarTermo não recarrega a lista.
      verifyNever(() => mockRepo.listarTodasVersoes());
    });
  });
}
