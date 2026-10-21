import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sci_app/presentation/widgets/jornada_banner.dart';
import 'package:sci_app/providers/frequencia_provider.dart';

void main() {
  testWidgets('JornadaBanner exibe nada quando aluno nao esta em campo', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          frequenciaHojeProvider.overrideWith((ref) => Future.value(
            const EstadoJornadaHoje(status: StatusJornada.semCheckin),
          )),
        ],
        child: const MaterialApp(
          home: Scaffold(body: JornadaBanner()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(JornadaBanner), findsOneWidget);
    expect(find.text('LIMITE MÁXIMO DE 8H ATINGIDO'), findsNothing);
    expect(find.text('Carga Diária de 6h Atingida'), findsNothing);
  });

  testWidgets('JornadaBanner exibe alerta de 6h quando em campo ha 6h sem deficit', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          frequenciaHojeProvider.overrideWith((ref) => Future.value(
            const EstadoJornadaHoje(
              status: StatusJornada.emCampo,
              horasEmCampo: 6.2,
            ),
          )),
        ],
        child: const MaterialApp(
          home: Scaffold(body: JornadaBanner()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Carga Diária de 6h Atingida'), findsOneWidget);
    expect(find.text('SAIR'), findsOneWidget);
  });

  testWidgets('JornadaBanner exibe alerta vermelho bloqueante aos 8h em campo', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          frequenciaHojeProvider.overrideWith((ref) => Future.value(
            const EstadoJornadaHoje(
              status: StatusJornada.emCampo,
              horasEmCampo: 8.1,
            ),
          )),
        ],
        child: const MaterialApp(
          home: Scaffold(body: JornadaBanner()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('LIMITE MÁXIMO DE 8H ATINGIDO'), findsOneWidget);
    expect(find.text('REGISTRAR SAÍDA AGORA'), findsOneWidget);
  });
}
