// test/providers/abono_provider_test.dart
//
// Testa AbonoNotifier.solicitarAbono contra o contrato real de
// fn_criar_abono, já homologada no banco com 4 cenários (aluno
// bloqueado, supervisor com/sem escopo, professor irrestrito) — este
// arquivo testa a camada Flutter que consome essa RPC, não repete a
// validação de autorização (isso já é coberto pela função em si,
// SECURITY DEFINER, e não pode ser reproduzido fielmente com mock).
//
// Usa arquivo temporário REAL (dart:io) em vez de mockar File — File
// não é uma interface própria para Mocktail, e criar um arquivo
// pequeno de verdade no diretório temp do sistema é mais simples e
// mais fiel do que tentar simular.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sci_app/providers/abono_provider.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}

class MockStorageFileApi extends Mock implements StorageFileApi {}

class MockPostgrestRpcBuilder extends Mock
    implements PostgrestFilterBuilder<dynamic> {}

class MockPostgrestSelectBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class FakeFile extends Fake implements File {}

void _stubAwaitRpc(MockPostgrestRpcBuilder builder, {dynamic value}) {
  when(() => builder.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onValue = invocation.positionalArguments[0] as Function;
    return Future<dynamic>.value(onValue(value));
  });
}

void _stubAwaitRpcError(MockPostgrestRpcBuilder builder, Object error) {
  when(() => builder.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onError = invocation.namedArguments[#onError] as Function?;
    if (onError != null) {
      if (onError is Function(Object, StackTrace)) {
        return Future<dynamic>.sync(() => onError(error, StackTrace.current));
      } else if (onError is Function(Object)) {
        return Future<dynamic>.sync(() => onError(error));
      } else {
        return Future<dynamic>.sync(() {
          try {
            return (onError as dynamic)(error, StackTrace.current);
          } catch (_) {
            return (onError as dynamic)(error);
          }
        });
      }
    }
    return Future<dynamic>.error(error);
  });
}

