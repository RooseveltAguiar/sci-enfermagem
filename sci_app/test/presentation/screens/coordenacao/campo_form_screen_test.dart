import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sci_app/providers/auth_provider.dart';
import 'package:sci_app/presentation/screens/coordenacao/campo_form_screen.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}
class MockPostgrestTransformBuilder extends Mock implements PostgrestTransformBuilder<Map<String, dynamic>?> {}

void _stubAwait(
  MockPostgrestFilterBuilder builder, {
  List<Map<String, dynamic>> value = const [],
}) {
  when(() => builder.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onValue = invocation.positionalArguments[0] as Function;
    return Future<dynamic>.value(onValue(value));
  });
}

void main() {
  late MockSupabaseClient mockSupabase;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
  });

  testWidgets('CampoFormScreen exibe formulário no modo criar', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CampoFormScreen(
            modo: 'criar',
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(CampoFormScreen), findsOneWidget);
    expect(find.text('Novo Campo'), findsOneWidget);
  });

  testWidgets('CampoFormScreen exercita caminho de sucesso do modo editar com mock de Supabase', (tester) async {
    final mockCamposBuilder = MockSupabaseQueryBuilder();
    final mockCamposFilter = MockPostgrestFilterBuilder();
    final mockCamposSingle = MockPostgrestTransformBuilder();

    final mockTurnosBuilder = MockSupabaseQueryBuilder();
    final mockTurnosFilter = MockPostgrestFilterBuilder();

    // 1. Stub campos_estagio
    when(() => mockSupabase.from('campos_estagio')).thenAnswer((_) => mockCamposBuilder);
    when(() => mockCamposBuilder.select('*')).thenAnswer((_) => mockCamposFilter);
    when(() => mockCamposFilter.eq('id', 'campo-123')).thenAnswer((_) => mockCamposFilter);
    when(() => mockCamposFilter.maybeSingle()).thenAnswer((_) => mockCamposSingle);
    when(() => mockCamposSingle.then<dynamic>(any(), onError: any(named: 'onError')))
        .thenAnswer((invocation) {
      final onValue = invocation.positionalArguments[0] as Function;
      return Future<dynamic>.value(onValue({
        'id': 'campo-123',
        'nome': 'Hospital Santa Casa',
        'endereco': 'Rua Flores, 123',
        'latitude': -3.7500,
        'longitude': -38.5200,
        'raio_metros': 200,
        'ativo': true,
      }));
    });

    // 2. Stub turnos + turnos_horarios
    when(() => mockSupabase.from('turnos')).thenAnswer((_) => mockTurnosBuilder);
    when(() => mockTurnosBuilder.select('*, turnos_horarios(*)')).thenAnswer((_) => mockTurnosFilter);
    when(() => mockTurnosFilter.eq('campo_id', 'campo-123')).thenAnswer((_) => mockTurnosFilter);
    _stubAwait(mockTurnosFilter, value: [
      {
        'id': 't-1',
        'campo_id': 'campo-123',
        'tipo': 'manha',
        'turnos_horarios': [
          {
            'dia_semana': 1,
            'hora_inicio': '07:00',
            'hora_fim': '13:00',
          }
        ]
      }
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
        child: const MaterialApp(
          home: CampoFormScreen(
            modo: 'editar',
            campoId: 'campo-123',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(CampoFormScreen), findsOneWidget);
    expect(find.text('Editar Campo'), findsOneWidget);
    expect(find.text('Hospital Santa Casa'), findsOneWidget);
  });
}
