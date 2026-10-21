// test/providers/legislacao_provider_test.dart
//
// Nuance importante deste provider em relação ao de transferência:
// LegislacoesController dispara carregarLegislacoes() dentro do
// PRÓPRIO CONSTRUTOR (fire-and-forget, não aguardado). Isso significa
// que o mock de listarLegislacoesAtivas() precisa estar registrado
// ANTES de qualquer leitura do provider — inclusive antes do primeiro
// container.read(legislacoesProvider.notifier) — e cada teste precisa
// dar um respiro assíncrono (Future.delayed(Duration.zero) ou
// aguardar o método explicitamente) antes de inspecionar o estado,
// já que o construtor não é awaitable.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sci_app/data/models/legislacao_model.dart';
import 'package:sci_app/data/repositories/legislacao_repository.dart';
import 'package:sci_app/providers/legislacao_provider.dart';

class MockLegislacaoRepository extends Mock implements LegislacaoRepository {}

class FakeLegislacaoModel extends Fake implements LegislacaoModel {}

void main() {
  late MockLegislacaoRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(FakeLegislacaoModel());
  });

  setUp(() {
    mockRepo = MockLegislacaoRepository();
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        legislacaoRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('LegislacoesController — carregamento inicial (construtor)', () {
    test('estado final após settle é AsyncData com a lista retornada '
        'pelo repository', () async {
      when(() => mockRepo.listarLegislacoesAtivas())
          .thenAnswer((_) async => <LegislacaoModel>[]);

      final container = buildContainer();
      container.read(legislacoesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(legislacoesProvider);
      expect(state, isA<AsyncData<List<LegislacaoModel>>>());
      expect(state.value, isEmpty);
      verify(() => mockRepo.listarLegislacoesAtivas()).called(1);
    });

    test('propaga exceção do repository como AsyncError, não deixa '
        'em loading indefinido', () async {
      when(() => mockRepo.listarLegislacoesAtivas())
          .thenThrow(Exception('Falha de rede simulada'));

      final container = buildContainer();
      container.read(legislacoesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(legislacoesProvider);
      expect(state, isA<AsyncError>());
    });
  });

  group('LegislacoesController.criarLegislacao', () {
    test('propaga todos os 6 argumentos nomeados e recarrega a lista '
        'ao final', () async {
      when(() => mockRepo.listarLegislacoesAtivas())
          .thenAnswer((_) async => <LegislacaoModel>[]);
      when(() => mockRepo.criarLegislacao(
            titulo: any(named: 'titulo'),
            conteudo: any(named: 'conteudo'),
            tipo: any(named: 'tipo'),
            vigenciaInicio: any(named: 'vigenciaInicio'),
            vigenciaFim: any(named: 'vigenciaFim'),
            ativo: any(named: 'ativo'),
          )).thenAnswer((_) async {});

      final container = buildContainer();
      container.read(legislacoesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final vigIni = DateTime(2026, 1, 1);
      final vigFim = DateTime(2026, 12, 31);

      await container.read(legislacoesProvider.notifier).criarLegislacao(
            titulo: 'Portaria de Teste',
            conteudo: 'Corpo da portaria de teste.',
            tipo: 'portaria',
            vigenciaInicio: vigIni,
            vigenciaFim: vigFim,
            ativo: true,
          );

      verify(() => mockRepo.criarLegislacao(
            titulo: 'Portaria de Teste',
            conteudo: 'Corpo da portaria de teste.',
            tipo: 'portaria',
            vigenciaInicio: vigIni,
            vigenciaFim: vigFim,
            ativo: true,
          )).called(1);

      // carregarLegislacoes() é chamado 1x no construtor + 1x aqui.
      verify(() => mockRepo.listarLegislacoesAtivas()).called(2);
    });

    test('aceita vigenciaInicio e vigenciaFim nulos (campos opcionais)',
        () async {
      when(() => mockRepo.listarLegislacoesAtivas())
          .thenAnswer((_) async => <LegislacaoModel>[]);
      when(() => mockRepo.criarLegislacao(
            titulo: any(named: 'titulo'),
            conteudo: any(named: 'conteudo'),
            tipo: any(named: 'tipo'),
            vigenciaInicio: any(named: 'vigenciaInicio'),
            vigenciaFim: any(named: 'vigenciaFim'),
            ativo: any(named: 'ativo'),
          )).thenAnswer((_) async {});

      final container = buildContainer();
      container.read(legislacoesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await container.read(legislacoesProvider.notifier).criarLegislacao(
            titulo: 'Manual sem vigência definida',
            conteudo: 'Corpo.',
            tipo: 'manual',
            ativo: false,
          );

      verify(() => mockRepo.criarLegislacao(
            titulo: 'Manual sem vigência definida',
            conteudo: 'Corpo.',
            tipo: 'manual',
            vigenciaInicio: null,
            vigenciaFim: null,
            ativo: false,
          )).called(1);
    });
  });

  group('LegislacoesController.editarLegislacao', () {
    test('propaga id e os 6 campos editáveis, incluindo ativo',
        () async {
      when(() => mockRepo.listarLegislacoesAtivas())
          .thenAnswer((_) async => <LegislacaoModel>[]);
      when(() => mockRepo.editarLegislacao(
            id: any(named: 'id'),
            titulo: any(named: 'titulo'),
            conteudo: any(named: 'conteudo'),
            tipo: any(named: 'tipo'),
            vigenciaInicio: any(named: 'vigenciaInicio'),
            vigenciaFim: any(named: 'vigenciaFim'),
            ativo: any(named: 'ativo'),
          )).thenAnswer((_) async {});

      final container = buildContainer();
      container.read(legislacoesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await container.read(legislacoesProvider.notifier).editarLegislacao(
            id: 'leg-001',
            titulo: 'Título Editado',
            conteudo: 'Conteúdo editado.',
            tipo: 'resolucao',
            ativo: false,
          );

      verify(() => mockRepo.editarLegislacao(
            id: 'leg-001',
            titulo: 'Título Editado',
            conteudo: 'Conteúdo editado.',
            tipo: 'resolucao',
            vigenciaInicio: null,
            vigenciaFim: null,
            ativo: false,
          )).called(1);
    });
  });

  group('LegislacoesController.desativarLegislacao', () {
    test('chama o repository com o id certo e recarrega a lista',
        () async {
      when(() => mockRepo.listarLegislacoesAtivas())
          .thenAnswer((_) async => <LegislacaoModel>[]);
      when(() => mockRepo.desativarLegislacao(any()))
          .thenAnswer((_) async {});

      final container = buildContainer();
      container.read(legislacoesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await container
          .read(legislacoesProvider.notifier)
          .desativarLegislacao('leg-999');

      verify(() => mockRepo.desativarLegislacao('leg-999')).called(1);
      verify(() => mockRepo.listarLegislacoesAtivas()).called(2);
    });
  });
}
