import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

// -- Auth
import '../presentation/screens/auth/splash_screen.dart';
import '../presentation/screens/auth/login_screen.dart';

// -- Aluno
import '../presentation/screens/aluno/aluno_home_screen.dart';
import '../presentation/screens/aluno/registrar_presenca_screen.dart';
import '../presentation/screens/aluno/frequencia_historico_screen.dart';
import '../presentation/screens/aluno/banco_horas_screen.dart';
import '../presentation/screens/aluno/dossie_aluno_screen.dart';

// -- Supervisor
import '../presentation/screens/supervisor/supervisor_home_screen.dart';
import '../presentation/screens/supervisor/validar_lista_screen.dart';
import '../presentation/screens/supervisor/validar_detalhe_screen.dart';

// -- Professor
import '../presentation/screens/professor/professor_alunos_screen.dart';

// -- Coordenacao
import '../presentation/screens/coordenacao/coordenacao_home_screen.dart';
import '../presentation/screens/coordenacao/campos_estagio_screen.dart';
import '../presentation/screens/coordenacao/campo_form_screen.dart';
import '../presentation/screens/coordenacao/campo_detalhes_screen.dart';

// -- Shared
import '../presentation/screens/shared/notificacoes_screen.dart';
import '../presentation/screens/shared/frequencia_auditoria_screen.dart';

// -- Sprint 2 (Módulo de Atividades e Configurações)
import '../presentation/screens/atividades/atividades_lista_screen.dart';
import '../presentation/screens/atividades/registrar_atividade_screen.dart';
import '../presentation/screens/atividades/validar_atividade_detalhe_screen.dart';
import '../presentation/screens/atividades/atividades_padrao_screen.dart';
import '../presentation/screens/coordenacao/configuracoes_screen.dart';

// -- Sprint 3 (Módulo de Avaliação)
import '../presentation/screens/avaliacao/avaliacao_lista_screen.dart';
import '../presentation/screens/avaliacao/avaliacao_form_screen.dart';
import '../presentation/screens/avaliacao/avaliacao_detalhe_screen.dart';
import '../presentation/screens/avaliacao/avaliacao_validar_screen.dart';

// -- Sprint 4 (Cadastro de Usuários + Relatórios)
import '../presentation/screens/coordenacao/usuarios_lista_screen.dart';
import '../presentation/screens/coordenacao/usuarios_form_screen.dart';
import '../presentation/screens/shared/relatorios_hub_screen.dart';
import '../presentation/screens/shared/relatorio_screen.dart';
import '../data/models/usuario_model.dart';

// -- Sprint 5 (Legislação, Termos, Sugestões, Transferência, Conflitos)
import '../data/models/legislacao_model.dart';
import '../providers/legislacao_provider.dart';
import '../data/models/termo_model.dart';
import '../providers/termos_provider.dart';
import '../presentation/screens/legislacao/legislacao_lista_screen.dart';
import '../presentation/screens/legislacao/legislacao_detalhe_screen.dart';
import '../presentation/screens/legislacao/legislacao_form_screen.dart';
import '../presentation/screens/termos/termos_aceite_screen.dart';
import '../presentation/screens/termos/termos_lista_screen.dart';
import '../presentation/screens/termos/termos_form_screen.dart';
import '../presentation/screens/sugestoes/sugestoes_screen.dart';
import '../presentation/screens/transferencia/transferencia_screen.dart';
import '../presentation/screens/conflitos/conflitos_lista_screen.dart';
import '../presentation/screens/conflitos/conflito_form_screen.dart';
// -- Sprint 6 (Exportação + Offline Completo)
import '../presentation/screens/exportacao/exportacao_screen.dart';
import '../presentation/widgets/offline_banner.dart';

// -- Sprint 11 (Chat In-App)
import '../presentation/screens/chat/conversas_lista_screen.dart';
import '../presentation/screens/chat/nova_conversa_screen.dart';
import '../presentation/screens/chat/chat_detalhe_screen.dart';

// -- Sprint 12 (Visita Técnica do Professor)
import '../presentation/screens/professor/visitas_lista_screen.dart';
import '../presentation/screens/professor/registrar_visita_screen.dart';
import '../presentation/screens/coordenacao/visitas_validar_screen.dart';
import '../presentation/widgets/logout_button.dart';
import '../providers/notificacoes_provider.dart';

