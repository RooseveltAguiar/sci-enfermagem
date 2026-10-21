// test/providers/sugestoes_provider_test.dart
//
// Ponto central deste provider: carregarSugestoes(isCoordenacao) tem
// DOIS caminhos que chamam métodos DIFERENTES do repositório:
//   isCoordenacao=true  → listarTodasSugestoes(perfil: <filtro atual>)
//   isCoordenacao=false → listarMinhasSugestoes()
// E o construtor chama carregarSugestoes() SEM argumento — ou seja,
// SEMPRE no modo "minhas sugestões" no load inicial, independente do
// perfil do usuário. A tela de coordenação precisa fazer uma chamada
// explícita com isCoordenacao:true depois da montagem. Isso é
// testado explicitamente porque é o tipo de detalhe que um refactor
// "simplificador" futuro erra fácil.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sci_app/data/models/sugestao_model.dart';
import 'package:sci_app/data/repositories/sugestoes_repository.dart';
import 'package:sci_app/providers/sugestoes_provider.dart';

class MockSugestoesRepository extends Mock implements SugestoesRepository {}

void main() {
  late MockSugestoesRepository mockRepo;

  setUp(() {
    mockRepo = MockSugestoesRepository();
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        sugestoesRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('SugestoesController — carregamento inicial (construtor)', () {
    test('chama listarMinhasSugestoes() por padrão, NUNCA '
        'listarTodasSugestoes() — mesmo sem saber ainda o perfil do '
        'usuário', () async {
      when(() => mockRepo.listarMinhasSugestoes())
          .thenAnswer((_) async => <SugestaoModel>[]);

      final container = buildContainer();
      container.read(sugestoesControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      verify(() => mockRepo.listarMinhasSugestoes()).called(1);
      verifyNever(() => mockRepo.listarTodasSugestoes(
          perfil: any(named: 'perfil')));

      final state = container.read(sugestoesControllerProvider);
      expect(state, isA<AsyncData<List<SugestaoModel>>>());
    });
  });

  group('SugestoesController.carregarSugestoes', () {
    test('isCoordenacao=true lê o filtro atual de '
        'sugestoesFiltroPerfilProvider e chama listarTodasSugestoes '
        'com esse filtro', () async {
      when(() => mockRepo.listarMinhasSugestoes())
          .thenAnswer((_) async => <SugestaoModel>[]);
      when(() => mockRepo.listarTodasSugestoes(perfil: any(named: 'perfil')))
          .thenAnswer((_) async => <SugestaoModel>[]);

      final container = buildContainer();
      container.read(sugestoesControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      container.read(sugestoesFiltroPerfilProvider.notifier).state =
          'professor';

      await container
          .read(sugestoesControllerProvider.notifier)
          .carregarSugestoes(isCoordenacao: true);

      verify(() => mockRepo.listarTodasSugestoes(perfil: 'professor'))
          .called(1);
    });

    test('isCoordenacao=false (padrão) chama listarMinhasSugestoes, '
        'ignorando o filtro de perfil', () async {
      when(() => mockRepo.listarMinhasSugestoes())
          .thenAnswer((_) async => <SugestaoModel>[]);

      final container = buildContainer();
      container.read(sugestoesControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      clearInteractions(mockRepo);
      when(() => mockRepo.listarMinhasSugestoes())
          .thenAnswer((_) async => <SugestaoModel>[]);

      await container
          .read(sugestoesControllerProvider.notifier)
          .carregarSugestoes();

      verify(() => mockRepo.listarMinhasSugestoes()).called(1);
      verifyNever(() => mockRepo.listarTodasSugestoes(
          perfil: any(named: 'perfil')));
    });
  });

  group('SugestoesController.enviarSugestao', () {
    test('propaga o conteúdo exato para o repository', () async {
      when(() => mockRepo.listarMinhasSugestoes())
          .thenAnswer((_) async => <SugestaoModel>[]);
      when(() => mockRepo.enviarSugestao(any())).thenAnswer((_) async {});

      final container = buildContainer();
      container.read(sugestoesControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      const texto = 'Sugestão com pelo menos vinte caracteres úteis.';
      await container
          .read(sugestoesControllerProvider.notifier)
          .enviarSugestao(texto);

      verify(() => mockRepo.enviarSugestao(texto)).called(1);
    });

    test('após enviar com isCoordenacao=true, recarrega via '
        'listarTodasSugestoes (não listarMinhasSugestoes)', () async {
      when(() => mockRepo.listarMinhasSugestoes())
          .thenAnswer((_) async => <SugestaoModel>[]);
      when(() => mockRepo.listarTodasSugestoes(perfil: any(named: 'perfil')))
          .thenAnswer((_) async => <SugestaoModel>[]);
      when(() => mockRepo.enviarSugestao(any())).thenAnswer((_) async {});

      final container = buildContainer();
      container.read(sugestoesControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      clearInteractions(mockRepo);
      when(() => mockRepo.listarTodasSugestoes(perfil: any(named: 'perfil')))
          .thenAnswer((_) async => <SugestaoModel>[]);
      when(() => mockRepo.enviarSugestao(any())).thenAnswer((_) async {});

      await container
          .read(sugestoesControllerProvider.notifier)
          .enviarSugestao('Texto qualquer com vinte caracteres.',
              isCoordenacao: true);

      verify(() => mockRepo.listarTodasSugestoes(
          perfil: any(named: 'perfil'))).called(1);
      verifyNever(() => mockRepo.listarMinhasSugestoes());
    });

    test('após enviar com isCoordenacao=false (padrão), recarrega '
        'via listarMinhasSugestoes', () async {
      when(() => mockRepo.listarMinhasSugestoes())
          .thenAnswer((_) async => <SugestaoModel>[]);
      when(() => mockRepo.enviarSugestao(any())).thenAnswer((_) async {});

      final container = buildContainer();
      container.read(sugestoesControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      clearInteractions(mockRepo);
      when(() => mockRepo.listarMinhasSugestoes())
          .thenAnswer((_) async => <SugestaoModel>[]);
      when(() => mockRepo.enviarSugestao(any())).thenAnswer((_) async {});

      await container
          .read(sugestoesControllerProvider.notifier)
          .enviarSugestao('Texto qualquer com vinte caracteres.');

      verify(() => mockRepo.listarMinhasSugestoes()).called(1);
      verifyNever(() => mockRepo.listarTodasSugestoes(
          perfil: any(named: 'perfil')));
    });
  });
}
