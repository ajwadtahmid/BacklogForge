// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $GamesTable extends Games with TableInfo<$GamesTable, Game> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GamesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _appIdMeta = const VerificationMeta('appId');
  @override
  late final GeneratedColumn<int> appId = GeneratedColumn<int>(
    'app_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playtimeMinutesMeta = const VerificationMeta(
    'playtimeMinutes',
  );
  @override
  late final GeneratedColumn<int> playtimeMinutes = GeneratedColumn<int>(
    'playtime_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _rushedHoursMeta = const VerificationMeta(
    'rushedHours',
  );
  @override
  late final GeneratedColumn<double> rushedHours = GeneratedColumn<double>(
    'rushed_hours',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _casuallyHoursMeta = const VerificationMeta(
    'casuallyHours',
  );
  @override
  late final GeneratedColumn<double> casuallyHours = GeneratedColumn<double>(
    'casually_hours',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completionistHoursMeta =
      const VerificationMeta('completionistHours');
  @override
  late final GeneratedColumn<double> completionistHours =
      GeneratedColumn<double>(
        'completionist_hours',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('backlog'),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _manualOverrideMeta = const VerificationMeta(
    'manualOverride',
  );
  @override
  late final GeneratedColumn<bool> manualOverride = GeneratedColumn<bool>(
    'manual_override',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("manual_override" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    appId,
    name,
    playtimeMinutes,
    rushedHours,
    casuallyHours,
    completionistHours,
    status,
    addedAt,
    completedAt,
    manualOverride,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'games';
  @override
  VerificationContext validateIntegrity(
    Insertable<Game> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('app_id')) {
      context.handle(
        _appIdMeta,
        appId.isAcceptableOrUnknown(data['app_id']!, _appIdMeta),
      );
    } else if (isInserting) {
      context.missing(_appIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('playtime_minutes')) {
      context.handle(
        _playtimeMinutesMeta,
        playtimeMinutes.isAcceptableOrUnknown(
          data['playtime_minutes']!,
          _playtimeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('rushed_hours')) {
      context.handle(
        _rushedHoursMeta,
        rushedHours.isAcceptableOrUnknown(
          data['rushed_hours']!,
          _rushedHoursMeta,
        ),
      );
    }
    if (data.containsKey('casually_hours')) {
      context.handle(
        _casuallyHoursMeta,
        casuallyHours.isAcceptableOrUnknown(
          data['casually_hours']!,
          _casuallyHoursMeta,
        ),
      );
    }
    if (data.containsKey('completionist_hours')) {
      context.handle(
        _completionistHoursMeta,
        completionistHours.isAcceptableOrUnknown(
          data['completionist_hours']!,
          _completionistHoursMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('manual_override')) {
      context.handle(
        _manualOverrideMeta,
        manualOverride.isAcceptableOrUnknown(
          data['manual_override']!,
          _manualOverrideMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Game map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Game(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      appId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}app_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      playtimeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playtime_minutes'],
      )!,
      rushedHours: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rushed_hours'],
      ),
      casuallyHours: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}casually_hours'],
      ),
      completionistHours: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}completionist_hours'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      manualOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}manual_override'],
      )!,
    );
  }

  @override
  $GamesTable createAlias(String alias) {
    return $GamesTable(attachedDatabase, alias);
  }
}

class Game extends DataClass implements Insertable<Game> {
  final int id;
  final int appId;
  final String name;
  final int playtimeMinutes;
  final double? rushedHours;
  final double? casuallyHours;
  final double? completionistHours;
  final String status;
  final DateTime addedAt;
  final DateTime? completedAt;
  final bool manualOverride;
  const Game({
    required this.id,
    required this.appId,
    required this.name,
    required this.playtimeMinutes,
    this.rushedHours,
    this.casuallyHours,
    this.completionistHours,
    required this.status,
    required this.addedAt,
    this.completedAt,
    required this.manualOverride,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['app_id'] = Variable<int>(appId);
    map['name'] = Variable<String>(name);
    map['playtime_minutes'] = Variable<int>(playtimeMinutes);
    if (!nullToAbsent || rushedHours != null) {
      map['rushed_hours'] = Variable<double>(rushedHours);
    }
    if (!nullToAbsent || casuallyHours != null) {
      map['casually_hours'] = Variable<double>(casuallyHours);
    }
    if (!nullToAbsent || completionistHours != null) {
      map['completionist_hours'] = Variable<double>(completionistHours);
    }
    map['status'] = Variable<String>(status);
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['manual_override'] = Variable<bool>(manualOverride);
    return map;
  }

  GamesCompanion toCompanion(bool nullToAbsent) {
    return GamesCompanion(
      id: Value(id),
      appId: Value(appId),
      name: Value(name),
      playtimeMinutes: Value(playtimeMinutes),
      rushedHours: rushedHours == null && nullToAbsent
          ? const Value.absent()
          : Value(rushedHours),
      casuallyHours: casuallyHours == null && nullToAbsent
          ? const Value.absent()
          : Value(casuallyHours),
      completionistHours: completionistHours == null && nullToAbsent
          ? const Value.absent()
          : Value(completionistHours),
      status: Value(status),
      addedAt: Value(addedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      manualOverride: Value(manualOverride),
    );
  }

  factory Game.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Game(
      id: serializer.fromJson<int>(json['id']),
      appId: serializer.fromJson<int>(json['appId']),
      name: serializer.fromJson<String>(json['name']),
      playtimeMinutes: serializer.fromJson<int>(json['playtimeMinutes']),
      rushedHours: serializer.fromJson<double?>(json['rushedHours']),
      casuallyHours: serializer.fromJson<double?>(json['casuallyHours']),
      completionistHours: serializer.fromJson<double?>(
        json['completionistHours'],
      ),
      status: serializer.fromJson<String>(json['status']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      manualOverride: serializer.fromJson<bool>(json['manualOverride']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'appId': serializer.toJson<int>(appId),
      'name': serializer.toJson<String>(name),
      'playtimeMinutes': serializer.toJson<int>(playtimeMinutes),
      'rushedHours': serializer.toJson<double?>(rushedHours),
      'casuallyHours': serializer.toJson<double?>(casuallyHours),
      'completionistHours': serializer.toJson<double?>(completionistHours),
      'status': serializer.toJson<String>(status),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'manualOverride': serializer.toJson<bool>(manualOverride),
    };
  }

  Game copyWith({
    int? id,
    int? appId,
    String? name,
    int? playtimeMinutes,
    Value<double?> rushedHours = const Value.absent(),
    Value<double?> casuallyHours = const Value.absent(),
    Value<double?> completionistHours = const Value.absent(),
    String? status,
    DateTime? addedAt,
    Value<DateTime?> completedAt = const Value.absent(),
    bool? manualOverride,
  }) => Game(
    id: id ?? this.id,
    appId: appId ?? this.appId,
    name: name ?? this.name,
    playtimeMinutes: playtimeMinutes ?? this.playtimeMinutes,
    rushedHours: rushedHours.present ? rushedHours.value : this.rushedHours,
    casuallyHours: casuallyHours.present
        ? casuallyHours.value
        : this.casuallyHours,
    completionistHours: completionistHours.present
        ? completionistHours.value
        : this.completionistHours,
    status: status ?? this.status,
    addedAt: addedAt ?? this.addedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    manualOverride: manualOverride ?? this.manualOverride,
  );
  Game copyWithCompanion(GamesCompanion data) {
    return Game(
      id: data.id.present ? data.id.value : this.id,
      appId: data.appId.present ? data.appId.value : this.appId,
      name: data.name.present ? data.name.value : this.name,
      playtimeMinutes: data.playtimeMinutes.present
          ? data.playtimeMinutes.value
          : this.playtimeMinutes,
      rushedHours: data.rushedHours.present
          ? data.rushedHours.value
          : this.rushedHours,
      casuallyHours: data.casuallyHours.present
          ? data.casuallyHours.value
          : this.casuallyHours,
      completionistHours: data.completionistHours.present
          ? data.completionistHours.value
          : this.completionistHours,
      status: data.status.present ? data.status.value : this.status,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      manualOverride: data.manualOverride.present
          ? data.manualOverride.value
          : this.manualOverride,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Game(')
          ..write('id: $id, ')
          ..write('appId: $appId, ')
          ..write('name: $name, ')
          ..write('playtimeMinutes: $playtimeMinutes, ')
          ..write('rushedHours: $rushedHours, ')
          ..write('casuallyHours: $casuallyHours, ')
          ..write('completionistHours: $completionistHours, ')
          ..write('status: $status, ')
          ..write('addedAt: $addedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('manualOverride: $manualOverride')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    appId,
    name,
    playtimeMinutes,
    rushedHours,
    casuallyHours,
    completionistHours,
    status,
    addedAt,
    completedAt,
    manualOverride,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Game &&
          other.id == this.id &&
          other.appId == this.appId &&
          other.name == this.name &&
          other.playtimeMinutes == this.playtimeMinutes &&
          other.rushedHours == this.rushedHours &&
          other.casuallyHours == this.casuallyHours &&
          other.completionistHours == this.completionistHours &&
          other.status == this.status &&
          other.addedAt == this.addedAt &&
          other.completedAt == this.completedAt &&
          other.manualOverride == this.manualOverride);
}

class GamesCompanion extends UpdateCompanion<Game> {
  final Value<int> id;
  final Value<int> appId;
  final Value<String> name;
  final Value<int> playtimeMinutes;
  final Value<double?> rushedHours;
  final Value<double?> casuallyHours;
  final Value<double?> completionistHours;
  final Value<String> status;
  final Value<DateTime> addedAt;
  final Value<DateTime?> completedAt;
  final Value<bool> manualOverride;
  const GamesCompanion({
    this.id = const Value.absent(),
    this.appId = const Value.absent(),
    this.name = const Value.absent(),
    this.playtimeMinutes = const Value.absent(),
    this.rushedHours = const Value.absent(),
    this.casuallyHours = const Value.absent(),
    this.completionistHours = const Value.absent(),
    this.status = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.manualOverride = const Value.absent(),
  });
  GamesCompanion.insert({
    this.id = const Value.absent(),
    required int appId,
    required String name,
    this.playtimeMinutes = const Value.absent(),
    this.rushedHours = const Value.absent(),
    this.casuallyHours = const Value.absent(),
    this.completionistHours = const Value.absent(),
    this.status = const Value.absent(),
    required DateTime addedAt,
    this.completedAt = const Value.absent(),
    this.manualOverride = const Value.absent(),
  }) : appId = Value(appId),
       name = Value(name),
       addedAt = Value(addedAt);
  static Insertable<Game> custom({
    Expression<int>? id,
    Expression<int>? appId,
    Expression<String>? name,
    Expression<int>? playtimeMinutes,
    Expression<double>? rushedHours,
    Expression<double>? casuallyHours,
    Expression<double>? completionistHours,
    Expression<String>? status,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? completedAt,
    Expression<bool>? manualOverride,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (appId != null) 'app_id': appId,
      if (name != null) 'name': name,
      if (playtimeMinutes != null) 'playtime_minutes': playtimeMinutes,
      if (rushedHours != null) 'rushed_hours': rushedHours,
      if (casuallyHours != null) 'casually_hours': casuallyHours,
      if (completionistHours != null) 'completionist_hours': completionistHours,
      if (status != null) 'status': status,
      if (addedAt != null) 'added_at': addedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (manualOverride != null) 'manual_override': manualOverride,
    });
  }

  GamesCompanion copyWith({
    Value<int>? id,
    Value<int>? appId,
    Value<String>? name,
    Value<int>? playtimeMinutes,
    Value<double?>? rushedHours,
    Value<double?>? casuallyHours,
    Value<double?>? completionistHours,
    Value<String>? status,
    Value<DateTime>? addedAt,
    Value<DateTime?>? completedAt,
    Value<bool>? manualOverride,
  }) {
    return GamesCompanion(
      id: id ?? this.id,
      appId: appId ?? this.appId,
      name: name ?? this.name,
      playtimeMinutes: playtimeMinutes ?? this.playtimeMinutes,
      rushedHours: rushedHours ?? this.rushedHours,
      casuallyHours: casuallyHours ?? this.casuallyHours,
      completionistHours: completionistHours ?? this.completionistHours,
      status: status ?? this.status,
      addedAt: addedAt ?? this.addedAt,
      completedAt: completedAt ?? this.completedAt,
      manualOverride: manualOverride ?? this.manualOverride,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (appId.present) {
      map['app_id'] = Variable<int>(appId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (playtimeMinutes.present) {
      map['playtime_minutes'] = Variable<int>(playtimeMinutes.value);
    }
    if (rushedHours.present) {
      map['rushed_hours'] = Variable<double>(rushedHours.value);
    }
    if (casuallyHours.present) {
      map['casually_hours'] = Variable<double>(casuallyHours.value);
    }
    if (completionistHours.present) {
      map['completionist_hours'] = Variable<double>(completionistHours.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (manualOverride.present) {
      map['manual_override'] = Variable<bool>(manualOverride.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GamesCompanion(')
          ..write('id: $id, ')
          ..write('appId: $appId, ')
          ..write('name: $name, ')
          ..write('playtimeMinutes: $playtimeMinutes, ')
          ..write('rushedHours: $rushedHours, ')
          ..write('casuallyHours: $casuallyHours, ')
          ..write('completionistHours: $completionistHours, ')
          ..write('status: $status, ')
          ..write('addedAt: $addedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('manualOverride: $manualOverride')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _completionThresholdMeta =
      const VerificationMeta('completionThreshold');
  @override
  late final GeneratedColumn<String> completionThreshold =
      GeneratedColumn<String>(
        'completion_threshold',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('casually'),
      );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<String> sortOrder = GeneratedColumn<String>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('alpha'),
  );
  static const VerificationMeta _showCompletedTabMeta = const VerificationMeta(
    'showCompletedTab',
  );
  @override
  late final GeneratedColumn<bool> showCompletedTab = GeneratedColumn<bool>(
    'show_completed_tab',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_completed_tab" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _themeMeta = const VerificationMeta('theme');
  @override
  late final GeneratedColumn<String> theme = GeneratedColumn<String>(
    'theme',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('dark'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    completionThreshold,
    sortOrder,
    showCompletedTab,
    theme,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('completion_threshold')) {
      context.handle(
        _completionThresholdMeta,
        completionThreshold.isAcceptableOrUnknown(
          data['completion_threshold']!,
          _completionThresholdMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('show_completed_tab')) {
      context.handle(
        _showCompletedTabMeta,
        showCompletedTab.isAcceptableOrUnknown(
          data['show_completed_tab']!,
          _showCompletedTabMeta,
        ),
      );
    }
    if (data.containsKey('theme')) {
      context.handle(
        _themeMeta,
        theme.isAcceptableOrUnknown(data['theme']!, _themeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      completionThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completion_threshold'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_order'],
      )!,
      showCompletedTab: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_completed_tab'],
      )!,
      theme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final int id;
  final String completionThreshold;
  final String sortOrder;
  final bool showCompletedTab;
  final String theme;
  const AppSetting({
    required this.id,
    required this.completionThreshold,
    required this.sortOrder,
    required this.showCompletedTab,
    required this.theme,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['completion_threshold'] = Variable<String>(completionThreshold);
    map['sort_order'] = Variable<String>(sortOrder);
    map['show_completed_tab'] = Variable<bool>(showCompletedTab);
    map['theme'] = Variable<String>(theme);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      completionThreshold: Value(completionThreshold),
      sortOrder: Value(sortOrder),
      showCompletedTab: Value(showCompletedTab),
      theme: Value(theme),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      id: serializer.fromJson<int>(json['id']),
      completionThreshold: serializer.fromJson<String>(
        json['completionThreshold'],
      ),
      sortOrder: serializer.fromJson<String>(json['sortOrder']),
      showCompletedTab: serializer.fromJson<bool>(json['showCompletedTab']),
      theme: serializer.fromJson<String>(json['theme']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'completionThreshold': serializer.toJson<String>(completionThreshold),
      'sortOrder': serializer.toJson<String>(sortOrder),
      'showCompletedTab': serializer.toJson<bool>(showCompletedTab),
      'theme': serializer.toJson<String>(theme),
    };
  }

  AppSetting copyWith({
    int? id,
    String? completionThreshold,
    String? sortOrder,
    bool? showCompletedTab,
    String? theme,
  }) => AppSetting(
    id: id ?? this.id,
    completionThreshold: completionThreshold ?? this.completionThreshold,
    sortOrder: sortOrder ?? this.sortOrder,
    showCompletedTab: showCompletedTab ?? this.showCompletedTab,
    theme: theme ?? this.theme,
  );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      id: data.id.present ? data.id.value : this.id,
      completionThreshold: data.completionThreshold.present
          ? data.completionThreshold.value
          : this.completionThreshold,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      showCompletedTab: data.showCompletedTab.present
          ? data.showCompletedTab.value
          : this.showCompletedTab,
      theme: data.theme.present ? data.theme.value : this.theme,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('id: $id, ')
          ..write('completionThreshold: $completionThreshold, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('showCompletedTab: $showCompletedTab, ')
          ..write('theme: $theme')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, completionThreshold, sortOrder, showCompletedTab, theme);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.id == this.id &&
          other.completionThreshold == this.completionThreshold &&
          other.sortOrder == this.sortOrder &&
          other.showCompletedTab == this.showCompletedTab &&
          other.theme == this.theme);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<int> id;
  final Value<String> completionThreshold;
  final Value<String> sortOrder;
  final Value<bool> showCompletedTab;
  final Value<String> theme;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.completionThreshold = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.showCompletedTab = const Value.absent(),
    this.theme = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.completionThreshold = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.showCompletedTab = const Value.absent(),
    this.theme = const Value.absent(),
  });
  static Insertable<AppSetting> custom({
    Expression<int>? id,
    Expression<String>? completionThreshold,
    Expression<String>? sortOrder,
    Expression<bool>? showCompletedTab,
    Expression<String>? theme,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (completionThreshold != null)
        'completion_threshold': completionThreshold,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (showCompletedTab != null) 'show_completed_tab': showCompletedTab,
      if (theme != null) 'theme': theme,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? completionThreshold,
    Value<String>? sortOrder,
    Value<bool>? showCompletedTab,
    Value<String>? theme,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      completionThreshold: completionThreshold ?? this.completionThreshold,
      sortOrder: sortOrder ?? this.sortOrder,
      showCompletedTab: showCompletedTab ?? this.showCompletedTab,
      theme: theme ?? this.theme,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (completionThreshold.present) {
      map['completion_threshold'] = Variable<String>(completionThreshold.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<String>(sortOrder.value);
    }
    if (showCompletedTab.present) {
      map['show_completed_tab'] = Variable<bool>(showCompletedTab.value);
    }
    if (theme.present) {
      map['theme'] = Variable<String>(theme.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('completionThreshold: $completionThreshold, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('showCompletedTab: $showCompletedTab, ')
          ..write('theme: $theme')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $GamesTable games = $GamesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final Index idxGamesStatus = Index(
    'idx_games_status',
    'CREATE INDEX idx_games_status ON games (status)',
  );
  late final Index idxGamesName = Index(
    'idx_games_name',
    'CREATE INDEX idx_games_name ON games (name)',
  );
  late final Index idxGamesCompletedAt = Index(
    'idx_games_completed_at',
    'CREATE INDEX idx_games_completed_at ON games (completed_at)',
  );
  late final GamesDao gamesDao = GamesDao(this as AppDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    games,
    appSettings,
    idxGamesStatus,
    idxGamesName,
    idxGamesCompletedAt,
  ];
}

typedef $$GamesTableCreateCompanionBuilder =
    GamesCompanion Function({
      Value<int> id,
      required int appId,
      required String name,
      Value<int> playtimeMinutes,
      Value<double?> rushedHours,
      Value<double?> casuallyHours,
      Value<double?> completionistHours,
      Value<String> status,
      required DateTime addedAt,
      Value<DateTime?> completedAt,
      Value<bool> manualOverride,
    });
typedef $$GamesTableUpdateCompanionBuilder =
    GamesCompanion Function({
      Value<int> id,
      Value<int> appId,
      Value<String> name,
      Value<int> playtimeMinutes,
      Value<double?> rushedHours,
      Value<double?> casuallyHours,
      Value<double?> completionistHours,
      Value<String> status,
      Value<DateTime> addedAt,
      Value<DateTime?> completedAt,
      Value<bool> manualOverride,
    });

class $$GamesTableFilterComposer extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableFilterComposer({
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

  ColumnFilters<int> get appId => $composableBuilder(
    column: $table.appId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playtimeMinutes => $composableBuilder(
    column: $table.playtimeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rushedHours => $composableBuilder(
    column: $table.rushedHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get casuallyHours => $composableBuilder(
    column: $table.casuallyHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get completionistHours => $composableBuilder(
    column: $table.completionistHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get manualOverride => $composableBuilder(
    column: $table.manualOverride,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GamesTableOrderingComposer
    extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableOrderingComposer({
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

  ColumnOrderings<int> get appId => $composableBuilder(
    column: $table.appId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playtimeMinutes => $composableBuilder(
    column: $table.playtimeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rushedHours => $composableBuilder(
    column: $table.rushedHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get casuallyHours => $composableBuilder(
    column: $table.casuallyHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get completionistHours => $composableBuilder(
    column: $table.completionistHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get manualOverride => $composableBuilder(
    column: $table.manualOverride,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GamesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get appId =>
      $composableBuilder(column: $table.appId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get playtimeMinutes => $composableBuilder(
    column: $table.playtimeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rushedHours => $composableBuilder(
    column: $table.rushedHours,
    builder: (column) => column,
  );

  GeneratedColumn<double> get casuallyHours => $composableBuilder(
    column: $table.casuallyHours,
    builder: (column) => column,
  );

  GeneratedColumn<double> get completionistHours => $composableBuilder(
    column: $table.completionistHours,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get manualOverride => $composableBuilder(
    column: $table.manualOverride,
    builder: (column) => column,
  );
}

class $$GamesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GamesTable,
          Game,
          $$GamesTableFilterComposer,
          $$GamesTableOrderingComposer,
          $$GamesTableAnnotationComposer,
          $$GamesTableCreateCompanionBuilder,
          $$GamesTableUpdateCompanionBuilder,
          (Game, BaseReferences<_$AppDatabase, $GamesTable, Game>),
          Game,
          PrefetchHooks Function()
        > {
  $$GamesTableTableManager(_$AppDatabase db, $GamesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GamesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GamesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GamesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> appId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> playtimeMinutes = const Value.absent(),
                Value<double?> rushedHours = const Value.absent(),
                Value<double?> casuallyHours = const Value.absent(),
                Value<double?> completionistHours = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<bool> manualOverride = const Value.absent(),
              }) => GamesCompanion(
                id: id,
                appId: appId,
                name: name,
                playtimeMinutes: playtimeMinutes,
                rushedHours: rushedHours,
                casuallyHours: casuallyHours,
                completionistHours: completionistHours,
                status: status,
                addedAt: addedAt,
                completedAt: completedAt,
                manualOverride: manualOverride,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int appId,
                required String name,
                Value<int> playtimeMinutes = const Value.absent(),
                Value<double?> rushedHours = const Value.absent(),
                Value<double?> casuallyHours = const Value.absent(),
                Value<double?> completionistHours = const Value.absent(),
                Value<String> status = const Value.absent(),
                required DateTime addedAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<bool> manualOverride = const Value.absent(),
              }) => GamesCompanion.insert(
                id: id,
                appId: appId,
                name: name,
                playtimeMinutes: playtimeMinutes,
                rushedHours: rushedHours,
                casuallyHours: casuallyHours,
                completionistHours: completionistHours,
                status: status,
                addedAt: addedAt,
                completedAt: completedAt,
                manualOverride: manualOverride,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GamesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GamesTable,
      Game,
      $$GamesTableFilterComposer,
      $$GamesTableOrderingComposer,
      $$GamesTableAnnotationComposer,
      $$GamesTableCreateCompanionBuilder,
      $$GamesTableUpdateCompanionBuilder,
      (Game, BaseReferences<_$AppDatabase, $GamesTable, Game>),
      Game,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<String> completionThreshold,
      Value<String> sortOrder,
      Value<bool> showCompletedTab,
      Value<String> theme,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<String> completionThreshold,
      Value<String> sortOrder,
      Value<bool> showCompletedTab,
      Value<String> theme,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
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

  ColumnFilters<String> get completionThreshold => $composableBuilder(
    column: $table.completionThreshold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showCompletedTab => $composableBuilder(
    column: $table.showCompletedTab,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
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

  ColumnOrderings<String> get completionThreshold => $composableBuilder(
    column: $table.completionThreshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showCompletedTab => $composableBuilder(
    column: $table.showCompletedTab,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get completionThreshold => $composableBuilder(
    column: $table.completionThreshold,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get showCompletedTab => $composableBuilder(
    column: $table.showCompletedTab,
    builder: (column) => column,
  );

  GeneratedColumn<String> get theme =>
      $composableBuilder(column: $table.theme, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> completionThreshold = const Value.absent(),
                Value<String> sortOrder = const Value.absent(),
                Value<bool> showCompletedTab = const Value.absent(),
                Value<String> theme = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                completionThreshold: completionThreshold,
                sortOrder: sortOrder,
                showCompletedTab: showCompletedTab,
                theme: theme,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> completionThreshold = const Value.absent(),
                Value<String> sortOrder = const Value.absent(),
                Value<bool> showCompletedTab = const Value.absent(),
                Value<String> theme = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                id: id,
                completionThreshold: completionThreshold,
                sortOrder: sortOrder,
                showCompletedTab: showCompletedTab,
                theme: theme,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$GamesTableTableManager get games =>
      $$GamesTableTableManager(_db, _db.games);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
