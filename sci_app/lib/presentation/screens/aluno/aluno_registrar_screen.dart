import 'package:flutter/material.dart';

class AlunoRegistrarScreen extends StatelessWidget {
  const AlunoRegistrarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Atividades'),
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Tela de Registro de Procedimentos (Sprint 2)'),
      ),
    );
  }
}
