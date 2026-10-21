import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/avaliacoes_provider.dart';
import '../../../providers/campos_provider.dart';
import '../../../providers/relatorios_provider.dart';
import '../../../providers/usuarios_provider.dart';
import '../../widgets/logout_button.dart';

class CoordenacaoHomeScreen extends ConsumerWidget {
  const CoordenacaoHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final alunosAsync = ref.watch(usuariosPorPerfilProvider('aluno'));
    final camposAsync = ref.watch(camposProvider);
    final avaliacoesAsync = ref.watch(avaliacoesProvider);
    final freqState = ref.watch(relatorioProvider('frequencia'));

    final totalAlunosCount = alunosAsync.maybeWhen(
      data: (list) => list.where((u) => u.ativo).length.toString(),
      orElse: () => '...',
    );

    final camposAtivosCount = camposAsync.maybeWhen(
      data: (list) => list.where((c) => c.ativo).length.toString(),
      orElse: () => '...',
    );

    final pendentesCount = avaliacoesAsync.maybeWhen(
      data: (list) => list.where((a) => a.status == 'submetida').length.toString(),
      orElse: () => '0',
    );

    final agrupados = agruparFrequenciaPorUsuario(freqState.dados);
    final alunosEmRisco = agrupados
        .where((r) => extrairPercentualFrequencia(r) < 75.0)
        .toList();

    final abaixo75Count = freqState.loading ? '...' : alunosEmRisco.length.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visão Geral da Coordenação'),
        elevation: 0,
        actions: const [
          LogoutButton(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subtítulo de Boas-Vindas
            Text(
              'Painel de Controle e Indicadores de Estágio',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),

            // Grid Responsivo de KPIs
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                int crossAxisCount = 4;
                double childAspectRatio = 1.6;

                if (width < 600) {
                  crossAxisCount = 1;
                  childAspectRatio = 2.8;
                } else if (width < 960) {
                  crossAxisCount = 2;
                  childAspectRatio = 2.0;
                }

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: childAspectRatio,
                  children: [
                    _buildKpiCard(
                      context,
                      title: 'Total de Alunos',
                      value: totalAlunosCount,
                      subtitle: 'Alocados em estágio',
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF2563EB), // Blue 600
                      onTap: () => context.go('/coordenacao/usuarios'),
                    ),
                    _buildKpiCard(
                      context,
                      title: 'Campos Ativos',
                      value: camposAtivosCount,
                      subtitle: 'Unidades de saúde',
                      icon: Icons.domain_rounded,
                      color: const Color(0xFF0D9488), // Teal 600
                      onTap: () => context.go('/coordenacao/campos'),
                    ),
                    _buildKpiCard(
                      context,
                      title: 'Pendentes de Validação',
                      value: pendentesCount,
                      subtitle: 'Avaliações aguardando',
                      icon: Icons.pending_actions_rounded,
                      color: const Color(0xFFEA580C), // Orange 600
                      onTap: () => context.go('/coordenacao/avaliacoes'),
                    ),
                    _buildKpiCard(
                      context,
                      title: 'Abaixo de 75%',
                      value: abaixo75Count,
                      subtitle: 'Alunos em atenção',
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFDC2626), // Red 600
                      onTap: () => context.go(
                        '/coordenacao/home/frequencia?filtro=abaixo_75',
                        extra: 'Frequência de Internos (< 75%)',
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 36),

            // Seção: Alunos em Risco
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Colors.redAccent, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Alunos em Risco de Frequência (< 75%)',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => context.go(
                    '/coordenacao/home/frequencia?filtro=abaixo_75',
                    extra: 'Frequência de Internos (< 75%)',
                  ),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Ver relatório de frequência'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Cards Elegantes de Alunos em Risco (Agrupados por Usuário)
            if (alunosEmRisco.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  'Nenhum aluno com frequência abaixo de 75% no período atual.',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              ...alunosEmRisco.map((aluno) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildRiscoTile(
                    context,
                    aluno: aluno,
                  ),
                );
              }),

            const SizedBox(height: 36),

