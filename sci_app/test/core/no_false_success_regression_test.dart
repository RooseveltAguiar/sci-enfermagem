import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/providers/atividades_provider.dart';
import 'package:sci_app/providers/visitas_provider.dart';
import 'package:sci_app/providers/abono_provider.dart';
import 'package:sci_app/data/repositories/avaliacao_repository.dart';
import 'package:sci_app/data/repositories/conflitos_repository.dart';
import 'package:sci_app/data/repositories/sugestoes_repository.dart';
import 'package:sci_app/data/repositories/termos_repository.dart';
import 'package:sci_app/data/repositories/usuarios_repository.dart';
import 'package:sci_app/data/models/usuario_model.dart';
import 'package:sci_app/data/repositories/transferencia_repository.dart';

import 'package:sci_app/presentation/screens/coordenacao/campo_form_screen.dart';
import 'package:sci_app/presentation/screens/atividades/registrar_atividade_screen.dart';
import 'package:sci_app/presentation/screens/coordenacao/usuarios_form_screen.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockUser extends Mock implements User {}
class MockStorageClient extends Mock implements SupabaseStorageClient {}
class MockStorageFileApi extends Mock implements StorageFileApi {}
class MockFile extends Mock implements File {}
class FakeFile extends Fake implements File {}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockFile mockFile;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(FakeFile());
    registerFallbackValue(MockFile());
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    mockFile = MockFile();

    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.id).thenReturn('user_test_123');

    when(() => mockFile.path).thenReturn('atestado_medico.pdf');
    when(() => mockFile.length()).thenAnswer((_) async => 2048);
  });

  group('Gate Permanente DoD: Testes de Regressão Anti-Falso Sucesso (Nível de Repositório)', () {
    test('atividades — repositório lança exceção quando Supabase falha na escrita', () async {
      when(() => mockSupabase.from('alocacoes_alunos')).thenThrow(const PostgrestException(message: 'Erro de alocação'));
      when(() => mockSupabase.from('atividades')).thenThrow(const PostgrestException(message: 'Erro de permissão Supabase em Atividades'));

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(atividadesAlunoProvider.notifier);

      expect(
        () => notifier.registrarAtividades(
          selecionadas: ['Aferição de pressão arterial'],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('visitas_tecnicas — repositório lança exceção quando Supabase falha no registro', () async {
      when(() => mockSupabase.from('visitas_tecnicas')).thenThrow(const PostgrestException(message: 'Falha de rede Supabase em Visitas'));

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(visitasServiceProvider);

      expect(
        () => service.registrarVisita(
          campoId: 'c-10',
          relato: 'Relato completo com mais de trinta caracteres obrigatorios para o teste de visita',
          lat: -3.79,
          lng: -38.52,
          gpsDisponivel: true,
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('abonos (Pendência 3) — QUANDO UPLOAD NO STORAGE FUNCIONA MAS RPC NO BANCO FALHA: EXCLUI O ARQUIVO DO STORAGE (REVERSÃO) E REGISTRA ASYNCERROR', () async {
      final mockStorage = MockStorageClient();
      final mockFileApi = MockStorageFileApi();
      when(() => mockSupabase.storage).thenReturn(mockStorage);
      when(() => mockStorage.from('documentos-abono')).thenReturn(mockFileApi);

      // 1. Upload no Storage tem sucesso
      when(() => mockFileApi.upload(any<String>(), any<File>())).thenAnswer((_) async => 'user_test_123/arquivo.pdf');
      
      // 2. Mock da exclusão/reversão no Storage
      when(() => mockFileApi.remove(any<List<String>>())).thenAnswer((_) async => []);

      // 3. RPC fn_criar_abono no PostgreSQL falha
      when(() => mockSupabase.rpc('fn_criar_abono', params: any(named: 'params')))
          .thenThrow(const PostgrestException(message: 'fora_do_escopo_supervisor'));

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(abonoProvider.notifier);

      await notifier.solicitarAbono(
        frequenciaId: 'freq_1',
        justificativa: 'Justificativa valida de teste de abono',
        documento: mockFile,
      );

      // VERIFICAÇÃO 1: A exclusão de reversão do anexo no Storage foi invocada de fato?
      verify(() => mockFileApi.remove(any<List<String>>())).called(1);

      // VERIFICAÇÃO 2: O provider está em estado de erro (sem falso sucesso)?
      expect(notifier.state.hasError, isTrue);
      expect(notifier.state.error.toString(), contains('Acesso negado: este aluno não está alocado ao seu campo de estágio.'));
    });

    test('avaliacoes — lança exceção ao tentar salvar rascunho com falha no banco', () async {
      when(() => mockSupabase.from('avaliacoes')).thenThrow(const PostgrestException(message: 'Erro RLS Supabase Avaliações'));

      final repo = AvaliacaoRepository(mockSupabase);

      expect(
        () => repo.salvarRascunho({
          'tipo': 'do_interno',
          'nota_geral': 8,
          'pontos_positivos': 'Pontos positivos com tamanho minimo valido',
          'pontos_melhoria': 'Pontos de melhoria com tamanho minimo valido',
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('sugestoes — lança exceção ao enviar sugestao com falha de escrita', () async {
      when(() => mockSupabase.from('sugestoes')).thenThrow(const PostgrestException(message: 'Erro ao inserir sugestão'));

      final repo = SugestoesRepository(mockSupabase);

      expect(
        () => repo.enviarSugestao('Melhoria nos turnos de estagio'),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('conflitos — lança exceção ao registrar conflito com erro no Supabase', () async {
      when(() => mockSupabase.from('conflitos')).thenThrow(const PostgrestException(message: 'Erro no registro de conflito'));

      final repo = ConflitosRepository(mockSupabase);

      expect(
        () => repo.registrarConflito(
          alunoId: 'aluno_1',
          campoId: 'campo_1',
          descricao: 'Conflito de horario',
          dataOcorrencia: DateTime.now(),
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('usuarios — lança exceção se a edicao de usuario falhar no Supabase', () async {
      when(() => mockSupabase.from('usuarios')).thenThrow(const PostgrestException(message: 'Falha ao editar usuário'));

      final repo = UsuariosRepository(mockSupabase);

      expect(
        () => repo.editarUsuario(id: 'usr_1', nome: 'Nome Editado'),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('termos — lança exceção ao aceitar termo sem conectividade Supabase', () async {
      when(() => mockSupabase.from('usuarios')).thenThrow(const PostgrestException(message: 'Erro ao atualizar aceite de termo'));

      final repo = TermosRepository(mockSupabase);

      expect(
        () => repo.aceitarTermo('v1.0'),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('transferencias — lança exceção com mensagem tratando falha na RPC de transferencia', () async {
      when(() => mockSupabase.rpc('fn_transferir_aluno', params: any(named: 'params')))
          .thenThrow(const PostgrestException(message: 'alocacao_dupla_detectada'));

      final repo = TransferenciaRepository(mockSupabase);

      expect(
        () => repo.transferirAluno(
          alunoId: 'aluno_1',
          campoDestinoId: 'campo_dest',
          turnoDestinoId: 'turno_dest',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Gate Permanente DoD: Testes de Regressão Anti-Falso Sucesso em Nível de UI (Widget Tests)', () {
    testWidgets('CampoFormScreen — NUNCA exibe SnackBar de sucesso quando o Supabase lança erro no salvamento (Clique Real NATIVO Sem warnIfMissed)', (tester) async {
      // Configura a física da tela virtual ampla para garantir clique 100% real sem warning
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(() => mockSupabase.from('campos_estagio')).thenThrow(const PostgrestException(message: 'Erro de conexao simulado'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
          child: const MaterialApp(
            home: CampoFormScreen(modo: 'criar'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Hospital Teste Falso Sucesso');
      
      // Clique NATIVO no botão visível
      await tester.tap(find.text('SALVAR CAMPO E HORÁRIOS'));
      await tester.pumpAndSettle();

      // Confirmação no BottomSheet é obrigatória
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      // Validação estrita de UI: SnackBar de SUCESSO NUNCA deve ser exibida
      expect(find.text('Campo de estágio salvo com sucesso!'), findsNothing);
      expect(find.textContaining('Erro ao salvar campo de estágio'), findsOneWidget);
    });

    testWidgets('CampoFormScreen (modo editar) — EXIBE SnackBar de erro quando falha em _carregarDadosCampoReal', (tester) async {
      when(() => mockSupabase.from('campos_estagio')).thenThrow(const PostgrestException(message: 'Falha de banco ao ler campo'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
          child: const MaterialApp(
            home: CampoFormScreen(modo: 'editar', campoId: 'c_999'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Validação estrita de UI: DEVE exibir a SnackBar de ERRO REAL de carregamento
      expect(find.textContaining('Erro ao carregar dados do campo'), findsOneWidget);
    });

    testWidgets('UsuariosFormScreen — NUNCA exibe SnackBar de sucesso quando a edicao de usuario falhar no Supabase', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(() => mockSupabase.from('usuarios')).thenThrow(const PostgrestException(message: 'Erro de conexao Supabase'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
          child: MaterialApp(
            home: UsuariosFormScreen(
              modo: 'editar',
              usuario: UsuarioModel(
                id: 'u1',
                cpf: '12345678901',
                nome: 'Maria da Silva Teste',
                perfil: 'aluno',
                email: 'maria@teste.com',
                ativo: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();

      // Validação de UI: NUNCA exibe mensagem de sucesso
      expect(find.text('Usuário atualizado com sucesso.'), findsNothing);
      expect(find.textContaining('Falha ao atualizar'), findsOneWidget);
    });

    testWidgets('RegistrarAtividadeScreen — NUNCA exibe SnackBar de sucesso quando o Supabase falha na escrita', (tester) async {
      when(() => mockSupabase.from('atividades')).thenThrow(const PostgrestException(message: 'Erro de permissao de escrita'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
            atividadesPadraoProvider.overrideWith((ref) async => [
              const AtividadePadraoModel(id: '1', nome: 'Verificação de sinais vitais'),
            ]),
          ],
          child: const MaterialApp(
            home: RegistrarAtividadeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final chip = find.text('Verificação de sinais vitais');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      final btnRegistrar = find.text('REGISTRAR ATIVIDADES');
      await tester.ensureVisible(btnRegistrar);
      await tester.tap(btnRegistrar);
      await tester.pumpAndSettle();

      // Confirmação no BottomSheet é obrigatória
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();

      // Validação estrita de UI: SnackBar de SUCESSO NUNCA deve ser exibida
      expect(find.text('Atividades registradas com sucesso!'), findsNothing);
      expect(find.textContaining('Erro ao registrar atividades'), findsOneWidget);
    });
  });
}
