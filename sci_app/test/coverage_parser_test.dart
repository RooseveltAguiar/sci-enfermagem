import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// ignore_for_file: avoid_print

void main() {
  test('Verificar cobertura do Sprint 4 em lcov.info (limiar >= 80% nos repositórios)', () {
    final file = File('coverage/lcov.info');
    expect(file.existsSync(), true, reason: 'Arquivo lcov.info deve existir');

    final lines = file.readAsLinesSync();
    String currentFile = '';
    int lf = 0;
    int lh = 0;

    int repoLf = 0;
    int repoLh = 0;

    for (final line in lines) {
      if (line.startsWith('SF:')) {
        currentFile = line.substring(3);
      } else if (line.startsWith('LF:')) {
        lf = int.tryParse(line.substring(3)) ?? 0;
      } else if (line.startsWith('LH:')) {
        lh = int.tryParse(line.substring(3)) ?? 0;
        if (lf > 0 &&
            (currentFile.contains('usuarios_repository.dart') ||
                currentFile.contains('relatorios_repository.dart') ||
                currentFile.contains('legislacao_repository.dart') ||
                currentFile.contains('termos_repository.dart') ||
                currentFile.contains('sugestoes_repository.dart') ||
                currentFile.contains('transferencia_repository.dart') ||
                currentFile.contains('conflitos_repository.dart'))) {
          final pct = (lh / lf * 100).toStringAsFixed(1);
          print('$currentFile -> $pct% ($lh / $lf)');
          repoLf += lf;
          repoLh += lh;
        }
      }
    }

    final totalPct = (repoLh / repoLf * 100);
    print('==============================================');
    print('COBERTURA DE REPOSITÓRIOS -> ${totalPct.toStringAsFixed(1)}% ($repoLh / $repoLf)');
    print('==============================================');

    expect(totalPct >= 80.0, true,
        reason: 'A cobertura dos repositórios deve ser >= 80%');
  });
}
