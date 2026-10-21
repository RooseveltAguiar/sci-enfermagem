import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

class AbonoNotifier extends StateNotifier<AsyncValue<void>> {
  final SupabaseClient _supabase;

  AbonoNotifier(this._supabase) : super(const AsyncData(null));

  Future<void> solicitarAbono({
    required String frequenciaId,
    required String justificativa,
    required File documento,
  }) async {
    state = const AsyncLoading();
    try {
      final String extensao = p.extension(documento.path);
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}$extensao';
      final String filePath = '${_supabase.auth.currentUser!.id}/$fileName';

      // 1. Upload do arquivo para o bucket
      await _supabase.storage.from('documentos-abono').upload(filePath, documento);

      // Obter mimetype
      String mimeType = 'application/octet-stream';
      if (extensao == '.pdf') mimeType = 'application/pdf';
      if (extensao == '.png') mimeType = 'image/png';
      if (extensao == '.jpg' || extensao == '.jpeg') mimeType = 'image/jpeg';

      // 2. Inserir registro de abono
      final abonoResponse = await _supabase.from('abonos').insert({
        'frequencia_id': frequenciaId,
        'abonado_por': _supabase.auth.currentUser!.id,
        'justificativa': justificativa,
      }).select('id').single();

      final String abonoId = abonoResponse['id'];

      // 3. Inserir metadados do documento
      await _supabase.from('documentos_abono').insert({
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
  final supabase = ref.watch(supabaseClientProvider);
  return AbonoNotifier(supabase);
});
