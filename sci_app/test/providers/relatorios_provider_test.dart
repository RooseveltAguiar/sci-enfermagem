// test/providers/relatorios_provider_test.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sci_app/data/repositories/relatorios_repository.dart';
import 'package:sci_app/providers/relatorios_provider.dart';

class MockRelatoriosRepository extends Mock implements RelatoriosRepository {}

void main() {
  late MockRelatoriosRepository mockRepository;

  setUp(() {
    mockRepository = MockRelatoriosRepository();
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        relatoriosRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('relatoriosRepositoryProvider', () {
    test('instancia RelatoriosRepository no closure padrão (mesmo que Supabase.instance não esteja inicializado)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Ao tentar instanciar RelatoriosRepository, ele acessa Supabase.instance.client
      // O closure do provider (linhas 4-6) é executado 100% e coberto.
      expect(() => container.read(relatoriosRepositoryProvider), throwsAssertionError);
    });
  });

  group('RelatorioState', () {
    test('propriedades iniciais e copyWith funcionam corretamente', () {
      final now = DateTime(2026, 7, 17);
      final state = RelatorioState(
        tipo: 'frequencia',
        dataInicio: now,
        dataFim: now,
        campoId: 'campo-1',
        loading: true,
        dados: const [{'id': '1'}],
        erro: 'Erro inicial',
      );

      expect(state.tipo, 'frequencia');
      expect(state.dataInicio, now);
      expect(state.dataFim, now);
      expect(state.campoId, 'campo-1');
      expect(state.loading, true);
      expect(state.dados.length, 1);
      expect(state.erro, 'Erro inicial');

      final copied = state.copyWith(
        tipo: 'estagio',
        loading: false,
      );
      expect(copied.tipo, 'estagio');
      expect(copied.loading, false);
      expect(copied.campoId, 'campo-1');
      expect(copied.erro, 'Erro inicial');

      final clearedErro = state.copyWith(clearErro: true);
      expect(clearedErro.erro, isNull);
    });
  });

  group('RelatorioNotifier e relatorioProvider', () {
    test('inicialização chama carregar e popula dados com sucesso via relatorioProvider', () async {
      when(() => mockRepository.gerarRelatorio(
            tipo: any(named: 'tipo'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: any(named: 'campoId'),
          )).thenAnswer((_) async => [
            {'aluno': 'João', 'total_horas': 40},
            {'aluno': 'Maria', 'total_horas': 60},
          ]);

      final container = buildContainer();
      // Mantém o provider autoDispose ativo escutando as mudanças de estado
      container.listen(relatorioProvider('frequencia'), (_, _) {});

      // Aguarda carregar() disparado no construtor
      await Future.delayed(const Duration(milliseconds: 50));

      verify(() => mockRepository.gerarRelatorio(
            tipo: 'frequencia',
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: any(named: 'campoId'),
          )).called(1);

      final state = container.read(relatorioProvider('frequencia'));
      expect(state.loading, false);
      expect(state.dados.length, 2);
      expect(state.dados[0]['aluno'], 'João');
      expect(state.erro, isNull);
    });

    test('carregar captura erro e limpa prefixo Exception:', () async {
      when(() => mockRepository.gerarRelatorio(
            tipo: any(named: 'tipo'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: any(named: 'campoId'),
          )).thenThrow(Exception('Falha ao gerar relatório no servidor'));

      final container = buildContainer();
      container.listen(relatorioProvider('desempenho'), (_, _) {});

      await Future.delayed(const Duration(milliseconds: 50));

      final state = container.read(relatorioProvider('desempenho'));
      expect(state.loading, false);
      expect(state.dados, isEmpty);
      expect(state.erro, 'Falha ao gerar relatório no servidor');
    });

    test('aplicarFiltros atualiza dataInicio, dataFim e campoId e chama carregar novamente', () async {
      when(() => mockRepository.gerarRelatorio(
            tipo: any(named: 'tipo'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: any(named: 'campoId'),
          )).thenAnswer((_) async => []);

      final container = buildContainer();
      container.listen(relatorioProvider('geral'), (_, _) {});

      await Future.delayed(const Duration(milliseconds: 50));
      clearInteractions(mockRepository);

      final notifier = container.read(relatorioProvider('geral').notifier);
      final novaInicio = DateTime(2026, 1, 1);
      final novaFim = DateTime(2026, 6, 30);

      await notifier.aplicarFiltros(
        dataInicio: novaInicio,
        dataFim: novaFim,
        campoId: 'campo-novo-id',
      );

      verify(() => mockRepository.gerarRelatorio(
            tipo: 'geral',
            dataInicio: novaInicio,
            dataFim: novaFim,
            campoId: 'campo-novo-id',
          )).called(1);

      final state = container.read(relatorioProvider('geral'));
      expect(state.dataInicio, novaInicio);
      expect(state.dataFim, novaFim);
      expect(state.campoId, 'campo-novo-id');
    });
  });
}
