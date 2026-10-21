import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/repositories/relatorios_repository.dart';

class ExportService {
  final SupabaseClient _supabase;
  final RelatoriosRepository _relatoriosRepository;

  ExportService([SupabaseClient? supabase, RelatoriosRepository? relatoriosRepository])
      : _supabase = supabase ?? Supabase.instance.client,
        _relatoriosRepository = relatoriosRepository ?? RelatoriosRepository(supabase ?? Supabase.instance.client);

  Future<void> exportarRelatorioEmPdf({
    required String tipo,
    required DateTime dataInicio,
    required DateTime dataFim,
    String? campoId,
    String? alunoId,
  }) async {
    final bytes = await gerarPdfBytes(
      tipo: tipo,
      dataInicio: dataInicio,
      dataFim: dataFim,
      campoId: campoId,
      alunoId: alunoId,
    );

    final fileName = 'relatorio_${tipo}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    XFile xFile;
    if (kIsWeb) {
      xFile = XFile.fromData(
        bytes,
        name: fileName,
        mimeType: 'application/pdf',
      );
    } else {
      try {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        xFile = XFile(file.path, name: fileName, mimeType: 'application/pdf');
      } catch (_) {
        xFile = XFile.fromData(
          bytes,
          name: fileName,
          mimeType: 'application/pdf',
        );
      }
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        subject: 'Relatório $tipo - SCI Enfermagem',
      ),
    );
  }

  Future<void> exportarRelatorioEmCsv({
    required String tipo,
    required DateTime dataInicio,
    required DateTime dataFim,
    String? campoId,
  }) async {
    final csvString = await gerarCsvString(
      tipo: tipo,
      dataInicio: dataInicio,
      dataFim: dataFim,
      campoId: campoId,
    );

    final fileName = 'relatorio_${tipo}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    final csvBytes = Uint8List.fromList(utf8.encode(csvString));

    XFile xFile;
    if (kIsWeb) {
      xFile = XFile.fromData(
        csvBytes,
        name: fileName,
        mimeType: 'text/csv',
      );
    } else {
      try {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsString(csvString);
        xFile = XFile(file.path, name: fileName, mimeType: 'text/csv');
      } catch (_) {
        xFile = XFile.fromData(
          csvBytes,
          name: fileName,
          mimeType: 'text/csv',
        );
      }
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        subject: 'Relatório $tipo CSV - SCI Enfermagem',
      ),
    );
  }

  Future<Uint8List> gerarPdfBytes({
    required String tipo,
    required DateTime dataInicio,
    required DateTime dataFim,
    String? campoId,
    String? alunoId,
  }) async {
    final dados = await _buscarDados(tipo, dataInicio, dataFim, campoId, alunoId);

    final doc = pw.Document();
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Cabeçalho
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('UECE - Internato de Enfermagem',
                      style: pw.TextStyle(font: fontBold, fontSize: 16)),
                  pw.SizedBox(height: 4),
                  pw.Text('Relatório: ${tipo.toUpperCase()}',
                      style: pw.TextStyle(font: fontBold, fontSize: 14)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Período: ${DateFormat('dd/MM/yyyy').format(dataInicio)} a ${DateFormat('dd/MM/yyyy').format(dataFim)}',
                    style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(thickness: 1),
                  pw.SizedBox(height: 12),
                ],
              ),
            ),

            // Conteúdo (Tabela ou Seções)
            if (dados.isEmpty)
              pw.Center(
                child: pw.Text('Nenhum registro encontrado para o período selecionado.',
                    style: pw.TextStyle(font: font, fontSize: 12)),
              )
            else if (tipo == 'compilado' && dados.isNotEmpty)
              ..._construirSecoesCompilado(dados.first, font, fontBold, context)
            else
              _construirTabelaGenerica(dados, font, fontBold, context),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              'Gerado em ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())} - Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  Future<String> gerarCsvString({
    required String tipo,
    required DateTime dataInicio,
    required DateTime dataFim,
    String? campoId,
  }) async {
    final dados = await _buscarDados(tipo, dataInicio, dataFim, campoId, null);
    if (dados.isEmpty) {
      return '';
    }

    final colunas = dados.first.keys.toList();
    final linhas = <List<dynamic>>[
      colunas,
      ...dados.map((row) => colunas.map((col) => row[col]?.toString() ?? '').toList())
    ];

    return const ListToCsvConverter().convert(linhas);
  }

  Future<List<Map<String, dynamic>>> _buscarDados(
    String tipo,
    DateTime dataInicio,
    DateTime dataFim,
    String? campoId,
    String? alunoId,
  ) async {
    if (tipo == 'compilado') {
      if (alunoId == null || alunoId.isEmpty) {
        throw ArgumentError('ID do aluno é obrigatório para relatório compilado.');
      }
      final response = await _supabase.rpc('fn_compilar_dados_aluno', params: {
        'p_aluno_id': alunoId,
        'p_data_inicio': DateFormat('yyyy-MM-dd').format(dataInicio),
        'p_data_fim': DateFormat('yyyy-MM-dd').format(dataFim),
      });
      if (response == null) return [];
      if (response is Map) {
        return [Map<String, dynamic>.from(response)];
      }
      if (response is List) {
        return response.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } else {
      return _relatoriosRepository.gerarRelatorio(
        tipo: tipo,
        dataInicio: dataInicio,
        dataFim: dataFim,
        campoId: campoId,
      );
    }
  }

  List<pw.Widget> _construirSecoesCompilado(
    Map<String, dynamic> compilado,
    pw.Font font,
    pw.Font fontBold,
    pw.Context context,
  ) {
    final widgets = <pw.Widget>[];

    widgets.add(pw.Text('Resumo do Aluno', style: pw.TextStyle(font: fontBold, fontSize: 13)));
    widgets.add(pw.SizedBox(height: 6));

    final campos = <String, String>{
      'Percentual de Frequência':
          compilado['percentual_frequencia'] != null ? '${compilado['percentual_frequencia']}%' : 'N/A',
      'Atividades Registradas': '${compilado['atividades_registradas'] ?? 0}',
      'Atividades Validadas': '${compilado['atividades_validadas'] ?? 0}',
      'Nota Média (Avaliação do Interno)':
          compilado['nota_media_do_interno']?.toString() ?? 'Sem avaliação no período',
      'Nota de Autoavaliação':
          compilado['nota_autoavaliacao']?.toString() ?? 'Sem autoavaliação no período',
      'Termos Aceitos': (compilado['termos_aceitos'] == true) ? 'Sim' : 'Não',
      'Campo de Estágio': compilado['campo_estagio_nome']?.toString() ?? 'Não alocado',
    };

    campos.forEach((label, valor) {
      widgets.add(pw.Text('$label: $valor', style: pw.TextStyle(font: font, fontSize: 11)));
    });

    return widgets;
  }

  pw.Widget _construirTabelaGenerica(
    List<Map<String, dynamic>> dados,
    pw.Font font,
    pw.Font fontBold,
    pw.Context context,
  ) {
    if (dados.isEmpty) return pw.SizedBox.shrink();
    final colunas = dados.first.keys.toList();
    final linhas = dados
        .map((row) => colunas.map((col) => row[col]?.toString() ?? '').toList())
        .toList();

    return pw.TableHelper.fromTextArray(
      headers: colunas.map((c) => c.toUpperCase()).toList(),
      data: linhas,
      context: context,
      headerStyle: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellStyle: pw.TextStyle(font: font, fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    );
  }
}
