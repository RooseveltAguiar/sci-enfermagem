import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/data/models/usuario_model.dart';
import 'package:sci_app/presentation/screens/coordenacao/usuarios_form_screen.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/providers/usuarios_provider.dart';

class MockUsuariosController extends Mock implements UsuariosController {}
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  late MockUsuariosController mockController;
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockGoTrueClient;

  setUp(() {
    mockController = MockUsuariosController();
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrueClient = MockGoTrueClient();
    when(() => mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
    when(() => mockGoTrueClient.currentUser).thenReturn(null);
  });

  Widget buildSubject({required String modo, UsuarioModel? usuario}) {
    return ProviderScope(
      overrides: [
        usuariosControllerProvider.overrideWithValue(mockController),
        supabaseClientProvider.overrideWithValue(mockSupabaseClient),
      ],
      child: MaterialApp(
        home: UsuariosFormScreen(modo: modo, usuario: usuario),
      ),
    );
  }

  group('UsuariosFormScreen - Widget Tests', () {
    testWidgets('Em modo criação, renderiza campos e valida nome incompleto',
        (tester) async {
      await tester.pumpWidget(buildSubject(modo: 'criar'));

      expect(find.text('Novo Usuário'), findsOneWidget);
      expect(find.text('Criar usuário'), findsOneWidget);

      // Digitar apenas 1 palavra no nome
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nome completo *'), 'Ana');
      await tester.tap(find.text('Criar usuário'));
      await tester.pump();

      expect(
          find.text('Informe o nome completo (mínimo 3 palavras)'), findsOneWidget);
    });

    testWidgets('Em modo edição, CPF é desabilitado e permite salvar alterações',
        (tester) async {
      const usuario = UsuarioModel(
        id: 'user-123',
        cpf: '11122233344',
        nome: 'Maria Silva Costa',
        perfil: 'aluno',
        ativo: true,
      );

      when(() => mockController.editarUsuario(
            id: any(named: 'id'),
            nome: any(named: 'nome'),
            email: any(named: 'email'),
            perfil: any(named: 'perfil'),
          )).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject(modo: 'editar', usuario: usuario));

      expect(find.text('Editar Usuário'), findsOneWidget);
      expect(find.text('Salvar alterações'), findsOneWidget);

      // Verificar se o nome veio preenchido
      expect(find.text('Maria Silva Costa'), findsOneWidget);

      // Atualizar o nome
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nome completo *'),
          'Maria Silva Costa Santos');
      await tester.tap(find.text('Salvar alterações'));
      await tester.pump();

      verify(() => mockController.editarUsuario(
            id: 'user-123',
            nome: 'Maria Silva Costa Santos',
            email: null,
            perfil: 'aluno',
          )).called(1);
    });

    testWidgets('Em modo criação, CPF e nome válidos exibem modal de confirmação e criam usuário',
        (tester) async {
      when(() => mockController.verificarDuplicidadeCpf(any()))
          .thenAnswer((_) async => false);
      when(() => mockController.criarUsuario(
            cpf: any(named: 'cpf'),
            nome: any(named: 'nome'),
            perfil: any(named: 'perfil'),
            email: any(named: 'email'),
          )).thenAnswer((_) async => {
            'id': 'new-id',
            'senha_temporaria': 'SenhaTemp123!',
          });

      await tester.pumpWidget(buildSubject(modo: 'criar'));

      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), '52998224725');
      await tester.enterText(campos.at(1), 'Ana Cláudia Santos Rodrigues');
      await tester.pump();

      await tester.tap(find.text('Criar usuário'));
      await tester.pumpAndSettle();

      expect(find.text('Criar usuário?'), findsOneWidget);

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      verify(() => mockController.criarUsuario(
            cpf: '529.982.247-25',
            nome: 'Ana Cláudia Santos Rodrigues',
            perfil: 'aluno',
            email: null,
          )).called(1);
    });

    testWidgets('Em modo edição, alternar status exibe modal de confirmação',
        (tester) async {
      const usuario = UsuarioModel(
        id: 'user-123',
        cpf: '11122233344',
        nome: 'Maria Silva Costa',
        perfil: 'aluno',
        ativo: true,
      );

      when(() => mockController.desativarUsuario(
            any(),
            any(),
          )).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject(modo: 'editar', usuario: usuario));

      await tester.tap(find.text('Desativar usuário'));
      await tester.pumpAndSettle();

      expect(find.text('Desativar usuário?'), findsOneWidget);
    });
  });
}
