import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../providers/auth_provider.dart';
import '../../widgets/logout_button.dart';

class RelatorioCardItem {
  final String tipo;
  final String titulo;
  final String descricao;
  final IconData icon;
  final Color color;
  final bool apenasCoordenacao;

  const RelatorioCardItem({
    required this.tipo,
    required this.titulo,
    required this.descricao,
    required this.icon,
    required this.color,
    this.apenasCoordenacao = false,
  });
}

class RelatoriosHubScreen extends ConsumerWidget {
  const RelatoriosHubScreen({super.key});

  static const List<RelatorioCardItem> _itens = [
    RelatorioCardItem(
      tipo: 'frequencia',
      titulo: 'Frequência de Internos',
      descricao: 'Consolidado de presenças e saídas registradas via GPS',
      icon: Icons.calendar_today_rounded,
      color: Color(0xFF2563EB), // Blue 600
    ),
    RelatorioCardItem(
      tipo: 'atividades',
      titulo: 'Atividades Realizadas',
      descricao: 'Procedimentos e diários práticos por período',
      icon: Icons.assignment_rounded,
      color: Color(0xFF0D9488), // Teal 600
    ),
    RelatorioCardItem(
      tipo: 'avaliacoes',
      titulo: 'Avaliações de Desempenho',
      descricao: 'Resumo de notas, conceitos e feedback de supervisores',
      icon: Icons.fact_check_rounded,
      color: Color(0xFF7C3AED), // Purple 600
    ),
    RelatorioCardItem(
      tipo: 'internos_campo',
      titulo: 'Internos em Campo',
      descricao: 'Alunos atualmente alocados em campos de estágio',
      icon: Icons.groups_rounded,
      color: Color(0xFFEA580C), // Orange 600
    ),
    RelatorioCardItem(
      tipo: 'supervisores',
      titulo: 'Supervisores Ativos',
      descricao: 'Supervisores vinculados aos campos de estágio',
      icon: Icons.badge_rounded,
      color: Color(0xFF0284C7), // Sky 600
    ),
    RelatorioCardItem(
      tipo: 'locais_estagio',
      titulo: 'Locais de Estágio',
      descricao: 'Capacidade e ocupação dos campos conveniados',
      icon: Icons.location_on_rounded,
      color: Color(0xFFE11D48), // Rose 600
      apenasCoordenacao: true,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final perfilAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios Gerenciais'),
        elevation: 0,
        actions: const [
          LogoutButton(),
        ],
      ),
      body: perfilAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...')),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (profile) {
          final isCoord = profile == 'coordenacao';
          final prefix = isCoord ? '/coordenacao' : '/professor';

          final visiveis = _itens.where((item) {
            if (item.apenasCoordenacao && !isCoord) return false;
            return true;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selecione um relatório para consultar, filtrar e exportar dados',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    int crossAxisCount = 3;
                    double childAspectRatio = 2.2;

                    if (width < 650) {
                      crossAxisCount = 1;
                      childAspectRatio = 2.6;
                    } else if (width < 1050) {
                      crossAxisCount = 2;
                      childAspectRatio = 2.0;
                    }

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: visiveis.length,
                      itemBuilder: (context, index) {
                        final item = visiveis[index];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              context.go('$prefix/relatorios/${item.tipo}', extra: item.titulo);
                            },
                            splashColor: item.color.withValues(alpha: 0.12),
                            highlightColor: item.color.withValues(alpha: 0.06),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: item.color.withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: item.color.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: item.color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      item.icon,
                                      size: 26,
                                      color: item.color,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          item.titulo,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.descricao,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                                            height: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: item.color.withValues(alpha: 0.6),
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
