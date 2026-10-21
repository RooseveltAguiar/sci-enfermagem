import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/dossie_provider.dart';
import '../../../providers/banco_horas_provider.dart';
import '../../widgets/logout_button.dart';

class DossieAlunoScreen extends ConsumerStatefulWidget {
  final String alunoId;

  const DossieAlunoScreen({
    super.key,
    required this.alunoId,
  });

  @override
  ConsumerState<DossieAlunoScreen> createState() => _DossieAlunoScreenState();
}

class _DossieAlunoScreenState extends ConsumerState<DossieAlunoScreen> {
  late DateTime _dataInicio;
  late DateTime _dataFim;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default semestre atual
    final inicioMes = now.month <= 6 ? 1 : 7;
    _dataInicio = DateTime(now.year, inicioMes, 1);
    _dataFim = now;
  }

  Future<void> _selecionarPeriodo() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _dataInicio, end: _dataFim),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF005A9C),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dataInicio = picked.start;
        _dataFim = picked.end;
      });
    }
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final dossieAsync = ref.watch(dossieAlunoProvider((
      alunoId: widget.alunoId,
      dataInicio: _dataInicio,
      dataFim: _dataFim,
    )));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dossiê do Aluno'),
        actions: const [
          LogoutButton(),
        ],
      ),
      body: dossieAsync.when(
        data: (dossie) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dossieAlunoProvider((
                alunoId: widget.alunoId,
                dataInicio: _dataInicio,
                dataFim: _dataFim,
              )));
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // SEÇÃO 1: CABEÇALHO
                  _buildCabecalhoCard(dossie),
                  const SizedBox(height: 24),

                  // SEÇÃO 2: RESUMO ACADÊMICO
                  _buildResumoAcademicoCard(dossie.resumoAcademico),
                  const SizedBox(height: 24),

                  // SEÇÃO 3: BANCO DE HORAS
                  _buildBancoHorasCard(dossie.bancoHoras),
                  const SizedBox(height: 24),

                  // SEÇÃO 4: HISTÓRICO DE ALOCAÇÕES
                  _buildHistoricoAlocacoesCard(dossie.historicoAlocacoes),
                  const SizedBox(height: 24),

                  // SEÇÃO 5: OCORRÊNCIAS / CONFLITOS
                  _buildOcorrenciasCard(dossie.ocorrencias),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(semanticsLabel: 'Carregando dossiê do aluno...'),
          ),
        ),
        error: (err, stack) {
          final errStr = err.toString();
          final errLower = errStr.toLowerCase();
          final isRlsError = errLower.contains('rls') || errStr.contains('42501') || errLower.contains('permission denied') || errLower.contains('permissão');

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isRlsError ? Icons.lock_outline_rounded : Icons.error_outline_rounded,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isRlsError ? 'Acesso Não Autorizado ao Dossiê' : 'Erro ao Carregar Dossiê',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isRlsError
                        ? 'Você não possui permissão (RLS) para visualizar as informações deste aluno.'
                        : errStr,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 1. CABEÇALHO
  Widget _buildCabecalhoCard(DossieAlunoData dossie) {
    final isAtivo = dossie.status == 'Ativo';
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF005A9C).withValues(alpha: 0.1),
                  child: Text(
                    dossie.nome.isNotEmpty ? dossie.nome.substring(0, 1).toUpperCase() : 'A',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF005A9C),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dossie.nome,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'CPF: ${dossie.cpfMascarado}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(dossie.status),
                  backgroundColor: isAtivo ? Colors.green.shade100 : Colors.red.shade100,
                  labelStyle: TextStyle(
                    color: isAtivo ? Colors.green.shade900 : Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Campo Atual', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        dossie.campoAtual ?? 'Sem alocação ativa',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Turno', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        dossie.turnoAtual ?? 'N/A',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 2. RESUMO ACADÊMICO
  Widget _buildResumoAcademicoCard(ResumoAcademicoData resumo) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.school_outlined, color: Color(0xFF005A9C)),
                    SizedBox(width: 8),
                    Text('Resumo Acadêmico', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: _selecionarPeriodo,
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text('${_formatDate(_dataInicio)} - ${_formatDate(_dataFim)}', style: const TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildIndicadorItem(
                    label: 'Frequência',
                    valor: '${resumo.percentualFrequencia.toStringAsFixed(1)}%',
                    cor: resumo.percentualFrequencia >= 75.0 ? const Color(0xFF1B6B45) : Colors.red.shade700,
                  ),
                ),
                Expanded(
                  child: _buildIndicadorItem(
                    label: 'Atividades',
                    valor: '${resumo.atividadesValidadas}/${resumo.atividadesRegistradas}',
                    cor: Colors.blue.shade800,
                    subtit: 'Validadas/Total',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildNotaItem(
                    titulo: 'Avaliação do Interno',
                    nota: resumo.notaMediaDoInterno,
                  ),
                ),
                Expanded(
                  child: _buildNotaItem(
                    titulo: 'Autoavaliação',
                    nota: resumo.notaAutoavaliacao,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  resumo.termosAceitos ? Icons.check_circle : Icons.cancel,
                  color: resumo.termosAceitos ? Colors.green : Colors.red,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  resumo.termosAceitos ? 'Termos de Estágio Aceitos' : 'Termos de Estágio Pendentes',
                  style: TextStyle(
                    fontSize: 13,
                    color: resumo.termosAceitos ? Colors.green.shade900 : Colors.red.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicadorItem({required String label, required String valor, required Color cor, String? subtit}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(valor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cor)),
          if (subtit != null) Text(subtit, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildNotaItem({required String titulo, required double? nota}) {
    final semAvaliacao = nota == null;
    final notaStr = semAvaliacao ? 'Sem avaliação no período' : nota.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          notaStr,
          style: TextStyle(
            fontSize: semAvaliacao ? 12 : 16,
            fontWeight: semAvaliacao ? FontWeight.normal : FontWeight.bold,
            color: semAvaliacao ? Colors.grey.shade600 : const Color(0xFF005A9C),
            fontStyle: semAvaliacao ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }

  // 3. BANCO DE HORAS
  Widget _buildBancoHorasCard(BancoHorasAluno saldo) {
    Color cardColor;
    Color textColor;
    String statusLabel;
    IconData icon;

    if (saldo.isCredito) {
      cardColor = const Color(0xFF1B6B45);
      textColor = Colors.white;
      statusLabel = 'Crédito Disponível';
      icon = Icons.add_circle_outline_rounded;
    } else if (saldo.isDeficit) {
      cardColor = Colors.red.shade700;
      textColor = Colors.white;
      statusLabel = 'Déficit a Repor';
      icon = Icons.warning_amber_rounded;
    } else {
      cardColor = Colors.grey.shade800;
      textColor = Colors.white;
      statusLabel = 'Jornada em Dia';
      icon = Icons.check_circle_outline_rounded;
    }

    final hAbs = saldo.saldoHoras.abs().toStringAsFixed(1);
    final minAbs = (saldo.saldoMinutos.abs() % 60);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: textColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Text(
                'Banco de Horas',
                style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${saldo.isDeficit ? '-' : (saldo.isCredito ? '+' : '')}${hAbs}h ${minAbs}min',
            style: TextStyle(
              color: textColor,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // 4. HISTÓRICO DE ALOCAÇÕES
  Widget _buildHistoricoAlocacoesCard(List<AlocacaoHistoricoItem> alocacoes) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history_rounded, color: Color(0xFF005A9C)),
                SizedBox(width: 8),
                Text('Histórico de Alocações', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            if (alocacoes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Nenhuma alocação registrada.', style: TextStyle(color: Colors.grey.shade600)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: alocacoes.length,
                separatorBuilder: (context, index) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  final item = alocacoes[index];
                  final inicioStr = _formatDate(item.dataInicio);
                  final fimStr = item.dataFim != null ? _formatDate(item.dataFim!) : 'Atual';

                  return Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item.isVigente ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.campoNome,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Turno: ${item.turnoTipo} • Período: $inicioStr até $fimStr',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      if (item.isVigente)
                        Chip(
                          label: const Text('Vigente'),
                          backgroundColor: Colors.green.shade50,
                          labelStyle: TextStyle(color: Colors.green.shade900, fontSize: 10, fontWeight: FontWeight.bold),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // 5. OCORRÊNCIAS / CONFLITOS
  Widget _buildOcorrenciasCard(dynamic ocorrencias) {
    final list = ocorrencias as List;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.report_problem_outlined, color: Colors.orange),
                SizedBox(width: 8),
                Text('Ocorrências e Registros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            if (list.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      'Nenhuma ocorrência registrada.',
                      style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final conflito = list[index];
                  final dataStr = conflito.dataOcorrencia != null
                      ? _formatDate(conflito.dataOcorrencia!)
                      : 'Data não informada';

                  return Card(
                    color: Colors.orange.shade50,
                    elevation: 0,
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      title: Text(
                        conflito.descricao,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Campo: ${conflito.campoNome ?? "N/A"} • Data: $dataStr',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
