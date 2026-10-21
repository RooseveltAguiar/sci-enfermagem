import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final bool isAvailable;

  LocationResult({
    this.latitude,
    this.longitude,
    this.accuracy,
    required this.isAvailable,
  });
}

class LocationService {
  static const double maxAccuracyMeters = 150.0;
  // FLAG DE TESTE NO CHROME: Desabilita verificação real de GPS por hora
  static const bool disableGpsRequirement = bool.fromEnvironment('DISABLE_GPS', defaultValue: false);

  Future<LocationResult> getCurrentPosition() async {
    if (disableGpsRequirement) {
      // Simula coordenadas do Campus Itaperi - UECE com precisão perfeita (10m)
      return LocationResult(
        latitude: -3.7899,
        longitude: -38.5528,
        accuracy: 10.0,
        isAvailable: true,
      );
    }

    bool serviceEnabled;
    LocationPermission permission;

    // Testa se o serviço de GPS está ativado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationResult(isAvailable: false);
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationResult(isAvailable: false);
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationResult(isAvailable: false);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Validação de precisão definida nos requisitos (AC-002-5)
      if (position.accuracy > maxAccuracyMeters) {
        return LocationResult(
          latitude: null,
          longitude: null,
          accuracy: position.accuracy,
          isAvailable: false,
        );
      }

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        isAvailable: true,
      );
    } catch (e) {
      // Falha ao obter a localização (timeout, etc)
      return LocationResult(isAvailable: false);
    }
  }
}
