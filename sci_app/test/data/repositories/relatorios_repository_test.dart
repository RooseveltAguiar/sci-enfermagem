import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/data/repositories/relatorios_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

void _stubAwait(
  MockPostgrestFilterBuilder builder, {
  List<Map<String, dynamic>> value = const [],
  Object? error,
}) {
  when(() => builder.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    if (error != null) {
      final onError = invocation.namedArguments[#onError] as Function?;
      if (onError != null) {
        Future.microtask(() => onError(error, StackTrace.current));
        return Future<dynamic>.value(null);
      }
      return Future<dynamic>.error(error);
    }
    final onValue = invocation.positionalArguments[0] as Function;
    return Future<dynamic>.value(onValue(value));
  });
}

void main() {
  late MockSupabaseClient mockClient;
  late MockPostgrestFilterBuilder mockFilterBuilder;
  late RelatoriosRepository repository;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockClient = MockSupabaseClient();
    mockFilterBuilder = MockPostgrestFilterBuilder();
    repository = RelatoriosRepository(mockClient);
  });

  group('RelatoriosRepository - mapTipoParaRpc', () {
    test('mapea todos os 6 tipos conhecidos corretamente', () {
      expect(repository.mapTipoParaRpc('frequencia'), 'fn_relatorio_frequencia');
      expect(repository.mapTipoParaRpc('atividades'), 'fn_relatorio_atividades');
      expect(repository.mapTipoParaRpc('avaliacoes'), 'fn_relatorio_avaliacoes');
      expect(
          repository.mapTipoParaRpc('internos_campo'), 'fn_relatorio_internos_em_campo');
      expect(
          repository.mapTipoParaRpc('locais_estagio'), 'fn_relatorio_locais_estagio');
      expect(
          repository.mapTipoParaRpc('supervisores'), 'fn_relatorio_supervisores');
    });

    test('lança ArgumentError para tipo desconhecido', () {
      expect(() => repository.mapTipoParaRpc('invalido'), throwsArgumentError);
    });
  });

  group('RelatoriosRepository - gerarRelatorio', () {
    test('chama rpc correspondente e retorna lista de mapas', () async {
      when(() => mockClient.rpc('fn_relatorio_frequencia', params: any(named: 'params')))
          .thenAnswer((_) => mockFilterBuilder);

      _stubAwait(mockFilterBuilder, value: [
        {'aluno': 'Ana', 'total_horas': 40}
      ]);

      final resultado = await repository.gerarRelatorio(
        tipo: 'frequencia',
        dataInicio: DateTime(2026, 6, 1),
        dataFim: DateTime(2026, 6, 30),
      );

      expect(resultado.length, 1);
      expect(resultado.first['aluno'], 'Ana');
      expect(resultado.first['total_horas'], 40);
    });

    test('envia parâmetro p_campo_id quando especificado', () async {
      when(() => mockClient.rpc('fn_relatorio_atividades', params: any(named: 'params')))
          .thenAnswer((_) => mockFilterBuilder);

      _stubAwait(mockFilterBuilder, value: []);

      await repository.gerarRelatorio(
        tipo: 'atividades',
        dataInicio: DateTime(2026, 6, 1),
        dataFim: DateTime(2026, 6, 30),
        campoId: 'campo-123',
      );

      final captured = verify(() => mockClient.rpc('fn_relatorio_atividades',
              params: captureAny(named: 'params')))
          .captured
          .single as Map<String, dynamic>;

      expect(captured['p_campo_id'], 'campo-123');
      expect(captured['p_data_inicio'], '2026-06-01');
      expect(captured['p_data_fim'], '2026-06-30');
    });
  });
}
