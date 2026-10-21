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

// -- Supervisor
import '../presentation/screens/supervisor/supervisor_home_screen.dart';
import '../presentation/screens/supervisor/validar_lista_screen.dart';
import '../presentation/screens/supervisor/validar_detalhe_screen.dart';

// -- Professor
import '../presentation/screens/professor/professor_alunos_screen.dart';
import '../presentation/screens/professor/professor_ratificar_screen.dart';

// -- Coordenacao
import '../presentation/screens/coordenacao/coordenacao_home_screen.dart';
import '../presentation/screens/coordenacao/campos_estagio_screen.dart';
import '../presentation/screens/coordenacao/campo_form_screen.dart';

// -- Shared
import '../presentation/screens/shared/notificacoes_screen.dart';
import '../presentation/screens/shared/frequencia_auditoria_screen.dart';

// -- Sprint 2 (Módulo de Atividades e Configurações)
import '../presentation/screens/atividades/atividades_lista_screen.dart';
import '../presentation/screens/atividades/registrar_atividade_screen.dart';
import '../presentation/screens/atividades/validar_atividade_detalhe_screen.dart';
import '../presentation/screens/atividades/atividades_padrao_screen.dart';
import '../presentation/screens/coordenacao/configuracoes_screen.dart';

// Scaffold com Bottom Nav Bar Genérico para gerenciar os Shells
class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final List<BottomNavigationBarItem> items;

  const ScaffoldWithNavBar({
    Key? key,
    required this.navigationShell,
    required this.items,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        items: items,
        currentIndex: navigationShell.currentIndex,
        onTap: (int index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userProfile = ref.watch(userProfileProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuth = authState.value?.session != null;
      final isSplash = state.matchedLocation == '/splash';
      final isLogin = state.matchedLocation == '/login';

      if (authState.isLoading) return null; // Espera resolver

      if (!isAuth && !isLogin && !isSplash) {
        return '/login';
      }

      if (isAuth && (isLogin || isSplash)) {
        if (userProfile.isLoading) return '/splash'; // Espera perfil
        
        final perfil = userProfile.value;
        if (perfil == 'aluno') return '/aluno/home';
        if (perfil == 'supervisor') return '/supervisor/home';
        if (perfil == 'professor') return '/professor/home';
        if (perfil == 'coordenacao') return '/coordenacao/home';
        
        // Fallback
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
              BottomNavigationBarItem(icon: Icon(Icons.fact_check), label: 'Ratificar'),
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
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/professor/ratificar',
                builder: (context, state) => const ProfessorRatificarScreen(),
                routes: [
                  GoRoute(
                    path: 'atividades-padrao',
                    builder: (context, state) => const AtividadesPadraoScreen(),
                  ),
                ],
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
              BottomNavigationBarItem(icon: Icon(Icons.place), label: 'Campos'),
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
                ],
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
    ],
  );
});
