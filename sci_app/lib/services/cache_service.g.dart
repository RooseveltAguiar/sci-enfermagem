// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_service.dart';

// ignore_for_file: type=lint
class $SyncQueueTableTable extends SyncQueueTable
    with TableInfo<$SyncQueueTableTable, SyncQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _operacaoMeta = const VerificationMeta(
    'operacao',
  );
  @override
  late final GeneratedColumn<String> operacao = GeneratedColumn<String>(
    'operacao',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tabelaMeta = const VerificationMeta('tabela');
  @override
  late final GeneratedColumn<String> tabela = GeneratedColumn<String>(
    'tabela',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _criadoEmMeta = const VerificationMeta(
    'criadoEm',
  );
  @override
  late final GeneratedColumn<int> criadoEm = GeneratedColumn<int>(
    'criado_em',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tentativasMeta = const VerificationMeta(
    'tentativas',
  );
  @override
  late final GeneratedColumn<int> tentativas = GeneratedColumn<int>(
    'tentativas',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _erroUltimoMeta = const VerificationMeta(
    'erroUltimo',
  );
  @override
  late final GeneratedColumn<String> erroUltimo = GeneratedColumn<String>(
    'erro_ultimo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _registroIdMeta = const VerificationMeta(
    'registroId',
  );
  @override
  late final GeneratedColumn<String> registroId = GeneratedColumn<String>(
    'registro_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    operacao,
    tabela,
    payload,
    criadoEm,
    tentativas,
    erroUltimo,
    registroId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('operacao')) {
      context.handle(
        _operacaoMeta,
        operacao.isAcceptableOrUnknown(data['operacao']!, _operacaoMeta),
      );
    } else if (isInserting) {
      context.missing(_operacaoMeta);
    }
    if (data.containsKey('tabela')) {
      context.handle(
        _tabelaMeta,
        tabela.isAcceptableOrUnknown(data['tabela']!, _tabelaMeta),
      );
    } else if (isInserting) {
      context.missing(_tabelaMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('criado_em')) {
      context.handle(
        _criadoEmMeta,
        criadoEm.isAcceptableOrUnknown(data['criado_em']!, _criadoEmMeta),
      );
    } else if (isInserting) {
      context.missing(_criadoEmMeta);
    }
    if (data.containsKey('tentativas')) {
      context.handle(
        _tentativasMeta,
        tentativas.isAcceptableOrUnknown(data['tentativas']!, _tentativasMeta),
      );
    }
    if (data.containsKey('erro_ultimo')) {
      context.handle(
        _erroUltimoMeta,
        erroUltimo.isAcceptableOrUnknown(data['erro_ultimo']!, _erroUltimoMeta),
      );
    }
    if (data.containsKey('registro_id')) {
      context.handle(
        _registroIdMeta,
        registroId.isAcceptableOrUnknown(data['registro_id']!, _registroIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      operacao: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operacao'],
      )!,
      tabela: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tabela'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      criadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}criado_em'],
      )!,
      tentativas: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tentativas'],
      )!,
      erroUltimo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}erro_ultimo'],
      ),
      registroId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}registro_id'],
      ),
    );
  }

  @override
  $SyncQueueTableTable createAlias(String alias) {
    return $SyncQueueTableTable(attachedDatabase, alias);
  }
}

class SyncQueueEntry extends DataClass implements Insertable<SyncQueueEntry> {
  final int id;
  final String operacao;
  final String tabela;
  final String payload;
  final int criadoEm;
  final int tentativas;
  final String? erroUltimo;
  final String? registroId;
  const SyncQueueEntry({
    required this.id,
    required this.operacao,
    required this.tabela,
    required this.payload,
    required this.criadoEm,
    required this.tentativas,
    this.erroUltimo,
    this.registroId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['operacao'] = Variable<String>(operacao);
    map['tabela'] = Variable<String>(tabela);
    map['payload'] = Variable<String>(payload);
    map['criado_em'] = Variable<int>(criadoEm);
    map['tentativas'] = Variable<int>(tentativas);
    if (!nullToAbsent || erroUltimo != null) {
      map['erro_ultimo'] = Variable<String>(erroUltimo);
    }
    if (!nullToAbsent || registroId != null) {
      map['registro_id'] = Variable<String>(registroId);
    }
    return map;
  }

  SyncQueueTableCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueTableCompanion(
      id: Value(id),
      operacao: Value(operacao),
      tabela: Value(tabela),
      payload: Value(payload),
      criadoEm: Value(criadoEm),
      tentativas: Value(tentativas),
      erroUltimo: erroUltimo == null && nullToAbsent
          ? const Value.absent()
          : Value(erroUltimo),
      registroId: registroId == null && nullToAbsent
          ? const Value.absent()
          : Value(registroId),
    );
  }

