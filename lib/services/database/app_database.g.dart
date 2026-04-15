// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AuthTable extends Auth with TableInfo<$AuthTable, AuthData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuthTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    check: () => id.equals(1),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _steamIdMeta = const VerificationMeta(
    'steamId',
  );
  @override
  late final GeneratedColumn<String> steamId = GeneratedColumn<String>(
    'steam_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, steamId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'auth';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuthData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('steam_id')) {
      context.handle(
        _steamIdMeta,
        steamId.isAcceptableOrUnknown(data['steam_id']!, _steamIdMeta),
      );
    } else if (isInserting) {
      context.missing(_steamIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuthData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuthData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      steamId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}steam_id'],
      )!,
    );
  }

  @override
  $AuthTable createAlias(String alias) {
    return $AuthTable(attachedDatabase, alias);
  }
}

class AuthData extends DataClass implements Insertable<AuthData> {
  final int id;
  final String steamId;
  const AuthData({required this.id, required this.steamId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['steam_id'] = Variable<String>(steamId);
    return map;
  }

  AuthCompanion toCompanion(bool nullToAbsent) {
    return AuthCompanion(id: Value(id), steamId: Value(steamId));
  }

  factory AuthData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuthData(
      id: serializer.fromJson<int>(json['id']),
      steamId: serializer.fromJson<String>(json['steamId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'steamId': serializer.toJson<String>(steamId),
    };
  }

  AuthData copyWith({int? id, String? steamId}) =>
      AuthData(id: id ?? this.id, steamId: steamId ?? this.steamId);
  AuthData copyWithCompanion(AuthCompanion data) {
    return AuthData(
      id: data.id.present ? data.id.value : this.id,
      steamId: data.steamId.present ? data.steamId.value : this.steamId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuthData(')
          ..write('id: $id, ')
          ..write('steamId: $steamId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, steamId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthData &&
          other.id == this.id &&
          other.steamId == this.steamId);
}

class AuthCompanion extends UpdateCompanion<AuthData> {
  final Value<int> id;
  final Value<String> steamId;
  const AuthCompanion({
    this.id = const Value.absent(),
    this.steamId = const Value.absent(),
  });
  AuthCompanion.insert({
    this.id = const Value.absent(),
    required String steamId,
  }) : steamId = Value(steamId);
  static Insertable<AuthData> custom({
    Expression<int>? id,
    Expression<String>? steamId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (steamId != null) 'steam_id': steamId,
    });
  }

  AuthCompanion copyWith({Value<int>? id, Value<String>? steamId}) {
    return AuthCompanion(id: id ?? this.id, steamId: steamId ?? this.steamId);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (steamId.present) {
      map['steam_id'] = Variable<String>(steamId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuthCompanion(')
          ..write('id: $id, ')
          ..write('steamId: $steamId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AuthTable auth = $AuthTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [auth];
}

typedef $$AuthTableCreateCompanionBuilder =
    AuthCompanion Function({Value<int> id, required String steamId});
typedef $$AuthTableUpdateCompanionBuilder =
    AuthCompanion Function({Value<int> id, Value<String> steamId});

class $$AuthTableFilterComposer extends Composer<_$AppDatabase, $AuthTable> {
  $$AuthTableFilterComposer({
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

  ColumnFilters<String> get steamId => $composableBuilder(
    column: $table.steamId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AuthTableOrderingComposer extends Composer<_$AppDatabase, $AuthTable> {
  $$AuthTableOrderingComposer({
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

  ColumnOrderings<String> get steamId => $composableBuilder(
    column: $table.steamId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AuthTableAnnotationComposer
    extends Composer<_$AppDatabase, $AuthTable> {
  $$AuthTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get steamId =>
      $composableBuilder(column: $table.steamId, builder: (column) => column);
}

class $$AuthTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AuthTable,
          AuthData,
          $$AuthTableFilterComposer,
          $$AuthTableOrderingComposer,
          $$AuthTableAnnotationComposer,
          $$AuthTableCreateCompanionBuilder,
          $$AuthTableUpdateCompanionBuilder,
          (AuthData, BaseReferences<_$AppDatabase, $AuthTable, AuthData>),
          AuthData,
          PrefetchHooks Function()
        > {
  $$AuthTableTableManager(_$AppDatabase db, $AuthTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuthTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuthTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuthTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> steamId = const Value.absent(),
              }) => AuthCompanion(id: id, steamId: steamId),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String steamId,
              }) => AuthCompanion.insert(id: id, steamId: steamId),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AuthTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AuthTable,
      AuthData,
      $$AuthTableFilterComposer,
      $$AuthTableOrderingComposer,
      $$AuthTableAnnotationComposer,
      $$AuthTableCreateCompanionBuilder,
      $$AuthTableUpdateCompanionBuilder,
      (AuthData, BaseReferences<_$AppDatabase, $AuthTable, AuthData>),
      AuthData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AuthTableTableManager get auth => $$AuthTableTableManager(_db, _db.auth);
}
