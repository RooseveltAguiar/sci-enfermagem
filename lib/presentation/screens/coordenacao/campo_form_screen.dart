import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/confirmation_bottom_sheet.dart';

class CampoFormScreen extends ConsumerStatefulWidget {
  final String modo;
  final String? campoId;

  const CampoFormScreen({Key? key, required this.modo, this.campoId}) : super(key: key);

  @override
  ConsumerState<CampoFormScreen> createState() => _CampoFormScreenState();
}

class _CampoFormScreenState extends ConsumerState<CampoFormScreen> {
  final _nomeController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  double _raioMetros = 150.0;
  bool _ativo = true;

  // Mock list of turnos
  List<Map<String, dynamic>> turnos = [];

  @override
  void initState() {
    super.initState();
    if (widget.modo == 'editar') {
      // Mock carregamento
      _nomeController.text = 'Hospital Geral';
      _enderecoController.text = 'Rua X, 100';
      _latController.text = '-3.79';
      _lngController.text = '-38.55';
      turnos = [
        {'descricao': 'Manhã', 'hora_inicio': '07:00', 'hora_fim': '13:00'},
      ];
    }
  }

  void _adicionarTurno() {
    setState(() {
      turnos.add({'descricao': 'Novo Turno', 'hora_inicio': '00:00', 'hora_fim': '00:00'});
    });
  }

  void _salvar() {
    if (turnos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adicione pelo menos um turno.')));
      return;
    }

    ConfirmationBottomSheet.show(
      context,
      title: 'Salvar Campo?',
      message: 'Confirma as informações do campo de estágio?',
      confirmText: 'Salvar',
      onConfirm: () {
        // Envia pro Supabase
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!')));
        context.pop(); // dismiss modal
        context.pop(); // go back
      },
    );
  }

  void _desativar() {
    ConfirmationBottomSheet.show(
      context,
      title: 'Desativar Campo?',
      message: 'Atenção: Isso afetará todos os alunos alocados. Deseja continuar?',
      confirmText: 'Desativar',
      onConfirm: () {
        // Envia soft delete
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campo desativado.')));
        context.pop(); 
        context.pop(); 
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.modo == 'criar' ? 'Novo Campo' : 'Editar Campo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(labelText: 'Nome do Campo', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _enderecoController,
              decoration: const InputDecoration(labelText: 'Endereço', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            
            const Text('Localização Geográfica (GPS)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                // Mock obter localizacao atual
                setState(() {
                  _latController.text = '-3.12345';
                  _lngController.text = '-38.12345';
                });
              },
              icon: const Icon(Icons.my_location),
              label: const Text('Usar minha localização atual'),
            ),
            const SizedBox(height: 24),
            
            Text('Raio de Aceitação: ${_raioMetros.toInt()}m', style: const TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _raioMetros,
              min: 50,
              max: 500,
              divisions: 9,
              label: '${_raioMetros.toInt()}m',
              onChanged: (val) => setState(() => _raioMetros = val),
            ),
            
            SwitchListTile(
              title: const Text('Campo Ativo'),
              value: _ativo,
              onChanged: (val) => setState(() => _ativo = val),
            ),
            
            const Divider(height: 48),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Turnos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                TextButton.icon(
                  onPressed: _adicionarTurno,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
            
            if (turnos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Nenhum turno cadastrado.'),
              )
            else
              ...turnos.map((t) => Dismissible(
                key: UniqueKey(),
                background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
                onDismissed: (_) {
                  setState(() => turnos.remove(t));
                },
                child: ListTile(
                  title: Text(t['descricao']),
                  subtitle: Text('${t['hora_inicio']} - ${t['hora_fim']}'),
                  trailing: const Icon(Icons.edit),
                ),
              )),
              
            const SizedBox(height: 48),
            
            FilledButton(
              onPressed: _salvar,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('SALVAR CAMPO'),
            ),
            if (widget.modo == 'editar') ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _desativar,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('DESATIVAR CAMPO'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