// Scaffold com Bottom Nav Bar Genérico para gerenciar os Shells
class ScaffoldWithNavBar extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final List<BottomNavigationBarItem> items;

  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
    required this.items,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final naoLidasCount = ref.watch(notificacoesNaoLidasCountProvider);

    final decoratedItems = items.map((item) {
      if (item.label == 'Notificações') {
        if (naoLidasCount > 0) {
          return BottomNavigationBarItem(
            icon: Badge(
              label: Text('$naoLidasCount'),
              child: const Icon(Icons.notifications_active),
            ),
            activeIcon: Badge(
              label: Text('$naoLidasCount'),
              child: const Icon(Icons.notifications_active),
            ),
            label: item.label,
          );
        }
        return BottomNavigationBarItem(
          icon: const Icon(Icons.notifications_none_outlined),
          activeIcon: const Icon(Icons.notifications_outlined),
          label: item.label,
        );
      }
      return item;
    }).toList();

    final navItems = [
      ...decoratedItems,
      const BottomNavigationBarItem(
        icon: Icon(Icons.logout_rounded, color: Colors.redAccent),
        activeIcon: Icon(Icons.logout_rounded, color: Colors.redAccent),
        label: 'Sair',
      ),
    ];

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: navItems,
        currentIndex: navigationShell.currentIndex,
        onTap: (int index) {
          if (index == items.length) {
            LogoutButton.confirmarLogout(context, ref);
            return;
          }
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userProfile = ref.watch(userProfileProvider);
  final demoProfile = ref.watch(demoProfileProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuth = (authState.value?.session != null) || (demoProfile != null);
      final isSplash = state.matchedLocation == '/splash';
      final isLogin = state.matchedLocation == '/login';

      if (authState.isLoading && demoProfile == null) return null; // Espera resolver

      if (!isAuth && !isLogin) {
        return '/login';
      }

      if (isAuth && userProfile.value == 'aluno' && state.matchedLocation != '/termos/aceitar') {
        final termoPendente = ref.read(termoPendenteProvider).value ?? false;
        if (termoPendente) {
          return '/termos/aceitar';
        }
      }

      if (state.matchedLocation.startsWith('/professor/ratificar')) {
        return '/professor/home';
      }

      if (isAuth && (isLogin || isSplash)) {
        if (userProfile.isLoading) return null;
        
        final perfil = userProfile.value;
        if (perfil == 'aluno') return '/aluno/home';
        if (perfil == 'supervisor') return '/supervisor/home';
        if (perfil == 'professor') return '/professor/home';
        if (perfil == 'coordenacao') return '/coordenacao/home';
        
        if (perfil == null) return null;
        return '/login';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/banco-horas',
        builder: (context, state) => const BancoHorasScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ConversasListaScreen(),
        routes: [
          GoRoute(
            path: 'nova',
            builder: (context, state) => const NovaConversaScreen(),
          ),
          GoRoute(
            path: ':conversaId',
            builder: (context, state) => ChatDetalheScreen(conversaId: state.pathParameters['conversaId']!),
          ),
        ],
      ),

      // ==========================================
      // ALUNO SHELL (Ator 1)
      // ==========================================
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(
            navigationShell: navigationShell,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Frequência'),
              BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Atividades'),
              BottomNavigationBarItem(icon: Icon(Icons.assessment_outlined), label: 'Avaliações'),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Mensagens'),
              BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notificações'),
            ],
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/aluno/home',
                builder: (context, state) => const AlunoHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'registrar',
                    builder: (context, state) => const RegistrarPresencaScreen(),
                  ),
                  GoRoute(
                    path: 'historico',
                    builder: (context, state) => const FrequenciaHistoricoScreen(),
                  ),
                  GoRoute(
                    path: 'banco-horas',
                    builder: (context, state) => const BancoHorasScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/aluno/atividades',
                builder: (context, state) => const AtividadesListaScreen(),
                routes: [
                  GoRoute(
                    path: 'registrar',
                    builder: (context, state) => const RegistrarAtividadeScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/aluno/avaliacoes',
                builder: (context, state) => const AvaliacaoListaScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/aluno/chat',
                builder: (context, state) => const ConversasListaScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/aluno/notificacoes',
                builder: (context, state) => const NotificacoesScreen(),
              ),
            ],
          ),
        ],
      ),

      // ==========================================
      // SUPERVISOR SHELL (Ator 2)
      // ==========================================
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(
            navigationShell: navigationShell,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.pending_actions), label: 'Pendentes'),
              BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Histórico'),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Mensagens'),
              BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notificações'),
            ],
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/supervisor/home',
                builder: (context, state) => const SupervisorHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'validar',
                    builder: (context, state) => const ValidarListaScreen(),
                  ),
                  GoRoute(
                    path: 'validar/:id',
                    builder: (context, state) => ValidarDetalheScreen(frequenciaId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/supervisor/historico',
                builder: (context, state) => const FrequenciaHistoricoScreen(), // Reutilizando a tela
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/supervisor/chat',
                builder: (context, state) => const ConversasListaScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/supervisor/notificacoes',
                builder: (context, state) => const NotificacoesScreen(),
              ),
            ],
          ),
        ],
      ),

      // ==========================================
      // PROFESSOR SHELL (Ator 3)
      // ==========================================
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(
            navigationShell: navigationShell,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Meus Alunos'),
              BottomNavigationBarItem(icon: Icon(Icons.fact_check_outlined), label: 'Visitas'),
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Relatórios'),
              BottomNavigationBarItem(icon: Icon(Icons.gavel), label: 'Legislação'),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Mensagens'),
              BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notificações'),
            ],
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/professor/home',
                builder: (context, state) => const ProfessorAlunosScreen(),
                routes: [
                  GoRoute(
                    path: 'banco-horas/:alunoId',
                    builder: (context, state) => BancoHorasScreen(alunoId: state.pathParameters['alunoId']),
                  ),
                  GoRoute(
                    path: 'dossie/:alunoId',
                    builder: (context, state) => DossieAlunoScreen(alunoId: state.pathParameters['alunoId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/professor/visitas',
                builder: (context, state) => const VisitasListaScreen(),
                routes: [
                  GoRoute(
                    path: 'nova',
                    builder: (context, state) => const RegistrarVisitaScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/professor/relatorios',
                builder: (context, state) => const RelatoriosHubScreen(),
                routes: [
                  GoRoute(
                    path: ':tipo',
                    builder: (context, state) => RelatorioScreen(
                      tipo: state.pathParameters['tipo']!,
                      titulo: state.extra as String?,
                      filtroInicial: state.uri.queryParameters['filtro'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/professor/legislacao',
                builder: (context, state) => const LegislacaoListaScreen(),
                routes: [
                  GoRoute(
                    path: 'novo',
                    builder: (context, state) => const LegislacaoFormScreen(),
                  ),
                  GoRoute(
                    path: 'nova',
                    builder: (context, state) => const LegislacaoFormScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      if (id == 'novo' || id == 'nova') {
                        return const LegislacaoFormScreen();
                      }
                      final doc = state.extra as LegislacaoModel?;
                      if (doc != null) {
                        return LegislacaoDetalheScreen(doc: doc);
                      }
                      return _LegislacaoDetalheLoader(id: id);
                    },
                    routes: [
                      GoRoute(
                        path: 'editar',
                        builder: (context, state) => LegislacaoFormScreen(doc: state.extra as LegislacaoModel?),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/professor/chat',
                builder: (context, state) => const ConversasListaScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/professor/notificacoes',
                builder: (context, state) => const NotificacoesScreen(),
              ),
            ],
          ),
        ],
      ),

      // ==========================================
      // COORDENACAO SHELL (Ator 4)
      // ==========================================
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(
            navigationShell: navigationShell,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Visão Geral'),
              BottomNavigationBarItem(icon: Icon(Icons.fact_check_outlined), label: 'Visitas'),
              BottomNavigationBarItem(icon: Icon(Icons.place), label: 'Campos'),
              BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Usuários'),
              BottomNavigationBarItem(icon: Icon(Icons.assessment_outlined), label: 'Avaliações'),
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Relatórios'),
              BottomNavigationBarItem(icon: Icon(Icons.file_download), label: 'Exportar'),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Mensagens'),
              BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notificações'),
            ],
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coordenacao/home',
                builder: (context, state) => const CoordenacaoHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'banco-horas',
                    builder: (context, state) => const BancoHorasScreen(),
                  ),
                  GoRoute(
                    path: 'frequencia',
                    builder: (context, state) => RelatorioScreen(
                      tipo: 'frequencia',
                      titulo: state.extra as String? ?? 'Frequência de Internos (< 75%)',
                      filtroInicial: state.uri.queryParameters['filtro'] ?? 'abaixo_75',
                      voltarParaHome: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coordenacao/visitas',
                builder: (context, state) => const VisitasValidarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coordenacao/campos',
                builder: (context, state) => const CamposEstagioScreen(),
                routes: [
                  GoRoute(
                    path: 'novo',
                    builder: (context, state) => const CampoFormScreen(modo: 'criar'),
                  ),
                  GoRoute(
                    path: ':id/editar',
                    builder: (context, state) => CampoFormScreen(modo: 'editar', campoId: state.pathParameters['id']),
                  ),
                  GoRoute(
                    path: ':id/detalhes',
                    builder: (context, state) => CampoDetalhesScreen(
                      campoId: state.pathParameters['id']!,
                      campoNome: state.extra as String?,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coordenacao/usuarios',
                builder: (context, state) => const UsuariosListaScreen(),
                routes: [
                  GoRoute(
                    path: 'novo',
                    builder: (context, state) => const UsuariosFormScreen(modo: 'criar'),
                  ),
                  GoRoute(
                    path: ':id/editar',
                    builder: (context, state) => UsuariosFormScreen(
                      modo: 'editar',
                      usuario: state.extra as UsuarioModel?,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coordenacao/avaliacoes',
                builder: (context, state) => const AvaliacaoListaScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coordenacao/relatorios',
                builder: (context, state) => const RelatoriosHubScreen(),
                routes: [
                  GoRoute(
                    path: ':tipo',
                    builder: (context, state) => RelatorioScreen(
                      tipo: state.pathParameters['tipo']!,
                      titulo: state.extra as String?,
                      filtroInicial: state.uri.queryParameters['filtro'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coordenacao/exportacao',
                builder: (context, state) => const ExportacaoScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coordenacao/chat',
                builder: (context, state) => const ConversasListaScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coordenacao/notificacoes',
                builder: (context, state) => const NotificacoesScreen(),
              ),
            ],
          ),
        ],
      ),

      // ==========================================
      // SHARED (Sem bottom nav, empilhadas por cima)
      // ==========================================
      GoRoute(
        path: '/frequencia/:id/auditoria',
        builder: (context, state) => FrequenciaAuditoriaScreen(frequenciaId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/supervisor/atividades/:alunoId/validar',
        builder: (context, state) => ValidarAtividadeDetalheScreen(alunoId: state.pathParameters['alunoId']!),
      ),
      GoRoute(
        path: '/coordenacao/configuracoes',
        builder: (context, state) => const ConfiguracoesScreen(),
      ),
      GoRoute(
        path: '/coordenacao/atividades-padrao',
        builder: (context, state) => const AtividadesPadraoScreen(),
      ),

      // -- Sprint 3: Avaliações (Rotas compartilhadas / standalone)
      GoRoute(
        path: '/avaliacao',
        builder: (context, state) => const AvaliacaoListaScreen(),
      ),
      GoRoute(
        path: '/avaliacao/nova',
        builder: (context, state) => AvaliacaoFormScreen(
          tipoInicial: state.uri.queryParameters['tipo'],
          alunoIdInicial: state.uri.queryParameters['alunoId'],
        ),
      ),
      GoRoute(
        path: '/avaliacao/:id',
        builder: (context, state) => AvaliacaoDetalheScreen(
          avaliacaoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/avaliacao/:id/editar',
        builder: (context, state) => AvaliacaoFormScreen(
          avaliacaoId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/avaliacao/:id/validar',
        redirect: (context, state) {
          final perfil = ref.read(userProfileProvider).value;
          if (perfil != 'coordenacao') {
            return '/avaliacao/${state.pathParameters['id']}';
          }
          return null;
        },
        builder: (context, state) => AvaliacaoValidarScreen(
          avaliacaoId: state.pathParameters['id']!,
        ),
      ),

      // -- Sprint 5: Legislação, Termos, Sugestões, Transferência, Conflitos
      GoRoute(
        path: '/termos/aceitar',
        builder: (context, state) => const TermosAceiteScreen(),
      ),
      GoRoute(
        path: '/coordenacao/termos',
        builder: (context, state) => const TermosListaScreen(),
        routes: [
          GoRoute(
            path: 'novo',
            builder: (context, state) => const TermosFormScreen(),
          ),
          GoRoute(
            path: ':id/editar',
            builder: (context, state) => TermosFormScreen(termo: state.extra as TermoModel?),
          ),
        ],
      ),
      GoRoute(
        path: '/legislacao',
        builder: (context, state) => const LegislacaoListaScreen(),
      ),
      GoRoute(
        path: '/legislacao/novo',
        builder: (context, state) => const LegislacaoFormScreen(),
      ),
      GoRoute(
        path: '/legislacao/nova',
        builder: (context, state) => const LegislacaoFormScreen(),
      ),
      GoRoute(
        path: '/legislacao/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          if (id == 'novo' || id == 'nova') {
            return const LegislacaoFormScreen();
          }
          final doc = state.extra as LegislacaoModel?;
          if (doc != null) {
            return LegislacaoDetalheScreen(doc: doc);
          }
          return _LegislacaoDetalheLoader(id: id);
        },
      ),
      GoRoute(
        path: '/legislacao/:id/editar',
        builder: (context, state) => LegislacaoFormScreen(doc: state.extra as LegislacaoModel?),
      ),
      GoRoute(
        path: '/sugestoes',
        builder: (context, state) => const SugestoesScreen(),
      ),
      GoRoute(
        path: '/transferencia',
        builder: (context, state) => const TransferenciaScreen(),
      ),
      GoRoute(
        path: '/conflitos',
        builder: (context, state) => const ConflitosListaScreen(),
      ),
      GoRoute(
        path: '/conflitos/novo',
        builder: (context, state) => const ConflitoFormScreen(),
      ),
      GoRoute(
        path: '/exportacao',
        builder: (context, state) => const ExportacaoScreen(),
      ),
      GoRoute(
        path: '/professor/alunos/:alunoId/dossie',
        builder: (context, state) => DossieAlunoScreen(alunoId: state.pathParameters['alunoId']!),
      ),
      GoRoute(
        path: '/coordenacao/alunos/:alunoId/dossie',
        builder: (context, state) => DossieAlunoScreen(alunoId: state.pathParameters['alunoId']!),
      ),
      GoRoute(
        path: '/professor/banco-horas/:alunoId',
        builder: (context, state) => BancoHorasScreen(alunoId: state.pathParameters['alunoId']),
      ),
      GoRoute(
        path: '/professor/alunos/:alunoId/banco-horas',
        builder: (context, state) => BancoHorasScreen(alunoId: state.pathParameters['alunoId']),
      ),
      GoRoute(
        path: '/coordenacao/alunos/:alunoId/banco-horas',
        builder: (context, state) => BancoHorasScreen(alunoId: state.pathParameters['alunoId']),
      ),
    ],
  );
});

class _LegislacaoDetalheLoader extends ConsumerWidget {
  final String id;
  const _LegislacaoDetalheLoader({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(legislacoesProvider);
    return docsAsync.when(
      data: (docs) {
        try {
          final doc = docs.firstWhere((d) => d.id == id);
          return LegislacaoDetalheScreen(doc: doc);
        } catch (_) {
          return Scaffold(
            appBar: AppBar(title: const Text('Legislação e Normas')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.description_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Documento não encontrado.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.go('/legislacao'),
                    child: const Text('Voltar à lista'),
                  ),
                ],
              ),
            ),
          );
        }
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Carregando...')),
        body: const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: Center(child: Text('Erro ao carregar: $e')),
      ),
    );
  }
}

