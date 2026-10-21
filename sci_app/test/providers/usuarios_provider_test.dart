// test/providers/usuarios_provider_test.dart
//
// Duas peças neste arquivo:
//
// 1. UsuariosPorPerfilNotifier — AsyncNotifier.family, uma instância
//    por perfil ("aluno", "supervisor" etc). Cada `arg` (perfil) tem
//    seu próprio estado independente — testado explicitamente porque
//    family providers são fáceis de testar errado (ex: invalidar o
//    perfil errado, ou achar que existe um estado global único).
//
// 2. UsuariosController — não é um StateNotifier, é uma classe comum
//    injetada via Provider simples. Cada método invalida
//    usuariosPorPerfilProvider(perfil) — com o PERFIL CERTO, que
//    seria fácil trocar (ex: invalidar o perfil do usuário editado
//    em vez do perfil informado como parâmetro).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sci_app/data/models/usuario_model.dart';
import 'package:sci_app/data/repositories/usuarios_repository.dart';
import 'package:sci_app/providers/usuarios_provider.dart';

class MockUsuariosRepository extends Mock implements UsuariosRepository {}

void main() {
  late MockUsuariosRepository mockRepo;

  setUp(() {
    mockRepo = MockUsuariosRepository();
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        usuariosRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('usuariosPorPerfilProvider (family)', () {
    test('cada perfil tem estado independente — carregar "aluno" não '
        'afeta o estado de "supervisor"', () async {
      when(() => mockRepo.listarUsuariosPorPerfil('aluno'))
          .thenAnswer((_) async => <UsuarioModel>[]);
      when(() => mockRepo.listarUsuariosPorPerfil('supervisor'))
          .thenAnswer((_) async => <UsuarioModel>[]);

      final container = buildContainer();

      await container.read(usuariosPorPerfilProvider('aluno').future);
      await container.read(usuariosPorPerfilProvider('supervisor').future);

      verify(() => mockRepo.listarUsuariosPorPerfil('aluno')).called(1);
      verify(() => mockRepo.listarUsuariosPorPerfil('supervisor'))
          .called(1);
    });

    test('refresh() de um perfil específico não recarrega outro '
        'perfil', () async {
      when(() => mockRepo.listarUsuariosPorPerfil('aluno'))
          .thenAnswer((_) async => <UsuarioModel>[]);
      when(() => mockRepo.listarUsuariosPorPerfil('professor'))
          .thenAnswer((_) async => <UsuarioModel>[]);

      final container = buildContainer();
      await container.read(usuariosPorPerfilProvider('aluno').future);
      await container.read(usuariosPorPerfilProvider('professor').future);
      clearInteractions(mockRepo);
      when(() => mockRepo.listarUsuariosPorPerfil('aluno'))
          .thenAnswer((_) async => <UsuarioModel>[]);

      await container
          .read(usuariosPorPerfilProvider('aluno').notifier)
          .refresh();

      verify(() => mockRepo.listarUsuariosPorPerfil('aluno')).called(1);
      verifyNever(() => mockRepo.listarUsuariosPorPerfil('professor'));
    });
  });

  group('UsuariosController.verificarDuplicidadeCpf', () {
    test('delega diretamente ao repository e retorna o resultado dele',
        () async {
      when(() => mockRepo.verificarDuplicidadeCpf('52998224725'))
          .thenAnswer((_) async => true);

      final container = buildContainer();
      final controller = container.read(usuariosControllerProvider);

      final result = await controller.verificarDuplicidadeCpf('52998224725');

      expect(result, true);
      verify(() => mockRepo.verificarDuplicidadeCpf('52998224725'))
          .called(1);
    });
  });

  group('UsuariosController.criarUsuario', () {
    test('propaga os 4 argumentos e invalida usuariosPorPerfilProvider '
        'com o PERFIL DO NOVO USUÁRIO (não outro)', () async {
      when(() => mockRepo.listarUsuariosPorPerfil('aluno'))
          .thenAnswer((_) async => <UsuarioModel>[]);
      when(() => mockRepo.criarUsuario(
            cpf: any(named: 'cpf'),
            nome: any(named: 'nome'),
            perfil: any(named: 'perfil'),
            email: any(named: 'email'),
          )).thenAnswer((_) async => {'id': 'novo-id'});

      final container = buildContainer();

      // Materializa o provider de família para 'aluno' ANTES da
      // criação, para que a invalidação seja observável depois.
      await container.read(usuariosPorPerfilProvider('aluno').future);
      clearInteractions(mockRepo);
      when(() => mockRepo.listarUsuariosPorPerfil('aluno'))
          .thenAnswer((_) async => <UsuarioModel>[]);
      when(() => mockRepo.criarUsuario(
            cpf: any(named: 'cpf'),
            nome: any(named: 'nome'),
            perfil: any(named: 'perfil'),
            email: any(named: 'email'),
          )).thenAnswer((_) async => {'id': 'novo-id'});

      final controller = container.read(usuariosControllerProvider);

      await controller.criarUsuario(
        cpf: '52998224725',
        nome: 'Novo Aluno',
        perfil: 'aluno',
        email: 'novo@sci.uece.br',
      );

      final captured = verify(() => mockRepo.criarUsuario(
            cpf: captureAny(named: 'cpf'),
            nome: captureAny(named: 'nome'),
            perfil: captureAny(named: 'perfil'),
            email: captureAny(named: 'email'),
          )).captured;
      expect(captured[0], '52998224725');
      expect(captured[1], 'Novo Aluno');
      expect(captured[2], 'aluno');
      expect(captured[3], 'novo@sci.uece.br');

      // Invalidação real do family('aluno') — ler de novo deve
      // disparar nova chamada ao repository.
      await container.read(usuariosPorPerfilProvider('aluno').future);
      verify(() => mockRepo.listarUsuariosPorPerfil('aluno')).called(1);
    });
  });

  group('UsuariosController.editarUsuario', () {
    test('invalida o perfil INFORMADO como parâmetro, não deduz de '
        'outro lugar', () async {
      when(() => mockRepo.listarUsuariosPorPerfil('professor'))
          .thenAnswer((_) async => <UsuarioModel>[]);
      when(() => mockRepo.editarUsuario(
            id: any(named: 'id'),
            nome: any(named: 'nome'),
            email: any(named: 'email'),
          )).thenAnswer((_) async {});

      final container = buildContainer();
      await container.read(usuariosPorPerfilProvider('professor').future);
      clearInteractions(mockRepo);
      when(() => mockRepo.listarUsuariosPorPerfil('professor'))
          .thenAnswer((_) async => <UsuarioModel>[]);
      when(() => mockRepo.editarUsuario(
            id: any(named: 'id'),
            nome: any(named: 'nome'),
            email: any(named: 'email'),
          )).thenAnswer((_) async {});

      final controller = container.read(usuariosControllerProvider);

      await controller.editarUsuario(
        id: 'prof-001',
        nome: 'Professor Editado',
        email: 'prof@sci.uece.br',
        perfil: 'professor',
      );

      verify(() => mockRepo.editarUsuario(
            id: 'prof-001',
            nome: 'Professor Editado',
            email: 'prof@sci.uece.br',
          )).called(1);

      await container.read(usuariosPorPerfilProvider('professor').future);
      verify(() => mockRepo.listarUsuariosPorPerfil('professor')).called(1);
    });
  });

  group('UsuariosController.desativarUsuario / reativarUsuario', () {
    test('desativarUsuario chama o repository com o id certo e '
        'invalida o perfil certo', () async {
      when(() => mockRepo.listarUsuariosPorPerfil('supervisor'))
          .thenAnswer((_) async => <UsuarioModel>[]);
      when(() => mockRepo.desativarUsuario(any()))
          .thenAnswer((_) async {});

      final container = buildContainer();
      await container.read(usuariosPorPerfilProvider('supervisor').future);
      clearInteractions(mockRepo);
      when(() => mockRepo.listarUsuariosPorPerfil('supervisor'))
          .thenAnswer((_) async => <UsuarioModel>[]);
      when(() => mockRepo.desativarUsuario(any()))
          .thenAnswer((_) async {});

      final controller = container.read(usuariosControllerProvider);
      await controller.desativarUsuario('sup-005', 'supervisor');

      verify(() => mockRepo.desativarUsuario('sup-005')).called(1);
      await container.read(usuariosPorPerfilProvider('supervisor').future);
      verify(() => mockRepo.listarUsuariosPorPerfil('supervisor')).called(1);
    });

    test('reativarUsuario chama o repository com o id certo e '
        'invalida o perfil certo', () async {
      when(() => mockRepo.listarUsuariosPorPerfil('aluno'))
          .thenAnswer((_) async => <UsuarioModel>[]);
      when(() => mockRepo.reativarUsuario(any()))
          .thenAnswer((_) async {});

      final container = buildContainer();
      await container.read(usuariosPorPerfilProvider('aluno').future);
      clearInteractions(mockRepo);
      when(() => mockRepo.listarUsuariosPorPerfil('aluno'))
          .thenAnswer((_) async => <UsuarioModel>[]);
      when(() => mockRepo.reativarUsuario(any()))
          .thenAnswer((_) async {});

      final controller = container.read(usuariosControllerProvider);
      await controller.reativarUsuario('al-777', 'aluno');

      verify(() => mockRepo.reativarUsuario('al-777')).called(1);
      await container.read(usuariosPorPerfilProvider('aluno').future);
      verify(() => mockRepo.listarUsuariosPorPerfil('aluno')).called(1);
    });
  });
}
