import 'package:drift/drift.dart';
import 'db_connection/cache_db_connection.dart' as db_conn;

part 'cache_service.g.dart';

@DataClassName('SyncQueueEntry')
class SyncQueueTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get operacao => text()();
  TextColumn get tabela => text()();
  TextColumn get payload => text()();
  IntColumn get criadoEm => integer()();
  IntColumn get tentativas => integer().withDefault(const Constant(0))();
  TextColumn get erroUltimo => text().nullable()();
  TextColumn get registroId => text().nullable()();
}

@DataClassName('CacheFrequenciaEntry')
class CacheFrequenciasTable extends Table {
  TextColumn get id => text()();
  TextColumn get dadosJson => text()();
  IntColumn get atualizadoEm => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CacheAtividadeEntry')
class CacheAtividadesTable extends Table {
  TextColumn get id => text()();
  TextColumn get dadosJson => text()();
  IntColumn get atualizadoEm => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CacheAvaliacaoEntry')
class CacheAvaliacoesTable extends Table {
  TextColumn get id => text()();
  TextColumn get dadosJson => text()();
  IntColumn get atualizadoEm => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CacheCampoEntry')
class CacheCamposTable extends Table {
  TextColumn get id => text()();
  TextColumn get dadosJson => text()();
  IntColumn get atualizadoEm => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CacheTurnoEntry')
class CacheTurnosTable extends Table {
  TextColumn get id => text()();
  TextColumn get dadosJson => text()();
  IntColumn get atualizadoEm => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CacheUsuarioPublicoEntry')
class CacheUsuariosPublicoTable extends Table {
  TextColumn get id => text()();
  TextColumn get dadosJson => text()();
  IntColumn get atualizadoEm => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  SyncQueueTable,
  CacheFrequenciasTable,
  CacheAtividadesTable,
  CacheAvaliacoesTable,
  CacheCamposTable,
  CacheTurnosTable,
  CacheUsuariosPublicoTable,
])
class CacheService extends _$CacheService {
  CacheService([QueryExecutor? executor]) : super(executor ?? db_conn.openConnection());

  @override
  int get schemaVersion => 1;

  // -- Métodos de SyncQueue --
  Future<List<SyncQueueEntry>> getPendingSyncEntries() async {
    return (select(syncQueueTable)
          ..where((tbl) => tbl.tentativas.isSmallerThanValue(3))
          ..orderBy([(t) => OrderingTerm.asc(t.criadoEm)]))
        .get();
  }

  Future<List<SyncQueueEntry>> getAllSyncEntries() async {
    return (select(syncQueueTable)..orderBy([(t) => OrderingTerm.asc(t.criadoEm)])).get();
  }

  Future<int> enqueueSync({
    required String operacao,
    required String tabela,
    required String payload,
    String? registroId,
  }) {
    return into(syncQueueTable).insert(
      SyncQueueTableCompanion.insert(
        operacao: operacao,
        tabela: tabela,
        payload: payload,
        criadoEm: DateTime.now().millisecondsSinceEpoch,
        registroId: Value(registroId),
      ),
    );
  }

