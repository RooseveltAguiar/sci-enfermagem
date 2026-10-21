// test/providers/conflitos_provider_test.dart
//
// Ponto central: carregarConflitos({campoId, ...}) tem um fallback —
//   campoId explícito, se fornecido, tem prioridade
//   senão, usa o valor atual de conflitosFiltroCampoProvider
//   se nenhum dos dois, permanece null (sem filtro de campo)
// Os três casos são testados separadamente porque um bug comum aqui
// seria inverter a prioridade (provider sobrescrevendo o argumento
// explícito) ou esquecer o fallback (sempre null quando campoId não
// é passado, ignorando o filtro que o usuário já selecionou na tela).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sci_app/data/models/conflito_model.dart';
import 'package:sci_app/data/repositories/conflitos_repository.dart';
import 'package:sci_app/providers/conflitos_provider.dart';

class MockConflitosRepository extends Mock implements ConflitosRepository {}

void main() {
  late MockConflitosRepository mockRepo;

  setUp(() {
    mockRepo = MockConflitosRepository();
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        conflitosRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ConflitosController — carregamento inicial (construtor)', () {
    test('chama listarConflitos sem filtro de campo (provider de '
        'filtro nasce null) e sem filtro de data', () async {
      when(() => mockRepo.listarConflitos(
            campoId: any(named: 'campoId'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
          )).thenAnswer((_) async => <ConflitoModel>[]);

      final container = buildContainer();
      container.read(conflitosControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      verify(() => mockRepo.listarConflitos(
            campoId: null,
            dataInicio: null,
            dataFim: null,
          )).called(1);
    });
  });

  group('ConflitosController.carregarConflitos — fallback de campoId',
      () {
    test('campoId explícito tem prioridade sobre o filtro global,'
        ' mesmo que o filtro global tenha outro valor', () async {
      when(() => mockRepo.listarConflitos(
            campoId: any(named: 'campoId'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
          )).thenAnswer((_) async => <ConflitoModel>[]);

      final container = buildContainer();
      container.read(conflitosControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Filtro global setado para um campo diferente do que será
      // passado explicitamente — confirma que o explícito vence.
      container.read(conflitosFiltroCampoProvider.notifier).state =
          'campo-global-XYZ';
      clearInteractions(mockRepo);
      when(() => mockRepo.listarConflitos(
            campoId: any(named: 'campoId'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
          )).thenAnswer((_) async => <ConflitoModel>[]);

      await container
          .read(conflitosControllerProvider.notifier)
          .carregarConflitos(campoId: 'campo-explicito-ABC');

      verify(() => mockRepo.listarConflitos(
            campoId: 'campo-explicito-ABC',
            dataInicio: null,
            dataFim: null,
          )).called(1);
    });

    test('sem campoId explícito, usa o valor atual do filtro global',
        () async {
      when(() => mockRepo.listarConflitos(
            campoId: any(named: 'campoId'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
          )).thenAnswer((_) async => <ConflitoModel>[]);

      final container = buildContainer();
      container.read(conflitosControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      container.read(conflitosFiltroCampoProvider.notifier).state =
          'campo-do-filtro-global';
      clearInteractions(mockRepo);
      when(() => mockRepo.listarConflitos(
            campoId: any(named: 'campoId'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
          )).thenAnswer((_) async => <ConflitoModel>[]);

      // Sem campoId — deve cair no fallback do filtro global.
      await container
          .read(conflitosControllerProvider.notifier)
          .carregarConflitos();

      verify(() => mockRepo.listarConflitos(
            campoId: 'campo-do-filtro-global',
            dataInicio: null,
            dataFim: null,
          )).called(1);
    });

    test('propaga dataInicio e dataFim corretamente junto com o '
        'filtro de campo', () async {
      when(() => mockRepo.listarConflitos(
            campoId: any(named: 'campoId'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
          )).thenAnswer((_) async => <ConflitoModel>[]);

      final container = buildContainer();
      container.read(conflitosControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      clearInteractions(mockRepo);
      when(() => mockRepo.listarConflitos(
            campoId: any(named: 'campoId'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
          )).thenAnswer((_) async => <ConflitoModel>[]);

      final ini = DateTime(2026, 1, 1);
      final fim = DateTime(2026, 6, 30);

      await container
          .read(conflitosControllerProvider.notifier)
          .carregarConflitos(dataInicio: ini, dataFim: fim);

      verify(() => mockRepo.listarConflitos(
            campoId: null,
            dataInicio: ini,
            dataFim: fim,
          )).called(1);
    });
  });

  group('ConflitosController.registrarConflito', () {
    test('propaga os 4 argumentos exatos para o repository e '
        'recarrega a lista ao final', () async {
      when(() => mockRepo.listarConflitos(
            campoId: any(named: 'campoId'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
          )).thenAnswer((_) async => <ConflitoModel>[]);
      when(() => mockRepo.registrarConflito(
            alunoId: any(named: 'alunoId'),
            campoId: any(named: 'campoId'),
            descricao: any(named: 'descricao'),
            dataOcorrencia: any(named: 'dataOcorrencia'),
          )).thenAnswer((_) async {});

      final container = buildContainer();
      container.read(conflitosControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      clearInteractions(mockRepo);
      when(() => mockRepo.listarConflitos(
            campoId: any(named: 'campoId'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
          )).thenAnswer((_) async => <ConflitoModel>[]);
      when(() => mockRepo.registrarConflito(
            alunoId: any(named: 'alunoId'),
            campoId: any(named: 'campoId'),
            descricao: any(named: 'descricao'),
            dataOcorrencia: any(named: 'dataOcorrencia'),
          )).thenAnswer((_) async {});

      final dataOcorrencia = DateTime(2026, 7, 10);

      await container
          .read(conflitosControllerProvider.notifier)
          .registrarConflito(
            alunoId: 'aluno-777',
            campoId: 'campo-888',
            descricao: 'Descrição do conflito com mais de vinte caracteres.',
            dataOcorrencia: dataOcorrencia,
          );

      verify(() => mockRepo.registrarConflito(
            alunoId: 'aluno-777',
            campoId: 'campo-888',
            descricao: 'Descrição do conflito com mais de vinte caracteres.',
            dataOcorrencia: dataOcorrencia,
          )).called(1);

      verify(() => mockRepo.listarConflitos(
            campoId: any(named: 'campoId'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
          )).called(1);
    });
  });
}
