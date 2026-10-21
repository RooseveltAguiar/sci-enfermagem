import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'auth_provider.dart';

class AbonoNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  AbonoNotifier(this.ref) : super(const AsyncData(null));

  Future<void> solicitarAbono({
    required String frequenciaId,
    required String justificativa,
    required File documento,
  }) async {
    state = const AsyncLoading();
    try {
      final supabase = ref.read(supabaseClientProvider);
      final String extensao = p.extension(documento.path);
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}$extensao';
      final String filePath = '${supabase.auth.currentUser!.id}/$fileName';

      await supabase.storage.from('documentos-abono').upload(filePath, documento);

      String mimeType = 'application/octet-stream';
      if (extensao == '.pdf') mimeType = 'application/pdf';
      if (extensao == '.png') mimeType = 'image/png';
      if (extensao == '.jpg' || extensao == '.jpeg') mimeType = 'image/jpeg';

      try {
        await supabase.rpc('fn_criar_abono', params: {
          'p_frequencia_id': frequenciaId,
          'p_justificativa': justificativa,
          'p_nome_arquivo': p.basename(documento.path),
          'p_caminho_referencia': filePath,
          'p_mime_type': mimeType,
          'p_tamanho_bytes': await documento.length(),
        });
      } catch (e) {
        await supabase.storage.from('documentos-abono').remove([filePath]);
        final msg = e.toString().toLowerCase();
        if (msg.contains('perfil_nao_autorizado')) {
          throw Exception('Acesso negado: apenas supervisores e professores podem abonar faltas.');
        } else if (msg.contains('fora_do_escopo_supervisor')) {
          throw Exception('Acesso negado: este aluno não está alocado ao seu campo de estágio.');
        }
        rethrow;
      }

      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }
}

final abonoProvider = StateNotifierProvider<AbonoNotifier, AsyncValue<void>>((ref) {
  return AbonoNotifier(ref);
});

class AnexoAbonoInfo {
  final String abonoId;
  final String justificativa;
  final String nomeArquivo;
  final String caminhoReferencia;
  final String mimeType;
  final String signedUrl;

  AnexoAbonoInfo({
    required this.abonoId,
    required this.justificativa,
    required this.nomeArquivo,
    required this.caminhoReferencia,
    required this.mimeType,
    required this.signedUrl,
  });
}

final anexoAbonoProvider = FutureProvider.family<AnexoAbonoInfo?, String>((ref, frequenciaId) async {
  final supabase = ref.read(supabaseClientProvider);
  
  final abonoResponse = await supabase
      .from('abonos')
      .select('id, justificativa')
      .eq('frequencia_id', frequenciaId)
      .limit(1);

  final List abonoList = abonoResponse as List;
  if (abonoList.isEmpty) return null;
  final abono = abonoList.first;
  final String abonoId = abono['id'];
  final String justificativa = abono['justificativa'] ?? '';

  final docResponse = await supabase
      .from('documentos_abono')
      .select('*')
      .eq('abono_id', abonoId)
      .limit(1);

  final List docList = docResponse as List;
  if (docList.isEmpty) return null;
  final doc = docList.first;
  final String caminho = doc['caminho_referencia'];
  final String nomeArquivo = doc['nome_arquivo'];
  final String mimeType = doc['mime_type'] ?? 'application/octet-stream';

  final String signedUrl = await supabase.storage
      .from('documentos-abono')
      .createSignedUrl(caminho, 3600);

  return AnexoAbonoInfo(
    abonoId: abonoId,
    justificativa: justificativa,
    nomeArquivo: nomeArquivo,
    caminhoReferencia: caminho,
    mimeType: mimeType,
    signedUrl: signedUrl,
  );
});

