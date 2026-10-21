import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Dummy logo
            Icon(Icons.health_and_safety, size: 100, color: Colors.teal),
            SizedBox(height: 24),
            Text('SCI - Enfermagem', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 48),
            CircularProgressIndicator(semanticsLabel: 'Carregando...'),
          ],
        ),
      ),
    );
  }
}
