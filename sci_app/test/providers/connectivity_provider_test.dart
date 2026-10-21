import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/providers/connectivity_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<List<ConnectivityResult>> fakeStreamController;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'check') {
          return ['wifi'];
        }
        return ['wifi'];
      },
    );
  });

  setUp(() {
    fakeStreamController = StreamController<List<ConnectivityResult>>.broadcast();
  });

  tearDown(() {
    fakeStreamController.close();
  });

  group('ConnectivityProvider', () {
    test('isOnlineProvider retorna true por default otimista no boot (quando stream em loading)', () {
      final container = ProviderContainer(
        overrides: [
          connectivityStreamProvider.overrideWith((ref) => fakeStreamController.stream.map((results) => results.any((r) => r != ConnectivityResult.none))),
        ],
      );
      addTearDown(container.dispose);

      final isOnline = container.read(isOnlineProvider);
      expect(isOnline, isTrue);
    });

    test('isOnlineProvider reflete o valor recebido pela stream (online e offline)', () async {
      final container = ProviderContainer(
        overrides: [
          connectivityStreamProvider.overrideWith((ref) => fakeStreamController.stream.map((results) => results.any((r) => r != ConnectivityResult.none))),
        ],
      );
      addTearDown(container.dispose);

      final onlineValues = <bool>[];
      container.listen(isOnlineProvider, (prev, next) {
        onlineValues.add(next);
      }, fireImmediately: true);

      fakeStreamController.add([ConnectivityResult.wifi]);
      await Future.delayed(Duration.zero);

      fakeStreamController.add([ConnectivityResult.none]);
      await Future.delayed(Duration.zero);

      fakeStreamController.add([ConnectivityResult.mobile]);
      await Future.delayed(Duration.zero);

      expect(onlineValues.contains(true), isTrue);
      expect(onlineValues.contains(false), isTrue);
    });

    test('connectivityStreamProvider construção real monitora Connectivity().onConnectivityChanged', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final stream = container.read(connectivityStreamProvider);
      expect(stream, isA<AsyncValue<bool>>());
    });
  });
}
