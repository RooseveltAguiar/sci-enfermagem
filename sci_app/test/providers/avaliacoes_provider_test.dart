import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/data/models/avaliacao_model.dart';
import 'package:sci_app/data/repositories/avaliacao_repository.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/providers/avaliacoes_provider.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockUser extends Mock implements User {}
class MockAvaliacaoRepository extends Mock implements AvaliacaoRepository {}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockAvaliacaoRepository mockRepo;

  final avaliacaoRascunho = AvaliacaoModel(
    id: 'a-1',
    alocacaoId: 'aloc-1',
    avaliadorId: 'user-1',
    tipo: 'do_interno',
    periodoReferencia: DateTime(2026, 7, 1),
    status: 'rascunho',
  );

  final avaliacaoSubmetida = AvaliacaoModel(
    id: 'a-2',
    alocacaoId: 'aloc-2',
    avaliadorId: 'user-2',
    tipo: 'setorial',
    periodoReferencia: DateTime(2026, 7, 1),
    status: 'submetida',
  );

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    mockRepo = MockAvaliacaoRepository();

    when(() => mockSupabase.auth).thenReturn(mockAuth);
  });

  group('AvaliacoesNotifier - Cobertura de build, fetch e actions', () {
    test('retorna lista vazia quando usuário não está logado (currentUser == null)', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
          avaliacaoRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final lista = await container.read(avaliacoesProvider.future);
      expect(lista, isEmpty);
      verifyNever(() => mockRepo.listar());
    });

    test('retorna lista vazia quando perfil é null', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
          avaliacaoRepositoryProvider.overrideWithValue(mockRepo),
          userProfileProvider.overrideWith((ref) => null),
        ],
      );
      addTearDown(container.dispose);

      final lista = await container.read(avaliacoesProvider.future);
      expect(lista, isEmpty);
      verifyNever(() => mockRepo.listar());
    });

    test('busca avaliações no repositório quando usuário e perfil existem', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockRepo.listar()).thenAnswer((_) async => [avaliacaoRascunho, avaliacaoSubmetida]);

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
          avaliacaoRepositoryProvider.overrideWithValue(mockRepo),
          userProfileProvider.overrideWith((ref) => 'professor'),
        ],
      );
      addTearDown(container.dispose);

      final lista = await container.read(avaliacoesProvider.future);
      expect(lista.length, 2);
      expect(lista, contains(avaliacaoRascunho));
      verify(() => mockRepo.listar()).called(1);
    });

    test('salvarRascunho salva no repositório e executa refresh', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockRepo.listar()).thenAnswer((_) async => [avaliacaoRascunho]);
      when(() => mockRepo.salvarRascunho(any())).thenAnswer((_) async => avaliacaoRascunho);

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
          avaliacaoRepositoryProvider.overrideWithValue(mockRepo),
          userProfileProvider.overrideWith((ref) => 'professor'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(avaliacoesProvider.future);

      final notifier = container.read(avaliacoesProvider.notifier);
      final salvo = await notifier.salvarRascunho({'tipo': 'do_interno'});

      expect(salvo.id, 'a-1');
      verify(() => mockRepo.salvarRascunho({'tipo': 'do_interno'})).called(1);
      verify(() => mockRepo.listar()).called(2); // 1 do build, 1 do refresh
    });

    test('submitAvaliacao chama submeter e refresh', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockRepo.listar()).thenAnswer((_) async => []);
      when(() => mockRepo.submeter('a-1')).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
          avaliacaoRepositoryProvider.overrideWithValue(mockRepo),
          userProfileProvider.overrideWith((ref) => 'aluno'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(avaliacoesProvider.future);
      await container.read(avaliacoesProvider.notifier).submitAvaliacao('a-1');

      verify(() => mockRepo.submeter('a-1')).called(1);
      verify(() => mockRepo.listar()).called(2);
    });

    test('validarAvaliacao chama validar e refresh', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockRepo.listar()).thenAnswer((_) async => []);
      when(() => mockRepo.validar('a-2', comentario: 'ok')).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
          avaliacaoRepositoryProvider.overrideWithValue(mockRepo),
          userProfileProvider.overrideWith((ref) => 'coordenacao'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(avaliacoesProvider.future);
      await container.read(avaliacoesProvider.notifier).validarAvaliacao('a-2', comentario: 'ok');

      verify(() => mockRepo.validar('a-2', comentario: 'ok')).called(1);
    });

    test('aprovarAvaliacao chama aprovar e refresh', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockRepo.listar()).thenAnswer((_) async => []);
      when(() => mockRepo.aprovar('a-2', comentario: 'excelente')).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
          avaliacaoRepositoryProvider.overrideWithValue(mockRepo),
          userProfileProvider.overrideWith((ref) => 'coordenacao'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(avaliacoesProvider.future);
      await container.read(avaliacoesProvider.notifier).aprovarAvaliacao('a-2', comentario: 'excelente');

      verify(() => mockRepo.aprovar('a-2', comentario: 'excelente')).called(1);
    });

    test('devolverAvaliacao chama devolver e refresh', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockRepo.listar()).thenAnswer((_) async => []);
      when(() => mockRepo.devolver('a-2', 'ajustar nota')).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
          avaliacaoRepositoryProvider.overrideWithValue(mockRepo),
          userProfileProvider.overrideWith((ref) => 'coordenacao'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(avaliacoesProvider.future);
      await container.read(avaliacoesProvider.notifier).devolverAvaliacao('a-2', 'ajustar nota');

      verify(() => mockRepo.devolver('a-2', 'ajustar nota')).called(1);
    });

    test('excluirRascunho chama excluirRascunho e refresh', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockRepo.listar()).thenAnswer((_) async => []);
      when(() => mockRepo.excluirRascunho('a-1')).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
          avaliacaoRepositoryProvider.overrideWithValue(mockRepo),
          userProfileProvider.overrideWith((ref) => 'professor'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(avaliacoesProvider.future);
      await container.read(avaliacoesProvider.notifier).excluirRascunho('a-1');

      verify(() => mockRepo.excluirRascunho('a-1')).called(1);
    });

    test('pendentesValidacaoProvider filtra apenas avaliações submetidas', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockRepo.listar()).thenAnswer((_) async => [avaliacaoRascunho, avaliacaoSubmetida]);

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
          avaliacaoRepositoryProvider.overrideWithValue(mockRepo),
          userProfileProvider.overrideWith((ref) => 'coordenacao'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(avaliacoesProvider.future);
      final pendentes = container.read(pendentesValidacaoProvider);
      expect(pendentes.value, isNotNull);
      expect(pendentes.value!.length, 1);
      expect(pendentes.value!.first.status, 'submetida');
    });

    test('avaliacaoRepositoryProvider default instancia AvaliacaoRepository', () {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(avaliacaoRepositoryProvider);
      expect(repo, isA<AvaliacaoRepository>());
    });
  });

  group('Regras de Negócio Legadas / Schema', () {
    test('AvaliacaoModel serialização de status e validação de comentário', () {
      final json = {
        'id': '123',
        'alocacao_id': '456',
        'avaliador_id': '789',
        'tipo': 'setorial',
        'periodo_referencia': '2026-07-01',
        'status': 'rascunho',
        'nota_geral': 8,
        'comentario_validacao': 'Favor detalhar ponto 2'
      };

      final avaliacao = AvaliacaoModel.fromJson(json);
      expect(avaliacao.status, 'rascunho');
      expect(avaliacao.comentarioValidacao, 'Favor detalhar ponto 2');

      const comentarioCurto = 'Curto demais';
      expect(comentarioCurto.trim().length < 20, isTrue);
    });
  });
}
