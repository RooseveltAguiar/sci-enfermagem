import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/frequencia_provider.dart';
import '../../../providers/banco_horas_provider.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/logout_button.dart';
import '../../widgets/jornada_banner.dart';

class AlunoHomeScreen extends ConsumerStatefulWidget {
  const AlunoHomeScreen({super.key});

  @override
  ConsumerState<AlunoHomeScreen> createState() => _AlunoHomeScreenState();
}

class _AlunoHomeScreenState extends ConsumerState<AlunoHomeScreen> {
  String _filtroStatus = 'todos';
  final GlobalKey _historicoKey = GlobalKey();

  void _selecionarFiltro(String status) {
    setState(() {
      _filtroStatus = status;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _historicoKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  FrequenciaStatus _parseStatus(String statusStr) {
    switch (statusStr.toLowerCase().trim()) {
      case 'validado':
        return FrequenciaStatus.validado;
      case 'ratificado':
        return FrequenciaStatus.ratificado;
      case 'rejeitado':
        return FrequenciaStatus.rejeitado;
      case 'ausente':
        return FrequenciaStatus.ausente;
      case 'abonado_pend_ratificacao':
      case 'abono_pendente':
        return FrequenciaStatus.abonadoPendRatificacao;
      case 'pendente_validacao':
      case 'pendente':
      default:
        return FrequenciaStatus.pendenteValidacao;
    }
  }

  Color _getBorderColorForStatus(String statusStr) {
    switch (statusStr.toLowerCase().trim()) {
      case 'validado':
      case 'ratificado':
        return const Color(0xFF1B6B45);
      case 'rejeitado':
      case 'ausente':
        return Colors.red.shade600;
      default:
        return Colors.orange.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final historicoAsync = ref.watch(historicoAlunoProvider);
    final bancoHorasAsync = ref.watch(saldoBancoHorasProvider(null));
    final usuarioAsync = ref.watch(usuarioAtualProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            usuarioAsync.when(
              data: (usr) => Text(
                usr['nome'] ?? 'Aluno Teste QA',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              loading: () => const Text(
                'Aluno Teste QA',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              error: (_, __) => const Text(
                'Aluno Teste QA',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B6B45).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF1B6B45).withValues(alpha: 0.3)),
                  ),
                  child: usuarioAsync.when(
                    data: (usr) => Text(
                      'Perfil: ${usr['perfil'] ?? 'Aluno'}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF1B6B45),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    loading: () => const Text(
                      'Perfil: Aluno',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF1B6B45),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    error: (_, __) => const Text(
                      'Perfil: Aluno',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF1B6B45),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Painel Frequência',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar dados do painel',
            onPressed: () {
              ref.read(historicoAlunoProvider.notifier).loadHistoricoAluno();
              ref.invalidate(saldoBancoHorasProvider(null));
              ref.invalidate(usuarioAtualProvider);
            },
          ),
          const LogoutButton(),
        ],
      ),
      body: historicoAsync.when(
        data: (frequencias) {
          final pendentesCount = frequencias.where((f) => f.status == 'pendente' || f.status == 'pendente_validacao').length;
          final validadosCount = frequencias.where((f) => f.status == 'validado').length;
          final ratificadosCount = frequencias.where((f) => f.status == 'ratificado').length;

          final totalAvaliadas = frequencias.where((f) => f.status == 'ratificado' || f.status == 'ausente' || f.status == 'validado').length;
          final presentes = frequencias.where((f) => f.status == 'ratificado' || f.status == 'validado').length;
          final percentual = totalAvaliadas == 0 ? 100.0 : (presentes / totalAvaliadas) * 100;
          final emRisco = percentual < 75.0;

          // Filtragem interativa estilo Power BI Slicer
          final frequenciasFiltradas = frequencias.where((f) {
            final st = f.status.toLowerCase().trim();
            if (_filtroStatus == 'pendentes') {
              return st == 'pendente' || st == 'pendente_validacao';
            }
            if (_filtroStatus == 'validados') {
              return st == 'validado';
            }
            if (_filtroStatus == 'ratificados') {
              return st == 'ratificado';
            }
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(historicoAlunoProvider.notifier).loadHistoricoAluno();
              ref.invalidate(saldoBancoHorasProvider(null));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner de Alerta de Jornada
                  const JornadaBanner(),

                  // ==========================================
                  // POWER BI DASHBOARD HEADER CARDS (KPI GRID)
                  // ==========================================
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Linha 1: Card de Frequência Geral + Card de Banco de Horas
                        Row(
                          children: [
                            // KPI Card: Taxa de Frequência
                            Expanded(
                              flex: 3,
                              child: InkWell(
                                onTap: () => _selecionarFiltro('todos'),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: emRisco
                                          ? [Colors.red.shade50, Colors.orange.shade50]
                                          : [const Color(0xFFE8F5E9), const Color(0xFFF1F8E9)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: emRisco ? Colors.red.shade400 : const Color(0xFF1B6B45),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            width: 54,
                                            height: 54,
                                            child: CircularProgressIndicator(
                                              value: percentual / 100,
                                              color: emRisco ? Colors.red.shade700 : const Color(0xFF1B6B45),
                                              backgroundColor: Colors.grey.shade300,
                                              strokeWidth: 6,
                                            ),
                                          ),
                                          Text(
                                            '${percentual.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: emRisco ? Colors.red.shade900 : const Color(0xFF1B6B45),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  emRisco ? Icons.warning_amber_rounded : Icons.verified_rounded,
                                                  size: 16,
                                                  color: emRisco ? Colors.red.shade800 : const Color(0xFF1B6B45),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Frequência',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: emRisco ? Colors.red.shade900 : const Color(0xFF1B6B45),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              emRisco ? 'Atenção < 75%' : 'Frequência Regular',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: emRisco ? Colors.red.shade700 : Colors.grey.shade700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$presentes de $totalAvaliadas validados',
                                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // KPI Card: Banco de Horas
                            Expanded(
                              flex: 2,
                              child: InkWell(
                                onTap: () => context.push('/banco-horas'),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.amber.shade400, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amber.withValues(alpha: 0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: const [
                                          Icon(Icons.account_balance_wallet_outlined, color: Colors.amber, size: 24),
                                          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.brown),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      bancoHorasAsync.when(
                                        data: (banco) => Text(
                                          '${banco.isCredito ? '+' : ''}${banco.saldoHoras.toStringAsFixed(1)}h',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            color: banco.isDeficit ? Colors.red.shade800 : Colors.brown.shade900,
                                          ),
                                        ),
                                        loading: () => const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        error: (_, __) => const Text('0.0h', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Banco de Horas',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.brown),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Linha 2: Resumo de Métricas (Pendentes / Validadas / Ratificadas)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildMetricItem(
                                  label: 'Pendentes',
                                  filterValue: 'pendentes',
                                  count: pendentesCount,
                                  color: Colors.orange.shade800,
                                  icon: Icons.pending_actions_rounded,
                                ),
                              ),
                              Container(height: 24, width: 1, color: Colors.grey.shade300),
                              Expanded(
                                child: _buildMetricItem(
                                  label: 'Validadas',
                                  filterValue: 'validados',
                                  count: validadosCount,
                                  color: const Color(0xFF1B6B45),
                                  icon: Icons.task_alt_rounded,
                                ),
                              ),
                              Container(height: 24, width: 1, color: Colors.grey.shade300),
                              Expanded(
                                child: _buildMetricItem(
                                  label: 'Ratificadas',
                                  filterValue: 'ratificados',
                                  count: ratificadosCount,
                                  color: Colors.blue.shade700,
                                  icon: Icons.verified_user_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ==========================================
                  // SELETOR DE FILTROS INTERATIVOS (POWER BI SLICER)
                  // ==========================================
                  Padding(
                    key: _historicoKey,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Histórico de Frequência',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${frequenciasFiltradas.length} registro(s)',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('todos', 'Todos (${frequencias.length})'),
                              const SizedBox(width: 8),
                              _buildFilterChip('pendentes', 'Pendentes ($pendentesCount)'),
                              const SizedBox(width: 8),
                              _buildFilterChip('validados', 'Validadas ($validadosCount)'),
                              const SizedBox(width: 8),
                              _buildFilterChip('ratificados', 'Ratificadas ($ratificadosCount)'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ==========================================
                  // LISTA DE REGISTROS ESTILO DASHBOARD CARD
                  // ==========================================
                  frequenciasFiltradas.isEmpty
                      ? Container(
                          margin: const EdgeInsets.all(24.0),
                          padding: const EdgeInsets.all(32.0),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.assignment_late_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'Nenhum registro encontrado para o filtro selecionado.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: frequenciasFiltradas.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final freq = frequenciasFiltradas[index];
                            final statusEnum = _parseStatus(freq.status);
                            final borderColor = _getBorderColorForStatus(freq.status);

                            return Card(
                              elevation: 1.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: InkWell(
                                onTap: () => context.push('/frequencia/${freq.id}/auditoria'),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border(
                                      left: BorderSide(color: borderColor, width: 5),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: borderColor.withValues(alpha: 0.12),
                                        child: Icon(
                                          Icons.fact_check_outlined,
                                          color: borderColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              freq.campoNome ?? 'Campo de Estágio',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(Icons.schedule, size: 12, color: Colors.grey.shade600),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Turno: ${freq.turnoDescricao ?? 'N/A'}',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                                ),
                                                const SizedBox(width: 12),
                                                Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade600),
                                                const SizedBox(width: 4),
                                                Text(
                                                  freq.dataRegistro,
                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      StatusChip(status: statusEnum),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando painel do aluno...')),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Erro ao carregar painel: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(historicoAlunoProvider.notifier).loadHistoricoAluno(),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/aluno/home/registrar');
        },
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Registrar Presença'),
        backgroundColor: const Color(0xFF1B6B45),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String filterValue,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _filtroStatus == filterValue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selecionarFiltro(filterValue),
        borderRadius: BorderRadius.circular(10),
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: color.withValues(alpha: 0.4), width: 1) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? color : Colors.grey.shade700,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filtroStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filtroStatus = value);
        }
      },
      selectedColor: const Color(0xFF1B6B45),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade800,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      backgroundColor: Colors.grey.shade200,
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
