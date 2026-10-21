import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/frequencia_provider.dart';
import '../../widgets/status_chip.dart';

class ValidarListaScreen extends ConsumerWidget {
  const ValidarListaScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendentesAsync = ref.watch(pendentesValidacaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Validação')),
      body: pendentesAsync.when(
        data: (frequencias) {
          return RefreshIndicator(
            onRefresh: () async => ref.read(pendentesValidacaoProvider.notifier).loadPendentesValidacao(),
            child: ListView.builder(
              itemCount: frequencias.length,
              itemBuilder: (context, index) {
                final freq = frequencias[index];
                return ListTile(
                  title: Text(freq.alunoNome ?? 'Aluno'),
                  subtitle: Text(freq.dataRegistro),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/supervisor/home/validar/${freq.id}');
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
    );
  }
}
