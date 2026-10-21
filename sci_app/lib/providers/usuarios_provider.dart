import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/usuario_model.dart';
import '../data/repositories/usuarios_repository.dart';
import 'auth_provider.dart';

final usuariosRepositoryProvider = Provider<UsuariosRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return UsuariosRepository(supabase);
});

class UsuariosPorPerfilNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<UsuarioModel>, String> {
  @override
  FutureOr<List<UsuarioModel>> build(String arg) async {
    final repo = ref.read(usuariosRepositoryProvider);
    return repo.listarUsuariosPorPerfil(arg);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(usuariosRepositoryProvider);
      return repo.listarUsuariosPorPerfil(arg);
    });
  }
}

final usuariosPorPerfilProvider = AsyncNotifierProvider.autoDispose
    .family<UsuariosPorPerfilNotifier, List<UsuarioModel>, String>(
  UsuariosPorPerfilNotifier.new,
);

class UsuariosController {
  final Ref _ref;

  UsuariosController(this._ref);

  Future<bool> verificarDuplicidadeCpf(String cpf) async {
    final repo = _ref.read(usuariosRepositoryProvider);
    return repo.verificarDuplicidadeCpf(cpf);
  }

  Future<Map<String, dynamic>> criarUsuario({
    required String cpf,
    required String nome,
    required String perfil,
    String? email,
  }) async {
    final repo = _ref.read(usuariosRepositoryProvider);
    final res = await repo.criarUsuario(
      cpf: cpf,
      nome: nome,
      perfil: perfil,
      email: email,
    );
    _ref.invalidate(usuariosPorPerfilProvider(perfil));
    return res;
  }

  Future<void> editarUsuario({
    required String id,
    required String nome,
    String? email,
    required String perfil,
  }) async {
    final repo = _ref.read(usuariosRepositoryProvider);
    await repo.editarUsuario(id: id, nome: nome, email: email);
    _ref.invalidate(usuariosPorPerfilProvider(perfil));
  }

  Future<void> desativarUsuario(String id, String perfil) async {
    final repo = _ref.read(usuariosRepositoryProvider);
    await repo.desativarUsuario(id);
    _ref.invalidate(usuariosPorPerfilProvider(perfil));
  }

  Future<void> reativarUsuario(String id, String perfil) async {
    final repo = _ref.read(usuariosRepositoryProvider);
    await repo.reativarUsuario(id);
    _ref.invalidate(usuariosPorPerfilProvider(perfil));
  }
}

final usuariosControllerProvider = Provider<UsuariosController>((ref) {
  return UsuariosController(ref);
});
