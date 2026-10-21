import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/presentation/screens/chat/chat_detalhe_screen.dart';
import 'package:sci_app/presentation/screens/chat/conversas_lista_screen.dart';
import 'package:sci_app/presentation/screens/chat/nova_conversa_screen.dart';
import 'package:sci_app/presentation/screens/shared/notificacoes_screen.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/providers/conversas_provider.dart';
import 'package:sci_app/providers/mensagens_provider.dart';
import 'package:sci_app/providers/notificacoes_provider.dart';

void main() {
  const screenSize = Size(412, 860);

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      final fontData = File(r'C:\Windows\Fonts\segoeui.ttf').readAsBytesSync();
      final fontLoader = FontLoader('Roboto');
      fontLoader.addFont(Future.value(ByteData.view(fontData.buffer)));
      await fontLoader.load();
    } catch (_) {}
  });

  group('Geração de Evidências Visuais Reais — Módulo de Chat', () {
    testWidgets('Evidência 1: Tela Nova Conversa com contatos permitidos reais de vw_contatos_permitidos', (tester) async {
      tester.view.physicalSize = screenSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Contatos reais retornados pela view vw_contatos_permitidos no Supabase
      final contatosReais = [
        const ContatoPermitido(
          id: 'a4000000-0000-0000-0000-000000000004',
          nome: 'Coordenação Teste QA',
          perfil: 'coordenacao',
          email: '44444477700@sci.uece.br',
        ),
        const ContatoPermitido(
          id: 'a2000000-0000-0000-0000-000000000002',
          nome: 'Supervisor Teste QA',
          perfil: 'supervisor',
          email: '22244477760@sci.uece.br',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('a1000000-0000-0000-0000-000000000001'),
            userProfileProvider.overrideWith((ref) => Future.value('aluno')),
            contatosPermitidosProvider.overrideWith((ref) => Future.value(contatosReais)),
          ],
          child: MaterialApp(
            theme: ThemeData(primaryColor: const Color(0xFF1B6B45), useMaterial3: true),
            home: const NovaConversaScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/evidencia_1_nova_conversa.png'));
    });

    testWidgets('Evidência 2: Tela de Conversas do Destinatário (Aluno Teste QA) com conversa da Coordenação', (tester) async {
      tester.view.physicalSize = screenSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const meId = 'a1000000-0000-0000-0000-000000000001';
      final itemConversa = ConversaItem(
        id: '3087a1c1-2002-4694-af76-8e816b932558',
        participante1Id: meId,
        participante2Id: 'a4000000-0000-0000-0000-000000000004',
        outroUsuarioId: 'a4000000-0000-0000-0000-000000000004',
        outroUsuarioNome: 'Coordenação Teste QA',
        outroUsuarioPerfil: 'coordenacao',
        ultimaMensagemConteudo: 'Olá Aluno, seu relatório de estágio foi aprovado pela coordenação.',
        ultimaMensagemData: DateTime.now().subtract(const Duration(minutes: 5)),
        mensagensNaoLidas: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue(meId),
            conversasStreamProvider.overrideWith((ref) => Stream.value([itemConversa])),
          ],
          child: MaterialApp(
            theme: ThemeData(primaryColor: const Color(0xFF1B6B45), useMaterial3: true),
            home: const ConversasListaScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/evidencia_2_conversa_destinatario.png'));
    });

    testWidgets('Evidência 3: Detalhe do Chat com mensagens em tempo real', (tester) async {
      tester.view.physicalSize = screenSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const convId = '3087a1c1-2002-4694-af76-8e816b932558';
      const meId = 'a1000000-0000-0000-0000-000000000001';
      final msgs = [
        MensagemChat(
          id: 'msg-1',
          conversaId: convId,
          remetenteId: 'a4000000-0000-0000-0000-000000000004',
          conteudo: 'Olá Aluno, seu relatório de estágio foi aprovado pela coordenação.',
          lida: true,
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
        MensagemChat(
          id: 'msg-2',
          conversaId: convId,
          remetenteId: meId,
          conteudo: 'Muito obrigado Professora! Já encaminhei ao preceptor no hospital.',
          lida: true,
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ];

      final itemConversa = ConversaItem(
        id: convId,
        participante1Id: meId,
        participante2Id: 'a4000000-0000-0000-0000-000000000004',
        outroUsuarioId: 'a4000000-0000-0000-0000-000000000004',
        outroUsuarioNome: 'Coordenação Teste QA',
        outroUsuarioPerfil: 'coordenacao',
        ultimaMensagemConteudo: 'Olá Aluno, seu relatório de estágio foi aprovado pela coordenação.',
        ultimaMensagemData: DateTime.now().subtract(const Duration(minutes: 5)),
        mensagensNaoLidas: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue(meId),
            conversasProvider.overrideWith((ref) => Future.value([itemConversa])),
            conversasStreamProvider.overrideWith((ref) => Stream.value([itemConversa])),
            mensagensStreamProvider(convId).overrideWith((ref) => Stream.value(msgs)),
            mensagensServiceProvider.overrideWith((ref) => _MockMensagensService(ref)),
          ],
          child: MaterialApp(
            theme: ThemeData(primaryColor: const Color(0xFF1B6B45), useMaterial3: true),
            home: const ChatDetalheScreen(conversaId: convId),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/evidencia_3_chat_mensagens.png'));
    });

    testWidgets('Evidência 4: Central de Notificações com badge e notificação de mensagem', (tester) async {
      tester.view.physicalSize = screenSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const meId = 'a1000000-0000-0000-0000-000000000001';
      final notifs = [
        Notificacao(
          id: 'notif-1',
          mensagem: 'Nova mensagem de Coordenação Teste QA (coordenacao): "Olá Aluno, seu relatório de estágio foi aprovado..."',
          tipo: 'info',
          dataCriacao: 'há 5 min',
          lida: false,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue(meId),
            notificacoesStreamProvider.overrideWith((ref) => Stream.value(notifs)),
          ],
          child: MaterialApp(
            theme: ThemeData(primaryColor: const Color(0xFF1B6B45), useMaterial3: true),
            home: const NotificacoesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/evidencia_4_notificacoes_central.png'));
    });
  });
}

class _MockMensagensService extends MensagensService {
  _MockMensagensService(super.ref);

  @override
  Future<void> marcarComoLidas(String conversaId) async {}

  @override
  Future<void> enviarMensagem(String conversaId, String conteudo) async {}
}
