import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'auth_provider.dart';

class AbonoNotifier extends StateNotifier<AsyncValue<void>> {
  final ref;

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

      final abonoResponse = await supabase.from('abonos').insert({
        'frequencia_id': frequenciaId,
        'abonado_por': supabase.auth.currentUser!.id,
        'justificativa': justificativa,
      }).select('id').single();

      final String abonoId = abonoResponse['id'];

      await supabase.from('documentos_abono').insert({
        'abono_id': abonoId,
        'nome_arquivo': p.basename(documento.path),
        'caminho_referencia': filePath,
        'mime_type': mimeType,
        'tamanho_bytes': await documento.length(),
      });

      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }
}

final abonoProvider = StateNotifierProvider<AbonoNotifier, AsyncValue<void>>((ref) {
  return AbonoNotifier(ref);
});
