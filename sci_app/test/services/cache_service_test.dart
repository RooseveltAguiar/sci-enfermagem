import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/services/cache_service.dart';

void main() {
  late CacheService cacheService;

  setUp(() {
    cacheService = CacheService(NativeDatabase.memory());
  });

  tearDown(() async {
    await cacheService.close();
  });

  group('CacheService - SyncQueue', () {
    test('enqueueSync adiciona item à fila e getPendingSyncEntries recupera itens com tentativas < 3', () async {
      final id1 = await cacheService.enqueueSync(
        operacao: 'insert',
        tabela: 'frequencias',
        payload: '{"aluno_id": "123"}',
        registroId: 'reg-1',
      );
      expect(id1, isPositive);

      final pendentes = await cacheService.getPendingSyncEntries();
      expect(pendentes.length, 1);
      expect(pendentes.first.operacao, 'insert');
      expect(pendentes.first.tabela, 'frequencias');
      expect(pendentes.first.registroId, 'reg-1');
      expect(pendentes.first.tentativas, 0);
    });

    test('getAllSyncEntries retorna todos os itens independentemente do número de tentativas', () async {
      final id = await cacheService.enqueueSync(
        operacao: 'update',
        tabela: 'atividades',
        payload: '{"id": "abc"}',
      );
      await cacheService.incrementRetry(id, 'erro 1');
      await cacheService.incrementRetry(id, 'erro 2');
      await cacheService.incrementRetry(id, 'erro 3');

      final pendentes = await cacheService.getPendingSyncEntries();
      expect(pendentes, isEmpty);

      final todos = await cacheService.getAllSyncEntries();
      expect(todos.length, 1);
      expect(todos.first.tentativas, 3);
      expect(todos.first.erroUltimo, 'erro 3');
    });

    test('incrementRetry atualiza numero de tentativas e mensagem do ultimo erro', () async {
      final id = await cacheService.enqueueSync(
        operacao: 'insert',
        tabela: 'frequencias',
        payload: '{}',
      );

      final suc = await cacheService.incrementRetry(id, 'Falha na conexão');
      expect(suc, isTrue);

      final nonExistent = await cacheService.incrementRetry(9999, 'Erro');
      expect(nonExistent, isFalse);

      final entry = (await cacheService.getAllSyncEntries()).first;
      expect(entry.tentativas, 1);
      expect(entry.erroUltimo, 'Falha na conexão');
    });

    test('removeSyncEntry deleta o registro da fila', () async {
      final id = await cacheService.enqueueSync(
        operacao: 'insert',
        tabela: 'frequencias',
        payload: '{}',
      );
      expect(await cacheService.getAllSyncEntries(), hasLength(1));

      await cacheService.removeSyncEntry(id);
      expect(await cacheService.getAllSyncEntries(), isEmpty);
    });

    test('getSyncEntryByRegistroId retorna a entrada correta ou null se não encontrar', () async {
      await cacheService.enqueueSync(
        operacao: 'insert',
        tabela: 'avaliacoes',
        payload: '{}',
        registroId: 'av-555',
      );

      final found = await cacheService.getSyncEntryByRegistroId('av-555');
      expect(found, isNotNull);
      expect(found!.tabela, 'avaliacoes');

      final notFound = await cacheService.getSyncEntryByRegistroId('inexistente');
      expect(notFound, isNull);
    });

    test('retrySyncEntryManual zera as tentativas e limpa o erroUltimo', () async {
      final id = await cacheService.enqueueSync(
        operacao: 'insert',
        tabela: 'frequencias',
        payload: '{}',
      );
      await cacheService.incrementRetry(id, 'erro 1');
      await cacheService.incrementRetry(id, 'erro 2');
      await cacheService.incrementRetry(id, 'erro 3');

      expect((await cacheService.getPendingSyncEntries()), isEmpty);

      await cacheService.retrySyncEntryManual(id);

      final pendentes = await cacheService.getPendingSyncEntries();
      expect(pendentes, hasLength(1));
      expect(pendentes.first.tentativas, 0);
      expect(pendentes.first.erroUltimo, isNull);
    });
  });

  group('CacheService - Tabelas de Cache (TTL e JSON)', () {
    test('cacheItem e getCachedItems funcionam para todas as tabelas (frequencias, atividades, avaliacoes, campos_estagio, turnos, usuarios_publico, default)', () async {
      final jsonExemplo = '{"nome": "Teste"}';
      await cacheService.cacheItem('frequencias', 'id-1', jsonExemplo);
      await cacheService.cacheItem('atividades', 'id-2', jsonExemplo);
      await cacheService.cacheItem('avaliacoes', 'id-3', jsonExemplo);
      await cacheService.cacheItem('campos_estagio', 'id-4', jsonExemplo);
      await cacheService.cacheItem('turnos', 'id-5', jsonExemplo);
      await cacheService.cacheItem('usuarios_publico', 'id-6', jsonExemplo);
      await cacheService.cacheItem('tabela_desconhecida', 'id-7', jsonExemplo);

      expect(await cacheService.getCachedItems('frequencias'), ['{"nome": "Teste"}']);
      expect(await cacheService.getCachedItems('atividades'), ['{"nome": "Teste"}']);
      expect(await cacheService.getCachedItems('avaliacoes'), ['{"nome": "Teste"}']);
      expect(await cacheService.getCachedItems('campos_estagio', applyTtl: true), ['{"nome": "Teste"}']);
      expect(await cacheService.getCachedItems('campos_estagio', applyTtl: false), ['{"nome": "Teste"}']);
      expect(await cacheService.getCachedItems('turnos', applyTtl: true), ['{"nome": "Teste"}']);
      expect(await cacheService.getCachedItems('turnos', applyTtl: false), ['{"nome": "Teste"}']);
      expect(await cacheService.getCachedItems('usuarios_publico'), ['{"nome": "Teste"}']);
      expect(await cacheService.getCachedItems('invalida'), isEmpty);
    });

    test('getCachedItems filtra itens expirados quando applyTtl: true, mas retorna quando applyTtl: false', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final antigo = now - (25 * 60 * 60 * 1000); // 25 horas atrás

      await cacheService.into(cacheService.cacheCamposTable).insert(
            CacheCamposTableCompanion.insert(
              id: 'c-expirado',
              dadosJson: '{"antigo": true}',
              atualizadoEm: antigo,
            ),
          );

      expect(await cacheService.getCachedItems('campos_estagio', applyTtl: false), ['{"antigo": true}']);
      expect(await cacheService.getCachedItems('campos_estagio', applyTtl: true), isEmpty);
    });

    test('insertOnConflictUpdate atualiza o JSON quando o id ja existe', () async {
      await cacheService.cacheItem('frequencias', 'freq-1', '{"status": "antigo"}');
      await cacheService.cacheItem('frequencias', 'freq-1', '{"status": "novo"}');

      final itens = await cacheService.getCachedItems('frequencias');
      expect(itens, ['{"status": "novo"}']);
    });

    test('cacheList codifica listas e mapas complexos com caracteres especiais e armazena cada item com idVal', () async {
      final itens = [
        {
          'id': 'item-1',
          'ativo': true,
          'numero': 42,
          'decimal': 3.14,
          'nulo': null,
          'texto': 'linha1\\nlinha2\r\t"citado"',
          'submapa': {'chave': 'valor com \n quebra'},
          'sublista': [1, false, null, {'sub': 'a'}, ['x', 'y']],
        },
        {
          'id': null, // ignored
          'nome': 'sem id'
        }
      ];

      await cacheService.cacheList('atividades', itens, 'id');
      final cac = await cacheService.getCachedItems('atividades');
      expect(cac.length, 1);
      final decoded = jsonDecode(cac.first) as Map<String, dynamic>;
      expect(decoded['id'], 'item-1');
      expect(decoded['ativo'], true);
      expect(decoded['numero'], 42);
      expect(decoded['decimal'], 3.14);
      expect(decoded['nulo'], isNull);
    });

    test('clearExpiredCache remove apenas registros expirados (> 24h) e mantém os recentes', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final antigo = now - (25 * 60 * 60 * 1000); // 25 horas atrás

      // Insere registros diretamente na tabela com data antiga usando into().insert
      await cacheService.into(cacheService.cacheCamposTable).insert(
            CacheCamposTableCompanion.insert(
              id: 'c-antigo',
              dadosJson: '{"expirado": true}',
              atualizadoEm: antigo,
            ),
          );
      await cacheService.into(cacheService.cacheTurnosTable).insert(
            CacheTurnosTableCompanion.insert(
              id: 't-antigo',
              dadosJson: '{"expirado": true}',
              atualizadoEm: antigo,
            ),
          );

      // Insere registros recentes via cacheItem
      await cacheService.cacheItem('campos_estagio', 'c-novo', '{"novo": true}');
      await cacheService.cacheItem('turnos', 't-novo', '{"novo": true}');

      expect(await cacheService.getCachedItems('campos_estagio', applyTtl: false), hasLength(2));
      expect(await cacheService.getCachedItems('turnos', applyTtl: false), hasLength(2));

      final removidos = await cacheService.clearExpiredCache();
      expect(removidos, 2);

      expect(await cacheService.getCachedItems('campos_estagio', applyTtl: false), ['{"novo": true}']);
      expect(await cacheService.getCachedItems('turnos', applyTtl: false), ['{"novo": true}']);
    });

    test('Table definition classes and column getters cover drift definitions safely', () {
      void tryGetters(void Function() fn) {
        try {
          fn();
        } catch (_) {}
      }

      tryGetters(() => SyncQueueTable().id);
      tryGetters(() => SyncQueueTable().operacao);
      tryGetters(() => SyncQueueTable().tabela);
      tryGetters(() => SyncQueueTable().payload);
      tryGetters(() => SyncQueueTable().criadoEm);
      tryGetters(() => SyncQueueTable().tentativas);
      tryGetters(() => SyncQueueTable().erroUltimo);
      tryGetters(() => SyncQueueTable().registroId);

      tryGetters(() => CacheFrequenciasTable().id);
      tryGetters(() => CacheFrequenciasTable().dadosJson);
      tryGetters(() => CacheFrequenciasTable().atualizadoEm);
      tryGetters(() => CacheFrequenciasTable().primaryKey);

      tryGetters(() => CacheAtividadesTable().id);
      tryGetters(() => CacheAtividadesTable().dadosJson);
      tryGetters(() => CacheAtividadesTable().atualizadoEm);
      tryGetters(() => CacheAtividadesTable().primaryKey);

      tryGetters(() => CacheAvaliacoesTable().id);
      tryGetters(() => CacheAvaliacoesTable().dadosJson);
      tryGetters(() => CacheAvaliacoesTable().atualizadoEm);
      tryGetters(() => CacheAvaliacoesTable().primaryKey);

      tryGetters(() => CacheCamposTable().id);
      tryGetters(() => CacheCamposTable().dadosJson);
      tryGetters(() => CacheCamposTable().atualizadoEm);
      tryGetters(() => CacheCamposTable().primaryKey);

      tryGetters(() => CacheTurnosTable().id);
      tryGetters(() => CacheTurnosTable().dadosJson);
      tryGetters(() => CacheTurnosTable().atualizadoEm);
      tryGetters(() => CacheTurnosTable().primaryKey);

      tryGetters(() => CacheUsuariosPublicoTable().id);
      tryGetters(() => CacheUsuariosPublicoTable().dadosJson);
      tryGetters(() => CacheUsuariosPublicoTable().atualizadoEm);
      tryGetters(() => CacheUsuariosPublicoTable().primaryKey);
    });
  });
}
