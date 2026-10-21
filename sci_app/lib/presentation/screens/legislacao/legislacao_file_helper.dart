import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/legislacao_model.dart';

class LegislacaoFileHelper {
  static String formatarTamanho(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String getMimeType(String? extensao, [String? nomeArquivo]) {
    final ext = (extensao ??
            (nomeArquivo != null && nomeArquivo.contains('.')
                ? nomeArquivo.split('.').last
                : ''))
        .toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  static Future<void> abrirOuBaixarDocumento(
    BuildContext context,
    LegislacaoModel doc,
  ) async {
    try {
      final nome = doc.arquivoNome ??
          'documento_${doc.id}.${doc.arquivoExtensao ?? "pdf"}';
      final mime = getMimeType(doc.arquivoExtensao, doc.arquivoNome);

      // 1. Se tiver URL remota (Supabase Storage ou web)
      if (doc.arquivoUrl != null && doc.arquivoUrl!.isNotEmpty) {
        final uri = Uri.parse(doc.arquivoUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      // 2. Se tiver bytes em Base64
      if (doc.arquivoBase64 != null && doc.arquivoBase64!.isNotEmpty) {
        final Uint8List bytes = base64Decode(doc.arquivoBase64!);
        final xfile = XFile.fromData(bytes, name: nome, mimeType: mime);

        if (kIsWeb) {
          // No Flutter Web, saveTo dispara o download nativo do arquivo no navegador
          await xfile.saveTo(nome);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Download do arquivo "$nome" iniciado.')),
            );
          }
          return;
        }

        // Em dispositivos móveis / Desktop
        if (doc.isPdf) {
          // Para PDF no Android/iOS, o printing abre o visualizador/compartilhador nativo de PDF
          await Printing.sharePdf(bytes: bytes, filename: nome);
        } else {
          // Para DOC/DOCX, abre o diálogo nativo do sistema operacional
          await SharePlus.instance.share(
            ShareParams(
              files: [xfile],
              subject: nome,
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arquivo não disponível para download.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir documento: $e')),
        );
      }
    }
  }
}
