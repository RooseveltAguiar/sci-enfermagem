import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/presentation/widgets/offline_banner.dart';
import 'package:sci_app/providers/connectivity_provider.dart';

void main() {
  testWidgets('OfflineBanner não exibe nada quando online (isOnlineProvider = true)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: OfflineBanner(),
          ),
        ),
      ),
    );

    expect(find.byType(SizedBox), findsWidgets);
    expect(find.text('Sem conexão. Usando dados em cache.'), findsNothing);
    expect(find.byIcon(Icons.wifi_off), findsNothing);
  });

  testWidgets('OfflineBanner exibe barra amarela de alerta quando offline (isOnlineProvider = false)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: OfflineBanner(),
          ),
        ),
      ),
    );

    expect(find.text('Sem conexão. Usando dados em cache.'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
  });
}
