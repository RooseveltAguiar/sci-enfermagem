import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'router/app_router.dart';

// TODO: Inserir as credenciais reais do seu projeto Supabase (Dashboard -> Settings -> API)
const supabaseUrl = 'https://xuviiirjqnaeioogfapp.supabase.co';
const supabaseAnonKey = 'sb_publishable_hdwFwvl17VCwpwar_wb3gA_LZteqLVB';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Falha ao exibir esta tela',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: SelectableText(
                  details.exceptionAsString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.red.shade900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Inicialização do Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );

  runApp(
    // O ProviderScope é obrigatório na raiz para o Riverpod funcionar
    const ProviderScope(
      child: SciApp(),
    ),
  );
}

class SciApp extends ConsumerWidget {
  const SciApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'SCI - Sistema de Controle do Internato',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B6B45)),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
