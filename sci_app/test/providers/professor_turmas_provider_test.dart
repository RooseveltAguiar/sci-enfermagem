// test/providers/professor_turmas_provider_test.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/providers/professor_turmas_provider.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestSelectBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

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

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();

    when(() => mockSupabase.auth).thenReturn(mockAuth);
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

  group('AlunoTurmaResumo', () {
    test('instanciação e propriedades com e sem campos opcionais', () {
      final a1 = AlunoTurmaResumo(
        alunoId: 'aluno-1',
        nome: 'João Silva',
        cpf: '111.111.111-11',
        turnoTipo: 'manhã',
        campoNome: 'Hospital A',
      );
      expect(a1.alunoId, 'aluno-1');
      expect(a1.nome, 'João Silva');
      expect(a1.cpf, '111.111.111-11');
      expect(a1.turnoTipo, 'manhã');
      expect(a1.campoNome, 'Hospital A');

      final a2 = AlunoTurmaResumo(
        alunoId: 'aluno-2',
        nome: 'Maria Souza',
        cpf: '222.222.222-22',
      );
      expect(a2.turnoTipo, isNull);
      expect(a2.campoNome, isNull);
    });
  });

  group('alunosDoProfessorProvider', () {
    test('retorna lista vazia quando usuário logado é null', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final container = buildContainer();
      final alunos = await container.read(alunosDoProfessorProvider.future);
      expect(alunos, isEmpty);
    });

    test('processa turnos, alocações, fallbacks nulos, deduplicação e ordenação alfabética', () async {
      when(() => mockUser.id).thenReturn('prof-123');
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockSelectBuilder = MockPostgrestSelectBuilder();

      when(() => mockSupabase.from('professor_turmas')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => mockSelectBuilder);
      when(() => mockSelectBuilder.eq('professor_id', 'prof-123'))
          .thenAnswer((_) => mockSelectBuilder);
      when(() => mockSelectBuilder.isFilter('deleted_at', null))
          .thenAnswer((_) => mockSelectBuilder);

      final mockResponse = [
        // Item com turno null -> deve dar continue
        {
          'turno_id': 't-null',
          'turnos': null,
        },
        // Item com turno válido, mas alocacoes_alunos é null ou vazia -> ignora/processa sem erro
        {
          'turno_id': 't-vazio',
          'turnos': {
            'tipo': 'noturno',
            'campos_estagio': {'nome': 'Hospital B'},
            'alocacoes_alunos': null,
          }
        },
        // Item com alocações contendo aluno incompleto (sem aluno_id ou sem usuario)
        {
          'turno_id': 't-incompleto',
          'turnos': {
            'tipo': 'tarde',
            'campos_estagio': {'nome': 'Hospital C'},
            'alocacoes_alunos': [
              {'aluno_id': null, 'usuarios': {'nome': 'X'}},
              {'aluno_id': 'a-sem-usuario', 'usuarios': null},
            ]
          }
        },
        // Item completo 1: Zé (para testar ordenação no fim da lista) e fallbacks nulos para nome e cpf
        {
          'turno_id': 't-1',
          'turnos': {
            'tipo': 'manhã',
            'campos_estagio': {'nome': 'Hospital D'},
            'alocacoes_alunos': [
              {
                'aluno_id': 'a-ze',
                'usuarios': {
                  'nome': 'Zélia Souza',
                  'cpf': '999.999.999-99',
                }
              },
              {
                'aluno_id': 'a-anonimo',
                'usuarios': {
                  'nome': null, // fallback: Aluno a-anonimo
                  'cpf': null,  // fallback: ''
                }
              }
            ]
          }
        },
        // Item completo 2: Carlos (para testar ordenação e deduplicação, caso Zélia apareça de novo em outro turno)
        {
          'turno_id': 't-2',
          'turnos': {
            'tipo': 'integral',
            'campos_estagio': {'nome': 'Hospital E'},
            'alocacoes_alunos': [
              {
                'aluno_id': 'a-carlos',
                'usuarios': {
                  'nome': 'Carlos Eduardo',
                  'cpf': '333.333.333-33',
                }
              },
              {
                // Duplicado de a-ze -> o mapa sobrescreve com os dados mais recentes do turno
                'aluno_id': 'a-ze',
                'usuarios': {
                  'nome': 'Zélia Souza',
                  'cpf': '999.999.999-99',
                }
              }
            ]
          }
        }
      ];

      _stubAwaitSelect(mockSelectBuilder, value: mockResponse);

      final container = buildContainer();
      final alunos = await container.read(alunosDoProfessorProvider.future);

      // Devemos ter 3 alunos únicos no resultado final:
      // 'a-anonimo' -> nome fallback 'Aluno a-anonimo'
      // 'a-carlos' -> 'Carlos Eduardo'
      // 'a-ze' -> 'Zélia Souza'
      expect(alunos.length, 3);

      // Verificando ordenação alfabética por nome
      expect(alunos[0].alunoId, 'a-anonimo');
      expect(alunos[0].nome, 'Aluno a-anonimo');
      expect(alunos[0].cpf, '');

      expect(alunos[1].alunoId, 'a-carlos');
      expect(alunos[1].nome, 'Carlos Eduardo');
      expect(alunos[1].cpf, '333.333.333-33');
      expect(alunos[1].turnoTipo, 'integral');
      expect(alunos[1].campoNome, 'Hospital E');

      expect(alunos[2].alunoId, 'a-ze');
      expect(alunos[2].nome, 'Zélia Souza');
    });
  });
}
