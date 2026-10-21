import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sci_app/core/utils/location_service.dart';

class MockGeolocatorPlatform extends Mock with MockPlatformInterfaceMixin implements GeolocatorPlatform {}

void main() {
  late MockGeolocatorPlatform mockPlatform;
  late LocationService locationService;

  setUp(() {
    mockPlatform = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockPlatform;
    locationService = LocationService();
  });

  group('LocationService & LocationResult', () {
    test('LocationResult construtor armazena propriedades corretamente', () {
      final res = LocationResult(
        latitude: -3.7899,
        longitude: -38.5528,
        accuracy: 12.5,
        isAvailable: true,
      );

      expect(res.latitude, -3.7899);
      expect(res.longitude, -38.5528);
      expect(res.accuracy, 12.5);
      expect(res.isAvailable, isTrue);
    });

    test('retorna isAvailable: false quando isLocationServiceEnabled é false', () async {
      when(() => mockPlatform.isLocationServiceEnabled())
          .thenAnswer((_) async => false);

      final result = await locationService.getCurrentPosition();
      expect(result.isAvailable, isFalse);
      verify(() => mockPlatform.isLocationServiceEnabled()).called(1);
    });

    test('retorna isAvailable: false quando permissão é negada em requestPermission', () async {
      when(() => mockPlatform.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockPlatform.checkPermission())
          .thenAnswer((_) async => LocationPermission.denied);
      when(() => mockPlatform.requestPermission())
          .thenAnswer((_) async => LocationPermission.denied);

      final result = await locationService.getCurrentPosition();
      expect(result.isAvailable, isFalse);
      verify(() => mockPlatform.requestPermission()).called(1);
    });

    test('retorna isAvailable: false quando permissão é deniedForever', () async {
      when(() => mockPlatform.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockPlatform.checkPermission())
          .thenAnswer((_) async => LocationPermission.deniedForever);

      final result = await locationService.getCurrentPosition();
      expect(result.isAvailable, isFalse);
    });

    test('retorna isAvailable: false com accuracy quando a precisão é superior a maxAccuracyMeters (> 150m)', () async {
      when(() => mockPlatform.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockPlatform.checkPermission())
          .thenAnswer((_) async => LocationPermission.always);

      final mockPosition = Position(
        longitude: -38.5,
        latitude: -3.7,
        timestamp: DateTime.now(),
        accuracy: 180.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      when(() => mockPlatform.getCurrentPosition(locationSettings: any(named: 'locationSettings')))
          .thenAnswer((_) async => mockPosition);

      final result = await locationService.getCurrentPosition();
      expect(result.isAvailable, isFalse);
      expect(result.latitude, isNull);
      expect(result.longitude, isNull);
      expect(result.accuracy, 180.0);
    });

    test('retorna isAvailable: true com coordenadas quando precisão <= 150m e permissão concedida após request', () async {
      when(() => mockPlatform.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockPlatform.checkPermission())
          .thenAnswer((_) async => LocationPermission.denied);
      when(() => mockPlatform.requestPermission())
          .thenAnswer((_) async => LocationPermission.whileInUse);

      final mockPosition = Position(
        longitude: -38.5528,
        latitude: -3.7899,
        timestamp: DateTime.now(),
        accuracy: 15.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      when(() => mockPlatform.getCurrentPosition(locationSettings: any(named: 'locationSettings')))
          .thenAnswer((_) async => mockPosition);

      final result = await locationService.getCurrentPosition();
      expect(result.isAvailable, isTrue);
      expect(result.latitude, -3.7899);
      expect(result.longitude, -38.5528);
      expect(result.accuracy, 15.0);
    });

    test('retorna isAvailable: false quando getCurrentPosition lança exceção (timeout ou erro de GPS)', () async {
      when(() => mockPlatform.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockPlatform.checkPermission())
          .thenAnswer((_) async => LocationPermission.always);
      when(() => mockPlatform.getCurrentPosition(locationSettings: any(named: 'locationSettings')))
          .thenThrow(Exception('Timeout no GPS'));

      final result = await locationService.getCurrentPosition();
      expect(result.isAvailable, isFalse);
    });
  });
}
