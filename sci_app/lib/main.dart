import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'router/app_router.dart';

// TODO: Inserir as credenciais reais do seu projeto Supabase (Dashboard -> Settings -> API)
const supabaseUrl = 'https://xuviiirjqnaeioogfapp.supabase.co';
const supabaseAnonKey = 'sb_publishable_hdwFwvl17VCwpwar_wb3gA_LZteqLVB';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
