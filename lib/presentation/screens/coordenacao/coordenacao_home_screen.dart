import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoordenacaoHomeScreen extends ConsumerWidget {
  const CoordenacaoHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visão Geral da Coordenação'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cards de Resumo
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildSummaryCard('Total de Alunos', '120', Icons.people, Colors.blue),
                _buildSummaryCard('Campos Ativos', '15', Icons.business, Colors.teal),
                _buildSummaryCard('Pendentes de Validação', '42', Icons.pending_actions, Colors.orange),
                _buildSummaryCard('Abaixo de 75%', '5', Icons.warning, Colors.red),
              ],
            ),
            
            const SizedBox(height: 32),
            const Text('Alunos em Risco (< 75%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            
            // Lista mockada de alunos em risco
            _buildRiscoTile('Carlos Souza', '70.0%', 'HGF - Manhã'),
            _buildRiscoTile('Marina Luz', '65.5%', 'IJF - Tarde'),
            _buildRiscoTile('Felipe Assis', '74.9%', 'Albert Sabin - Noite'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color.withOpacity(0.8))),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }

  Widget _buildRiscoTile(String nome, String freq, String info) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.shade100,
          child: Text(nome.substring(0,1), style: TextStyle(color: Colors.red.shade900)),
        ),
        title: Text(nome),
        subtitle: Text(info),
        trailing: Chip(
          label: Text(freq),
          backgroundColor: Colors.red.shade50,
          labelStyle: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
