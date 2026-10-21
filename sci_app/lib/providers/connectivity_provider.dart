import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

final connectivityStreamProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    return results.any((r) => r != ConnectivityResult.none);
  });
});

final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityStreamProvider);
  return status.maybeWhen(
    data: (online) => online,
    orElse: () => true, // Default otimista no boot
  );
});
