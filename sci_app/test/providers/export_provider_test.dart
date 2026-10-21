import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sci_app/providers/export_provider.dart';
import 'package:sci_app/services/export_service.dart';

class MockExportService extends Mock implements ExportService {}

void main() {
  late MockExportService mockService;

  setUp(() {
    mockService = MockExportService();
  });

  group('ExportState', () {
    test('valida construtor e copyWith com clearErro=true', () {
      const state = ExportState(loading: true, progressoMensagem: 'Msg', erro: 'Falha anterior', sucesso: false);
      final copiado = state.copyWith(loading: false, clearErro: true, sucesso: true);

      expect(copiado.loading, isFalse);
      expect(copiado.progressoMensagem, 'Msg');
      expect(copiado.erro, isNull);
      expect(copiado.sucesso, isTrue);
    });
  });

  group('ExportNotifier e Provider', () {
    test('gerarPdf atualiza estado para loading e depois sucesso quando exportService conclui', () async {
      when(() => mockService.exportarRelatorioEmPdf(
            tipo: 'frequencia',
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: any(named: 'campoId'),
            alunoId: any(named: 'alunoId'),
          )).thenAnswer((_) async {});

      final notifier = ExportNotifier(mockService);
      final states = <ExportState>[];
      notifier.addListener(states.add, fireImmediately: false);

      await notifier.gerarPdf(
        tipo: 'frequencia',
        dataInicio: DateTime(2026, 6, 1),
        dataFim: DateTime(2026, 6, 30),
      );

      expect(states.length, 2);
      expect(states[0].loading, isTrue);
      expect(states[0].progressoMensagem, 'Gerando PDF...');
      expect(states[1].loading, isFalse);
      expect(states[1].sucesso, isTrue);
    });

    test('gerarPdf captura e limpa exceção salvando mensagem em erro', () async {
      when(() => mockService.exportarRelatorioEmPdf(
            tipo: 'frequencia',
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: any(named: 'campoId'),
            alunoId: any(named: 'alunoId'),
          )).thenThrow(Exception('Falha ao gerar arquivo PDF'));

      final notifier = ExportNotifier(mockService);

      await notifier.gerarPdf(
        tipo: 'frequencia',
        dataInicio: DateTime(2026, 6, 1),
        dataFim: DateTime(2026, 6, 30),
      );

      expect(notifier.state.loading, isFalse);
      expect(notifier.state.sucesso, isFalse);
      expect(notifier.state.erro, 'Falha ao gerar arquivo PDF');
    });

    test('gerarCsv atualiza estado para loading e depois sucesso quando exportService conclui', () async {
      when(() => mockService.exportarRelatorioEmCsv(
            tipo: 'atividades',
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: any(named: 'campoId'),
          )).thenAnswer((_) async {});

      final notifier = ExportNotifier(mockService);

      await notifier.gerarCsv(
        tipo: 'atividades',
        dataInicio: DateTime(2026, 6, 1),
        dataFim: DateTime(2026, 6, 30),
      );

      expect(notifier.state.loading, isFalse);
      expect(notifier.state.sucesso, isTrue);
    });

    test('gerarCsv captura erro quando exportService falha', () async {
      when(() => mockService.exportarRelatorioEmCsv(
            tipo: 'atividades',
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: any(named: 'campoId'),
          )).thenThrow(Exception('Erro no CSV'));

      final notifier = ExportNotifier(mockService);

      await notifier.gerarCsv(
        tipo: 'atividades',
        dataInicio: DateTime(2026, 6, 1),
        dataFim: DateTime(2026, 6, 30),
      );

      expect(notifier.state.erro, 'Erro no CSV');
    });

    test('reset limpa todo o estado para o padrão ExportState()', () {
      final notifier = ExportNotifier(mockService);
      notifier.state = const ExportState(loading: true, erro: 'x', sucesso: true);

      notifier.reset();

      expect(notifier.state.loading, isFalse);
      expect(notifier.state.erro, isNull);
      expect(notifier.state.sucesso, isFalse);
    });

    test('exportProvider é construído corretamente via container', () {
      final container = ProviderContainer(
        overrides: [
          exportServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(exportProvider);
      expect(state.loading, isFalse);
    });
  });
}
