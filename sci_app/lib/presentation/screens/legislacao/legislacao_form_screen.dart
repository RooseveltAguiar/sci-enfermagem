import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/legislacao_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/legislacao_provider.dart';
import '../../widgets/confirmation_bottom_sheet.dart';
import 'legislacao_file_helper.dart';

class LegislacaoFormScreen extends ConsumerStatefulWidget {
  final LegislacaoModel? doc;

  const LegislacaoFormScreen({
    super.key,
    this.doc,
  });

  @override
  ConsumerState<LegislacaoFormScreen> createState() =>
      _LegislacaoFormScreenState();
}

class _LegislacaoFormScreenState extends ConsumerState<LegislacaoFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _tituloController;
  late final TextEditingController _tipoController;
  late final TextEditingController _conteudoController;

  DateTime? _vigenciaInicio;
  DateTime? _vigenciaFim;
  bool _ativo = true;
  bool _saving = false;

  // Gerenciamento de Anexo
  String? _nomeArquivo;
  String? _arquivoUrl;
  String? _arquivoBase64;
  int? _tamanhoArquivo;
  String? _extensaoArquivo;
  Uint8List? _bytesArquivo;
  bool _arquivoRemovido = false;

  bool get isEdicao => widget.doc != null;
  bool get _temArquivo =>
      !_arquivoRemovido &&
      (_bytesArquivo != null ||
          (_nomeArquivo != null && _nomeArquivo!.isNotEmpty));

  bool get _isPdf {
    final ext = (_extensaoArquivo ??
            (_nomeArquivo != null && _nomeArquivo!.contains('.')
                ? _nomeArquivo!.split('.').last
                : ''))
        .toLowerCase();
    return ext == 'pdf';
  }

  @override
  void initState() {
    super.initState();
    final doc = widget.doc;
    _tituloController = TextEditingController(text: doc?.titulo ?? '');
    _tipoController = TextEditingController(text: doc?.tipo ?? 'Portaria');
    _conteudoController = TextEditingController(text: doc?.conteudo ?? '');
    _vigenciaInicio = doc?.vigenciaInicio;
    _vigenciaFim = doc?.vigenciaFim;
    _ativo = doc?.ativo ?? true;

    if (doc != null && doc.temAnexo) {
      _nomeArquivo = doc.arquivoNome;
      _arquivoUrl = doc.arquivoUrl;
      _arquivoBase64 = doc.arquivoBase64;
      _tamanhoArquivo = doc.arquivoTamanho;
      _extensaoArquivo = doc.arquivoExtensao;
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _tipoController.dispose();
    _conteudoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarArquivo() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (file != null) {
        final bytes = await file.xFile.readAsBytes();
        final size = bytes.length;
        if (size > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('O arquivo deve ter no máximo 10 MB.'),
              ),
            );
          }
          return;
        }

        setState(() {
          _nomeArquivo = file.name;
          _tamanhoArquivo = size;
          _extensaoArquivo = file.extension ??
              (file.name.contains('.') ? file.name.split('.').last : 'pdf');
          _bytesArquivo = bytes;
          _arquivoRemovido = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar arquivo: $e')),
        );
      }
    }
  }

  void _removerArquivo() {
    setState(() {
      _nomeArquivo = null;
      _tamanhoArquivo = null;
      _extensaoArquivo = null;
      _bytesArquivo = null;
      _arquivoUrl = null;
      _arquivoBase64 = null;
      _arquivoRemovido = true;
    });
  }

  Future<void> _selecionarDataInicio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _vigenciaInicio ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _vigenciaInicio = picked;
        if (_vigenciaFim != null && _vigenciaFim!.isBefore(_vigenciaInicio!)) {
          _vigenciaFim = null;
        }
      });
    }
  }

  Future<void> _selecionarDataFim() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _vigenciaFim ??
          (_vigenciaInicio ?? DateTime.now()).add(const Duration(days: 1)),
      firstDate: _vigenciaInicio ?? DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _vigenciaFim = picked;
      });
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vigenciaInicio != null &&
        _vigenciaFim != null &&
        _vigenciaFim!.isBefore(_vigenciaInicio!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'A vigência final não pode ser anterior à vigência inicial.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      String? finalArquivoNome = _nomeArquivo;
      String? finalArquivoUrl = _arquivoUrl;
      String? finalArquivoBase64 = _arquivoBase64;
      int? finalArquivoTamanho = _tamanhoArquivo;
      String? finalArquivoExtensao = _extensaoArquivo;

      if (_arquivoRemovido) {
        finalArquivoNome = null;
        finalArquivoUrl = null;
        finalArquivoBase64 = null;
        finalArquivoTamanho = null;
        finalArquivoExtensao = null;
      } else if (_bytesArquivo != null) {
        finalArquivoBase64 = base64Encode(_bytesArquivo!);

        // Tentativa de envio ao Supabase Storage (se bucket existir)
        try {
          final supabase = ref.read(supabaseClientProvider);
          final safeName = _nomeArquivo!.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';
          final storagePath = 'legislacoes/$fileName';
          await supabase.storage.from('documentos-legislacao').uploadBinary(
            storagePath,
            _bytesArquivo!,
            fileOptions: FileOptions(
              contentType: LegislacaoFileHelper.getMimeType(
                  _extensaoArquivo, _nomeArquivo),
              upsert: true,
            ),
          );
          finalArquivoUrl = supabase.storage
              .from('documentos-legislacao')
              .getPublicUrl(storagePath);
        } catch (_) {
          // Fallback automático para base64 no banco
        }
      }

      if (isEdicao) {
        await ref.read(legislacoesProvider.notifier).editarLegislacao(
              id: widget.doc!.id,
              titulo: _tituloController.text.trim(),
              conteudo: _conteudoController.text.trim(),
              tipo: _tipoController.text.trim(),
              vigenciaInicio: _vigenciaInicio,
              vigenciaFim: _vigenciaFim,
              ativo: _ativo,
              arquivoNome: finalArquivoNome,
              arquivoUrl: finalArquivoUrl,
              arquivoBase64: finalArquivoBase64,
              arquivoTamanho: finalArquivoTamanho,
              arquivoExtensao: finalArquivoExtensao,
            );
      } else {
        await ref.read(legislacoesProvider.notifier).criarLegislacao(
              titulo: _tituloController.text.trim(),
              conteudo: _conteudoController.text.trim(),
              tipo: _tipoController.text.trim(),
              vigenciaInicio: _vigenciaInicio,
              vigenciaFim: _vigenciaFim,
              ativo: _ativo,
              arquivoNome: finalArquivoNome,
              arquivoUrl: finalArquivoUrl,
              arquivoBase64: finalArquivoBase64,
              arquivoTamanho: finalArquivoTamanho,
              arquivoExtensao: finalArquivoExtensao,
            );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEdicao
                  ? 'Legislação atualizada.'
                  : 'Legislação cadastrada.')),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/legislacao');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _desativar() async {
    await ConfirmationBottomSheet.show(
      context,
      title: 'Desativar Documento',
      message:
          'Desativar este documento? Ele não aparecerá mais para os usuários.',
      confirmText: 'Desativar',
      isDestructive: true,
      onConfirm: () async {
        setState(() => _saving = true);
        try {
          await ref
              .read(legislacoesProvider.notifier)
              .desativarLegislacao(widget.doc!.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Documento desativado.')),
            );
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/legislacao');
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao desativar: $e')),
            );
            setState(() => _saving = false);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdicao ? 'Editar Legislação' : 'Nova Legislação'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título do Documento *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Informe o título do documento'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tipoController,
                decoration: const InputDecoration(
                  labelText: 'Tipo / Categoria *',
                  hintText: 'Ex: Portaria, Resolução, Regimento',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Informe a categoria/tipo'
                    : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selecionarDataInicio,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _vigenciaInicio != null
                            ? 'Início: ${DateFormat('dd/MM/yyyy').format(_vigenciaInicio!)}'
                            : 'Vigência Inicial',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selecionarDataFim,
                      icon: const Icon(Icons.event),
                      label: Text(
                        _vigenciaFim != null
                            ? 'Fim: ${DateFormat('dd/MM/yyyy').format(_vigenciaFim!)}'
                            : 'Vigência Final',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Documento Ativo'),
                subtitle: const Text('Visível para consulta dos usuários'),
                value: _ativo,
                onChanged: (val) => setState(() => _ativo = val),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // SEÇÃO DE ANEXO (PDF ou DOC/DOCX)
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _temArquivo
                        ? const Color(0xFF006754)
                        : Colors.grey.shade300,
                    width: _temArquivo ? 1.5 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.attach_file,
                          color: _temArquivo
                              ? const Color(0xFF006754)
                              : Colors.grey.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Documento Anexo (PDF ou DOC)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _temArquivo
                                ? const Color(0xFF006754)
                                : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!_temArquivo) ...[
                      InkWell(
                        onTap: _selecionarArquivo,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 40,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Clique para selecionar um arquivo PDF ou DOC/DOCX',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Formatos aceitos: .pdf, .doc, .docx (até 10 MB)',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF006754).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _isPdf
                                    ? Colors.red.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _isPdf ? Icons.picture_as_pdf : Icons.description,
                                color: _isPdf
                                    ? Colors.red.shade700
                                    : Colors.blue.shade700,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _nomeArquivo ?? 'Documento selecionado',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${LegislacaoFileHelper.formatarTamanho(_tamanhoArquivo)} • ${_isPdf ? "PDF" : "Word/Doc"}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.black54),
                              tooltip: 'Trocar arquivo',
                              onPressed: _selecionarArquivo,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'Remover arquivo',
                              onPressed: _removerArquivo,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),
              TextFormField(
                controller: _conteudoController,
                maxLines: _temArquivo ? 5 : 8,
                decoration: InputDecoration(
                  labelText: _temArquivo
                      ? 'Conteúdo / Observações (Opcional)'
                      : 'Conteúdo *',
                  hintText: _temArquivo
                      ? 'Adicione uma breve descrição ou observação (opcional quando há anexo)'
                      : 'Digite o conteúdo integral da legislação...',
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if (_temArquivo) return null;
                  if (val == null || val.trim().isEmpty) {
                    return 'Informe o conteúdo ou anexe um arquivo PDF/DOC';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: 'Carregando...'))
                    : const Text('Salvar Legislação'),
              ),
              if (isEdicao) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _saving ? null : _desativar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Desativar documento'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
