import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/data/repositories/relatorios_repository.dart';
import 'package:sci_app/services/export_service.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockRelatoriosRepository extends Mock implements RelatoriosRepository {}
class MockPostgrestTransformBuilder extends Mock implements PostgrestFilterBuilder<dynamic> {}

void _stubAwaitRpc(
  MockPostgrestTransformBuilder builder,
  dynamic returnValue,
) {
  when(() => builder.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final callback = invocation.positionalArguments[0] as Function;
    final onError = invocation.namedArguments[#onError] as Function?;
    return Future<dynamic>.value(returnValue).then(
      (v) => callback(v),
      onError: onError,
    );
  });
}

void _stubAwaitRpcError(
  MockPostgrestTransformBuilder builder,
  dynamic error,
) {
  when(() => builder.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final callback = invocation.positionalArguments[0] as Function?;
    final onError = invocation.namedArguments[#onError] as Function?;
    return Future<dynamic>.error(error).then(
      (v) => callback != null ? callback(v) : null,
      onError: onError,
    );
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupabaseClient mockSupabase;
  late MockRelatoriosRepository mockRelatoriosRepository;
  late MockPostgrestTransformBuilder mockRpcBuilder;
  late ExportService exportService;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockRelatoriosRepository = MockRelatoriosRepository();
    mockRpcBuilder = MockPostgrestTransformBuilder();
    exportService = ExportService(mockSupabase, mockRelatoriosRepository);
  });

  group('ExportService - Geração de PDF e CSV em Bytes/Strings', () {
    test('gerarPdfBytes (tipo = compilado) consome fn_compilar_dados_aluno e monta PDF completo com seções', () async {
      when(() => mockSupabase.rpc(
            'fn_compilar_dados_aluno',
            params: any(named: 'params'),
          )).thenAnswer((_) => mockRpcBuilder);

      _stubAwaitRpc(mockRpcBuilder, {
        'aluno_id': 'aluno-123',
        'percentual_frequencia': 85.5,
        'atividades_registradas': 12,
        'atividades_validadas': 10,
        'nota_media_do_interno': 9.0,
        'nota_autoavaliacao': 9.5,
        'termos_aceitos': true,
        'campo_estagio_id': 'campo-456',
        'campo_estagio_nome': 'Hospital Geral de Fortaleza',
      });

      final bytes = await exportService.gerarPdfBytes(
        tipo: 'compilado',
        dataInicio: DateTime(2026, 6, 1),
        dataFim: DateTime(2026, 6, 30),
        alunoId: 'aluno-123',
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);

      verify(() => mockSupabase.rpc(
            'fn_compilar_dados_aluno',
            params: {
              'p_aluno_id': 'aluno-123',
              'p_data_inicio': '2026-06-01',
              'p_data_fim': '2026-06-30',
            },
          )).called(1);
    });

    test('gerarPdfBytes (tipo = compilado) com campos nulos ou zerados no retorno plano cobre todas as mensagens informativas', () async {
      when(() => mockSupabase.rpc(
            'fn_compilar_dados_aluno',
            params: any(named: 'params'),
          )).thenAnswer((_) => mockRpcBuilder);

      _stubAwaitRpc(mockRpcBuilder, {
        'aluno_id': 'aluno-sem-dados',
        'percentual_frequencia': null,
        'atividades_registradas': 0,
        'atividades_validadas': 0,
        'nota_media_do_interno': null,
        'nota_autoavaliacao': null,
        'termos_aceitos': false,
        'campo_estagio_id': null,
        'campo_estagio_nome': null,
      });

      final bytes = await exportService.gerarPdfBytes(
        tipo: 'compilado',
        dataInicio: DateTime(2026, 6, 1),
        dataFim: DateTime(2026, 6, 30),
        alunoId: 'aluno-sem-dados',
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
    });

    test('gerarPdfBytes (tipo = compilado) com resposta nula, lista ou formato desconhecido do RPC', () async {
      when(() => mockSupabase.rpc(
            'fn_compilar_dados_aluno',
            params: any(named: 'params'),
          )).thenAnswer((_) => mockRpcBuilder);

      // Teste com null
      _stubAwaitRpc(mockRpcBuilder, null);
      var bytes = await exportService.gerarPdfBytes(
        tipo: 'compilado',
        dataInicio: DateTime(2026, 6, 1),
        dataFim: DateTime(2026, 6, 30),
        alunoId: 'aluno-null',
      );
      expect(bytes.isNotEmpty, isTrue);

      // Teste com List de Map directly
      _stubAwaitRpc(mockRpcBuilder, [
        {'aluno': 'Direto na Lista', 'status': 'ativo'}
      ]);
      bytes = await exportService.gerarPdfBytes(
        tipo: 'compilado',
        dataInicio: DateTime(2026, 6, 1),
        dataFim: DateTime(2026, 6, 30),
        alunoId: 'aluno-list',
      );
      expect(bytes.isNotEmpty, isTrue);

      // Teste com tipo primitivo inesperado
      _stubAwaitRpc(mockRpcBuilder, 'resposta_invalida');
      bytes = await exportService.gerarPdfBytes(
        tipo: 'compilado',
        dataInicio: DateTime(2026, 6, 1),
        dataFim: DateTime(2026, 6, 30),
        alunoId: 'aluno-inv',
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('gerarPdfBytes (tipo = frequencia) consome relatoriosRepository e gera tabela PDF', () async {
      when(() => mockRelatoriosRepository.gerarRelatorio(
            tipo: any(named: 'tipo'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: any(named: 'campoId'),
          )).thenAnswer((_) async => [
            {'aluno_nome': 'Carlos', 'data': '2026-06-10', 'status': 'Presente'}
          ]);

      final bytes = await exportService.gerarPdfBytes(
        tipo: 'frequencia',
        dataInicio: DateTime(2026, 6, 1),
        dataFim: DateTime(2026, 6, 30),
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);

      verify(() => mockRelatoriosRepository.gerarRelatorio(
            tipo: 'frequencia',
            dataInicio: DateTime(2026, 6, 1),
            dataFim: DateTime(2026, 6, 30),
            campoId: null,
          )).called(1);
    });

    test('gerarPdfBytes para lista vazia gera PDF com mensagem informativa', () async {
      when(() => mockRelatoriosRepository.gerarRelatorio(
            tipo: any(named: 'tipo'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: any(named: 'campoId'),
          )).thenAnswer((_) async => []);

      final bytes = await exportService.gerarPdfBytes(
        tipo: 'atividades',
        dataInicio: DateTime(2026, 6, 1),
        dataFim: DateTime(2026, 6, 30),
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
    });

    test('gerarCsvString (tipo = atividades) consome relatoriosRepository e retorna CSV formatado', () async {
      when(() => mockRelatoriosRepository.gerarRelatorio(
            tipo: any(named: 'tipo'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: any(named: 'campoId'),
          )).thenAnswer((_) async => [
            {'id': '1', 'titulo': 'Sonda Vesical', 'aluno': 'Mariana'},
            {'id': '2', 'titulo': 'Curativo', 'aluno': 'Mariana'},
          ]);

      final csvString = await exportService.gerarCsvString(
        tipo: 'atividades',
        dataInicio: DateTime(2026, 6, 1),
        dataFim: DateTime(2026, 6, 30),
      );

      expect(csvString, contains('id,titulo,aluno'));
      expect(csvString, contains('1,Sonda Vesical,Mariana'));
      expect(csvString, contains('2,Curativo,Mariana'));
    });

    test('gerarCsvString retorna string vazia quando não há dados', () async {
      when(() => mockRelatoriosRepository.gerarRelatorio(
            tipo: any(named: 'tipo'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: any(named: 'campoId'),
          )).thenAnswer((_) async => []);

      final csvString = await exportService.gerarCsvString(
        tipo: 'avaliacoes',
        dataInicio: DateTime(2026, 6, 1),
        dataFim: DateTime(2026, 6, 30),
      );

      expect(csvString, equals(''));
    });
  });

  group('ExportService - Validações e Exceções', () {
    test('gerarPdfBytes (tipo = compilado) sem alunoId lança ArgumentError', () async {
      expect(
        () => exportService.gerarPdfBytes(
          tipo: 'compilado',
          dataInicio: DateTime(2026, 6, 1),
          dataFim: DateTime(2026, 6, 30),
          alunoId: null,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('gerarPdfBytes (tipo = compilado) com alunoId vazio lança ArgumentError', () async {
      expect(
        () => exportService.gerarPdfBytes(
          tipo: 'compilado',
          dataInicio: DateTime(2026, 6, 1),
          dataFim: DateTime(2026, 6, 30),
          alunoId: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('lança exceção descritiva quando RPC ou repositório falha', () async {
      when(() => mockSupabase.rpc(
            'fn_compilar_dados_aluno',
            params: any(named: 'params'),
          )).thenAnswer((_) => mockRpcBuilder);

      _stubAwaitRpcError(mockRpcBuilder, PostgrestException(message: 'Erro interno no banco'));

      expect(
        () => exportService.gerarPdfBytes(
          tipo: 'compilado',
          dataInicio: DateTime(2026, 6, 1),
          dataFim: DateTime(2026, 6, 30),
          alunoId: 'aluno-123',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ExportService - Métodos de Exportação Completa (Salvar em Disco e Compartilhar)', () {
    setUpAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getTemporaryDirectory') {
            return Directory.systemTemp.path;
          }
          return null;
        },
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider_windows'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getTemporaryPath') {
            return Directory.systemTemp.path;
          }
          return null;
        },
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (MethodCall methodCall) async {
          return 'success';
        },
      );
    });

    test('exportarRelatorioEmPdf gera arquivo e chama share sem erros', () async {
      when(() => mockRelatoriosRepository.gerarRelatorio(
            tipo: any(named: 'tipo'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: any(named: 'campoId'),
          )).thenAnswer((_) async => [
            {'nome': 'João', 'horas': 40}
          ]);

      await exportService.exportarRelatorioEmPdf(
        tipo: 'atividades',
        dataInicio: DateTime(2026, 6, 1),
        dataFim: DateTime(2026, 6, 30),
      );

      verify(() => mockRelatoriosRepository.gerarRelatorio(
            tipo: 'atividades',
            dataInicio: DateTime(2026, 6, 1),
            dataFim: DateTime(2026, 6, 30),
            campoId: null,
          )).called(1);
    });

    test('exportarRelatorioEmCsv gera arquivo e chama share sem erros', () async {
      when(() => mockRelatoriosRepository.gerarRelatorio(
            tipo: any(named: 'tipo'),
            dataInicio: any(named: 'dataInicio'),
            dataFim: any(named: 'dataFim'),
            campoId: any(named: 'campoId'),
          )).thenAnswer((_) async => [
            {'nome': 'Maria', 'horas': 20}
          ]);

      await exportService.exportarRelatorioEmCsv(
        tipo: 'frequencia',
        dataInicio: DateTime(2026, 6, 1),
        dataFim: DateTime(2026, 6, 30),
      );

      verify(() => mockRelatoriosRepository.gerarRelatorio(
            tipo: 'frequencia',
            dataInicio: DateTime(2026, 6, 1),
            dataFim: DateTime(2026, 6, 30),
            campoId: null,
          )).called(1);
    });
  });
}
