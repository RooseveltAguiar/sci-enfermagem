import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/banco_horas_provider.dart';
import '../../widgets/logout_button.dart';

class BancoHorasScreen extends ConsumerWidget {
  final String? alunoId;

  const BancoHorasScreen({
    super.key,
    this.alunoId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saldoAsync = ref.watch(saldoBancoHorasProvider(alunoId));
    final lancamentosAsync = ref.watch(lancamentosBancoHorasProvider(alunoId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extrato de Banco de Horas'),
        actions: const [
          LogoutButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(saldoBancoHorasProvider(alunoId));
          ref.invalidate(lancamentosBancoHorasProvider(alunoId));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card de Saldo Consolidado
              saldoAsync.when(
                data: (saldo) => _buildSaldoCard(context, saldo),
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando saldo...')),
                  ),
                ),
                error: (err, stack) => Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Erro ao carregar saldo: $err'),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Histórico de Lançamentos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Lista de Lançamentos
              lancamentosAsync.when(
                data: (lancamentos) {
                  if (lancamentos.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32.0),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhum lançamento no banco de horas até o momento.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: lancamentos.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = lancamentos[index];
                      final isCredito = item.tipo == 'credito';
                      final cor = isCredito ? const Color(0xFF1B6B45) : Colors.red.shade700;
                      final icone = isCredito ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
                      final sinal = isCredito ? '+' : '-';
                      final hStr = item.horas.abs().toStringAsFixed(1);

                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: cor.withValues(alpha: 0.1),
                            child: Icon(icone, color: cor),
                          ),
                          title: Text(
                            item.motivo,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Text(
                            'Data: ${item.dataLancamento}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$sinal${hStr}h',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: cor,
                                ),
                              ),
                              Text(
                                'Saldo: ${(item.saldoResultanteMinutos / 60.0).toStringAsFixed(1)}h',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando histórico...')),
                error: (err, stack) => Text('Erro ao carregar lançamentos: $err'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaldoCard(BuildContext context, BancoHorasAluno saldo) {
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
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: 0.3),
            blurRadius: 12,
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
                  Icon(icon, color: textColor, size: 24),
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
              Chip(
                label: const Text('Limite: 2h/dia extra'),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                labelStyle: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${saldo.isDeficit ? '-' : (saldo.isCredito ? '+' : '')}${hAbs}h ${minAbs}min',
            style: TextStyle(
              color: textColor,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            saldo.isDeficit
                ? 'Você possui horas em débito a repor no internato.'
                : (saldo.isCredito ? 'Você possui crédito excedente de horas.' : 'Nenhum débito ou crédito pendente.'),
            style: TextStyle(color: textColor.withValues(alpha: 0.9), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