  Future<bool> incrementRetry(int id, String erro) async {
    final entry = await (select(syncQueueTable)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (entry == null) return false;
    final novasTentativas = entry.tentativas + 1;
    await (update(syncQueueTable)..where((tbl) => tbl.id.equals(id))).write(
      SyncQueueTableCompanion(
        tentativas: Value(novasTentativas),
        erroUltimo: Value(erro),
      ),
    );
    return true;
  }

  Future<int> removeSyncEntry(int id) {
    return (delete(syncQueueTable)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<SyncQueueEntry?> getSyncEntryByRegistroId(String registroId) {
    return (select(syncQueueTable)..where((tbl) => tbl.registroId.equals(registroId))).getSingleOrNull();
  }

  Future<int> retrySyncEntryManual(int id) async {
    return (update(syncQueueTable)..where((tbl) => tbl.id.equals(id))).write(
      const SyncQueueTableCompanion(
        tentativas: Value(0),
        erroUltimo: Value(null),
      ),
    );
  }

  // -- Métodos de Cache com Suporte a TTL --
  Future<void> cacheItem(String tableName, String id, String jsonStr) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    switch (tableName) {
      case 'frequencias':
        await into(cacheFrequenciasTable).insertOnConflictUpdate(
          CacheFrequenciasTableCompanion.insert(id: id, dadosJson: jsonStr, atualizadoEm: now),
        );
        break;
      case 'atividades':
        await into(cacheAtividadesTable).insertOnConflictUpdate(
          CacheAtividadesTableCompanion.insert(id: id, dadosJson: jsonStr, atualizadoEm: now),
        );
        break;
      case 'avaliacoes':
        await into(cacheAvaliacoesTable).insertOnConflictUpdate(
          CacheAvaliacoesTableCompanion.insert(id: id, dadosJson: jsonStr, atualizadoEm: now),
        );
        break;
      case 'campos_estagio':
        await into(cacheCamposTable).insertOnConflictUpdate(
          CacheCamposTableCompanion.insert(id: id, dadosJson: jsonStr, atualizadoEm: now),
        );
        break;
      case 'turnos':
        await into(cacheTurnosTable).insertOnConflictUpdate(
          CacheTurnosTableCompanion.insert(id: id, dadosJson: jsonStr, atualizadoEm: now),
        );
        break;
      case 'usuarios_publico':
        await into(cacheUsuariosPublicoTable).insertOnConflictUpdate(
          CacheUsuariosPublicoTableCompanion.insert(id: id, dadosJson: jsonStr, atualizadoEm: now),
        );
        break;
    }
  }

  Future<List<String>> getCachedItems(String tableName, {bool applyTtl = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ttl24h = 24 * 60 * 60 * 1000;
    switch (tableName) {
      case 'frequencias':
        final rows = await select(cacheFrequenciasTable).get();
        return rows.map((r) => r.dadosJson).toList();
      case 'atividades':
        final rows = await select(cacheAtividadesTable).get();
        return rows.map((r) => r.dadosJson).toList();
      case 'avaliacoes':
        final rows = await select(cacheAvaliacoesTable).get();
        return rows.map((r) => r.dadosJson).toList();
      case 'campos_estagio':
        final query = select(cacheCamposTable);
        if (applyTtl) {
          query.where((tbl) => tbl.atualizadoEm.isBiggerOrEqualValue(now - ttl24h));
        }
        final rows = await query.get();
        return rows.map((r) => r.dadosJson).toList();
      case 'turnos':
        final query = select(cacheTurnosTable);
        if (applyTtl) {
          query.where((tbl) => tbl.atualizadoEm.isBiggerOrEqualValue(now - ttl24h));
        }
        final rows = await query.get();
        return rows.map((r) => r.dadosJson).toList();
      case 'usuarios_publico':
        final rows = await select(cacheUsuariosPublicoTable).get();
        return rows.map((r) => r.dadosJson).toList();
      default:
        return [];
    }
  }

  Future<void> cacheList(String tableName, List<Map<String, dynamic>> items, String idField) async {
    for (final item in items) {
      final idVal = item[idField]?.toString();
      if (idVal != null) {
        // Encode to simple JSON or preserve string
        final jsonStr = _encodeJsonMap(item);
        await cacheItem(tableName, idVal, jsonStr);
      }
    }
  }

  String _encodeJsonMap(Map<String, dynamic> map) {
    // Basic custom encoder to avoid requiring dart:convert everywhere or standard jsonEncode
    // We use dart:convert's jsonEncode safely
    return _convertToJson(map);
  }

  Future<int> clearExpiredCache() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ttl24h = 24 * 60 * 60 * 1000;
    int deleted = 0;
    deleted += await (delete(cacheCamposTable)..where((tbl) => tbl.atualizadoEm.isSmallerThanValue(now - ttl24h))).go();
    deleted += await (delete(cacheTurnosTable)..where((tbl) => tbl.atualizadoEm.isSmallerThanValue(now - ttl24h))).go();
    return deleted;
  }
}


String _convertToJson(Map<String, dynamic> map) {
  final buffer = StringBuffer('{');
  var first = true;
  map.forEach((key, value) {
    if (!first) buffer.write(',');
    first = false;
    buffer.write('"${_escapeJson(key)}":');
    if (value == null) {
      buffer.write('null');
    } else if (value is num || value is bool) {
      buffer.write('$value');
    } else if (value is Map) {
      buffer.write(_convertToJson(Map<String, dynamic>.from(value)));
    } else if (value is List) {
      buffer.write(_convertListToJson(value));
    } else {
      buffer.write('"${_escapeJson(value.toString())}"');
    }
  });
  buffer.write('}');
  return buffer.toString();
}

String _convertListToJson(List list) {
  final buffer = StringBuffer('[');
  for (var i = 0; i < list.length; i++) {
    if (i > 0) buffer.write(',');
    final value = list[i];
    if (value == null) {
      buffer.write('null');
    } else if (value is num || value is bool) {
      buffer.write('$value');
    } else if (value is Map) {
      buffer.write(_convertToJson(Map<String, dynamic>.from(value)));
    } else if (value is List) {
      buffer.write(_convertListToJson(value));
    } else {
      buffer.write('"${_escapeJson(value.toString())}"');
    }
  }
  buffer.write(']');
  return buffer.toString();
}

String _escapeJson(String input) {
  return input
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('\t', '\\t');
}