void _stubAwaitSelect(
  MockPostgrestSelectBuilder builder, {
  List<Map<String, dynamic>> value = const [],
}) {
  when(() => builder.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onValue = invocation.positionalArguments[0] as Function;
    return Future<dynamic>.value(onValue(value));
  });
}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockSupabaseStorageClient mockStorage;
  late MockStorageFileApi mockFileApi;
  late MockPostgrestRpcBuilder mockRpcBuilder;
  late File tempFile;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<String>[]);
    registerFallbackValue(FakeFile());
  });

  setUp(() async {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    mockStorage = MockSupabaseStorageClient();
    mockFileApi = MockStorageFileApi();
    mockRpcBuilder = MockPostgrestRpcBuilder();

    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.id).thenReturn('supervisor-abc');
    when(() => mockSupabase.storage).thenReturn(mockStorage);
    when(() => mockStorage.from('documentos-abono')).thenReturn(mockFileApi);

    final dir = await Directory.systemTemp.createTemp('abono_test_');
    tempFile = File('${dir.path}/atestado.pdf');
    await tempFile.writeAsBytes(List.filled(1024, 0));
  });

  tearDown(() async {
    if (await tempFile.exists()) {
      await tempFile.parent.delete(recursive: true);
    }
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(mockSupabase),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('AbonoNotifier.solicitarAbono — caminho de sucesso', () {
    test(
      'faz upload, chama fn_criar_abono com os 6 parâmetros corretos, '
      'termina em AsyncData(null)',
      () async {
        when(() => mockFileApi.upload(any(), any()))
            .thenAnswer((_) async => 'supervisor-abc/123.pdf');
        when(() => mockSupabase.rpc('fn_criar_abono',
                params: any(named: 'params')))
            .thenAnswer((_) => mockRpcBuilder);
        _stubAwaitRpc(mockRpcBuilder, value: 'novo-abono-id');

        final container = buildContainer();
        final notifier = container.read(abonoProvider.notifier);

        await notifier.solicitarAbono(
          frequenciaId: 'freq-001',
          justificativa:
              'Justificativa com pelo menos cinquenta caracteres para '
              'passar na constraint do banco de dados real.',
          documento: tempFile,
        );

        final state = container.read(abonoProvider);
        expect(state.hasError, false);
        expect(state.isLoading, false);

        final captured = verify(() => mockSupabase.rpc('fn_criar_abono',
                params: captureAny(named: 'params')))
            .captured
            .single as Map<String, dynamic>;

        expect(captured['p_frequencia_id'], 'freq-001');
        expect(captured.containsKey('p_justificativa'), isTrue);
        expect(captured['p_nome_arquivo'], 'atestado.pdf');
        expect(captured.containsKey('p_caminho_referencia'), isTrue);
        expect(captured['p_mime_type'], 'application/pdf');
        expect(captured['p_tamanho_bytes'], 1024);

        verifyNever(() => mockFileApi.remove(any()));
      },
    );

    test('caminho no storage usa currentUser.id como prefixo', () async {
      when(() => mockFileApi.upload(any(), any()))
          .thenAnswer((_) async => 'ignored');
      when(() => mockSupabase.rpc('fn_criar_abono',
              params: any(named: 'params')))
          .thenAnswer((_) => mockRpcBuilder);
      _stubAwaitRpc(mockRpcBuilder, value: 'abono-id');

      final container = buildContainer();
      final notifier = container.read(abonoProvider.notifier);

      await notifier.solicitarAbono(
        frequenciaId: 'freq-002',
        justificativa:
            'Outra justificativa com cinquenta caracteres no mínimo, '
            'garantindo passar na regra do banco.',
        documento: tempFile,
      );

      final captured =
          verify(() => mockFileApi.upload(captureAny(), any())).captured;
      expect((captured.single as String).startsWith('supervisor-abc/'),
          isTrue);
    });
  });

  group(
    'AbonoNotifier.solicitarAbono — os 2 códigos reais de erro da RPC '
    '(já confirmados no banco: perfil_nao_autorizado, '
    'fora_do_escopo_supervisor)',
    () {
      test('perfil_nao_autorizado → mensagem amigável específica + '
          'arquivo removido do storage', () async {
        when(() => mockFileApi.upload(any(), any()))
            .thenAnswer((_) async => 'path');
        when(() => mockSupabase.rpc('fn_criar_abono',
                params: any(named: 'params')))
            .thenAnswer((_) => mockRpcBuilder);
        _stubAwaitRpcError(
          mockRpcBuilder,
          const PostgrestException(
              message: 'perfil_nao_autorizado',
              code: 'perfil_nao_autorizado'),
        );
        when(() => mockFileApi.remove(any()))
            .thenAnswer((_) async => <FileObject>[]);

        final container = buildContainer();
        final notifier = container.read(abonoProvider.notifier);

        await notifier.solicitarAbono(
          frequenciaId: 'freq-003',
          justificativa:
              'Justificativa com cinquenta caracteres no mínimo para '
              'este teste de erro específico.',
          documento: tempFile,
        );

        final state = container.read(abonoProvider);
        expect(state.hasError, true);
        expect(
          state.error.toString(),
          contains('apenas supervisores e professores podem abonar'),
        );
        verify(() => mockFileApi.remove(any())).called(1);
      });

      test('fora_do_escopo_supervisor → mensagem amigável específica + '
          'arquivo removido do storage', () async {
        when(() => mockFileApi.upload(any(), any()))
            .thenAnswer((_) async => 'path');
        when(() => mockSupabase.rpc('fn_criar_abono',
                params: any(named: 'params')))
            .thenAnswer((_) => mockRpcBuilder);
        _stubAwaitRpcError(
          mockRpcBuilder,
          const PostgrestException(
              message: 'fora_do_escopo_supervisor',
              code: 'fora_do_escopo_supervisor'),
        );
        when(() => mockFileApi.remove(any()))
            .thenAnswer((_) async => <FileObject>[]);

        final container = buildContainer();
        final notifier = container.read(abonoProvider.notifier);

        await notifier.solicitarAbono(
          frequenciaId: 'freq-004',
          justificativa:
              'Justificativa com cinquenta caracteres no mínimo para '
              'este segundo teste de erro.',
          documento: tempFile,
        );

        final state = container.read(abonoProvider);
        expect(state.hasError, true);
        expect(
          state.error.toString(),
          contains('não está alocado ao seu campo de estágio'),
        );
        verify(() => mockFileApi.remove(any())).called(1);
      });

      test('código desconhecido → rethrow do erro original + arquivo '
          'removido mesmo assim', () async {
        when(() => mockFileApi.upload(any(), any()))
            .thenAnswer((_) async => 'path');
        when(() => mockSupabase.rpc('fn_criar_abono',
                params: any(named: 'params')))
            .thenAnswer((_) => mockRpcBuilder);
        _stubAwaitRpcError(
          mockRpcBuilder,
          const PostgrestException(
              message: 'erro_totalmente_diferente', code: 'outro_erro'),
        );
        when(() => mockFileApi.remove(any()))
            .thenAnswer((_) async => <FileObject>[]);

        final container = buildContainer();
        final notifier = container.read(abonoProvider.notifier);

        await notifier.solicitarAbono(
          frequenciaId: 'freq-005',
          justificativa:
              'Justificativa com cinquenta caracteres no mínimo para '
              'este terceiro teste de erro.',
          documento: tempFile,
        );

        final state = container.read(abonoProvider);
        expect(state.hasError, true);
        verify(() => mockFileApi.remove(any())).called(1);
      });
    },
  );

  group('AbonoNotifier.solicitarAbono — falha no upload em si', () {
    test('upload falha → nunca chega a chamar a RPC, estado vira erro',
        () async {
      when(() => mockFileApi.upload(any(), any()))
          .thenThrow(Exception('Falha de rede no upload'));

      final container = buildContainer();
      final notifier = container.read(abonoProvider.notifier);

      await notifier.solicitarAbono(
        frequenciaId: 'freq-006',
        justificativa:
            'Justificativa com cinquenta caracteres no mínimo para '
            'este teste de falha de upload.',
        documento: tempFile,
      );

      final state = container.read(abonoProvider);
      expect(state.hasError, true);
      verifyNever(() => mockSupabase.rpc('fn_criar_abono',
          params: any(named: 'params')));
    });
  });

  group('AbonoNotifier.solicitarAbono — detecção de MIME type', () {
    test('.png é detectado corretamente como image/png', () async {
      final pngFile = File('${tempFile.parent.path}/imagem.png');
      await pngFile.writeAsBytes(List.filled(512, 0));

      when(() => mockFileApi.upload(any(), any()))
          .thenAnswer((_) async => 'path');
      when(() => mockSupabase.rpc('fn_criar_abono',
              params: any(named: 'params')))
          .thenAnswer((_) => mockRpcBuilder);
      _stubAwaitRpc(mockRpcBuilder, value: 'abono-id');

      final container = buildContainer();
      final notifier = container.read(abonoProvider.notifier);

      await notifier.solicitarAbono(
        frequenciaId: 'freq-007',
        justificativa:
            'Justificativa com cinquenta caracteres no mínimo para '
            'este teste de MIME type.',
        documento: pngFile,
      );

      final captured = verify(() => mockSupabase.rpc('fn_criar_abono',
              params: captureAny(named: 'params')))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['p_mime_type'], 'image/png');
    });

    test('extensão desconhecida cai em application/octet-stream',
        () async {
      final unknownFile = File('${tempFile.parent.path}/arquivo.xyz');
      await unknownFile.writeAsBytes(List.filled(10, 0));

      when(() => mockFileApi.upload(any(), any()))
          .thenAnswer((_) async => 'path');
      when(() => mockSupabase.rpc('fn_criar_abono',
              params: any(named: 'params')))
          .thenAnswer((_) => mockRpcBuilder);
      _stubAwaitRpc(mockRpcBuilder, value: 'abono-id');

      final container = buildContainer();
      final notifier = container.read(abonoProvider.notifier);

      await notifier.solicitarAbono(
        frequenciaId: 'freq-008',
        justificativa:
            'Justificativa com cinquenta caracteres no mínimo para '
            'este teste de extensão desconhecida.',
        documento: unknownFile,
      );

      final captured = verify(() => mockSupabase.rpc('fn_criar_abono',
              params: captureAny(named: 'params')))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['p_mime_type'], 'application/octet-stream');
    });
  });

  group('anexoAbonoProvider', () {
    test('retorna null quando não há abono vinculado à frequência', () async {
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockSelectBuilder = MockPostgrestSelectBuilder();

      when(() => mockSupabase.from('abonos')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any()))
          .thenAnswer((_) => mockSelectBuilder);
      when(() => mockSelectBuilder.eq('frequencia_id', 'freq-sem-abono'))
          .thenAnswer((_) => mockSelectBuilder);
      when(() => mockSelectBuilder.limit(1))
          .thenAnswer((_) => mockSelectBuilder);
      _stubAwaitSelect(mockSelectBuilder, value: []);

      final container = buildContainer();
      final anexo = await container
          .read(anexoAbonoProvider('freq-sem-abono').future);
      expect(anexo, isNull);
    });

    test('retorna null quando abono existe mas não há documento', () async {
      final mockQueryBuilderAbonos = MockSupabaseQueryBuilder();
      final mockQueryBuilderDocs = MockSupabaseQueryBuilder();
      final mockSelectBuilderAbonos = MockPostgrestSelectBuilder();
      final mockSelectBuilderDocs = MockPostgrestSelectBuilder();

      when(() => mockSupabase.from('abonos')).thenAnswer((_) => mockQueryBuilderAbonos);
      when(() => mockSupabase.from('documentos_abono'))
          .thenAnswer((_) => mockQueryBuilderDocs);

      when(() => mockQueryBuilderAbonos.select(any()))
          .thenAnswer((_) => mockSelectBuilderAbonos);
      when(() => mockSelectBuilderAbonos.eq('frequencia_id', 'freq-sem-doc'))
          .thenAnswer((_) => mockSelectBuilderAbonos);
      when(() => mockSelectBuilderAbonos.limit(1))
          .thenAnswer((_) => mockSelectBuilderAbonos);
      _stubAwaitSelect(mockSelectBuilderAbonos, value: [
        {'id': 'abono-123', 'justificativa': 'Doença'}
      ]);

      when(() => mockQueryBuilderDocs.select(any()))
          .thenAnswer((_) => mockSelectBuilderDocs);
      when(() => mockSelectBuilderDocs.eq('abono_id', 'abono-123'))
          .thenAnswer((_) => mockSelectBuilderDocs);
      when(() => mockSelectBuilderDocs.limit(1))
          .thenAnswer((_) => mockSelectBuilderDocs);
      _stubAwaitSelect(mockSelectBuilderDocs, value: []);

      final container = buildContainer();
      final anexo = await container
          .read(anexoAbonoProvider('freq-sem-doc').future);
      expect(anexo, isNull);
    });

    test('retorna AnexoAbonoInfo com signedUrl quando abono e documento existem', () async {
      final mockQueryBuilderAbonos = MockSupabaseQueryBuilder();
      final mockQueryBuilderDocs = MockSupabaseQueryBuilder();
      final mockSelectBuilderAbonos = MockPostgrestSelectBuilder();
      final mockSelectBuilderDocs = MockPostgrestSelectBuilder();

      when(() => mockSupabase.from('abonos')).thenAnswer((_) => mockQueryBuilderAbonos);
      when(() => mockSupabase.from('documentos_abono'))
          .thenAnswer((_) => mockQueryBuilderDocs);

      when(() => mockQueryBuilderAbonos.select(any()))
          .thenAnswer((_) => mockSelectBuilderAbonos);
      when(() => mockSelectBuilderAbonos.eq('frequencia_id', 'freq-completa'))
          .thenAnswer((_) => mockSelectBuilderAbonos);
      when(() => mockSelectBuilderAbonos.limit(1))
          .thenAnswer((_) => mockSelectBuilderAbonos);
      _stubAwaitSelect(mockSelectBuilderAbonos, value: [
        {'id': 'abono-999', 'justificativa': 'Atestado médico de 3 dias'}
      ]);

      when(() => mockQueryBuilderDocs.select(any()))
          .thenAnswer((_) => mockSelectBuilderDocs);
      when(() => mockSelectBuilderDocs.eq('abono_id', 'abono-999'))
          .thenAnswer((_) => mockSelectBuilderDocs);
      when(() => mockSelectBuilderDocs.limit(1))
          .thenAnswer((_) => mockSelectBuilderDocs);
      _stubAwaitSelect(mockSelectBuilderDocs, value: [
        {
          'caminho_referencia': 'supervisor-abc/123.pdf',
          'nome_arquivo': 'atestado.pdf',
          'mime_type': 'application/pdf',
        }
      ]);

      when(() => mockFileApi.createSignedUrl('supervisor-abc/123.pdf', 3600))
          .thenAnswer((_) async => 'https://signed.url/atestado.pdf');

      final container = buildContainer();
      final anexo = await container
          .read(anexoAbonoProvider('freq-completa').future);

      expect(anexo, isNotNull);
      expect(anexo!.abonoId, 'abono-999');
      expect(anexo.justificativa, 'Atestado médico de 3 dias');
      expect(anexo.nomeArquivo, 'atestado.pdf');
      expect(anexo.caminhoReferencia, 'supervisor-abc/123.pdf');
      expect(anexo.mimeType, 'application/pdf');
      expect(anexo.signedUrl, 'https://signed.url/atestado.pdf');
    });
  });
}