  factory SyncQueueEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueEntry(
      id: serializer.fromJson<int>(json['id']),
      operacao: serializer.fromJson<String>(json['operacao']),
      tabela: serializer.fromJson<String>(json['tabela']),
      payload: serializer.fromJson<String>(json['payload']),
      criadoEm: serializer.fromJson<int>(json['criadoEm']),
      tentativas: serializer.fromJson<int>(json['tentativas']),
      erroUltimo: serializer.fromJson<String?>(json['erroUltimo']),
      registroId: serializer.fromJson<String?>(json['registroId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'operacao': serializer.toJson<String>(operacao),
      'tabela': serializer.toJson<String>(tabela),
      'payload': serializer.toJson<String>(payload),
      'criadoEm': serializer.toJson<int>(criadoEm),
      'tentativas': serializer.toJson<int>(tentativas),
      'erroUltimo': serializer.toJson<String?>(erroUltimo),
      'registroId': serializer.toJson<String?>(registroId),
    };
  }

  SyncQueueEntry copyWith({
    int? id,
    String? operacao,
    String? tabela,
    String? payload,
    int? criadoEm,
    int? tentativas,
    Value<String?> erroUltimo = const Value.absent(),
    Value<String?> registroId = const Value.absent(),
  }) => SyncQueueEntry(
    id: id ?? this.id,
    operacao: operacao ?? this.operacao,
    tabela: tabela ?? this.tabela,
    payload: payload ?? this.payload,
    criadoEm: criadoEm ?? this.criadoEm,
    tentativas: tentativas ?? this.tentativas,
    erroUltimo: erroUltimo.present ? erroUltimo.value : this.erroUltimo,
    registroId: registroId.present ? registroId.value : this.registroId,
  );
  SyncQueueEntry copyWithCompanion(SyncQueueTableCompanion data) {
    return SyncQueueEntry(
      id: data.id.present ? data.id.value : this.id,
      operacao: data.operacao.present ? data.operacao.value : this.operacao,
      tabela: data.tabela.present ? data.tabela.value : this.tabela,
      payload: data.payload.present ? data.payload.value : this.payload,
      criadoEm: data.criadoEm.present ? data.criadoEm.value : this.criadoEm,
      tentativas: data.tentativas.present
          ? data.tentativas.value
          : this.tentativas,
      erroUltimo: data.erroUltimo.present
          ? data.erroUltimo.value
          : this.erroUltimo,
      registroId: data.registroId.present
          ? data.registroId.value
          : this.registroId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueEntry(')
          ..write('id: $id, ')
          ..write('operacao: $operacao, ')
          ..write('tabela: $tabela, ')
          ..write('payload: $payload, ')
          ..write('criadoEm: $criadoEm, ')
          ..write('tentativas: $tentativas, ')
          ..write('erroUltimo: $erroUltimo, ')
          ..write('registroId: $registroId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    operacao,
    tabela,
    payload,
    criadoEm,
    tentativas,
    erroUltimo,
    registroId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueEntry &&
          other.id == this.id &&
          other.operacao == this.operacao &&
          other.tabela == this.tabela &&
          other.payload == this.payload &&
          other.criadoEm == this.criadoEm &&
          other.tentativas == this.tentativas &&
          other.erroUltimo == this.erroUltimo &&
          other.registroId == this.registroId);
}

class SyncQueueTableCompanion extends UpdateCompanion<SyncQueueEntry> {
  final Value<int> id;
  final Value<String> operacao;
  final Value<String> tabela;
  final Value<String> payload;
  final Value<int> criadoEm;
  final Value<int> tentativas;
  final Value<String?> erroUltimo;
  final Value<String?> registroId;
  const SyncQueueTableCompanion({
    this.id = const Value.absent(),
    this.operacao = const Value.absent(),
    this.tabela = const Value.absent(),
    this.payload = const Value.absent(),
    this.criadoEm = const Value.absent(),
    this.tentativas = const Value.absent(),
    this.erroUltimo = const Value.absent(),
    this.registroId = const Value.absent(),
  });
  SyncQueueTableCompanion.insert({
    this.id = const Value.absent(),
    required String operacao,
    required String tabela,
    required String payload,
    required int criadoEm,
    this.tentativas = const Value.absent(),
    this.erroUltimo = const Value.absent(),
    this.registroId = const Value.absent(),
  }) : operacao = Value(operacao),
       tabela = Value(tabela),
       payload = Value(payload),
       criadoEm = Value(criadoEm);
  static Insertable<SyncQueueEntry> custom({
    Expression<int>? id,
    Expression<String>? operacao,
    Expression<String>? tabela,
    Expression<String>? payload,
    Expression<int>? criadoEm,
    Expression<int>? tentativas,
    Expression<String>? erroUltimo,
    Expression<String>? registroId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operacao != null) 'operacao': operacao,
      if (tabela != null) 'tabela': tabela,
      if (payload != null) 'payload': payload,
      if (criadoEm != null) 'criado_em': criadoEm,
      if (tentativas != null) 'tentativas': tentativas,
      if (erroUltimo != null) 'erro_ultimo': erroUltimo,
      if (registroId != null) 'registro_id': registroId,
    });
  }

  SyncQueueTableCompanion copyWith({
    Value<int>? id,
    Value<String>? operacao,
    Value<String>? tabela,
    Value<String>? payload,
    Value<int>? criadoEm,
    Value<int>? tentativas,
    Value<String?>? erroUltimo,
    Value<String?>? registroId,
  }) {
    return SyncQueueTableCompanion(
      id: id ?? this.id,
      operacao: operacao ?? this.operacao,
      tabela: tabela ?? this.tabela,
      payload: payload ?? this.payload,
      criadoEm: criadoEm ?? this.criadoEm,
      tentativas: tentativas ?? this.tentativas,
      erroUltimo: erroUltimo ?? this.erroUltimo,
      registroId: registroId ?? this.registroId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (operacao.present) {
      map['operacao'] = Variable<String>(operacao.value);
    }
    if (tabela.present) {
      map['tabela'] = Variable<String>(tabela.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (criadoEm.present) {
      map['criado_em'] = Variable<int>(criadoEm.value);
    }
    if (tentativas.present) {
      map['tentativas'] = Variable<int>(tentativas.value);
    }
    if (erroUltimo.present) {
      map['erro_ultimo'] = Variable<String>(erroUltimo.value);
    }
    if (registroId.present) {
      map['registro_id'] = Variable<String>(registroId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueTableCompanion(')
          ..write('id: $id, ')
          ..write('operacao: $operacao, ')
          ..write('tabela: $tabela, ')
          ..write('payload: $payload, ')
          ..write('criadoEm: $criadoEm, ')
          ..write('tentativas: $tentativas, ')
          ..write('erroUltimo: $erroUltimo, ')
          ..write('registroId: $registroId')
          ..write(')'))
        .toString();
  }
}

class $CacheFrequenciasTableTable extends CacheFrequenciasTable
    with TableInfo<$CacheFrequenciasTableTable, CacheFrequenciaEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheFrequenciasTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dadosJsonMeta = const VerificationMeta(
    'dadosJson',
  );
  @override
  late final GeneratedColumn<String> dadosJson = GeneratedColumn<String>(
    'dados_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atualizadoEmMeta = const VerificationMeta(
    'atualizadoEm',
  );
  @override
  late final GeneratedColumn<int> atualizadoEm = GeneratedColumn<int>(
    'atualizado_em',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, dadosJson, atualizadoEm];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_frequencias_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheFrequenciaEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dados_json')) {
      context.handle(
        _dadosJsonMeta,
        dadosJson.isAcceptableOrUnknown(data['dados_json']!, _dadosJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dadosJsonMeta);
    }
    if (data.containsKey('atualizado_em')) {
      context.handle(
        _atualizadoEmMeta,
        atualizadoEm.isAcceptableOrUnknown(
          data['atualizado_em']!,
          _atualizadoEmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_atualizadoEmMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CacheFrequenciaEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheFrequenciaEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dadosJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dados_json'],
      )!,
      atualizadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}atualizado_em'],
      )!,
    );
  }

  @override
  $CacheFrequenciasTableTable createAlias(String alias) {
    return $CacheFrequenciasTableTable(attachedDatabase, alias);
  }
}

class CacheFrequenciaEntry extends DataClass
    implements Insertable<CacheFrequenciaEntry> {
  final String id;
  final String dadosJson;
  final int atualizadoEm;
  const CacheFrequenciaEntry({
    required this.id,
    required this.dadosJson,
    required this.atualizadoEm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['dados_json'] = Variable<String>(dadosJson);
    map['atualizado_em'] = Variable<int>(atualizadoEm);
    return map;
  }

  CacheFrequenciasTableCompanion toCompanion(bool nullToAbsent) {
    return CacheFrequenciasTableCompanion(
      id: Value(id),
      dadosJson: Value(dadosJson),
      atualizadoEm: Value(atualizadoEm),
    );
  }

  factory CacheFrequenciaEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheFrequenciaEntry(
      id: serializer.fromJson<String>(json['id']),
      dadosJson: serializer.fromJson<String>(json['dadosJson']),
      atualizadoEm: serializer.fromJson<int>(json['atualizadoEm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dadosJson': serializer.toJson<String>(dadosJson),
      'atualizadoEm': serializer.toJson<int>(atualizadoEm),
    };
  }

  CacheFrequenciaEntry copyWith({
    String? id,
    String? dadosJson,
    int? atualizadoEm,
  }) => CacheFrequenciaEntry(
    id: id ?? this.id,
    dadosJson: dadosJson ?? this.dadosJson,
    atualizadoEm: atualizadoEm ?? this.atualizadoEm,
  );
  CacheFrequenciaEntry copyWithCompanion(CacheFrequenciasTableCompanion data) {
    return CacheFrequenciaEntry(
      id: data.id.present ? data.id.value : this.id,
      dadosJson: data.dadosJson.present ? data.dadosJson.value : this.dadosJson,
      atualizadoEm: data.atualizadoEm.present
          ? data.atualizadoEm.value
          : this.atualizadoEm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheFrequenciaEntry(')
          ..write('id: $id, ')
          ..write('dadosJson: $dadosJson, ')
          ..write('atualizadoEm: $atualizadoEm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dadosJson, atualizadoEm);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheFrequenciaEntry &&
          other.id == this.id &&
          other.dadosJson == this.dadosJson &&
          other.atualizadoEm == this.atualizadoEm);
}

class CacheFrequenciasTableCompanion
    extends UpdateCompanion<CacheFrequenciaEntry> {
  final Value<String> id;
  final Value<String> dadosJson;
  final Value<int> atualizadoEm;
  final Value<int> rowid;
  const CacheFrequenciasTableCompanion({
    this.id = const Value.absent(),
    this.dadosJson = const Value.absent(),
    this.atualizadoEm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheFrequenciasTableCompanion.insert({
    required String id,
    required String dadosJson,
    required int atualizadoEm,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dadosJson = Value(dadosJson),
       atualizadoEm = Value(atualizadoEm);
  static Insertable<CacheFrequenciaEntry> custom({
    Expression<String>? id,
    Expression<String>? dadosJson,
    Expression<int>? atualizadoEm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dadosJson != null) 'dados_json': dadosJson,
      if (atualizadoEm != null) 'atualizado_em': atualizadoEm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheFrequenciasTableCompanion copyWith({
    Value<String>? id,
    Value<String>? dadosJson,
    Value<int>? atualizadoEm,
    Value<int>? rowid,
  }) {
    return CacheFrequenciasTableCompanion(
      id: id ?? this.id,
      dadosJson: dadosJson ?? this.dadosJson,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dadosJson.present) {
      map['dados_json'] = Variable<String>(dadosJson.value);
    }
    if (atualizadoEm.present) {
      map['atualizado_em'] = Variable<int>(atualizadoEm.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheFrequenciasTableCompanion(')
          ..write('id: $id, ')
          ..write('dadosJson: $dadosJson, ')
          ..write('atualizadoEm: $atualizadoEm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheAtividadesTableTable extends CacheAtividadesTable
    with TableInfo<$CacheAtividadesTableTable, CacheAtividadeEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheAtividadesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dadosJsonMeta = const VerificationMeta(
    'dadosJson',
  );
  @override
  late final GeneratedColumn<String> dadosJson = GeneratedColumn<String>(
    'dados_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atualizadoEmMeta = const VerificationMeta(
    'atualizadoEm',
  );
  @override
  late final GeneratedColumn<int> atualizadoEm = GeneratedColumn<int>(
    'atualizado_em',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, dadosJson, atualizadoEm];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_atividades_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheAtividadeEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dados_json')) {
      context.handle(
        _dadosJsonMeta,
        dadosJson.isAcceptableOrUnknown(data['dados_json']!, _dadosJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dadosJsonMeta);
    }
    if (data.containsKey('atualizado_em')) {
      context.handle(
        _atualizadoEmMeta,
        atualizadoEm.isAcceptableOrUnknown(
          data['atualizado_em']!,
          _atualizadoEmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_atualizadoEmMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CacheAtividadeEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheAtividadeEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dadosJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dados_json'],
      )!,
      atualizadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}atualizado_em'],
      )!,
    );
  }

  @override
  $CacheAtividadesTableTable createAlias(String alias) {
    return $CacheAtividadesTableTable(attachedDatabase, alias);
  }
}

class CacheAtividadeEntry extends DataClass
    implements Insertable<CacheAtividadeEntry> {
  final String id;
  final String dadosJson;
  final int atualizadoEm;
  const CacheAtividadeEntry({
    required this.id,
    required this.dadosJson,
    required this.atualizadoEm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['dados_json'] = Variable<String>(dadosJson);
    map['atualizado_em'] = Variable<int>(atualizadoEm);
    return map;
  }

  CacheAtividadesTableCompanion toCompanion(bool nullToAbsent) {
    return CacheAtividadesTableCompanion(
      id: Value(id),
      dadosJson: Value(dadosJson),
      atualizadoEm: Value(atualizadoEm),
    );
  }

  factory CacheAtividadeEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheAtividadeEntry(
      id: serializer.fromJson<String>(json['id']),
      dadosJson: serializer.fromJson<String>(json['dadosJson']),
      atualizadoEm: serializer.fromJson<int>(json['atualizadoEm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dadosJson': serializer.toJson<String>(dadosJson),
      'atualizadoEm': serializer.toJson<int>(atualizadoEm),
    };
  }

  CacheAtividadeEntry copyWith({
    String? id,
    String? dadosJson,
    int? atualizadoEm,
  }) => CacheAtividadeEntry(
    id: id ?? this.id,
    dadosJson: dadosJson ?? this.dadosJson,
    atualizadoEm: atualizadoEm ?? this.atualizadoEm,
  );
  CacheAtividadeEntry copyWithCompanion(CacheAtividadesTableCompanion data) {
    return CacheAtividadeEntry(
      id: data.id.present ? data.id.value : this.id,
      dadosJson: data.dadosJson.present ? data.dadosJson.value : this.dadosJson,
      atualizadoEm: data.atualizadoEm.present
          ? data.atualizadoEm.value
          : this.atualizadoEm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheAtividadeEntry(')
          ..write('id: $id, ')
          ..write('dadosJson: $dadosJson, ')
          ..write('atualizadoEm: $atualizadoEm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dadosJson, atualizadoEm);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheAtividadeEntry &&
          other.id == this.id &&
          other.dadosJson == this.dadosJson &&
          other.atualizadoEm == this.atualizadoEm);
}

class CacheAtividadesTableCompanion
    extends UpdateCompanion<CacheAtividadeEntry> {
  final Value<String> id;
  final Value<String> dadosJson;
  final Value<int> atualizadoEm;
  final Value<int> rowid;
  const CacheAtividadesTableCompanion({
    this.id = const Value.absent(),
    this.dadosJson = const Value.absent(),
    this.atualizadoEm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheAtividadesTableCompanion.insert({
    required String id,
    required String dadosJson,
    required int atualizadoEm,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dadosJson = Value(dadosJson),
       atualizadoEm = Value(atualizadoEm);
  static Insertable<CacheAtividadeEntry> custom({
    Expression<String>? id,
    Expression<String>? dadosJson,
    Expression<int>? atualizadoEm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dadosJson != null) 'dados_json': dadosJson,
      if (atualizadoEm != null) 'atualizado_em': atualizadoEm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheAtividadesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? dadosJson,
    Value<int>? atualizadoEm,
    Value<int>? rowid,
  }) {
    return CacheAtividadesTableCompanion(
      id: id ?? this.id,
      dadosJson: dadosJson ?? this.dadosJson,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dadosJson.present) {
      map['dados_json'] = Variable<String>(dadosJson.value);
    }
    if (atualizadoEm.present) {
      map['atualizado_em'] = Variable<int>(atualizadoEm.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheAtividadesTableCompanion(')
          ..write('id: $id, ')
          ..write('dadosJson: $dadosJson, ')
          ..write('atualizadoEm: $atualizadoEm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheAvaliacoesTableTable extends CacheAvaliacoesTable
    with TableInfo<$CacheAvaliacoesTableTable, CacheAvaliacaoEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheAvaliacoesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dadosJsonMeta = const VerificationMeta(
    'dadosJson',
  );
  @override
  late final GeneratedColumn<String> dadosJson = GeneratedColumn<String>(
    'dados_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atualizadoEmMeta = const VerificationMeta(
    'atualizadoEm',
  );
  @override
  late final GeneratedColumn<int> atualizadoEm = GeneratedColumn<int>(
    'atualizado_em',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, dadosJson, atualizadoEm];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_avaliacoes_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheAvaliacaoEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dados_json')) {
      context.handle(
        _dadosJsonMeta,
        dadosJson.isAcceptableOrUnknown(data['dados_json']!, _dadosJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dadosJsonMeta);
    }
    if (data.containsKey('atualizado_em')) {
      context.handle(
        _atualizadoEmMeta,
        atualizadoEm.isAcceptableOrUnknown(
          data['atualizado_em']!,
          _atualizadoEmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_atualizadoEmMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CacheAvaliacaoEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheAvaliacaoEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dadosJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dados_json'],
      )!,
      atualizadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}atualizado_em'],
      )!,
    );
  }

  @override
  $CacheAvaliacoesTableTable createAlias(String alias) {
    return $CacheAvaliacoesTableTable(attachedDatabase, alias);
  }
}

class CacheAvaliacaoEntry extends DataClass
    implements Insertable<CacheAvaliacaoEntry> {
  final String id;
  final String dadosJson;
  final int atualizadoEm;
  const CacheAvaliacaoEntry({
    required this.id,
    required this.dadosJson,
    required this.atualizadoEm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['dados_json'] = Variable<String>(dadosJson);
    map['atualizado_em'] = Variable<int>(atualizadoEm);
    return map;
  }

  CacheAvaliacoesTableCompanion toCompanion(bool nullToAbsent) {
    return CacheAvaliacoesTableCompanion(
      id: Value(id),
      dadosJson: Value(dadosJson),
      atualizadoEm: Value(atualizadoEm),
    );
  }

  factory CacheAvaliacaoEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheAvaliacaoEntry(
      id: serializer.fromJson<String>(json['id']),
      dadosJson: serializer.fromJson<String>(json['dadosJson']),
      atualizadoEm: serializer.fromJson<int>(json['atualizadoEm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dadosJson': serializer.toJson<String>(dadosJson),
      'atualizadoEm': serializer.toJson<int>(atualizadoEm),
    };
  }

  CacheAvaliacaoEntry copyWith({
    String? id,
    String? dadosJson,
    int? atualizadoEm,
  }) => CacheAvaliacaoEntry(
    id: id ?? this.id,
    dadosJson: dadosJson ?? this.dadosJson,
    atualizadoEm: atualizadoEm ?? this.atualizadoEm,
  );
  CacheAvaliacaoEntry copyWithCompanion(CacheAvaliacoesTableCompanion data) {
    return CacheAvaliacaoEntry(
      id: data.id.present ? data.id.value : this.id,
      dadosJson: data.dadosJson.present ? data.dadosJson.value : this.dadosJson,
      atualizadoEm: data.atualizadoEm.present
          ? data.atualizadoEm.value
          : this.atualizadoEm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheAvaliacaoEntry(')
          ..write('id: $id, ')
          ..write('dadosJson: $dadosJson, ')
          ..write('atualizadoEm: $atualizadoEm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dadosJson, atualizadoEm);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheAvaliacaoEntry &&
          other.id == this.id &&
          other.dadosJson == this.dadosJson &&
          other.atualizadoEm == this.atualizadoEm);
}

class CacheAvaliacoesTableCompanion
    extends UpdateCompanion<CacheAvaliacaoEntry> {
  final Value<String> id;
  final Value<String> dadosJson;
  final Value<int> atualizadoEm;
  final Value<int> rowid;
  const CacheAvaliacoesTableCompanion({
    this.id = const Value.absent(),
    this.dadosJson = const Value.absent(),
    this.atualizadoEm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheAvaliacoesTableCompanion.insert({
    required String id,
    required String dadosJson,
    required int atualizadoEm,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dadosJson = Value(dadosJson),
       atualizadoEm = Value(atualizadoEm);
  static Insertable<CacheAvaliacaoEntry> custom({
    Expression<String>? id,
    Expression<String>? dadosJson,
    Expression<int>? atualizadoEm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dadosJson != null) 'dados_json': dadosJson,
      if (atualizadoEm != null) 'atualizado_em': atualizadoEm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheAvaliacoesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? dadosJson,
    Value<int>? atualizadoEm,
    Value<int>? rowid,
  }) {
    return CacheAvaliacoesTableCompanion(
      id: id ?? this.id,
      dadosJson: dadosJson ?? this.dadosJson,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dadosJson.present) {
      map['dados_json'] = Variable<String>(dadosJson.value);
    }
    if (atualizadoEm.present) {
      map['atualizado_em'] = Variable<int>(atualizadoEm.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheAvaliacoesTableCompanion(')
          ..write('id: $id, ')
          ..write('dadosJson: $dadosJson, ')
          ..write('atualizadoEm: $atualizadoEm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheCamposTableTable extends CacheCamposTable
    with TableInfo<$CacheCamposTableTable, CacheCampoEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheCamposTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dadosJsonMeta = const VerificationMeta(
    'dadosJson',
  );
  @override
  late final GeneratedColumn<String> dadosJson = GeneratedColumn<String>(
    'dados_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atualizadoEmMeta = const VerificationMeta(
    'atualizadoEm',
  );
  @override
  late final GeneratedColumn<int> atualizadoEm = GeneratedColumn<int>(
    'atualizado_em',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, dadosJson, atualizadoEm];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_campos_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheCampoEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dados_json')) {
      context.handle(
        _dadosJsonMeta,
        dadosJson.isAcceptableOrUnknown(data['dados_json']!, _dadosJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dadosJsonMeta);
    }
    if (data.containsKey('atualizado_em')) {
      context.handle(
        _atualizadoEmMeta,
        atualizadoEm.isAcceptableOrUnknown(
          data['atualizado_em']!,
          _atualizadoEmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_atualizadoEmMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CacheCampoEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheCampoEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dadosJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dados_json'],
      )!,
      atualizadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}atualizado_em'],
      )!,
    );
  }

  @override
  $CacheCamposTableTable createAlias(String alias) {
    return $CacheCamposTableTable(attachedDatabase, alias);
  }
}

class CacheCampoEntry extends DataClass implements Insertable<CacheCampoEntry> {
  final String id;
  final String dadosJson;
  final int atualizadoEm;
  const CacheCampoEntry({
    required this.id,
    required this.dadosJson,
    required this.atualizadoEm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['dados_json'] = Variable<String>(dadosJson);
    map['atualizado_em'] = Variable<int>(atualizadoEm);
    return map;
  }

  CacheCamposTableCompanion toCompanion(bool nullToAbsent) {
    return CacheCamposTableCompanion(
      id: Value(id),
      dadosJson: Value(dadosJson),
      atualizadoEm: Value(atualizadoEm),
    );
  }

  factory CacheCampoEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheCampoEntry(
      id: serializer.fromJson<String>(json['id']),
      dadosJson: serializer.fromJson<String>(json['dadosJson']),
      atualizadoEm: serializer.fromJson<int>(json['atualizadoEm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dadosJson': serializer.toJson<String>(dadosJson),
      'atualizadoEm': serializer.toJson<int>(atualizadoEm),
    };
  }

  CacheCampoEntry copyWith({
    String? id,
    String? dadosJson,
    int? atualizadoEm,
  }) => CacheCampoEntry(
    id: id ?? this.id,
    dadosJson: dadosJson ?? this.dadosJson,
    atualizadoEm: atualizadoEm ?? this.atualizadoEm,
  );
  CacheCampoEntry copyWithCompanion(CacheCamposTableCompanion data) {
    return CacheCampoEntry(
      id: data.id.present ? data.id.value : this.id,
      dadosJson: data.dadosJson.present ? data.dadosJson.value : this.dadosJson,
      atualizadoEm: data.atualizadoEm.present
          ? data.atualizadoEm.value
          : this.atualizadoEm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheCampoEntry(')
          ..write('id: $id, ')
          ..write('dadosJson: $dadosJson, ')
          ..write('atualizadoEm: $atualizadoEm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dadosJson, atualizadoEm);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheCampoEntry &&
          other.id == this.id &&
          other.dadosJson == this.dadosJson &&
          other.atualizadoEm == this.atualizadoEm);
}

class CacheCamposTableCompanion extends UpdateCompanion<CacheCampoEntry> {
  final Value<String> id;
  final Value<String> dadosJson;
  final Value<int> atualizadoEm;
  final Value<int> rowid;
  const CacheCamposTableCompanion({
    this.id = const Value.absent(),
    this.dadosJson = const Value.absent(),
    this.atualizadoEm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheCamposTableCompanion.insert({
    required String id,
    required String dadosJson,
    required int atualizadoEm,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dadosJson = Value(dadosJson),
       atualizadoEm = Value(atualizadoEm);
  static Insertable<CacheCampoEntry> custom({
    Expression<String>? id,
    Expression<String>? dadosJson,
    Expression<int>? atualizadoEm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dadosJson != null) 'dados_json': dadosJson,
      if (atualizadoEm != null) 'atualizado_em': atualizadoEm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheCamposTableCompanion copyWith({
    Value<String>? id,
    Value<String>? dadosJson,
    Value<int>? atualizadoEm,
    Value<int>? rowid,
  }) {
    return CacheCamposTableCompanion(
      id: id ?? this.id,
      dadosJson: dadosJson ?? this.dadosJson,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dadosJson.present) {
      map['dados_json'] = Variable<String>(dadosJson.value);
    }
    if (atualizadoEm.present) {
      map['atualizado_em'] = Variable<int>(atualizadoEm.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheCamposTableCompanion(')
          ..write('id: $id, ')
          ..write('dadosJson: $dadosJson, ')
          ..write('atualizadoEm: $atualizadoEm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheTurnosTableTable extends CacheTurnosTable
    with TableInfo<$CacheTurnosTableTable, CacheTurnoEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheTurnosTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dadosJsonMeta = const VerificationMeta(
    'dadosJson',
  );
  @override
  late final GeneratedColumn<String> dadosJson = GeneratedColumn<String>(
    'dados_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atualizadoEmMeta = const VerificationMeta(
    'atualizadoEm',
  );
  @override
  late final GeneratedColumn<int> atualizadoEm = GeneratedColumn<int>(
    'atualizado_em',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, dadosJson, atualizadoEm];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_turnos_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheTurnoEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dados_json')) {
      context.handle(
        _dadosJsonMeta,
        dadosJson.isAcceptableOrUnknown(data['dados_json']!, _dadosJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dadosJsonMeta);
    }
    if (data.containsKey('atualizado_em')) {
      context.handle(
        _atualizadoEmMeta,
        atualizadoEm.isAcceptableOrUnknown(
          data['atualizado_em']!,
          _atualizadoEmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_atualizadoEmMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CacheTurnoEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheTurnoEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dadosJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dados_json'],
      )!,
      atualizadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}atualizado_em'],
      )!,
    );
  }

  @override
  $CacheTurnosTableTable createAlias(String alias) {
    return $CacheTurnosTableTable(attachedDatabase, alias);
  }
}

class CacheTurnoEntry extends DataClass implements Insertable<CacheTurnoEntry> {
  final String id;
  final String dadosJson;
  final int atualizadoEm;
  const CacheTurnoEntry({
    required this.id,
    required this.dadosJson,
    required this.atualizadoEm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['dados_json'] = Variable<String>(dadosJson);
    map['atualizado_em'] = Variable<int>(atualizadoEm);
    return map;
  }

  CacheTurnosTableCompanion toCompanion(bool nullToAbsent) {
    return CacheTurnosTableCompanion(
      id: Value(id),
      dadosJson: Value(dadosJson),
      atualizadoEm: Value(atualizadoEm),
    );
  }

  factory CacheTurnoEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheTurnoEntry(
      id: serializer.fromJson<String>(json['id']),
      dadosJson: serializer.fromJson<String>(json['dadosJson']),
      atualizadoEm: serializer.fromJson<int>(json['atualizadoEm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dadosJson': serializer.toJson<String>(dadosJson),
      'atualizadoEm': serializer.toJson<int>(atualizadoEm),
    };
  }

  CacheTurnoEntry copyWith({
    String? id,
    String? dadosJson,
    int? atualizadoEm,
  }) => CacheTurnoEntry(
    id: id ?? this.id,
    dadosJson: dadosJson ?? this.dadosJson,
    atualizadoEm: atualizadoEm ?? this.atualizadoEm,
  );
  CacheTurnoEntry copyWithCompanion(CacheTurnosTableCompanion data) {
    return CacheTurnoEntry(
      id: data.id.present ? data.id.value : this.id,
      dadosJson: data.dadosJson.present ? data.dadosJson.value : this.dadosJson,
      atualizadoEm: data.atualizadoEm.present
          ? data.atualizadoEm.value
          : this.atualizadoEm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheTurnoEntry(')
          ..write('id: $id, ')
          ..write('dadosJson: $dadosJson, ')
          ..write('atualizadoEm: $atualizadoEm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dadosJson, atualizadoEm);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheTurnoEntry &&
          other.id == this.id &&
          other.dadosJson == this.dadosJson &&
          other.atualizadoEm == this.atualizadoEm);
}

class CacheTurnosTableCompanion extends UpdateCompanion<CacheTurnoEntry> {
  final Value<String> id;
  final Value<String> dadosJson;
  final Value<int> atualizadoEm;
  final Value<int> rowid;
  const CacheTurnosTableCompanion({
    this.id = const Value.absent(),
    this.dadosJson = const Value.absent(),
    this.atualizadoEm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheTurnosTableCompanion.insert({
    required String id,
    required String dadosJson,
    required int atualizadoEm,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dadosJson = Value(dadosJson),
       atualizadoEm = Value(atualizadoEm);
  static Insertable<CacheTurnoEntry> custom({
    Expression<String>? id,
    Expression<String>? dadosJson,
    Expression<int>? atualizadoEm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dadosJson != null) 'dados_json': dadosJson,
      if (atualizadoEm != null) 'atualizado_em': atualizadoEm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheTurnosTableCompanion copyWith({
    Value<String>? id,
    Value<String>? dadosJson,
    Value<int>? atualizadoEm,
    Value<int>? rowid,
  }) {
    return CacheTurnosTableCompanion(
      id: id ?? this.id,
      dadosJson: dadosJson ?? this.dadosJson,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dadosJson.present) {
      map['dados_json'] = Variable<String>(dadosJson.value);
    }
    if (atualizadoEm.present) {
      map['atualizado_em'] = Variable<int>(atualizadoEm.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheTurnosTableCompanion(')
          ..write('id: $id, ')
          ..write('dadosJson: $dadosJson, ')
          ..write('atualizadoEm: $atualizadoEm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheUsuariosPublicoTableTable extends CacheUsuariosPublicoTable
    with TableInfo<$CacheUsuariosPublicoTableTable, CacheUsuarioPublicoEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheUsuariosPublicoTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dadosJsonMeta = const VerificationMeta(
    'dadosJson',
  );
  @override
  late final GeneratedColumn<String> dadosJson = GeneratedColumn<String>(
    'dados_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atualizadoEmMeta = const VerificationMeta(
    'atualizadoEm',
  );
  @override
  late final GeneratedColumn<int> atualizadoEm = GeneratedColumn<int>(
    'atualizado_em',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, dadosJson, atualizadoEm];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_usuarios_publico_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheUsuarioPublicoEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dados_json')) {
      context.handle(
        _dadosJsonMeta,
        dadosJson.isAcceptableOrUnknown(data['dados_json']!, _dadosJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dadosJsonMeta);
    }
    if (data.containsKey('atualizado_em')) {
      context.handle(
        _atualizadoEmMeta,
        atualizadoEm.isAcceptableOrUnknown(
          data['atualizado_em']!,
          _atualizadoEmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_atualizadoEmMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CacheUsuarioPublicoEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheUsuarioPublicoEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dadosJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dados_json'],
      )!,
      atualizadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}atualizado_em'],
      )!,
    );
  }

  @override
  $CacheUsuariosPublicoTableTable createAlias(String alias) {
    return $CacheUsuariosPublicoTableTable(attachedDatabase, alias);
  }
}

class CacheUsuarioPublicoEntry extends DataClass
    implements Insertable<CacheUsuarioPublicoEntry> {
  final String id;
  final String dadosJson;
  final int atualizadoEm;
  const CacheUsuarioPublicoEntry({
    required this.id,
    required this.dadosJson,
    required this.atualizadoEm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['dados_json'] = Variable<String>(dadosJson);
    map['atualizado_em'] = Variable<int>(atualizadoEm);
    return map;
  }

  CacheUsuariosPublicoTableCompanion toCompanion(bool nullToAbsent) {
    return CacheUsuariosPublicoTableCompanion(
      id: Value(id),
      dadosJson: Value(dadosJson),
      atualizadoEm: Value(atualizadoEm),
    );
  }

  factory CacheUsuarioPublicoEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheUsuarioPublicoEntry(
      id: serializer.fromJson<String>(json['id']),
      dadosJson: serializer.fromJson<String>(json['dadosJson']),
      atualizadoEm: serializer.fromJson<int>(json['atualizadoEm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dadosJson': serializer.toJson<String>(dadosJson),
      'atualizadoEm': serializer.toJson<int>(atualizadoEm),
    };
  }

  CacheUsuarioPublicoEntry copyWith({
    String? id,
    String? dadosJson,
    int? atualizadoEm,
  }) => CacheUsuarioPublicoEntry(
    id: id ?? this.id,
    dadosJson: dadosJson ?? this.dadosJson,
    atualizadoEm: atualizadoEm ?? this.atualizadoEm,
  );
  CacheUsuarioPublicoEntry copyWithCompanion(
    CacheUsuariosPublicoTableCompanion data,
  ) {
    return CacheUsuarioPublicoEntry(
      id: data.id.present ? data.id.value : this.id,
      dadosJson: data.dadosJson.present ? data.dadosJson.value : this.dadosJson,
      atualizadoEm: data.atualizadoEm.present
          ? data.atualizadoEm.value
          : this.atualizadoEm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheUsuarioPublicoEntry(')
          ..write('id: $id, ')
          ..write('dadosJson: $dadosJson, ')
          ..write('atualizadoEm: $atualizadoEm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dadosJson, atualizadoEm);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheUsuarioPublicoEntry &&
          other.id == this.id &&
          other.dadosJson == this.dadosJson &&
          other.atualizadoEm == this.atualizadoEm);
}

class CacheUsuariosPublicoTableCompanion
    extends UpdateCompanion<CacheUsuarioPublicoEntry> {
  final Value<String> id;
  final Value<String> dadosJson;
  final Value<int> atualizadoEm;
  final Value<int> rowid;
  const CacheUsuariosPublicoTableCompanion({
    this.id = const Value.absent(),
    this.dadosJson = const Value.absent(),
    this.atualizadoEm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheUsuariosPublicoTableCompanion.insert({
    required String id,
    required String dadosJson,
    required int atualizadoEm,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dadosJson = Value(dadosJson),
       atualizadoEm = Value(atualizadoEm);
  static Insertable<CacheUsuarioPublicoEntry> custom({
    Expression<String>? id,
    Expression<String>? dadosJson,
    Expression<int>? atualizadoEm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dadosJson != null) 'dados_json': dadosJson,
      if (atualizadoEm != null) 'atualizado_em': atualizadoEm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheUsuariosPublicoTableCompanion copyWith({
    Value<String>? id,
    Value<String>? dadosJson,
    Value<int>? atualizadoEm,
    Value<int>? rowid,
  }) {
    return CacheUsuariosPublicoTableCompanion(
      id: id ?? this.id,
      dadosJson: dadosJson ?? this.dadosJson,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dadosJson.present) {
      map['dados_json'] = Variable<String>(dadosJson.value);
    }
    if (atualizadoEm.present) {
      map['atualizado_em'] = Variable<int>(atualizadoEm.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheUsuariosPublicoTableCompanion(')
          ..write('id: $id, ')
          ..write('dadosJson: $dadosJson, ')
          ..write('atualizadoEm: $atualizadoEm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CacheService extends GeneratedDatabase {
  _$CacheService(QueryExecutor e) : super(e);
  $CacheServiceManager get managers => $CacheServiceManager(this);
  late final $SyncQueueTableTable syncQueueTable = $SyncQueueTableTable(this);
  late final $CacheFrequenciasTableTable cacheFrequenciasTable =
      $CacheFrequenciasTableTable(this);
  late final $CacheAtividadesTableTable cacheAtividadesTable =
      $CacheAtividadesTableTable(this);
  late final $CacheAvaliacoesTableTable cacheAvaliacoesTable =
      $CacheAvaliacoesTableTable(this);
  late final $CacheCamposTableTable cacheCamposTable = $CacheCamposTableTable(
    this,
  );
  late final $CacheTurnosTableTable cacheTurnosTable = $CacheTurnosTableTable(
    this,
  );
  late final $CacheUsuariosPublicoTableTable cacheUsuariosPublicoTable =
      $CacheUsuariosPublicoTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    syncQueueTable,
    cacheFrequenciasTable,
    cacheAtividadesTable,
    cacheAvaliacoesTable,
    cacheCamposTable,
    cacheTurnosTable,
    cacheUsuariosPublicoTable,
  ];
}

typedef $$SyncQueueTableTableCreateCompanionBuilder =
    SyncQueueTableCompanion Function({
      Value<int> id,
      required String operacao,
      required String tabela,
      required String payload,
      required int criadoEm,
      Value<int> tentativas,
      Value<String?> erroUltimo,
      Value<String?> registroId,
    });
typedef $$SyncQueueTableTableUpdateCompanionBuilder =
    SyncQueueTableCompanion Function({
      Value<int> id,
      Value<String> operacao,
      Value<String> tabela,
      Value<String> payload,
      Value<int> criadoEm,
      Value<int> tentativas,
      Value<String?> erroUltimo,
      Value<String?> registroId,
    });

class $$SyncQueueTableTableFilterComposer
    extends Composer<_$CacheService, $SyncQueueTableTable> {
  $$SyncQueueTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operacao => $composableBuilder(
    column: $table.operacao,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tabela => $composableBuilder(
    column: $table.tabela,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tentativas => $composableBuilder(
    column: $table.tentativas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get erroUltimo => $composableBuilder(
    column: $table.erroUltimo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get registroId => $composableBuilder(
    column: $table.registroId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableTableOrderingComposer
    extends Composer<_$CacheService, $SyncQueueTableTable> {
  $$SyncQueueTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operacao => $composableBuilder(
    column: $table.operacao,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tabela => $composableBuilder(
    column: $table.tabela,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tentativas => $composableBuilder(
    column: $table.tentativas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get erroUltimo => $composableBuilder(
    column: $table.erroUltimo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registroId => $composableBuilder(
    column: $table.registroId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableTableAnnotationComposer
    extends Composer<_$CacheService, $SyncQueueTableTable> {
  $$SyncQueueTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operacao =>
      $composableBuilder(column: $table.operacao, builder: (column) => column);

  GeneratedColumn<String> get tabela =>
      $composableBuilder(column: $table.tabela, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get criadoEm =>
      $composableBuilder(column: $table.criadoEm, builder: (column) => column);

  GeneratedColumn<int> get tentativas => $composableBuilder(
    column: $table.tentativas,
    builder: (column) => column,
  );

  GeneratedColumn<String> get erroUltimo => $composableBuilder(
    column: $table.erroUltimo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get registroId => $composableBuilder(
    column: $table.registroId,
    builder: (column) => column,
  );
}

class $$SyncQueueTableTableTableManager
    extends
        RootTableManager<
          _$CacheService,
          $SyncQueueTableTable,
          SyncQueueEntry,
          $$SyncQueueTableTableFilterComposer,
          $$SyncQueueTableTableOrderingComposer,
          $$SyncQueueTableTableAnnotationComposer,
          $$SyncQueueTableTableCreateCompanionBuilder,
          $$SyncQueueTableTableUpdateCompanionBuilder,
          (
            SyncQueueEntry,
            BaseReferences<
              _$CacheService,
              $SyncQueueTableTable,
              SyncQueueEntry
            >,
          ),
          SyncQueueEntry,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableTableManager(
    _$CacheService db,
    $SyncQueueTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> operacao = const Value.absent(),
                Value<String> tabela = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> criadoEm = const Value.absent(),
                Value<int> tentativas = const Value.absent(),
                Value<String?> erroUltimo = const Value.absent(),
                Value<String?> registroId = const Value.absent(),
              }) => SyncQueueTableCompanion(
                id: id,
                operacao: operacao,
                tabela: tabela,
                payload: payload,
                criadoEm: criadoEm,
                tentativas: tentativas,
                erroUltimo: erroUltimo,
                registroId: registroId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String operacao,
                required String tabela,
                required String payload,
                required int criadoEm,
                Value<int> tentativas = const Value.absent(),
                Value<String?> erroUltimo = const Value.absent(),
                Value<String?> registroId = const Value.absent(),
              }) => SyncQueueTableCompanion.insert(
                id: id,
                operacao: operacao,
                tabela: tabela,
                payload: payload,
                criadoEm: criadoEm,
                tentativas: tentativas,
                erroUltimo: erroUltimo,
                registroId: registroId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableTableProcessedTableManager =
    ProcessedTableManager<
      _$CacheService,
      $SyncQueueTableTable,
      SyncQueueEntry,
      $$SyncQueueTableTableFilterComposer,
      $$SyncQueueTableTableOrderingComposer,
      $$SyncQueueTableTableAnnotationComposer,
      $$SyncQueueTableTableCreateCompanionBuilder,
      $$SyncQueueTableTableUpdateCompanionBuilder,
      (
        SyncQueueEntry,
        BaseReferences<_$CacheService, $SyncQueueTableTable, SyncQueueEntry>,
      ),
      SyncQueueEntry,
      PrefetchHooks Function()
    >;
typedef $$CacheFrequenciasTableTableCreateCompanionBuilder =
    CacheFrequenciasTableCompanion Function({
      required String id,
      required String dadosJson,
      required int atualizadoEm,
      Value<int> rowid,
    });
typedef $$CacheFrequenciasTableTableUpdateCompanionBuilder =
    CacheFrequenciasTableCompanion Function({
      Value<String> id,
      Value<String> dadosJson,
      Value<int> atualizadoEm,
      Value<int> rowid,
    });

class $$CacheFrequenciasTableTableFilterComposer
    extends Composer<_$CacheService, $CacheFrequenciasTableTable> {
  $$CacheFrequenciasTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dadosJson => $composableBuilder(
    column: $table.dadosJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CacheFrequenciasTableTableOrderingComposer
    extends Composer<_$CacheService, $CacheFrequenciasTableTable> {
  $$CacheFrequenciasTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dadosJson => $composableBuilder(
    column: $table.dadosJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CacheFrequenciasTableTableAnnotationComposer
    extends Composer<_$CacheService, $CacheFrequenciasTableTable> {
  $$CacheFrequenciasTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dadosJson =>
      $composableBuilder(column: $table.dadosJson, builder: (column) => column);

  GeneratedColumn<int> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => column,
  );
}

class $$CacheFrequenciasTableTableTableManager
    extends
        RootTableManager<
          _$CacheService,
          $CacheFrequenciasTableTable,
          CacheFrequenciaEntry,
          $$CacheFrequenciasTableTableFilterComposer,
          $$CacheFrequenciasTableTableOrderingComposer,
          $$CacheFrequenciasTableTableAnnotationComposer,
          $$CacheFrequenciasTableTableCreateCompanionBuilder,
          $$CacheFrequenciasTableTableUpdateCompanionBuilder,
          (
            CacheFrequenciaEntry,
            BaseReferences<
              _$CacheService,
              $CacheFrequenciasTableTable,
              CacheFrequenciaEntry
            >,
          ),
          CacheFrequenciaEntry,
          PrefetchHooks Function()
        > {
  $$CacheFrequenciasTableTableTableManager(
    _$CacheService db,
    $CacheFrequenciasTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheFrequenciasTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CacheFrequenciasTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CacheFrequenciasTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> dadosJson = const Value.absent(),
                Value<int> atualizadoEm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheFrequenciasTableCompanion(
                id: id,
                dadosJson: dadosJson,
                atualizadoEm: atualizadoEm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String dadosJson,
                required int atualizadoEm,
                Value<int> rowid = const Value.absent(),
              }) => CacheFrequenciasTableCompanion.insert(
                id: id,
                dadosJson: dadosJson,
                atualizadoEm: atualizadoEm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CacheFrequenciasTableTableProcessedTableManager =
    ProcessedTableManager<
      _$CacheService,
      $CacheFrequenciasTableTable,
      CacheFrequenciaEntry,
      $$CacheFrequenciasTableTableFilterComposer,
      $$CacheFrequenciasTableTableOrderingComposer,
      $$CacheFrequenciasTableTableAnnotationComposer,
      $$CacheFrequenciasTableTableCreateCompanionBuilder,
      $$CacheFrequenciasTableTableUpdateCompanionBuilder,
      (
        CacheFrequenciaEntry,
        BaseReferences<
          _$CacheService,
          $CacheFrequenciasTableTable,
          CacheFrequenciaEntry
        >,
      ),
      CacheFrequenciaEntry,
      PrefetchHooks Function()
    >;
typedef $$CacheAtividadesTableTableCreateCompanionBuilder =
    CacheAtividadesTableCompanion Function({
      required String id,
      required String dadosJson,
      required int atualizadoEm,
      Value<int> rowid,
    });
typedef $$CacheAtividadesTableTableUpdateCompanionBuilder =
    CacheAtividadesTableCompanion Function({
      Value<String> id,
      Value<String> dadosJson,
      Value<int> atualizadoEm,
      Value<int> rowid,
    });

class $$CacheAtividadesTableTableFilterComposer
    extends Composer<_$CacheService, $CacheAtividadesTableTable> {
  $$CacheAtividadesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dadosJson => $composableBuilder(
    column: $table.dadosJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CacheAtividadesTableTableOrderingComposer
    extends Composer<_$CacheService, $CacheAtividadesTableTable> {
  $$CacheAtividadesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dadosJson => $composableBuilder(
    column: $table.dadosJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CacheAtividadesTableTableAnnotationComposer
    extends Composer<_$CacheService, $CacheAtividadesTableTable> {
  $$CacheAtividadesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dadosJson =>
      $composableBuilder(column: $table.dadosJson, builder: (column) => column);

  GeneratedColumn<int> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => column,
  );
}

class $$CacheAtividadesTableTableTableManager
    extends
        RootTableManager<
          _$CacheService,
          $CacheAtividadesTableTable,
          CacheAtividadeEntry,
          $$CacheAtividadesTableTableFilterComposer,
          $$CacheAtividadesTableTableOrderingComposer,
          $$CacheAtividadesTableTableAnnotationComposer,
          $$CacheAtividadesTableTableCreateCompanionBuilder,
          $$CacheAtividadesTableTableUpdateCompanionBuilder,
          (
            CacheAtividadeEntry,
            BaseReferences<
              _$CacheService,
              $CacheAtividadesTableTable,
              CacheAtividadeEntry
            >,
          ),
          CacheAtividadeEntry,
          PrefetchHooks Function()
        > {
  $$CacheAtividadesTableTableTableManager(
    _$CacheService db,
    $CacheAtividadesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheAtividadesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheAtividadesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CacheAtividadesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> dadosJson = const Value.absent(),
                Value<int> atualizadoEm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheAtividadesTableCompanion(
                id: id,
                dadosJson: dadosJson,
                atualizadoEm: atualizadoEm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String dadosJson,
                required int atualizadoEm,
                Value<int> rowid = const Value.absent(),
              }) => CacheAtividadesTableCompanion.insert(
                id: id,
                dadosJson: dadosJson,
                atualizadoEm: atualizadoEm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CacheAtividadesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$CacheService,
      $CacheAtividadesTableTable,
      CacheAtividadeEntry,
      $$CacheAtividadesTableTableFilterComposer,
      $$CacheAtividadesTableTableOrderingComposer,
      $$CacheAtividadesTableTableAnnotationComposer,
      $$CacheAtividadesTableTableCreateCompanionBuilder,
      $$CacheAtividadesTableTableUpdateCompanionBuilder,
      (
        CacheAtividadeEntry,
        BaseReferences<
          _$CacheService,
          $CacheAtividadesTableTable,
          CacheAtividadeEntry
        >,
      ),
      CacheAtividadeEntry,
      PrefetchHooks Function()
    >;
typedef $$CacheAvaliacoesTableTableCreateCompanionBuilder =
    CacheAvaliacoesTableCompanion Function({
      required String id,
      required String dadosJson,
      required int atualizadoEm,
      Value<int> rowid,
    });
typedef $$CacheAvaliacoesTableTableUpdateCompanionBuilder =
    CacheAvaliacoesTableCompanion Function({
      Value<String> id,
      Value<String> dadosJson,
      Value<int> atualizadoEm,
      Value<int> rowid,
    });

class $$CacheAvaliacoesTableTableFilterComposer
    extends Composer<_$CacheService, $CacheAvaliacoesTableTable> {
  $$CacheAvaliacoesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dadosJson => $composableBuilder(
    column: $table.dadosJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CacheAvaliacoesTableTableOrderingComposer
    extends Composer<_$CacheService, $CacheAvaliacoesTableTable> {
  $$CacheAvaliacoesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dadosJson => $composableBuilder(
    column: $table.dadosJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CacheAvaliacoesTableTableAnnotationComposer
    extends Composer<_$CacheService, $CacheAvaliacoesTableTable> {
  $$CacheAvaliacoesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dadosJson =>
      $composableBuilder(column: $table.dadosJson, builder: (column) => column);

  GeneratedColumn<int> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => column,
  );
}

class $$CacheAvaliacoesTableTableTableManager
    extends
        RootTableManager<
          _$CacheService,
          $CacheAvaliacoesTableTable,
          CacheAvaliacaoEntry,
          $$CacheAvaliacoesTableTableFilterComposer,
          $$CacheAvaliacoesTableTableOrderingComposer,
          $$CacheAvaliacoesTableTableAnnotationComposer,
          $$CacheAvaliacoesTableTableCreateCompanionBuilder,
          $$CacheAvaliacoesTableTableUpdateCompanionBuilder,
          (
            CacheAvaliacaoEntry,
            BaseReferences<
              _$CacheService,
              $CacheAvaliacoesTableTable,
              CacheAvaliacaoEntry
            >,
          ),
          CacheAvaliacaoEntry,
          PrefetchHooks Function()
        > {
  $$CacheAvaliacoesTableTableTableManager(
    _$CacheService db,
    $CacheAvaliacoesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheAvaliacoesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheAvaliacoesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CacheAvaliacoesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> dadosJson = const Value.absent(),
                Value<int> atualizadoEm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheAvaliacoesTableCompanion(
                id: id,
                dadosJson: dadosJson,
                atualizadoEm: atualizadoEm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String dadosJson,
                required int atualizadoEm,
                Value<int> rowid = const Value.absent(),
              }) => CacheAvaliacoesTableCompanion.insert(
                id: id,
                dadosJson: dadosJson,
                atualizadoEm: atualizadoEm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CacheAvaliacoesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$CacheService,
      $CacheAvaliacoesTableTable,
      CacheAvaliacaoEntry,
      $$CacheAvaliacoesTableTableFilterComposer,
      $$CacheAvaliacoesTableTableOrderingComposer,
      $$CacheAvaliacoesTableTableAnnotationComposer,
      $$CacheAvaliacoesTableTableCreateCompanionBuilder,
      $$CacheAvaliacoesTableTableUpdateCompanionBuilder,
      (
        CacheAvaliacaoEntry,
        BaseReferences<
          _$CacheService,
          $CacheAvaliacoesTableTable,
          CacheAvaliacaoEntry
        >,
      ),
      CacheAvaliacaoEntry,
      PrefetchHooks Function()
    >;
typedef $$CacheCamposTableTableCreateCompanionBuilder =
    CacheCamposTableCompanion Function({
      required String id,
      required String dadosJson,
      required int atualizadoEm,
      Value<int> rowid,
    });
typedef $$CacheCamposTableTableUpdateCompanionBuilder =
    CacheCamposTableCompanion Function({
      Value<String> id,
      Value<String> dadosJson,
      Value<int> atualizadoEm,
      Value<int> rowid,
    });

class $$CacheCamposTableTableFilterComposer
    extends Composer<_$CacheService, $CacheCamposTableTable> {
  $$CacheCamposTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dadosJson => $composableBuilder(
    column: $table.dadosJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CacheCamposTableTableOrderingComposer
    extends Composer<_$CacheService, $CacheCamposTableTable> {
  $$CacheCamposTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dadosJson => $composableBuilder(
    column: $table.dadosJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CacheCamposTableTableAnnotationComposer
    extends Composer<_$CacheService, $CacheCamposTableTable> {
  $$CacheCamposTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dadosJson =>
      $composableBuilder(column: $table.dadosJson, builder: (column) => column);

  GeneratedColumn<int> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => column,
  );
}

class $$CacheCamposTableTableTableManager
    extends
        RootTableManager<
          _$CacheService,
          $CacheCamposTableTable,
          CacheCampoEntry,
          $$CacheCamposTableTableFilterComposer,
          $$CacheCamposTableTableOrderingComposer,
          $$CacheCamposTableTableAnnotationComposer,
          $$CacheCamposTableTableCreateCompanionBuilder,
          $$CacheCamposTableTableUpdateCompanionBuilder,
          (
            CacheCampoEntry,
            BaseReferences<
              _$CacheService,
              $CacheCamposTableTable,
              CacheCampoEntry
            >,
          ),
          CacheCampoEntry,
          PrefetchHooks Function()
        > {
  $$CacheCamposTableTableTableManager(
    _$CacheService db,
    $CacheCamposTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheCamposTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheCamposTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheCamposTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> dadosJson = const Value.absent(),
                Value<int> atualizadoEm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheCamposTableCompanion(
                id: id,
                dadosJson: dadosJson,
                atualizadoEm: atualizadoEm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String dadosJson,
                required int atualizadoEm,
                Value<int> rowid = const Value.absent(),
              }) => CacheCamposTableCompanion.insert(
                id: id,
                dadosJson: dadosJson,
                atualizadoEm: atualizadoEm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CacheCamposTableTableProcessedTableManager =
    ProcessedTableManager<
      _$CacheService,
      $CacheCamposTableTable,
      CacheCampoEntry,
      $$CacheCamposTableTableFilterComposer,
      $$CacheCamposTableTableOrderingComposer,
      $$CacheCamposTableTableAnnotationComposer,
      $$CacheCamposTableTableCreateCompanionBuilder,
      $$CacheCamposTableTableUpdateCompanionBuilder,
      (
        CacheCampoEntry,
        BaseReferences<_$CacheService, $CacheCamposTableTable, CacheCampoEntry>,
      ),
      CacheCampoEntry,
      PrefetchHooks Function()
    >;
typedef $$CacheTurnosTableTableCreateCompanionBuilder =
    CacheTurnosTableCompanion Function({
      required String id,
      required String dadosJson,
      required int atualizadoEm,
      Value<int> rowid,
    });
typedef $$CacheTurnosTableTableUpdateCompanionBuilder =
    CacheTurnosTableCompanion Function({
      Value<String> id,
      Value<String> dadosJson,
      Value<int> atualizadoEm,
      Value<int> rowid,
    });

class $$CacheTurnosTableTableFilterComposer
    extends Composer<_$CacheService, $CacheTurnosTableTable> {
  $$CacheTurnosTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dadosJson => $composableBuilder(
    column: $table.dadosJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CacheTurnosTableTableOrderingComposer
    extends Composer<_$CacheService, $CacheTurnosTableTable> {
  $$CacheTurnosTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dadosJson => $composableBuilder(
    column: $table.dadosJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CacheTurnosTableTableAnnotationComposer
    extends Composer<_$CacheService, $CacheTurnosTableTable> {
  $$CacheTurnosTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dadosJson =>
      $composableBuilder(column: $table.dadosJson, builder: (column) => column);

  GeneratedColumn<int> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => column,
  );
}

class $$CacheTurnosTableTableTableManager
    extends
        RootTableManager<
          _$CacheService,
          $CacheTurnosTableTable,
          CacheTurnoEntry,
          $$CacheTurnosTableTableFilterComposer,
          $$CacheTurnosTableTableOrderingComposer,
          $$CacheTurnosTableTableAnnotationComposer,
          $$CacheTurnosTableTableCreateCompanionBuilder,
          $$CacheTurnosTableTableUpdateCompanionBuilder,
          (
            CacheTurnoEntry,
            BaseReferences<
              _$CacheService,
              $CacheTurnosTableTable,
              CacheTurnoEntry
            >,
          ),
          CacheTurnoEntry,
          PrefetchHooks Function()
        > {
  $$CacheTurnosTableTableTableManager(
    _$CacheService db,
    $CacheTurnosTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheTurnosTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheTurnosTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheTurnosTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> dadosJson = const Value.absent(),
                Value<int> atualizadoEm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheTurnosTableCompanion(
                id: id,
                dadosJson: dadosJson,
                atualizadoEm: atualizadoEm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String dadosJson,
                required int atualizadoEm,
                Value<int> rowid = const Value.absent(),
              }) => CacheTurnosTableCompanion.insert(
                id: id,
                dadosJson: dadosJson,
                atualizadoEm: atualizadoEm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CacheTurnosTableTableProcessedTableManager =
    ProcessedTableManager<
      _$CacheService,
      $CacheTurnosTableTable,
      CacheTurnoEntry,
      $$CacheTurnosTableTableFilterComposer,
      $$CacheTurnosTableTableOrderingComposer,
      $$CacheTurnosTableTableAnnotationComposer,
      $$CacheTurnosTableTableCreateCompanionBuilder,
      $$CacheTurnosTableTableUpdateCompanionBuilder,
      (
        CacheTurnoEntry,
        BaseReferences<_$CacheService, $CacheTurnosTableTable, CacheTurnoEntry>,
      ),
      CacheTurnoEntry,
      PrefetchHooks Function()
    >;
typedef $$CacheUsuariosPublicoTableTableCreateCompanionBuilder =
    CacheUsuariosPublicoTableCompanion Function({
      required String id,
      required String dadosJson,
      required int atualizadoEm,
      Value<int> rowid,
    });
typedef $$CacheUsuariosPublicoTableTableUpdateCompanionBuilder =
    CacheUsuariosPublicoTableCompanion Function({
      Value<String> id,
      Value<String> dadosJson,
      Value<int> atualizadoEm,
      Value<int> rowid,
    });

class $$CacheUsuariosPublicoTableTableFilterComposer
    extends Composer<_$CacheService, $CacheUsuariosPublicoTableTable> {
  $$CacheUsuariosPublicoTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dadosJson => $composableBuilder(
    column: $table.dadosJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CacheUsuariosPublicoTableTableOrderingComposer
    extends Composer<_$CacheService, $CacheUsuariosPublicoTableTable> {
  $$CacheUsuariosPublicoTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dadosJson => $composableBuilder(
    column: $table.dadosJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CacheUsuariosPublicoTableTableAnnotationComposer
    extends Composer<_$CacheService, $CacheUsuariosPublicoTableTable> {
  $$CacheUsuariosPublicoTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dadosJson =>
      $composableBuilder(column: $table.dadosJson, builder: (column) => column);

  GeneratedColumn<int> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => column,
  );
}

class $$CacheUsuariosPublicoTableTableTableManager
    extends
        RootTableManager<
          _$CacheService,
          $CacheUsuariosPublicoTableTable,
          CacheUsuarioPublicoEntry,
          $$CacheUsuariosPublicoTableTableFilterComposer,
          $$CacheUsuariosPublicoTableTableOrderingComposer,
          $$CacheUsuariosPublicoTableTableAnnotationComposer,
          $$CacheUsuariosPublicoTableTableCreateCompanionBuilder,
          $$CacheUsuariosPublicoTableTableUpdateCompanionBuilder,
          (
            CacheUsuarioPublicoEntry,
            BaseReferences<
              _$CacheService,
              $CacheUsuariosPublicoTableTable,
              CacheUsuarioPublicoEntry
            >,
          ),
          CacheUsuarioPublicoEntry,
          PrefetchHooks Function()
        > {
  $$CacheUsuariosPublicoTableTableTableManager(
    _$CacheService db,
    $CacheUsuariosPublicoTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheUsuariosPublicoTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CacheUsuariosPublicoTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CacheUsuariosPublicoTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> dadosJson = const Value.absent(),
                Value<int> atualizadoEm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheUsuariosPublicoTableCompanion(
                id: id,
                dadosJson: dadosJson,
                atualizadoEm: atualizadoEm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String dadosJson,
                required int atualizadoEm,
                Value<int> rowid = const Value.absent(),
              }) => CacheUsuariosPublicoTableCompanion.insert(
                id: id,
                dadosJson: dadosJson,
                atualizadoEm: atualizadoEm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CacheUsuariosPublicoTableTableProcessedTableManager =
    ProcessedTableManager<
      _$CacheService,
      $CacheUsuariosPublicoTableTable,
      CacheUsuarioPublicoEntry,
      $$CacheUsuariosPublicoTableTableFilterComposer,
      $$CacheUsuariosPublicoTableTableOrderingComposer,
      $$CacheUsuariosPublicoTableTableAnnotationComposer,
      $$CacheUsuariosPublicoTableTableCreateCompanionBuilder,
      $$CacheUsuariosPublicoTableTableUpdateCompanionBuilder,
      (
        CacheUsuarioPublicoEntry,
        BaseReferences<
          _$CacheService,
          $CacheUsuariosPublicoTableTable,
          CacheUsuarioPublicoEntry
        >,
      ),
      CacheUsuarioPublicoEntry,
      PrefetchHooks Function()
    >;

class $CacheServiceManager {
  final _$CacheService _db;
  $CacheServiceManager(this._db);
  $$SyncQueueTableTableTableManager get syncQueueTable =>
      $$SyncQueueTableTableTableManager(_db, _db.syncQueueTable);
  $$CacheFrequenciasTableTableTableManager get cacheFrequenciasTable =>
      $$CacheFrequenciasTableTableTableManager(_db, _db.cacheFrequenciasTable);
  $$CacheAtividadesTableTableTableManager get cacheAtividadesTable =>
      $$CacheAtividadesTableTableTableManager(_db, _db.cacheAtividadesTable);
  $$CacheAvaliacoesTableTableTableManager get cacheAvaliacoesTable =>
      $$CacheAvaliacoesTableTableTableManager(_db, _db.cacheAvaliacoesTable);
  $$CacheCamposTableTableTableManager get cacheCamposTable =>
      $$CacheCamposTableTableTableManager(_db, _db.cacheCamposTable);
  $$CacheTurnosTableTableTableManager get cacheTurnosTable =>
      $$CacheTurnosTableTableTableManager(_db, _db.cacheTurnosTable);
  $$CacheUsuariosPublicoTableTableTableManager get cacheUsuariosPublicoTable =>
      $$CacheUsuariosPublicoTableTableTableManager(
        _db,
        _db.cacheUsuariosPublicoTable,
      );
}