            // Seção: Campos de Estágio Ativos com Alunos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.domain_rounded, color: Colors.teal, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Campos de Estágio Ativos',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => context.go('/coordenacao/campos'),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Ver todos'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            camposAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, _) => const Text('Não foi possível carregar os campos.'),
              data: (campos) {
                final ativos = campos.where((c) => c.ativo).toList();
                if (ativos.isEmpty) {
                  return const Text('Nenhum campo de estágio ativo no banco.');
                }
                return Column(
                  children: ativos.take(5).map((c) {
                    final alunosNoCampo = agrupados
                        .where((a) => (a['campo_nome'] ?? '').toString().toLowerCase().contains(c.nome.toLowerCase()))
                        .length;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildCampoTile(
                        context,
                        campoId: c.id,
                        nome: c.nome,
                        endereco: c.endereco,
                        totalAlunos: alunosNoCampo,
                        professor: 'Coordenação / Docente Vinculado',
                        supervisor: 'Preceptoria Local',
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: color.withValues(alpha: 0.6),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiscoTile(
    BuildContext context, {
    required Map<String, dynamic> aluno,
  }) {
    final theme = Theme.of(context);
    final nome = (aluno['aluno_nome'] ?? 'Aluno').toString();
    final freq = (aluno['percentual'] ?? '0%').toString();
    final campo = (aluno['campo_nome'] ?? '-').toString();
    final turno = (aluno['turno_tipo'] ?? '-').toString();
    final resumoValidados = (aluno['_resumo_validados'] ?? '').toString();
    final pendentes = aluno['pendentes'] ?? 0;
    final validadas = aluno['validadas'] ?? 0;
    final ratificadas = aluno['ratificadas'] ?? 0;
    final totalReg = aluno['total_dias'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.red.shade100,
          child: Text(
            nome.isNotEmpty ? nome.substring(0, 1) : 'A',
            style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          nome,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$campo • $turno',
              style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 2),
            Text(
              '$totalReg registros ($pendentes Pendentes • $validadas Validadas • $ratificadas Ratificadas${resumoValidados.isNotEmpty ? ' • $resumoValidados' : ''})',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Text(
            freq,
            style: TextStyle(
              color: Colors.red.shade900,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        onTap: () => _exibirFichaAluno(
          context,
          aluno: aluno,
        ),
      ),
    );
  }

  void _exibirFichaAluno(
    BuildContext context, {
    required Map<String, dynamic> aluno,
  }) {
    final nome = (aluno['aluno_nome'] ?? 'Aluno').toString();
    final freq = (aluno['percentual'] ?? '0%').toString();
    final campo = (aluno['campo_nome'] ?? '-').toString();
    final turno = (aluno['turno_tipo'] ?? '-').toString();
    final resumoValidados = (aluno['_resumo_validados'] ?? '').toString();
    final pendentes = aluno['pendentes'] ?? 0;
    final validadas = aluno['validadas'] ?? 0;
    final ratificadas = aluno['ratificadas'] ?? 0;
    final ausentes = aluno['faltas'] ?? 0;
    final totalReg = aluno['total_dias'] ?? 0;
    final dataIni = (aluno['data_inicio'] ?? '-').toString();
    final dataFim = (aluno['data_fim'] ?? '-').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.red.shade100,
                  child: Text(
                    nome.isNotEmpty ? nome.substring(0, 1) : 'A',
                    style: TextStyle(fontSize: 22, color: Colors.red.shade900, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          'Atenção < 75%: $freq${resumoValidados.isNotEmpty ? ' ($resumoValidados)' : ''}',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade900, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            const Text('Dados Reais do Banco de Frequência', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildInfoTile(Icons.local_hospital, 'Campos Registrados no Banco', campo),
            _buildInfoTile(Icons.access_time, 'Turnos Registrados', turno.toUpperCase()),
            _buildInfoTile(Icons.calendar_today, 'Período dos Registros', '$dataIni a $dataFim ($totalReg registros)'),
            _buildInfoTile(
              Icons.fact_check_outlined,
              'Detalhamento por Status',
              '$pendentes Pendentes • $validadas Validadas • $ratificadas Ratificadas • $ausentes Ausentes',
            ),
            _buildInfoTile(
              Icons.bar_chart,
              'Frequência Acumulada',
              '$freq (${resumoValidados.isNotEmpty ? resumoValidados : '$totalReg registros'})',
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.teal.shade700),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoTile(
    BuildContext context, {
    required String campoId,
    required String nome,
    required String endereco,
    required int totalAlunos,
    required String professor,
    required String supervisor,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.teal.shade100,
          child: Icon(Icons.local_hospital, color: Colors.teal.shade900, size: 22),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                nome,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Text(
                '$totalAlunos alunos',
                style: TextStyle(
                  color: Colors.teal.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(endereco, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7))),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.school, size: 14, color: Colors.blue.shade700),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Prof: $professor', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  ),
                  Icon(Icons.badge, size: 14, color: Colors.teal.shade700),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Sup: $supervisor', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          context.push('/coordenacao/campos/$campoId/detalhes', extra: nome);
        },
      ),
    );
  }
}
