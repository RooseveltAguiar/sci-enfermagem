import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/frequencia_provider.dart';
import '../../providers/banco_horas_provider.dart';

class JornadaBanner extends ConsumerWidget {
  const JornadaBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jornadaAsync = ref.watch(frequenciaHojeProvider);
    final saldoAsync = ref.watch(saldoBancoHorasProvider(null));
    final configAsync = ref.watch(configuracoesJornadaProvider);

    final config = configAsync.asData?.value ?? const ConfiguracaoJornada();
    final cargaDiaria = config.cargaHorariaDiariaHoras;
    final maxExtra = config.cargaHorariaExtraMaxHoras;
    final maxAbsoluto = cargaDiaria + maxExtra;

    return jornadaAsync.when(
      data: (jornada) {
        if (jornada.status != StatusJornada.emCampo) {
          return const SizedBox.shrink();
        }

        final horas = jornada.horasEmCampo;
        final saldo = saldoAsync.asData?.value;
        final temDeficit = saldo != null && saldo.isDeficit;
        final deficitHoras = saldo != null ? saldo.saldoHoras.abs() : 0.0;
        final maxExtraHoje = deficitHoras > maxExtra ? maxExtra : deficitHoras;

        // 1. Alerta de Carga Máxima Absoluta Atingida (Banner Vermelho / Bloqueante Visual)
        if (horas >= maxAbsoluto) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'LIMITE MÁXIMO DE ${maxAbsoluto.toInt()}H ATINGIDO',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Você atingiu ${maxAbsoluto.toInt()} horas de permanência diária. Registre sua saída imediatamente.',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red.shade900,
                  ),
                  onPressed: () => context.push('/aluno/home/registrar'),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('REGISTRAR SAÍDA AGORA', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }

        // 2. Alerta de Carga Diária Atingida (Sem déficit ativo)
        if (horas >= cargaDiaria && !temDeficit) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade800,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Carga Diária de ${cargaDiaria.toInt()}h Atingida',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Você atingiu sua jornada obrigatória de hoje. Registre sua saída.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.amber.shade900,
                  ),
                  onPressed: () => context.push('/aluno/home/registrar'),
                  child: const Text('SAIR', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }

        // 3. Banner Informativo para Reposição de Déficit
        if (temDeficit) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1B6B45).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1B6B45).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_toggle_off_rounded, color: Color(0xFF1B6B45), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Você tem ${deficitHoras.toStringAsFixed(1)}h de déficit em aberto. '
                    'Pode permanecer até mais ${maxExtraHoje.toStringAsFixed(1)}h hoje para repor (máx. 2h/dia).',
                    style: const TextStyle(
                      color: Color(0xFF1B6B45),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}
