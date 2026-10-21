// test/data/repositories/usuarios_repository_test.dart
//
// UsuariosRepository aceita SupabaseClient opcional no construtor
// ([SupabaseClient? supabase] : _supabase = supabase ?? Supabase.instance.client)
// — diferente de AvaliacoesNotifier, isso permite injeção direta de
// mock sem precisar de refactor. Testado aqui construindo
// UsuariosRepository(mockClient) diretamente.
//
// Pré-verificado no banco antes de escrever este arquivo (não por
// suposição): RLS de "usuarios: select" permite professor/coordenação
// verem todas as linhas — então verificarDuplicidadeCpf() não esbarra
// em RLS ao checar duplicidade fora do próprio usuário.
//
// LIMITAÇÃO HONESTA: mesma de sempre — sem `flutter analyze`/`pub get`
// neste ambiente. Lógica verificada linha a linha contra
// usuarios_repository.dart real.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sci_app/data/repositories/usuarios_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<PostgrestList> {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

void _stubAwait(
  MockPostgrestFilterBuilder builder, {
  PostgrestList value = const [],
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
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockFunctionsClient mockFunctions;
  late UsuariosRepository repository;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockClient = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockFunctions = MockFunctionsClient();
    repository = UsuariosRepository(mockClient);

    when(() => mockClient.from(any())).thenAnswer((_) => mockQueryBuilder);
    when(() => mockClient.functions).thenReturn(mockFunctions);
  });

  group('UsuariosRepository.listarUsuariosPorPerfil', () {
    test('consulta vw_usuarios_publico (não a tabela usuarios direto) '
        'filtrando por perfil e ordenando por nome', () async {
      final filterBuilder = MockPostgrestFilterBuilder();
      when(() => mockQueryBuilder.select()).thenAnswer((_) => filterBuilder);
      when(() => filterBuilder.eq('perfil', 'aluno')).thenAnswer((_) => filterBuilder);
      when(() => filterBuilder.order('nome', ascending: true))
          .thenAnswer((_) => filterBuilder);
      _stubAwait(filterBuilder, value: []);

      await repository.listarUsuariosPorPerfil('aluno');

      verify(() => mockClient.from('vw_usuarios_publico')).called(1);
      verify(() => filterBuilder.eq('perfil', 'aluno')).called(1);
      verify(() => filterBuilder.order('nome', ascending: true)).called(1);
    });
  });

  group('UsuariosRepository.verificarDuplicidadeCpf', () {
    test('encontra na primeira checagem (dígitos) e NÃO faz a '
        'segunda consulta (com máscara) — curto-circuito', () async {
      const cpfComMascara = '529.982.247-25';
      const cpfDigitos = '52998224725';

      final filterBuilder = MockPostgrestFilterBuilder();
      when(() => mockQueryBuilder.select('id')).thenAnswer((_) => filterBuilder);
      when(() => filterBuilder.eq('cpf', cpfDigitos))
          .thenAnswer((_) => filterBuilder);
      _stubAwait(filterBuilder, value: [
        {'id': 'usuario-existente'}
      ]);

      final result = await repository.verificarDuplicidadeCpf(cpfComMascara);

      expect(result, true);
      verify(() => filterBuilder.eq('cpf', cpfDigitos)).called(1);
      verifyNever(() => filterBuilder.eq('cpf', cpfComMascara));
    });

    test('não encontra em nenhuma das duas checagens → false',
        () async {
      const cpfComMascara = '529.982.247-25';
      const cpfDigitos = '52998224725';

      final filterBuilder = MockPostgrestFilterBuilder();
      when(() => mockQueryBuilder.select('id')).thenAnswer((_) => filterBuilder);
      when(() => filterBuilder.eq('cpf', cpfDigitos))
          .thenAnswer((_) => filterBuilder);
      when(() => filterBuilder.eq('cpf', cpfComMascara))
          .thenAnswer((_) => filterBuilder);
      _stubAwait(filterBuilder, value: []);

      final result = await repository.verificarDuplicidadeCpf(cpfComMascara);

      expect(result, false);
    });

    test(
      'quando a entrada já vem sem máscara, as duas checagens usam '
      'exatamente a mesma string — comportamento correto mas revela '
      'que a segunda consulta é redundante neste caso (nunca achei '
      'nenhum CPF armazenado com máscara em toda a base de testes '
      'desta sprint — a coluna sempre guarda dígitos puros)',
      () async {
        const cpfSemMascara = '52998224705';

        final filterBuilder = MockPostgrestFilterBuilder();
        when(() => mockQueryBuilder.select('id')).thenAnswer((_) => filterBuilder);
        when(() => filterBuilder.eq('cpf', cpfSemMascara))
            .thenAnswer((_) => filterBuilder);
        _stubAwait(filterBuilder, value: []);

        final result =
            await repository.verificarDuplicidadeCpf(cpfSemMascara);

        expect(result, false);
        // Ambas as chamadas usam a mesma string — mocktail conta as
        // duas invocações mesmo com o mesmo argumento.
        verify(() => filterBuilder.eq('cpf', cpfSemMascara)).called(2);
      },
    );
  });

  group('UsuariosRepository.criarUsuario', () {
    test('invoca a Edge Function criar-usuario com o payload correto '
        'e retorna o corpo da resposta em sucesso (status 200)',
        () async {
      when(() => mockFunctions.invoke(
            'criar-usuario',
            body: any(named: 'body'),
          )).thenAnswer((_) async => FunctionResponse(
            status: 200,
            data: {'id': 'novo-id', 'senha_temporaria': 'Abc123!@'},
          ));

      final result = await repository.criarUsuario(
        cpf: '52998224725',
        nome: 'Novo Usuário',
        perfil: 'aluno',
        email: 'novo@sci.uece.br',
      );

      expect(result['id'], 'novo-id');
      expect(result['senha_temporaria'], 'Abc123!@');

      final captured = verify(() => mockFunctions.invoke(
            'criar-usuario',
            body: captureAny(named: 'body'),
          )).captured.single as Map;

      expect(captured['cpf'], '52998224725');
      expect(captured['nome'], 'Novo Usuário');
      expect(captured['perfil'], 'aluno');
      expect(captured['email'], 'novo@sci.uece.br');
    });

    test('status != 200 com corpo {"error": "cpf_ja_cadastrado"} '
        'lança Exception com essa mensagem', () async {
      when(() => mockFunctions.invoke(
            'criar-usuario',
            body: any(named: 'body'),
          )).thenAnswer((_) async => FunctionResponse(
            status: 409,
            data: {'error': 'cpf_ja_cadastrado'},
          ));

      expect(
        () => repository.criarUsuario(
          cpf: '11144477735',
          nome: 'Duplicata',
          perfil: 'aluno',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'mensagem',
            contains('cpf_ja_cadastrado'),
          ),
        ),
      );
    });

    test('status != 200 sem corpo de erro reconhecível cai na '
        'mensagem genérica "Falha ao criar usuário."', () async {
      when(() => mockFunctions.invoke(
            'criar-usuario',
            body: any(named: 'body'),
          )).thenAnswer((_) async => FunctionResponse(
            status: 500,
            data: null,
          ));

      expect(
        () => repository.criarUsuario(
          cpf: '52998224725',
          nome: 'Teste',
          perfil: 'aluno',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'mensagem',
            contains('Falha ao criar usuário.'),
          ),
        ),
      );
    });
  });

  group('UsuariosRepository.editarUsuario', () {
    test('envia apenas nome e email — nunca cpf ou perfil (imutáveis '
        'por trigger)', () async {
      final filterBuilder = MockPostgrestFilterBuilder();
      when(() => mockQueryBuilder.update(any())).thenAnswer((_) => filterBuilder);
      when(() => filterBuilder.eq('id', 'user-001'))
          .thenAnswer((_) => filterBuilder);
      _stubAwait(filterBuilder);

      await repository.editarUsuario(
        id: 'user-001',
        nome: 'Nome Editado',
        email: 'editado@sci.uece.br',
      );

      final captured = verify(() => mockQueryBuilder.update(captureAny()))
          .captured
          .single as Map;

      expect(captured.keys, containsAll(['nome', 'email']));
      expect(captured.containsKey('cpf'), isFalse);
      expect(captured.containsKey('perfil'), isFalse);
      expect(captured['nome'], 'Nome Editado');
    });
  });

  group('UsuariosRepository.desativarUsuario / reativarUsuario', () {
    test('desativarUsuario envia ativo=false e deleted_at preenchido '
        '(ISO 8601)', () async {
      final filterBuilder = MockPostgrestFilterBuilder();
      when(() => mockQueryBuilder.update(any())).thenAnswer((_) => filterBuilder);
      when(() => filterBuilder.eq('id', 'user-002'))
          .thenAnswer((_) => filterBuilder);
      _stubAwait(filterBuilder);

      await repository.desativarUsuario('user-002');

      final captured = verify(() => mockQueryBuilder.update(captureAny()))
          .captured
          .single as Map;

      expect(captured['ativo'], false);
      expect(captured['deleted_at'], isNotNull);
      expect(
        () => DateTime.parse(captured['deleted_at'] as String),
        returnsNormally,
      );
    });

    test('reativarUsuario envia ativo=true e deleted_at=null '
        'explicitamente (não omitido)', () async {
      final filterBuilder = MockPostgrestFilterBuilder();
      when(() => mockQueryBuilder.update(any())).thenAnswer((_) => filterBuilder);
      when(() => filterBuilder.eq('id', 'user-003'))
          .thenAnswer((_) => filterBuilder);
      _stubAwait(filterBuilder);

      await repository.reativarUsuario('user-003');

      final captured = verify(() => mockQueryBuilder.update(captureAny()))
          .captured
          .single as Map;

      expect(captured['ativo'], true);
      expect(captured.containsKey('deleted_at'), isTrue,
          reason: 'deleted_at precisa estar EXPLICITAMENTE presente '
              'como null no payload — se a chave estivesse ausente, '
              'o backend não saberia que deve limpar o campo');
      expect(captured['deleted_at'], isNull);
    });
  });
}
