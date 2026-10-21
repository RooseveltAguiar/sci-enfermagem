import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/providers/abono_provider.dart';

class AbonoFormScreen extends ConsumerStatefulWidget {
  final String frequenciaId;

  const AbonoFormScreen({Key? key, required this.frequenciaId}) : super(key: key);

  @override
  ConsumerState<AbonoFormScreen> createState() => _AbonoFormScreenState();
}

class _AbonoFormScreenState extends ConsumerState<AbonoFormScreen> {
  final _justificativaController = TextEditingController();
  File? _selectedFile;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _submitAbono() async {
    final justificativa = _justificativaController.text.trim();
    if (justificativa.length < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A justificativa deve ter no mínimo 50 caracteres.')),
      );
      return;
    }

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('É obrigatório anexar um documento comprobatório.')),
      );
      return;
    }

    await ref.read(abonoProvider.notifier).solicitarAbono(
      frequenciaId: widget.frequenciaId,
      justificativa: justificativa,
      documento: _selectedFile!,
    );

    if (mounted) {
      final state = ref.read(abonoProvider);
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar abono: ${state.error}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Abono submetido com sucesso!')),
        );
        Navigator.pop(context); // Volta pra lista de validações
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final abonoState = ref.watch(abonoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar Abono'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Justificativa',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _justificativaController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Descreva detalhadamente o motivo da ausência (mínimo 50 caracteres)...',
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Documento Comprobatório',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null ? Icons.check_circle : Icons.upload_file,
                      size: 48,
                      color: _selectedFile != null ? Colors.green : Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedFile != null 
                        ? 'Arquivo selecionado:\n${_selectedFile!.path.split('/').last}'
                        : 'Toque para selecionar o arquivo (PDF, JPG, PNG)\nTamanho máx: 5MB',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            
            FilledButton.icon(
              onPressed: abonoState.isLoading ? null : _submitAbono,
              icon: abonoState.isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(abonoState.isLoading ? 'Enviando...' : 'ENVIAR SOLICITAÇÃO'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
