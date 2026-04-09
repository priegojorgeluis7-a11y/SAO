// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $RolesTable extends Roles with TableInfo<$RolesTable, Role> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RolesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 40,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _permissionsJsonMeta = const VerificationMeta(
    'permissionsJson',
  );
  @override
  late final GeneratedColumn<String> permissionsJson = GeneratedColumn<String>(
    'permissions_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, permissionsJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'roles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Role> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('permissions_json')) {
      context.handle(
        _permissionsJsonMeta,
        permissionsJson.isAcceptableOrUnknown(
          data['permissions_json']!,
          _permissionsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Role map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Role(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      permissionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}permissions_json'],
      )!,
    );
  }

  @override
  $RolesTable createAlias(String alias) {
    return $RolesTable(attachedDatabase, alias);
  }
}

class Role extends DataClass implements Insertable<Role> {
  final int id;
  final String name;
  final String permissionsJson;
  const Role({
    required this.id,
    required this.name,
    required this.permissionsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['permissions_json'] = Variable<String>(permissionsJson);
    return map;
  }

  RolesCompanion toCompanion(bool nullToAbsent) {
    return RolesCompanion(
      id: Value(id),
      name: Value(name),
      permissionsJson: Value(permissionsJson),
    );
  }

  factory Role.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Role(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      permissionsJson: serializer.fromJson<String>(json['permissionsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'permissionsJson': serializer.toJson<String>(permissionsJson),
    };
  }

  Role copyWith({int? id, String? name, String? permissionsJson}) => Role(
    id: id ?? this.id,
    name: name ?? this.name,
    permissionsJson: permissionsJson ?? this.permissionsJson,
  );
  Role copyWithCompanion(RolesCompanion data) {
    return Role(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      permissionsJson: data.permissionsJson.present
          ? data.permissionsJson.value
          : this.permissionsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Role(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('permissionsJson: $permissionsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, permissionsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Role &&
          other.id == this.id &&
          other.name == this.name &&
          other.permissionsJson == this.permissionsJson);
}

class RolesCompanion extends UpdateCompanion<Role> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> permissionsJson;
  const RolesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.permissionsJson = const Value.absent(),
  });
  RolesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.permissionsJson = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Role> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? permissionsJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (permissionsJson != null) 'permissions_json': permissionsJson,
    });
  }

  RolesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? permissionsJson,
  }) {
    return RolesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      permissionsJson: permissionsJson ?? this.permissionsJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (permissionsJson.present) {
      map['permissions_json'] = Variable<String>(permissionsJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RolesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('permissionsJson: $permissionsJson')
          ..write(')'))
        .toString();
  }
}

class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleIdMeta = const VerificationMeta('roleId');
  @override
  late final GeneratedColumn<int> roleId = GeneratedColumn<int>(
    'role_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES roles (id)',
    ),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastLoginAtMeta = const VerificationMeta(
    'lastLoginAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastLoginAt = GeneratedColumn<DateTime>(
    'last_login_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    roleId,
    isActive,
    lastLoginAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<User> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('role_id')) {
      context.handle(
        _roleIdMeta,
        roleId.isAcceptableOrUnknown(data['role_id']!, _roleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_roleIdMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('last_login_at')) {
      context.handle(
        _lastLoginAtMeta,
        lastLoginAt.isAcceptableOrUnknown(
          data['last_login_at']!,
          _lastLoginAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      roleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}role_id'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      lastLoginAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_login_at'],
      ),
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final String id;
  final String name;
  final int roleId;
  final bool isActive;
  final DateTime? lastLoginAt;
  const User({
    required this.id,
    required this.name,
    required this.roleId,
    required this.isActive,
    this.lastLoginAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['role_id'] = Variable<int>(roleId);
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || lastLoginAt != null) {
      map['last_login_at'] = Variable<DateTime>(lastLoginAt);
    }
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      name: Value(name),
      roleId: Value(roleId),
      isActive: Value(isActive),
      lastLoginAt: lastLoginAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLoginAt),
    );
  }

  factory User.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      roleId: serializer.fromJson<int>(json['roleId']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      lastLoginAt: serializer.fromJson<DateTime?>(json['lastLoginAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'roleId': serializer.toJson<int>(roleId),
      'isActive': serializer.toJson<bool>(isActive),
      'lastLoginAt': serializer.toJson<DateTime?>(lastLoginAt),
    };
  }

  User copyWith({
    String? id,
    String? name,
    int? roleId,
    bool? isActive,
    Value<DateTime?> lastLoginAt = const Value.absent(),
  }) => User(
    id: id ?? this.id,
    name: name ?? this.name,
    roleId: roleId ?? this.roleId,
    isActive: isActive ?? this.isActive,
    lastLoginAt: lastLoginAt.present ? lastLoginAt.value : this.lastLoginAt,
  );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      roleId: data.roleId.present ? data.roleId.value : this.roleId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      lastLoginAt: data.lastLoginAt.present
          ? data.lastLoginAt.value
          : this.lastLoginAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('roleId: $roleId, ')
          ..write('isActive: $isActive, ')
          ..write('lastLoginAt: $lastLoginAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, roleId, isActive, lastLoginAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.name == this.name &&
          other.roleId == this.roleId &&
          other.isActive == this.isActive &&
          other.lastLoginAt == this.lastLoginAt);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> roleId;
  final Value<bool> isActive;
  final Value<DateTime?> lastLoginAt;
  final Value<int> rowid;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.roleId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.lastLoginAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCompanion.insert({
    required String id,
    required String name,
    required int roleId,
    this.isActive = const Value.absent(),
    this.lastLoginAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       roleId = Value(roleId);
  static Insertable<User> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? roleId,
    Expression<bool>? isActive,
    Expression<DateTime>? lastLoginAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (roleId != null) 'role_id': roleId,
      if (isActive != null) 'is_active': isActive,
      if (lastLoginAt != null) 'last_login_at': lastLoginAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? roleId,
    Value<bool>? isActive,
    Value<DateTime?>? lastLoginAt,
    Value<int>? rowid,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      roleId: roleId ?? this.roleId,
      isActive: isActive ?? this.isActive,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (roleId.present) {
      map['role_id'] = Variable<int>(roleId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (lastLoginAt.present) {
      map['last_login_at'] = Variable<DateTime>(lastLoginAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('roleId: $roleId, ')
          ..write('isActive: $isActive, ')
          ..write('lastLoginAt: $lastLoginAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 2,
      maxTextLength: 10,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [id, code, name, isActive];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Project> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class Project extends DataClass implements Insertable<Project> {
  final String id;
  final String code;
  final String name;
  final bool isActive;
  const Project({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      isActive: Value(isActive),
    );
  }

  factory Project.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Project copyWith({String? id, String? code, String? name, bool? isActive}) =>
      Project(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
        isActive: isActive ?? this.isActive,
      );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, code, name, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.isActive == this.isActive);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<bool> isActive;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String code,
    required String name,
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       code = Value(code),
       name = Value(name);
  static Insertable<Project> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? code,
    Value<String>? name,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectSegmentsTable extends ProjectSegments
    with TableInfo<$ProjectSegmentsTable, ProjectSegment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _segmentNameMeta = const VerificationMeta(
    'segmentName',
  );
  @override
  late final GeneratedColumn<String> segmentName = GeneratedColumn<String>(
    'segment_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pkStartMeta = const VerificationMeta(
    'pkStart',
  );
  @override
  late final GeneratedColumn<int> pkStart = GeneratedColumn<int>(
    'pk_start',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pkEndMeta = const VerificationMeta('pkEnd');
  @override
  late final GeneratedColumn<int> pkEnd = GeneratedColumn<int>(
    'pk_end',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    segmentName,
    pkStart,
    pkEnd,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectSegment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('segment_name')) {
      context.handle(
        _segmentNameMeta,
        segmentName.isAcceptableOrUnknown(
          data['segment_name']!,
          _segmentNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_segmentNameMeta);
    }
    if (data.containsKey('pk_start')) {
      context.handle(
        _pkStartMeta,
        pkStart.isAcceptableOrUnknown(data['pk_start']!, _pkStartMeta),
      );
    }
    if (data.containsKey('pk_end')) {
      context.handle(
        _pkEndMeta,
        pkEnd.isAcceptableOrUnknown(data['pk_end']!, _pkEndMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectSegment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectSegment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      segmentName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}segment_name'],
      )!,
      pkStart: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pk_start'],
      ),
      pkEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pk_end'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $ProjectSegmentsTable createAlias(String alias) {
    return $ProjectSegmentsTable(attachedDatabase, alias);
  }
}

class ProjectSegment extends DataClass implements Insertable<ProjectSegment> {
  final String id;
  final String projectId;
  final String segmentName;
  final int? pkStart;
  final int? pkEnd;
  final bool isActive;
  const ProjectSegment({
    required this.id,
    required this.projectId,
    required this.segmentName,
    this.pkStart,
    this.pkEnd,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['segment_name'] = Variable<String>(segmentName);
    if (!nullToAbsent || pkStart != null) {
      map['pk_start'] = Variable<int>(pkStart);
    }
    if (!nullToAbsent || pkEnd != null) {
      map['pk_end'] = Variable<int>(pkEnd);
    }
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  ProjectSegmentsCompanion toCompanion(bool nullToAbsent) {
    return ProjectSegmentsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      segmentName: Value(segmentName),
      pkStart: pkStart == null && nullToAbsent
          ? const Value.absent()
          : Value(pkStart),
      pkEnd: pkEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(pkEnd),
      isActive: Value(isActive),
    );
  }

  factory ProjectSegment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectSegment(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      segmentName: serializer.fromJson<String>(json['segmentName']),
      pkStart: serializer.fromJson<int?>(json['pkStart']),
      pkEnd: serializer.fromJson<int?>(json['pkEnd']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'segmentName': serializer.toJson<String>(segmentName),
      'pkStart': serializer.toJson<int?>(pkStart),
      'pkEnd': serializer.toJson<int?>(pkEnd),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  ProjectSegment copyWith({
    String? id,
    String? projectId,
    String? segmentName,
    Value<int?> pkStart = const Value.absent(),
    Value<int?> pkEnd = const Value.absent(),
    bool? isActive,
  }) => ProjectSegment(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    segmentName: segmentName ?? this.segmentName,
    pkStart: pkStart.present ? pkStart.value : this.pkStart,
    pkEnd: pkEnd.present ? pkEnd.value : this.pkEnd,
    isActive: isActive ?? this.isActive,
  );
  ProjectSegment copyWithCompanion(ProjectSegmentsCompanion data) {
    return ProjectSegment(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      segmentName: data.segmentName.present
          ? data.segmentName.value
          : this.segmentName,
      pkStart: data.pkStart.present ? data.pkStart.value : this.pkStart,
      pkEnd: data.pkEnd.present ? data.pkEnd.value : this.pkEnd,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectSegment(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('segmentName: $segmentName, ')
          ..write('pkStart: $pkStart, ')
          ..write('pkEnd: $pkEnd, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, projectId, segmentName, pkStart, pkEnd, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectSegment &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.segmentName == this.segmentName &&
          other.pkStart == this.pkStart &&
          other.pkEnd == this.pkEnd &&
          other.isActive == this.isActive);
}

class ProjectSegmentsCompanion extends UpdateCompanion<ProjectSegment> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> segmentName;
  final Value<int?> pkStart;
  final Value<int?> pkEnd;
  final Value<bool> isActive;
  final Value<int> rowid;
  const ProjectSegmentsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.segmentName = const Value.absent(),
    this.pkStart = const Value.absent(),
    this.pkEnd = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectSegmentsCompanion.insert({
    required String id,
    required String projectId,
    required String segmentName,
    this.pkStart = const Value.absent(),
    this.pkEnd = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       segmentName = Value(segmentName);
  static Insertable<ProjectSegment> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? segmentName,
    Expression<int>? pkStart,
    Expression<int>? pkEnd,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (segmentName != null) 'segment_name': segmentName,
      if (pkStart != null) 'pk_start': pkStart,
      if (pkEnd != null) 'pk_end': pkEnd,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectSegmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? segmentName,
    Value<int?>? pkStart,
    Value<int?>? pkEnd,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return ProjectSegmentsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      segmentName: segmentName ?? this.segmentName,
      pkStart: pkStart ?? this.pkStart,
      pkEnd: pkEnd ?? this.pkEnd,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (segmentName.present) {
      map['segment_name'] = Variable<String>(segmentName.value);
    }
    if (pkStart.present) {
      map['pk_start'] = Variable<int>(pkStart.value);
    }
    if (pkEnd.present) {
      map['pk_end'] = Variable<int>(pkEnd.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('segmentName: $segmentName, ')
          ..write('pkStart: $pkStart, ')
          ..write('pkEnd: $pkEnd, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogVersionsTable extends CatalogVersions
    with TableInfo<$CatalogVersionsTable, CatalogVersion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _versionNumberMeta = const VerificationMeta(
    'versionNumber',
  );
  @override
  late final GeneratedColumn<int> versionNumber = GeneratedColumn<int>(
    'version_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
    'published_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    versionNumber,
    publishedAt,
    checksum,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogVersion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    }
    if (data.containsKey('version_number')) {
      context.handle(
        _versionNumberMeta,
        versionNumber.isAcceptableOrUnknown(
          data['version_number']!,
          _versionNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_versionNumberMeta);
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatalogVersion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogVersion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      ),
      versionNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version_number'],
      )!,
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      ),
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $CatalogVersionsTable createAlias(String alias) {
    return $CatalogVersionsTable(attachedDatabase, alias);
  }
}

class CatalogVersion extends DataClass implements Insertable<CatalogVersion> {
  final String id;
  final String? projectId;
  final int versionNumber;
  final DateTime? publishedAt;
  final String? checksum;
  final String? notes;
  const CatalogVersion({
    required this.id,
    this.projectId,
    required this.versionNumber,
    this.publishedAt,
    this.checksum,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    map['version_number'] = Variable<int>(versionNumber);
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<DateTime>(publishedAt);
    }
    if (!nullToAbsent || checksum != null) {
      map['checksum'] = Variable<String>(checksum);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  CatalogVersionsCompanion toCompanion(bool nullToAbsent) {
    return CatalogVersionsCompanion(
      id: Value(id),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      versionNumber: Value(versionNumber),
      publishedAt: publishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAt),
      checksum: checksum == null && nullToAbsent
          ? const Value.absent()
          : Value(checksum),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory CatalogVersion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogVersion(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String?>(json['projectId']),
      versionNumber: serializer.fromJson<int>(json['versionNumber']),
      publishedAt: serializer.fromJson<DateTime?>(json['publishedAt']),
      checksum: serializer.fromJson<String?>(json['checksum']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String?>(projectId),
      'versionNumber': serializer.toJson<int>(versionNumber),
      'publishedAt': serializer.toJson<DateTime?>(publishedAt),
      'checksum': serializer.toJson<String?>(checksum),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  CatalogVersion copyWith({
    String? id,
    Value<String?> projectId = const Value.absent(),
    int? versionNumber,
    Value<DateTime?> publishedAt = const Value.absent(),
    Value<String?> checksum = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => CatalogVersion(
    id: id ?? this.id,
    projectId: projectId.present ? projectId.value : this.projectId,
    versionNumber: versionNumber ?? this.versionNumber,
    publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
    checksum: checksum.present ? checksum.value : this.checksum,
    notes: notes.present ? notes.value : this.notes,
  );
  CatalogVersion copyWithCompanion(CatalogVersionsCompanion data) {
    return CatalogVersion(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      versionNumber: data.versionNumber.present
          ? data.versionNumber.value
          : this.versionNumber,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogVersion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('versionNumber: $versionNumber, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('checksum: $checksum, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, projectId, versionNumber, publishedAt, checksum, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogVersion &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.versionNumber == this.versionNumber &&
          other.publishedAt == this.publishedAt &&
          other.checksum == this.checksum &&
          other.notes == this.notes);
}

class CatalogVersionsCompanion extends UpdateCompanion<CatalogVersion> {
  final Value<String> id;
  final Value<String?> projectId;
  final Value<int> versionNumber;
  final Value<DateTime?> publishedAt;
  final Value<String?> checksum;
  final Value<String?> notes;
  final Value<int> rowid;
  const CatalogVersionsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.versionNumber = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.checksum = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogVersionsCompanion.insert({
    required String id,
    this.projectId = const Value.absent(),
    required int versionNumber,
    this.publishedAt = const Value.absent(),
    this.checksum = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       versionNumber = Value(versionNumber);
  static Insertable<CatalogVersion> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<int>? versionNumber,
    Expression<DateTime>? publishedAt,
    Expression<String>? checksum,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (versionNumber != null) 'version_number': versionNumber,
      if (publishedAt != null) 'published_at': publishedAt,
      if (checksum != null) 'checksum': checksum,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogVersionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? projectId,
    Value<int>? versionNumber,
    Value<DateTime?>? publishedAt,
    Value<String?>? checksum,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return CatalogVersionsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      versionNumber: versionNumber ?? this.versionNumber,
      publishedAt: publishedAt ?? this.publishedAt,
      checksum: checksum ?? this.checksum,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (versionNumber.present) {
      map['version_number'] = Variable<int>(versionNumber.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogVersionsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('versionNumber: $versionNumber, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('checksum: $checksum, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogActivityTypesTable extends CatalogActivityTypes
    with TableInfo<$CatalogActivityTypesTable, CatalogActivityType> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogActivityTypesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 2,
      maxTextLength: 40,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requiresPkMeta = const VerificationMeta(
    'requiresPk',
  );
  @override
  late final GeneratedColumn<bool> requiresPk = GeneratedColumn<bool>(
    'requires_pk',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("requires_pk" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _requiresGeoMeta = const VerificationMeta(
    'requiresGeo',
  );
  @override
  late final GeneratedColumn<bool> requiresGeo = GeneratedColumn<bool>(
    'requires_geo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("requires_geo" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _requiresMinutaMeta = const VerificationMeta(
    'requiresMinuta',
  );
  @override
  late final GeneratedColumn<bool> requiresMinuta = GeneratedColumn<bool>(
    'requires_minuta',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("requires_minuta" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _requiresEvidenceMeta = const VerificationMeta(
    'requiresEvidence',
  );
  @override
  late final GeneratedColumn<bool> requiresEvidence = GeneratedColumn<bool>(
    'requires_evidence',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("requires_evidence" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _catalogVersionMeta = const VerificationMeta(
    'catalogVersion',
  );
  @override
  late final GeneratedColumn<int> catalogVersion = GeneratedColumn<int>(
    'catalog_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    code,
    name,
    requiresPk,
    requiresGeo,
    requiresMinuta,
    requiresEvidence,
    isActive,
    catalogVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_activity_types';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogActivityType> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('requires_pk')) {
      context.handle(
        _requiresPkMeta,
        requiresPk.isAcceptableOrUnknown(data['requires_pk']!, _requiresPkMeta),
      );
    }
    if (data.containsKey('requires_geo')) {
      context.handle(
        _requiresGeoMeta,
        requiresGeo.isAcceptableOrUnknown(
          data['requires_geo']!,
          _requiresGeoMeta,
        ),
      );
    }
    if (data.containsKey('requires_minuta')) {
      context.handle(
        _requiresMinutaMeta,
        requiresMinuta.isAcceptableOrUnknown(
          data['requires_minuta']!,
          _requiresMinutaMeta,
        ),
      );
    }
    if (data.containsKey('requires_evidence')) {
      context.handle(
        _requiresEvidenceMeta,
        requiresEvidence.isAcceptableOrUnknown(
          data['requires_evidence']!,
          _requiresEvidenceMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('catalog_version')) {
      context.handle(
        _catalogVersionMeta,
        catalogVersion.isAcceptableOrUnknown(
          data['catalog_version']!,
          _catalogVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatalogActivityType map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogActivityType(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      requiresPk: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requires_pk'],
      )!,
      requiresGeo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requires_geo'],
      )!,
      requiresMinuta: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requires_minuta'],
      )!,
      requiresEvidence: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requires_evidence'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      catalogVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}catalog_version'],
      )!,
    );
  }

  @override
  $CatalogActivityTypesTable createAlias(String alias) {
    return $CatalogActivityTypesTable(attachedDatabase, alias);
  }
}

class CatalogActivityType extends DataClass
    implements Insertable<CatalogActivityType> {
  final String id;
  final String code;
  final String name;
  final bool requiresPk;
  final bool requiresGeo;
  final bool requiresMinuta;
  final bool requiresEvidence;
  final bool isActive;
  final int catalogVersion;
  const CatalogActivityType({
    required this.id,
    required this.code,
    required this.name,
    required this.requiresPk,
    required this.requiresGeo,
    required this.requiresMinuta,
    required this.requiresEvidence,
    required this.isActive,
    required this.catalogVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['requires_pk'] = Variable<bool>(requiresPk);
    map['requires_geo'] = Variable<bool>(requiresGeo);
    map['requires_minuta'] = Variable<bool>(requiresMinuta);
    map['requires_evidence'] = Variable<bool>(requiresEvidence);
    map['is_active'] = Variable<bool>(isActive);
    map['catalog_version'] = Variable<int>(catalogVersion);
    return map;
  }

  CatalogActivityTypesCompanion toCompanion(bool nullToAbsent) {
    return CatalogActivityTypesCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      requiresPk: Value(requiresPk),
      requiresGeo: Value(requiresGeo),
      requiresMinuta: Value(requiresMinuta),
      requiresEvidence: Value(requiresEvidence),
      isActive: Value(isActive),
      catalogVersion: Value(catalogVersion),
    );
  }

  factory CatalogActivityType.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogActivityType(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      requiresPk: serializer.fromJson<bool>(json['requiresPk']),
      requiresGeo: serializer.fromJson<bool>(json['requiresGeo']),
      requiresMinuta: serializer.fromJson<bool>(json['requiresMinuta']),
      requiresEvidence: serializer.fromJson<bool>(json['requiresEvidence']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      catalogVersion: serializer.fromJson<int>(json['catalogVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'requiresPk': serializer.toJson<bool>(requiresPk),
      'requiresGeo': serializer.toJson<bool>(requiresGeo),
      'requiresMinuta': serializer.toJson<bool>(requiresMinuta),
      'requiresEvidence': serializer.toJson<bool>(requiresEvidence),
      'isActive': serializer.toJson<bool>(isActive),
      'catalogVersion': serializer.toJson<int>(catalogVersion),
    };
  }

  CatalogActivityType copyWith({
    String? id,
    String? code,
    String? name,
    bool? requiresPk,
    bool? requiresGeo,
    bool? requiresMinuta,
    bool? requiresEvidence,
    bool? isActive,
    int? catalogVersion,
  }) => CatalogActivityType(
    id: id ?? this.id,
    code: code ?? this.code,
    name: name ?? this.name,
    requiresPk: requiresPk ?? this.requiresPk,
    requiresGeo: requiresGeo ?? this.requiresGeo,
    requiresMinuta: requiresMinuta ?? this.requiresMinuta,
    requiresEvidence: requiresEvidence ?? this.requiresEvidence,
    isActive: isActive ?? this.isActive,
    catalogVersion: catalogVersion ?? this.catalogVersion,
  );
  CatalogActivityType copyWithCompanion(CatalogActivityTypesCompanion data) {
    return CatalogActivityType(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      requiresPk: data.requiresPk.present
          ? data.requiresPk.value
          : this.requiresPk,
      requiresGeo: data.requiresGeo.present
          ? data.requiresGeo.value
          : this.requiresGeo,
      requiresMinuta: data.requiresMinuta.present
          ? data.requiresMinuta.value
          : this.requiresMinuta,
      requiresEvidence: data.requiresEvidence.present
          ? data.requiresEvidence.value
          : this.requiresEvidence,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      catalogVersion: data.catalogVersion.present
          ? data.catalogVersion.value
          : this.catalogVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogActivityType(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('requiresPk: $requiresPk, ')
          ..write('requiresGeo: $requiresGeo, ')
          ..write('requiresMinuta: $requiresMinuta, ')
          ..write('requiresEvidence: $requiresEvidence, ')
          ..write('isActive: $isActive, ')
          ..write('catalogVersion: $catalogVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    code,
    name,
    requiresPk,
    requiresGeo,
    requiresMinuta,
    requiresEvidence,
    isActive,
    catalogVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogActivityType &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.requiresPk == this.requiresPk &&
          other.requiresGeo == this.requiresGeo &&
          other.requiresMinuta == this.requiresMinuta &&
          other.requiresEvidence == this.requiresEvidence &&
          other.isActive == this.isActive &&
          other.catalogVersion == this.catalogVersion);
}

class CatalogActivityTypesCompanion
    extends UpdateCompanion<CatalogActivityType> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<bool> requiresPk;
  final Value<bool> requiresGeo;
  final Value<bool> requiresMinuta;
  final Value<bool> requiresEvidence;
  final Value<bool> isActive;
  final Value<int> catalogVersion;
  final Value<int> rowid;
  const CatalogActivityTypesCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.requiresPk = const Value.absent(),
    this.requiresGeo = const Value.absent(),
    this.requiresMinuta = const Value.absent(),
    this.requiresEvidence = const Value.absent(),
    this.isActive = const Value.absent(),
    this.catalogVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogActivityTypesCompanion.insert({
    required String id,
    required String code,
    required String name,
    this.requiresPk = const Value.absent(),
    this.requiresGeo = const Value.absent(),
    this.requiresMinuta = const Value.absent(),
    this.requiresEvidence = const Value.absent(),
    this.isActive = const Value.absent(),
    this.catalogVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       code = Value(code),
       name = Value(name);
  static Insertable<CatalogActivityType> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<bool>? requiresPk,
    Expression<bool>? requiresGeo,
    Expression<bool>? requiresMinuta,
    Expression<bool>? requiresEvidence,
    Expression<bool>? isActive,
    Expression<int>? catalogVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (requiresPk != null) 'requires_pk': requiresPk,
      if (requiresGeo != null) 'requires_geo': requiresGeo,
      if (requiresMinuta != null) 'requires_minuta': requiresMinuta,
      if (requiresEvidence != null) 'requires_evidence': requiresEvidence,
      if (isActive != null) 'is_active': isActive,
      if (catalogVersion != null) 'catalog_version': catalogVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogActivityTypesCompanion copyWith({
    Value<String>? id,
    Value<String>? code,
    Value<String>? name,
    Value<bool>? requiresPk,
    Value<bool>? requiresGeo,
    Value<bool>? requiresMinuta,
    Value<bool>? requiresEvidence,
    Value<bool>? isActive,
    Value<int>? catalogVersion,
    Value<int>? rowid,
  }) {
    return CatalogActivityTypesCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      requiresPk: requiresPk ?? this.requiresPk,
      requiresGeo: requiresGeo ?? this.requiresGeo,
      requiresMinuta: requiresMinuta ?? this.requiresMinuta,
      requiresEvidence: requiresEvidence ?? this.requiresEvidence,
      isActive: isActive ?? this.isActive,
      catalogVersion: catalogVersion ?? this.catalogVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (requiresPk.present) {
      map['requires_pk'] = Variable<bool>(requiresPk.value);
    }
    if (requiresGeo.present) {
      map['requires_geo'] = Variable<bool>(requiresGeo.value);
    }
    if (requiresMinuta.present) {
      map['requires_minuta'] = Variable<bool>(requiresMinuta.value);
    }
    if (requiresEvidence.present) {
      map['requires_evidence'] = Variable<bool>(requiresEvidence.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (catalogVersion.present) {
      map['catalog_version'] = Variable<int>(catalogVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogActivityTypesCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('requiresPk: $requiresPk, ')
          ..write('requiresGeo: $requiresGeo, ')
          ..write('requiresMinuta: $requiresMinuta, ')
          ..write('requiresEvidence: $requiresEvidence, ')
          ..write('isActive: $isActive, ')
          ..write('catalogVersion: $catalogVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogFieldsTable extends CatalogFields
    with TableInfo<$CatalogFieldsTable, CatalogField> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogFieldsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityTypeIdMeta = const VerificationMeta(
    'activityTypeId',
  );
  @override
  late final GeneratedColumn<String> activityTypeId = GeneratedColumn<String>(
    'activity_type_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES catalog_activity_types (id)',
    ),
  );
  static const VerificationMeta _fieldKeyMeta = const VerificationMeta(
    'fieldKey',
  );
  @override
  late final GeneratedColumn<String> fieldKey = GeneratedColumn<String>(
    'field_key',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 60,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldLabelMeta = const VerificationMeta(
    'fieldLabel',
  );
  @override
  late final GeneratedColumn<String> fieldLabel = GeneratedColumn<String>(
    'field_label',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldTypeMeta = const VerificationMeta(
    'fieldType',
  );
  @override
  late final GeneratedColumn<String> fieldType = GeneratedColumn<String>(
    'field_type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 20,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _optionsJsonMeta = const VerificationMeta(
    'optionsJson',
  );
  @override
  late final GeneratedColumn<String> optionsJson = GeneratedColumn<String>(
    'options_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requiredFieldMeta = const VerificationMeta(
    'requiredField',
  );
  @override
  late final GeneratedColumn<bool> requiredField = GeneratedColumn<bool>(
    'required_field',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("required_field" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _catalogVersionMeta = const VerificationMeta(
    'catalogVersion',
  );
  @override
  late final GeneratedColumn<int> catalogVersion = GeneratedColumn<int>(
    'catalog_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    activityTypeId,
    fieldKey,
    fieldLabel,
    fieldType,
    optionsJson,
    requiredField,
    orderIndex,
    isActive,
    catalogVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_fields';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogField> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('activity_type_id')) {
      context.handle(
        _activityTypeIdMeta,
        activityTypeId.isAcceptableOrUnknown(
          data['activity_type_id']!,
          _activityTypeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activityTypeIdMeta);
    }
    if (data.containsKey('field_key')) {
      context.handle(
        _fieldKeyMeta,
        fieldKey.isAcceptableOrUnknown(data['field_key']!, _fieldKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldKeyMeta);
    }
    if (data.containsKey('field_label')) {
      context.handle(
        _fieldLabelMeta,
        fieldLabel.isAcceptableOrUnknown(data['field_label']!, _fieldLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldLabelMeta);
    }
    if (data.containsKey('field_type')) {
      context.handle(
        _fieldTypeMeta,
        fieldType.isAcceptableOrUnknown(data['field_type']!, _fieldTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldTypeMeta);
    }
    if (data.containsKey('options_json')) {
      context.handle(
        _optionsJsonMeta,
        optionsJson.isAcceptableOrUnknown(
          data['options_json']!,
          _optionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('required_field')) {
      context.handle(
        _requiredFieldMeta,
        requiredField.isAcceptableOrUnknown(
          data['required_field']!,
          _requiredFieldMeta,
        ),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('catalog_version')) {
      context.handle(
        _catalogVersionMeta,
        catalogVersion.isAcceptableOrUnknown(
          data['catalog_version']!,
          _catalogVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatalogField map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogField(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      activityTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_type_id'],
      )!,
      fieldKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_key'],
      )!,
      fieldLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_label'],
      )!,
      fieldType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_type'],
      )!,
      optionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}options_json'],
      ),
      requiredField: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}required_field'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      catalogVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}catalog_version'],
      )!,
    );
  }

  @override
  $CatalogFieldsTable createAlias(String alias) {
    return $CatalogFieldsTable(attachedDatabase, alias);
  }
}

class CatalogField extends DataClass implements Insertable<CatalogField> {
  final String id;
  final String activityTypeId;
  final String fieldKey;
  final String fieldLabel;
  final String fieldType;
  final String? optionsJson;
  final bool requiredField;
  final int orderIndex;
  final bool isActive;
  final int catalogVersion;
  const CatalogField({
    required this.id,
    required this.activityTypeId,
    required this.fieldKey,
    required this.fieldLabel,
    required this.fieldType,
    this.optionsJson,
    required this.requiredField,
    required this.orderIndex,
    required this.isActive,
    required this.catalogVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['activity_type_id'] = Variable<String>(activityTypeId);
    map['field_key'] = Variable<String>(fieldKey);
    map['field_label'] = Variable<String>(fieldLabel);
    map['field_type'] = Variable<String>(fieldType);
    if (!nullToAbsent || optionsJson != null) {
      map['options_json'] = Variable<String>(optionsJson);
    }
    map['required_field'] = Variable<bool>(requiredField);
    map['order_index'] = Variable<int>(orderIndex);
    map['is_active'] = Variable<bool>(isActive);
    map['catalog_version'] = Variable<int>(catalogVersion);
    return map;
  }

  CatalogFieldsCompanion toCompanion(bool nullToAbsent) {
    return CatalogFieldsCompanion(
      id: Value(id),
      activityTypeId: Value(activityTypeId),
      fieldKey: Value(fieldKey),
      fieldLabel: Value(fieldLabel),
      fieldType: Value(fieldType),
      optionsJson: optionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(optionsJson),
      requiredField: Value(requiredField),
      orderIndex: Value(orderIndex),
      isActive: Value(isActive),
      catalogVersion: Value(catalogVersion),
    );
  }

  factory CatalogField.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogField(
      id: serializer.fromJson<String>(json['id']),
      activityTypeId: serializer.fromJson<String>(json['activityTypeId']),
      fieldKey: serializer.fromJson<String>(json['fieldKey']),
      fieldLabel: serializer.fromJson<String>(json['fieldLabel']),
      fieldType: serializer.fromJson<String>(json['fieldType']),
      optionsJson: serializer.fromJson<String?>(json['optionsJson']),
      requiredField: serializer.fromJson<bool>(json['requiredField']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      catalogVersion: serializer.fromJson<int>(json['catalogVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'activityTypeId': serializer.toJson<String>(activityTypeId),
      'fieldKey': serializer.toJson<String>(fieldKey),
      'fieldLabel': serializer.toJson<String>(fieldLabel),
      'fieldType': serializer.toJson<String>(fieldType),
      'optionsJson': serializer.toJson<String?>(optionsJson),
      'requiredField': serializer.toJson<bool>(requiredField),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'isActive': serializer.toJson<bool>(isActive),
      'catalogVersion': serializer.toJson<int>(catalogVersion),
    };
  }

  CatalogField copyWith({
    String? id,
    String? activityTypeId,
    String? fieldKey,
    String? fieldLabel,
    String? fieldType,
    Value<String?> optionsJson = const Value.absent(),
    bool? requiredField,
    int? orderIndex,
    bool? isActive,
    int? catalogVersion,
  }) => CatalogField(
    id: id ?? this.id,
    activityTypeId: activityTypeId ?? this.activityTypeId,
    fieldKey: fieldKey ?? this.fieldKey,
    fieldLabel: fieldLabel ?? this.fieldLabel,
    fieldType: fieldType ?? this.fieldType,
    optionsJson: optionsJson.present ? optionsJson.value : this.optionsJson,
    requiredField: requiredField ?? this.requiredField,
    orderIndex: orderIndex ?? this.orderIndex,
    isActive: isActive ?? this.isActive,
    catalogVersion: catalogVersion ?? this.catalogVersion,
  );
  CatalogField copyWithCompanion(CatalogFieldsCompanion data) {
    return CatalogField(
      id: data.id.present ? data.id.value : this.id,
      activityTypeId: data.activityTypeId.present
          ? data.activityTypeId.value
          : this.activityTypeId,
      fieldKey: data.fieldKey.present ? data.fieldKey.value : this.fieldKey,
      fieldLabel: data.fieldLabel.present
          ? data.fieldLabel.value
          : this.fieldLabel,
      fieldType: data.fieldType.present ? data.fieldType.value : this.fieldType,
      optionsJson: data.optionsJson.present
          ? data.optionsJson.value
          : this.optionsJson,
      requiredField: data.requiredField.present
          ? data.requiredField.value
          : this.requiredField,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      catalogVersion: data.catalogVersion.present
          ? data.catalogVersion.value
          : this.catalogVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogField(')
          ..write('id: $id, ')
          ..write('activityTypeId: $activityTypeId, ')
          ..write('fieldKey: $fieldKey, ')
          ..write('fieldLabel: $fieldLabel, ')
          ..write('fieldType: $fieldType, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('requiredField: $requiredField, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isActive: $isActive, ')
          ..write('catalogVersion: $catalogVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    activityTypeId,
    fieldKey,
    fieldLabel,
    fieldType,
    optionsJson,
    requiredField,
    orderIndex,
    isActive,
    catalogVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogField &&
          other.id == this.id &&
          other.activityTypeId == this.activityTypeId &&
          other.fieldKey == this.fieldKey &&
          other.fieldLabel == this.fieldLabel &&
          other.fieldType == this.fieldType &&
          other.optionsJson == this.optionsJson &&
          other.requiredField == this.requiredField &&
          other.orderIndex == this.orderIndex &&
          other.isActive == this.isActive &&
          other.catalogVersion == this.catalogVersion);
}

class CatalogFieldsCompanion extends UpdateCompanion<CatalogField> {
  final Value<String> id;
  final Value<String> activityTypeId;
  final Value<String> fieldKey;
  final Value<String> fieldLabel;
  final Value<String> fieldType;
  final Value<String?> optionsJson;
  final Value<bool> requiredField;
  final Value<int> orderIndex;
  final Value<bool> isActive;
  final Value<int> catalogVersion;
  final Value<int> rowid;
  const CatalogFieldsCompanion({
    this.id = const Value.absent(),
    this.activityTypeId = const Value.absent(),
    this.fieldKey = const Value.absent(),
    this.fieldLabel = const Value.absent(),
    this.fieldType = const Value.absent(),
    this.optionsJson = const Value.absent(),
    this.requiredField = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.isActive = const Value.absent(),
    this.catalogVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogFieldsCompanion.insert({
    required String id,
    required String activityTypeId,
    required String fieldKey,
    required String fieldLabel,
    required String fieldType,
    this.optionsJson = const Value.absent(),
    this.requiredField = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.isActive = const Value.absent(),
    this.catalogVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       activityTypeId = Value(activityTypeId),
       fieldKey = Value(fieldKey),
       fieldLabel = Value(fieldLabel),
       fieldType = Value(fieldType);
  static Insertable<CatalogField> custom({
    Expression<String>? id,
    Expression<String>? activityTypeId,
    Expression<String>? fieldKey,
    Expression<String>? fieldLabel,
    Expression<String>? fieldType,
    Expression<String>? optionsJson,
    Expression<bool>? requiredField,
    Expression<int>? orderIndex,
    Expression<bool>? isActive,
    Expression<int>? catalogVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activityTypeId != null) 'activity_type_id': activityTypeId,
      if (fieldKey != null) 'field_key': fieldKey,
      if (fieldLabel != null) 'field_label': fieldLabel,
      if (fieldType != null) 'field_type': fieldType,
      if (optionsJson != null) 'options_json': optionsJson,
      if (requiredField != null) 'required_field': requiredField,
      if (orderIndex != null) 'order_index': orderIndex,
      if (isActive != null) 'is_active': isActive,
      if (catalogVersion != null) 'catalog_version': catalogVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogFieldsCompanion copyWith({
    Value<String>? id,
    Value<String>? activityTypeId,
    Value<String>? fieldKey,
    Value<String>? fieldLabel,
    Value<String>? fieldType,
    Value<String?>? optionsJson,
    Value<bool>? requiredField,
    Value<int>? orderIndex,
    Value<bool>? isActive,
    Value<int>? catalogVersion,
    Value<int>? rowid,
  }) {
    return CatalogFieldsCompanion(
      id: id ?? this.id,
      activityTypeId: activityTypeId ?? this.activityTypeId,
      fieldKey: fieldKey ?? this.fieldKey,
      fieldLabel: fieldLabel ?? this.fieldLabel,
      fieldType: fieldType ?? this.fieldType,
      optionsJson: optionsJson ?? this.optionsJson,
      requiredField: requiredField ?? this.requiredField,
      orderIndex: orderIndex ?? this.orderIndex,
      isActive: isActive ?? this.isActive,
      catalogVersion: catalogVersion ?? this.catalogVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (activityTypeId.present) {
      map['activity_type_id'] = Variable<String>(activityTypeId.value);
    }
    if (fieldKey.present) {
      map['field_key'] = Variable<String>(fieldKey.value);
    }
    if (fieldLabel.present) {
      map['field_label'] = Variable<String>(fieldLabel.value);
    }
    if (fieldType.present) {
      map['field_type'] = Variable<String>(fieldType.value);
    }
    if (optionsJson.present) {
      map['options_json'] = Variable<String>(optionsJson.value);
    }
    if (requiredField.present) {
      map['required_field'] = Variable<bool>(requiredField.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (catalogVersion.present) {
      map['catalog_version'] = Variable<int>(catalogVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogFieldsCompanion(')
          ..write('id: $id, ')
          ..write('activityTypeId: $activityTypeId, ')
          ..write('fieldKey: $fieldKey, ')
          ..write('fieldLabel: $fieldLabel, ')
          ..write('fieldType: $fieldType, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('requiredField: $requiredField, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isActive: $isActive, ')
          ..write('catalogVersion: $catalogVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatActivitiesTable extends CatActivities
    with TableInfo<$CatActivitiesTable, CatActivity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatActivitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _versionIdMeta = const VerificationMeta(
    'versionId',
  );
  @override
  late final GeneratedColumn<String> versionId = GeneratedColumn<String>(
    'version_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    isEnabled,
    sortOrder,
    versionId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cat_activities';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatActivity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('version_id')) {
      context.handle(
        _versionIdMeta,
        versionId.isAcceptableOrUnknown(data['version_id']!, _versionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_versionIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatActivity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatActivity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      versionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CatActivitiesTable createAlias(String alias) {
    return $CatActivitiesTable(attachedDatabase, alias);
  }
}

class CatActivity extends DataClass implements Insertable<CatActivity> {
  final String id;
  final String name;
  final String? description;
  final bool isEnabled;
  final int sortOrder;
  final String versionId;
  final DateTime updatedAt;
  const CatActivity({
    required this.id,
    required this.name,
    this.description,
    required this.isEnabled,
    required this.sortOrder,
    required this.versionId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['sort_order'] = Variable<int>(sortOrder);
    map['version_id'] = Variable<String>(versionId);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CatActivitiesCompanion toCompanion(bool nullToAbsent) {
    return CatActivitiesCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isEnabled: Value(isEnabled),
      sortOrder: Value(sortOrder),
      versionId: Value(versionId),
      updatedAt: Value(updatedAt),
    );
  }

  factory CatActivity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatActivity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      versionId: serializer.fromJson<String>(json['versionId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'versionId': serializer.toJson<String>(versionId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CatActivity copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    bool? isEnabled,
    int? sortOrder,
    String? versionId,
    DateTime? updatedAt,
  }) => CatActivity(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    isEnabled: isEnabled ?? this.isEnabled,
    sortOrder: sortOrder ?? this.sortOrder,
    versionId: versionId ?? this.versionId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CatActivity copyWithCompanion(CatActivitiesCompanion data) {
    return CatActivity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      versionId: data.versionId.present ? data.versionId.value : this.versionId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatActivity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('versionId: $versionId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    isEnabled,
    sortOrder,
    versionId,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatActivity &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.isEnabled == this.isEnabled &&
          other.sortOrder == this.sortOrder &&
          other.versionId == this.versionId &&
          other.updatedAt == this.updatedAt);
}

class CatActivitiesCompanion extends UpdateCompanion<CatActivity> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<bool> isEnabled;
  final Value<int> sortOrder;
  final Value<String> versionId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CatActivitiesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.versionId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatActivitiesCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required String versionId,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       versionId = Value(versionId),
       updatedAt = Value(updatedAt);
  static Insertable<CatActivity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<bool>? isEnabled,
    Expression<int>? sortOrder,
    Expression<String>? versionId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (versionId != null) 'version_id': versionId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatActivitiesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<bool>? isEnabled,
    Value<int>? sortOrder,
    Value<String>? versionId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CatActivitiesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isEnabled: isEnabled ?? this.isEnabled,
      sortOrder: sortOrder ?? this.sortOrder,
      versionId: versionId ?? this.versionId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (versionId.present) {
      map['version_id'] = Variable<String>(versionId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatActivitiesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('versionId: $versionId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatSubcategoriesTable extends CatSubcategories
    with TableInfo<$CatSubcategoriesTable, CatSubcategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatSubcategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _versionIdMeta = const VerificationMeta(
    'versionId',
  );
  @override
  late final GeneratedColumn<String> versionId = GeneratedColumn<String>(
    'version_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    activityId,
    name,
    description,
    isEnabled,
    sortOrder,
    versionId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cat_subcategories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatSubcategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('version_id')) {
      context.handle(
        _versionIdMeta,
        versionId.isAcceptableOrUnknown(data['version_id']!, _versionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_versionIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatSubcategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatSubcategory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      versionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CatSubcategoriesTable createAlias(String alias) {
    return $CatSubcategoriesTable(attachedDatabase, alias);
  }
}

class CatSubcategory extends DataClass implements Insertable<CatSubcategory> {
  final String id;
  final String activityId;
  final String name;
  final String? description;
  final bool isEnabled;
  final int sortOrder;
  final String versionId;
  final DateTime updatedAt;
  const CatSubcategory({
    required this.id,
    required this.activityId,
    required this.name,
    this.description,
    required this.isEnabled,
    required this.sortOrder,
    required this.versionId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['activity_id'] = Variable<String>(activityId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['sort_order'] = Variable<int>(sortOrder);
    map['version_id'] = Variable<String>(versionId);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CatSubcategoriesCompanion toCompanion(bool nullToAbsent) {
    return CatSubcategoriesCompanion(
      id: Value(id),
      activityId: Value(activityId),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isEnabled: Value(isEnabled),
      sortOrder: Value(sortOrder),
      versionId: Value(versionId),
      updatedAt: Value(updatedAt),
    );
  }

  factory CatSubcategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatSubcategory(
      id: serializer.fromJson<String>(json['id']),
      activityId: serializer.fromJson<String>(json['activityId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      versionId: serializer.fromJson<String>(json['versionId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'activityId': serializer.toJson<String>(activityId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'versionId': serializer.toJson<String>(versionId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CatSubcategory copyWith({
    String? id,
    String? activityId,
    String? name,
    Value<String?> description = const Value.absent(),
    bool? isEnabled,
    int? sortOrder,
    String? versionId,
    DateTime? updatedAt,
  }) => CatSubcategory(
    id: id ?? this.id,
    activityId: activityId ?? this.activityId,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    isEnabled: isEnabled ?? this.isEnabled,
    sortOrder: sortOrder ?? this.sortOrder,
    versionId: versionId ?? this.versionId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CatSubcategory copyWithCompanion(CatSubcategoriesCompanion data) {
    return CatSubcategory(
      id: data.id.present ? data.id.value : this.id,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      versionId: data.versionId.present ? data.versionId.value : this.versionId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatSubcategory(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('versionId: $versionId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    activityId,
    name,
    description,
    isEnabled,
    sortOrder,
    versionId,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatSubcategory &&
          other.id == this.id &&
          other.activityId == this.activityId &&
          other.name == this.name &&
          other.description == this.description &&
          other.isEnabled == this.isEnabled &&
          other.sortOrder == this.sortOrder &&
          other.versionId == this.versionId &&
          other.updatedAt == this.updatedAt);
}

class CatSubcategoriesCompanion extends UpdateCompanion<CatSubcategory> {
  final Value<String> id;
  final Value<String> activityId;
  final Value<String> name;
  final Value<String?> description;
  final Value<bool> isEnabled;
  final Value<int> sortOrder;
  final Value<String> versionId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CatSubcategoriesCompanion({
    this.id = const Value.absent(),
    this.activityId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.versionId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatSubcategoriesCompanion.insert({
    required String id,
    required String activityId,
    required String name,
    this.description = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required String versionId,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       activityId = Value(activityId),
       name = Value(name),
       versionId = Value(versionId),
       updatedAt = Value(updatedAt);
  static Insertable<CatSubcategory> custom({
    Expression<String>? id,
    Expression<String>? activityId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<bool>? isEnabled,
    Expression<int>? sortOrder,
    Expression<String>? versionId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activityId != null) 'activity_id': activityId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (versionId != null) 'version_id': versionId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatSubcategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? activityId,
    Value<String>? name,
    Value<String?>? description,
    Value<bool>? isEnabled,
    Value<int>? sortOrder,
    Value<String>? versionId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CatSubcategoriesCompanion(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      name: name ?? this.name,
      description: description ?? this.description,
      isEnabled: isEnabled ?? this.isEnabled,
      sortOrder: sortOrder ?? this.sortOrder,
      versionId: versionId ?? this.versionId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (versionId.present) {
      map['version_id'] = Variable<String>(versionId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatSubcategoriesCompanion(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('versionId: $versionId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatPurposesTable extends CatPurposes
    with TableInfo<$CatPurposesTable, CatPurpose> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatPurposesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subcategoryIdMeta = const VerificationMeta(
    'subcategoryId',
  );
  @override
  late final GeneratedColumn<String> subcategoryId = GeneratedColumn<String>(
    'subcategory_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _versionIdMeta = const VerificationMeta(
    'versionId',
  );
  @override
  late final GeneratedColumn<String> versionId = GeneratedColumn<String>(
    'version_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    activityId,
    subcategoryId,
    name,
    isEnabled,
    sortOrder,
    versionId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cat_purposes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatPurpose> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('subcategory_id')) {
      context.handle(
        _subcategoryIdMeta,
        subcategoryId.isAcceptableOrUnknown(
          data['subcategory_id']!,
          _subcategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('version_id')) {
      context.handle(
        _versionIdMeta,
        versionId.isAcceptableOrUnknown(data['version_id']!, _versionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_versionIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatPurpose map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatPurpose(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      )!,
      subcategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subcategory_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      versionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CatPurposesTable createAlias(String alias) {
    return $CatPurposesTable(attachedDatabase, alias);
  }
}

class CatPurpose extends DataClass implements Insertable<CatPurpose> {
  final String id;
  final String activityId;
  final String? subcategoryId;
  final String name;
  final bool isEnabled;
  final int sortOrder;
  final String versionId;
  final DateTime updatedAt;
  const CatPurpose({
    required this.id,
    required this.activityId,
    this.subcategoryId,
    required this.name,
    required this.isEnabled,
    required this.sortOrder,
    required this.versionId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['activity_id'] = Variable<String>(activityId);
    if (!nullToAbsent || subcategoryId != null) {
      map['subcategory_id'] = Variable<String>(subcategoryId);
    }
    map['name'] = Variable<String>(name);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['sort_order'] = Variable<int>(sortOrder);
    map['version_id'] = Variable<String>(versionId);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CatPurposesCompanion toCompanion(bool nullToAbsent) {
    return CatPurposesCompanion(
      id: Value(id),
      activityId: Value(activityId),
      subcategoryId: subcategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(subcategoryId),
      name: Value(name),
      isEnabled: Value(isEnabled),
      sortOrder: Value(sortOrder),
      versionId: Value(versionId),
      updatedAt: Value(updatedAt),
    );
  }

  factory CatPurpose.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatPurpose(
      id: serializer.fromJson<String>(json['id']),
      activityId: serializer.fromJson<String>(json['activityId']),
      subcategoryId: serializer.fromJson<String?>(json['subcategoryId']),
      name: serializer.fromJson<String>(json['name']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      versionId: serializer.fromJson<String>(json['versionId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'activityId': serializer.toJson<String>(activityId),
      'subcategoryId': serializer.toJson<String?>(subcategoryId),
      'name': serializer.toJson<String>(name),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'versionId': serializer.toJson<String>(versionId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CatPurpose copyWith({
    String? id,
    String? activityId,
    Value<String?> subcategoryId = const Value.absent(),
    String? name,
    bool? isEnabled,
    int? sortOrder,
    String? versionId,
    DateTime? updatedAt,
  }) => CatPurpose(
    id: id ?? this.id,
    activityId: activityId ?? this.activityId,
    subcategoryId: subcategoryId.present
        ? subcategoryId.value
        : this.subcategoryId,
    name: name ?? this.name,
    isEnabled: isEnabled ?? this.isEnabled,
    sortOrder: sortOrder ?? this.sortOrder,
    versionId: versionId ?? this.versionId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CatPurpose copyWithCompanion(CatPurposesCompanion data) {
    return CatPurpose(
      id: data.id.present ? data.id.value : this.id,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      subcategoryId: data.subcategoryId.present
          ? data.subcategoryId.value
          : this.subcategoryId,
      name: data.name.present ? data.name.value : this.name,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      versionId: data.versionId.present ? data.versionId.value : this.versionId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatPurpose(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('subcategoryId: $subcategoryId, ')
          ..write('name: $name, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('versionId: $versionId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    activityId,
    subcategoryId,
    name,
    isEnabled,
    sortOrder,
    versionId,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatPurpose &&
          other.id == this.id &&
          other.activityId == this.activityId &&
          other.subcategoryId == this.subcategoryId &&
          other.name == this.name &&
          other.isEnabled == this.isEnabled &&
          other.sortOrder == this.sortOrder &&
          other.versionId == this.versionId &&
          other.updatedAt == this.updatedAt);
}

class CatPurposesCompanion extends UpdateCompanion<CatPurpose> {
  final Value<String> id;
  final Value<String> activityId;
  final Value<String?> subcategoryId;
  final Value<String> name;
  final Value<bool> isEnabled;
  final Value<int> sortOrder;
  final Value<String> versionId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CatPurposesCompanion({
    this.id = const Value.absent(),
    this.activityId = const Value.absent(),
    this.subcategoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.versionId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatPurposesCompanion.insert({
    required String id,
    required String activityId,
    this.subcategoryId = const Value.absent(),
    required String name,
    this.isEnabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required String versionId,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       activityId = Value(activityId),
       name = Value(name),
       versionId = Value(versionId),
       updatedAt = Value(updatedAt);
  static Insertable<CatPurpose> custom({
    Expression<String>? id,
    Expression<String>? activityId,
    Expression<String>? subcategoryId,
    Expression<String>? name,
    Expression<bool>? isEnabled,
    Expression<int>? sortOrder,
    Expression<String>? versionId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activityId != null) 'activity_id': activityId,
      if (subcategoryId != null) 'subcategory_id': subcategoryId,
      if (name != null) 'name': name,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (versionId != null) 'version_id': versionId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatPurposesCompanion copyWith({
    Value<String>? id,
    Value<String>? activityId,
    Value<String?>? subcategoryId,
    Value<String>? name,
    Value<bool>? isEnabled,
    Value<int>? sortOrder,
    Value<String>? versionId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CatPurposesCompanion(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      name: name ?? this.name,
      isEnabled: isEnabled ?? this.isEnabled,
      sortOrder: sortOrder ?? this.sortOrder,
      versionId: versionId ?? this.versionId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (subcategoryId.present) {
      map['subcategory_id'] = Variable<String>(subcategoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (versionId.present) {
      map['version_id'] = Variable<String>(versionId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatPurposesCompanion(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('subcategoryId: $subcategoryId, ')
          ..write('name: $name, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('versionId: $versionId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatTopicsTable extends CatTopics
    with TableInfo<$CatTopicsTable, CatTopic> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatTopicsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _versionIdMeta = const VerificationMeta(
    'versionId',
  );
  @override
  late final GeneratedColumn<String> versionId = GeneratedColumn<String>(
    'version_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    description,
    name,
    isEnabled,
    sortOrder,
    versionId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cat_topics';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatTopic> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('version_id')) {
      context.handle(
        _versionIdMeta,
        versionId.isAcceptableOrUnknown(data['version_id']!, _versionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_versionIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatTopic map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatTopic(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      versionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CatTopicsTable createAlias(String alias) {
    return $CatTopicsTable(attachedDatabase, alias);
  }
}

class CatTopic extends DataClass implements Insertable<CatTopic> {
  final String id;
  final String? type;
  final String? description;
  final String name;
  final bool isEnabled;
  final int sortOrder;
  final String versionId;
  final DateTime updatedAt;
  const CatTopic({
    required this.id,
    this.type,
    this.description,
    required this.name,
    required this.isEnabled,
    required this.sortOrder,
    required this.versionId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['name'] = Variable<String>(name);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['sort_order'] = Variable<int>(sortOrder);
    map['version_id'] = Variable<String>(versionId);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CatTopicsCompanion toCompanion(bool nullToAbsent) {
    return CatTopicsCompanion(
      id: Value(id),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      name: Value(name),
      isEnabled: Value(isEnabled),
      sortOrder: Value(sortOrder),
      versionId: Value(versionId),
      updatedAt: Value(updatedAt),
    );
  }

  factory CatTopic.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatTopic(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String?>(json['type']),
      description: serializer.fromJson<String?>(json['description']),
      name: serializer.fromJson<String>(json['name']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      versionId: serializer.fromJson<String>(json['versionId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String?>(type),
      'description': serializer.toJson<String?>(description),
      'name': serializer.toJson<String>(name),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'versionId': serializer.toJson<String>(versionId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CatTopic copyWith({
    String? id,
    Value<String?> type = const Value.absent(),
    Value<String?> description = const Value.absent(),
    String? name,
    bool? isEnabled,
    int? sortOrder,
    String? versionId,
    DateTime? updatedAt,
  }) => CatTopic(
    id: id ?? this.id,
    type: type.present ? type.value : this.type,
    description: description.present ? description.value : this.description,
    name: name ?? this.name,
    isEnabled: isEnabled ?? this.isEnabled,
    sortOrder: sortOrder ?? this.sortOrder,
    versionId: versionId ?? this.versionId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CatTopic copyWithCompanion(CatTopicsCompanion data) {
    return CatTopic(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      description: data.description.present
          ? data.description.value
          : this.description,
      name: data.name.present ? data.name.value : this.name,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      versionId: data.versionId.present ? data.versionId.value : this.versionId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatTopic(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('name: $name, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('versionId: $versionId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    description,
    name,
    isEnabled,
    sortOrder,
    versionId,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatTopic &&
          other.id == this.id &&
          other.type == this.type &&
          other.description == this.description &&
          other.name == this.name &&
          other.isEnabled == this.isEnabled &&
          other.sortOrder == this.sortOrder &&
          other.versionId == this.versionId &&
          other.updatedAt == this.updatedAt);
}

class CatTopicsCompanion extends UpdateCompanion<CatTopic> {
  final Value<String> id;
  final Value<String?> type;
  final Value<String?> description;
  final Value<String> name;
  final Value<bool> isEnabled;
  final Value<int> sortOrder;
  final Value<String> versionId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CatTopicsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.description = const Value.absent(),
    this.name = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.versionId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatTopicsCompanion.insert({
    required String id,
    this.type = const Value.absent(),
    this.description = const Value.absent(),
    required String name,
    this.isEnabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required String versionId,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       versionId = Value(versionId),
       updatedAt = Value(updatedAt);
  static Insertable<CatTopic> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? description,
    Expression<String>? name,
    Expression<bool>? isEnabled,
    Expression<int>? sortOrder,
    Expression<String>? versionId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (description != null) 'description': description,
      if (name != null) 'name': name,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (versionId != null) 'version_id': versionId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatTopicsCompanion copyWith({
    Value<String>? id,
    Value<String?>? type,
    Value<String?>? description,
    Value<String>? name,
    Value<bool>? isEnabled,
    Value<int>? sortOrder,
    Value<String>? versionId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CatTopicsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      description: description ?? this.description,
      name: name ?? this.name,
      isEnabled: isEnabled ?? this.isEnabled,
      sortOrder: sortOrder ?? this.sortOrder,
      versionId: versionId ?? this.versionId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (versionId.present) {
      map['version_id'] = Variable<String>(versionId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatTopicsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('name: $name, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('versionId: $versionId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatRelActivityTopicsTable extends CatRelActivityTopics
    with TableInfo<$CatRelActivityTopicsTable, CatRelActivityTopic> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatRelActivityTopicsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topicIdMeta = const VerificationMeta(
    'topicId',
  );
  @override
  late final GeneratedColumn<String> topicId = GeneratedColumn<String>(
    'topic_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _versionIdMeta = const VerificationMeta(
    'versionId',
  );
  @override
  late final GeneratedColumn<String> versionId = GeneratedColumn<String>(
    'version_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    activityId,
    topicId,
    isEnabled,
    versionId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cat_rel_activity_topics';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatRelActivityTopic> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('topic_id')) {
      context.handle(
        _topicIdMeta,
        topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_topicIdMeta);
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('version_id')) {
      context.handle(
        _versionIdMeta,
        versionId.isAcceptableOrUnknown(data['version_id']!, _versionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_versionIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {activityId, topicId};
  @override
  CatRelActivityTopic map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatRelActivityTopic(
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      )!,
      topicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic_id'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      versionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CatRelActivityTopicsTable createAlias(String alias) {
    return $CatRelActivityTopicsTable(attachedDatabase, alias);
  }
}

class CatRelActivityTopic extends DataClass
    implements Insertable<CatRelActivityTopic> {
  final String activityId;
  final String topicId;
  final bool isEnabled;
  final String versionId;
  final DateTime updatedAt;
  const CatRelActivityTopic({
    required this.activityId,
    required this.topicId,
    required this.isEnabled,
    required this.versionId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['activity_id'] = Variable<String>(activityId);
    map['topic_id'] = Variable<String>(topicId);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['version_id'] = Variable<String>(versionId);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CatRelActivityTopicsCompanion toCompanion(bool nullToAbsent) {
    return CatRelActivityTopicsCompanion(
      activityId: Value(activityId),
      topicId: Value(topicId),
      isEnabled: Value(isEnabled),
      versionId: Value(versionId),
      updatedAt: Value(updatedAt),
    );
  }

  factory CatRelActivityTopic.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatRelActivityTopic(
      activityId: serializer.fromJson<String>(json['activityId']),
      topicId: serializer.fromJson<String>(json['topicId']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      versionId: serializer.fromJson<String>(json['versionId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'activityId': serializer.toJson<String>(activityId),
      'topicId': serializer.toJson<String>(topicId),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'versionId': serializer.toJson<String>(versionId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CatRelActivityTopic copyWith({
    String? activityId,
    String? topicId,
    bool? isEnabled,
    String? versionId,
    DateTime? updatedAt,
  }) => CatRelActivityTopic(
    activityId: activityId ?? this.activityId,
    topicId: topicId ?? this.topicId,
    isEnabled: isEnabled ?? this.isEnabled,
    versionId: versionId ?? this.versionId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CatRelActivityTopic copyWithCompanion(CatRelActivityTopicsCompanion data) {
    return CatRelActivityTopic(
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      versionId: data.versionId.present ? data.versionId.value : this.versionId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatRelActivityTopic(')
          ..write('activityId: $activityId, ')
          ..write('topicId: $topicId, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('versionId: $versionId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(activityId, topicId, isEnabled, versionId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatRelActivityTopic &&
          other.activityId == this.activityId &&
          other.topicId == this.topicId &&
          other.isEnabled == this.isEnabled &&
          other.versionId == this.versionId &&
          other.updatedAt == this.updatedAt);
}

class CatRelActivityTopicsCompanion
    extends UpdateCompanion<CatRelActivityTopic> {
  final Value<String> activityId;
  final Value<String> topicId;
  final Value<bool> isEnabled;
  final Value<String> versionId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CatRelActivityTopicsCompanion({
    this.activityId = const Value.absent(),
    this.topicId = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.versionId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatRelActivityTopicsCompanion.insert({
    required String activityId,
    required String topicId,
    this.isEnabled = const Value.absent(),
    required String versionId,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : activityId = Value(activityId),
       topicId = Value(topicId),
       versionId = Value(versionId),
       updatedAt = Value(updatedAt);
  static Insertable<CatRelActivityTopic> custom({
    Expression<String>? activityId,
    Expression<String>? topicId,
    Expression<bool>? isEnabled,
    Expression<String>? versionId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (activityId != null) 'activity_id': activityId,
      if (topicId != null) 'topic_id': topicId,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (versionId != null) 'version_id': versionId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatRelActivityTopicsCompanion copyWith({
    Value<String>? activityId,
    Value<String>? topicId,
    Value<bool>? isEnabled,
    Value<String>? versionId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CatRelActivityTopicsCompanion(
      activityId: activityId ?? this.activityId,
      topicId: topicId ?? this.topicId,
      isEnabled: isEnabled ?? this.isEnabled,
      versionId: versionId ?? this.versionId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (topicId.present) {
      map['topic_id'] = Variable<String>(topicId.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (versionId.present) {
      map['version_id'] = Variable<String>(versionId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatRelActivityTopicsCompanion(')
          ..write('activityId: $activityId, ')
          ..write('topicId: $topicId, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('versionId: $versionId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatResultsTable extends CatResults
    with TableInfo<$CatResultsTable, CatResult> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _severityMeta = const VerificationMeta(
    'severity',
  );
  @override
  late final GeneratedColumn<String> severity = GeneratedColumn<String>(
    'severity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _versionIdMeta = const VerificationMeta(
    'versionId',
  );
  @override
  late final GeneratedColumn<String> versionId = GeneratedColumn<String>(
    'version_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    category,
    severity,
    isEnabled,
    sortOrder,
    versionId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cat_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatResult> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('severity')) {
      context.handle(
        _severityMeta,
        severity.isAcceptableOrUnknown(data['severity']!, _severityMeta),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('version_id')) {
      context.handle(
        _versionIdMeta,
        versionId.isAcceptableOrUnknown(data['version_id']!, _versionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_versionIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatResult map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatResult(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      severity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}severity'],
      ),
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      versionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CatResultsTable createAlias(String alias) {
    return $CatResultsTable(attachedDatabase, alias);
  }
}

class CatResult extends DataClass implements Insertable<CatResult> {
  final String id;
  final String name;
  final String? category;
  final String? severity;
  final bool isEnabled;
  final int sortOrder;
  final String versionId;
  final DateTime updatedAt;
  const CatResult({
    required this.id,
    required this.name,
    this.category,
    this.severity,
    required this.isEnabled,
    required this.sortOrder,
    required this.versionId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || severity != null) {
      map['severity'] = Variable<String>(severity);
    }
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['sort_order'] = Variable<int>(sortOrder);
    map['version_id'] = Variable<String>(versionId);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CatResultsCompanion toCompanion(bool nullToAbsent) {
    return CatResultsCompanion(
      id: Value(id),
      name: Value(name),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      severity: severity == null && nullToAbsent
          ? const Value.absent()
          : Value(severity),
      isEnabled: Value(isEnabled),
      sortOrder: Value(sortOrder),
      versionId: Value(versionId),
      updatedAt: Value(updatedAt),
    );
  }

  factory CatResult.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatResult(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String?>(json['category']),
      severity: serializer.fromJson<String?>(json['severity']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      versionId: serializer.fromJson<String>(json['versionId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String?>(category),
      'severity': serializer.toJson<String?>(severity),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'versionId': serializer.toJson<String>(versionId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CatResult copyWith({
    String? id,
    String? name,
    Value<String?> category = const Value.absent(),
    Value<String?> severity = const Value.absent(),
    bool? isEnabled,
    int? sortOrder,
    String? versionId,
    DateTime? updatedAt,
  }) => CatResult(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category.present ? category.value : this.category,
    severity: severity.present ? severity.value : this.severity,
    isEnabled: isEnabled ?? this.isEnabled,
    sortOrder: sortOrder ?? this.sortOrder,
    versionId: versionId ?? this.versionId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CatResult copyWithCompanion(CatResultsCompanion data) {
    return CatResult(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      severity: data.severity.present ? data.severity.value : this.severity,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      versionId: data.versionId.present ? data.versionId.value : this.versionId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatResult(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('severity: $severity, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('versionId: $versionId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    severity,
    isEnabled,
    sortOrder,
    versionId,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatResult &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.severity == this.severity &&
          other.isEnabled == this.isEnabled &&
          other.sortOrder == this.sortOrder &&
          other.versionId == this.versionId &&
          other.updatedAt == this.updatedAt);
}

class CatResultsCompanion extends UpdateCompanion<CatResult> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> category;
  final Value<String?> severity;
  final Value<bool> isEnabled;
  final Value<int> sortOrder;
  final Value<String> versionId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CatResultsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.severity = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.versionId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatResultsCompanion.insert({
    required String id,
    required String name,
    this.category = const Value.absent(),
    this.severity = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required String versionId,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       versionId = Value(versionId),
       updatedAt = Value(updatedAt);
  static Insertable<CatResult> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? severity,
    Expression<bool>? isEnabled,
    Expression<int>? sortOrder,
    Expression<String>? versionId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (severity != null) 'severity': severity,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (versionId != null) 'version_id': versionId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatResultsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? category,
    Value<String?>? severity,
    Value<bool>? isEnabled,
    Value<int>? sortOrder,
    Value<String>? versionId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CatResultsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      isEnabled: isEnabled ?? this.isEnabled,
      sortOrder: sortOrder ?? this.sortOrder,
      versionId: versionId ?? this.versionId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (severity.present) {
      map['severity'] = Variable<String>(severity.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (versionId.present) {
      map['version_id'] = Variable<String>(versionId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatResultsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('severity: $severity, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('versionId: $versionId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatAttendeesTable extends CatAttendees
    with TableInfo<$CatAttendeesTable, CatAttendee> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatAttendeesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _versionIdMeta = const VerificationMeta(
    'versionId',
  );
  @override
  late final GeneratedColumn<String> versionId = GeneratedColumn<String>(
    'version_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    description,
    name,
    isEnabled,
    sortOrder,
    versionId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cat_attendees';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatAttendee> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('version_id')) {
      context.handle(
        _versionIdMeta,
        versionId.isAcceptableOrUnknown(data['version_id']!, _versionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_versionIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatAttendee map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatAttendee(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      versionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CatAttendeesTable createAlias(String alias) {
    return $CatAttendeesTable(attachedDatabase, alias);
  }
}

class CatAttendee extends DataClass implements Insertable<CatAttendee> {
  final String id;
  final String type;
  final String? description;
  final String name;
  final bool isEnabled;
  final int sortOrder;
  final String versionId;
  final DateTime updatedAt;
  const CatAttendee({
    required this.id,
    required this.type,
    this.description,
    required this.name,
    required this.isEnabled,
    required this.sortOrder,
    required this.versionId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['name'] = Variable<String>(name);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['sort_order'] = Variable<int>(sortOrder);
    map['version_id'] = Variable<String>(versionId);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CatAttendeesCompanion toCompanion(bool nullToAbsent) {
    return CatAttendeesCompanion(
      id: Value(id),
      type: Value(type),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      name: Value(name),
      isEnabled: Value(isEnabled),
      sortOrder: Value(sortOrder),
      versionId: Value(versionId),
      updatedAt: Value(updatedAt),
    );
  }

  factory CatAttendee.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatAttendee(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      description: serializer.fromJson<String?>(json['description']),
      name: serializer.fromJson<String>(json['name']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      versionId: serializer.fromJson<String>(json['versionId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'description': serializer.toJson<String?>(description),
      'name': serializer.toJson<String>(name),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'versionId': serializer.toJson<String>(versionId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CatAttendee copyWith({
    String? id,
    String? type,
    Value<String?> description = const Value.absent(),
    String? name,
    bool? isEnabled,
    int? sortOrder,
    String? versionId,
    DateTime? updatedAt,
  }) => CatAttendee(
    id: id ?? this.id,
    type: type ?? this.type,
    description: description.present ? description.value : this.description,
    name: name ?? this.name,
    isEnabled: isEnabled ?? this.isEnabled,
    sortOrder: sortOrder ?? this.sortOrder,
    versionId: versionId ?? this.versionId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CatAttendee copyWithCompanion(CatAttendeesCompanion data) {
    return CatAttendee(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      description: data.description.present
          ? data.description.value
          : this.description,
      name: data.name.present ? data.name.value : this.name,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      versionId: data.versionId.present ? data.versionId.value : this.versionId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatAttendee(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('name: $name, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('versionId: $versionId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    description,
    name,
    isEnabled,
    sortOrder,
    versionId,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatAttendee &&
          other.id == this.id &&
          other.type == this.type &&
          other.description == this.description &&
          other.name == this.name &&
          other.isEnabled == this.isEnabled &&
          other.sortOrder == this.sortOrder &&
          other.versionId == this.versionId &&
          other.updatedAt == this.updatedAt);
}

class CatAttendeesCompanion extends UpdateCompanion<CatAttendee> {
  final Value<String> id;
  final Value<String> type;
  final Value<String?> description;
  final Value<String> name;
  final Value<bool> isEnabled;
  final Value<int> sortOrder;
  final Value<String> versionId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CatAttendeesCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.description = const Value.absent(),
    this.name = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.versionId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatAttendeesCompanion.insert({
    required String id,
    required String type,
    this.description = const Value.absent(),
    required String name,
    this.isEnabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required String versionId,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       name = Value(name),
       versionId = Value(versionId),
       updatedAt = Value(updatedAt);
  static Insertable<CatAttendee> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? description,
    Expression<String>? name,
    Expression<bool>? isEnabled,
    Expression<int>? sortOrder,
    Expression<String>? versionId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (description != null) 'description': description,
      if (name != null) 'name': name,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (versionId != null) 'version_id': versionId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatAttendeesCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String?>? description,
    Value<String>? name,
    Value<bool>? isEnabled,
    Value<int>? sortOrder,
    Value<String>? versionId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CatAttendeesCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      description: description ?? this.description,
      name: name ?? this.name,
      isEnabled: isEnabled ?? this.isEnabled,
      sortOrder: sortOrder ?? this.sortOrder,
      versionId: versionId ?? this.versionId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (versionId.present) {
      map['version_id'] = Variable<String>(versionId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatAttendeesCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('name: $name, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('versionId: $versionId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogIndexTable extends CatalogIndex
    with TableInfo<$CatalogIndexTable, CatalogIndexData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogIndexTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeVersionIdMeta = const VerificationMeta(
    'activeVersionId',
  );
  @override
  late final GeneratedColumn<String> activeVersionId = GeneratedColumn<String>(
    'active_version_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    projectId,
    activeVersionId,
    hash,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_index';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogIndexData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('active_version_id')) {
      context.handle(
        _activeVersionIdMeta,
        activeVersionId.isAcceptableOrUnknown(
          data['active_version_id']!,
          _activeVersionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activeVersionIdMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {projectId};
  @override
  CatalogIndexData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogIndexData(
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      activeVersionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_version_id'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CatalogIndexTable createAlias(String alias) {
    return $CatalogIndexTable(attachedDatabase, alias);
  }
}

class CatalogIndexData extends DataClass
    implements Insertable<CatalogIndexData> {
  final String projectId;
  final String activeVersionId;
  final String? hash;
  final DateTime updatedAt;
  const CatalogIndexData({
    required this.projectId,
    required this.activeVersionId,
    this.hash,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['project_id'] = Variable<String>(projectId);
    map['active_version_id'] = Variable<String>(activeVersionId);
    if (!nullToAbsent || hash != null) {
      map['hash'] = Variable<String>(hash);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CatalogIndexCompanion toCompanion(bool nullToAbsent) {
    return CatalogIndexCompanion(
      projectId: Value(projectId),
      activeVersionId: Value(activeVersionId),
      hash: hash == null && nullToAbsent ? const Value.absent() : Value(hash),
      updatedAt: Value(updatedAt),
    );
  }

  factory CatalogIndexData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogIndexData(
      projectId: serializer.fromJson<String>(json['projectId']),
      activeVersionId: serializer.fromJson<String>(json['activeVersionId']),
      hash: serializer.fromJson<String?>(json['hash']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'projectId': serializer.toJson<String>(projectId),
      'activeVersionId': serializer.toJson<String>(activeVersionId),
      'hash': serializer.toJson<String?>(hash),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CatalogIndexData copyWith({
    String? projectId,
    String? activeVersionId,
    Value<String?> hash = const Value.absent(),
    DateTime? updatedAt,
  }) => CatalogIndexData(
    projectId: projectId ?? this.projectId,
    activeVersionId: activeVersionId ?? this.activeVersionId,
    hash: hash.present ? hash.value : this.hash,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CatalogIndexData copyWithCompanion(CatalogIndexCompanion data) {
    return CatalogIndexData(
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      activeVersionId: data.activeVersionId.present
          ? data.activeVersionId.value
          : this.activeVersionId,
      hash: data.hash.present ? data.hash.value : this.hash,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogIndexData(')
          ..write('projectId: $projectId, ')
          ..write('activeVersionId: $activeVersionId, ')
          ..write('hash: $hash, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(projectId, activeVersionId, hash, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogIndexData &&
          other.projectId == this.projectId &&
          other.activeVersionId == this.activeVersionId &&
          other.hash == this.hash &&
          other.updatedAt == this.updatedAt);
}

class CatalogIndexCompanion extends UpdateCompanion<CatalogIndexData> {
  final Value<String> projectId;
  final Value<String> activeVersionId;
  final Value<String?> hash;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CatalogIndexCompanion({
    this.projectId = const Value.absent(),
    this.activeVersionId = const Value.absent(),
    this.hash = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogIndexCompanion.insert({
    required String projectId,
    required String activeVersionId,
    this.hash = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : projectId = Value(projectId),
       activeVersionId = Value(activeVersionId),
       updatedAt = Value(updatedAt);
  static Insertable<CatalogIndexData> custom({
    Expression<String>? projectId,
    Expression<String>? activeVersionId,
    Expression<String>? hash,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (projectId != null) 'project_id': projectId,
      if (activeVersionId != null) 'active_version_id': activeVersionId,
      if (hash != null) 'hash': hash,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogIndexCompanion copyWith({
    Value<String>? projectId,
    Value<String>? activeVersionId,
    Value<String?>? hash,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CatalogIndexCompanion(
      projectId: projectId ?? this.projectId,
      activeVersionId: activeVersionId ?? this.activeVersionId,
      hash: hash ?? this.hash,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (activeVersionId.present) {
      map['active_version_id'] = Variable<String>(activeVersionId.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogIndexCompanion(')
          ..write('projectId: $projectId, ')
          ..write('activeVersionId: $activeVersionId, ')
          ..write('hash: $hash, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogBundleCacheTable extends CatalogBundleCache
    with TableInfo<$CatalogBundleCacheTable, CatalogBundleCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogBundleCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionIdMeta = const VerificationMeta(
    'versionId',
  );
  @override
  late final GeneratedColumn<String> versionId = GeneratedColumn<String>(
    'version_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonBlobMeta = const VerificationMeta(
    'jsonBlob',
  );
  @override
  late final GeneratedColumn<String> jsonBlob = GeneratedColumn<String>(
    'json_blob',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    projectId,
    versionId,
    jsonBlob,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_bundle_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogBundleCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('version_id')) {
      context.handle(
        _versionIdMeta,
        versionId.isAcceptableOrUnknown(data['version_id']!, _versionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_versionIdMeta);
    }
    if (data.containsKey('json_blob')) {
      context.handle(
        _jsonBlobMeta,
        jsonBlob.isAcceptableOrUnknown(data['json_blob']!, _jsonBlobMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonBlobMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {projectId, versionId};
  @override
  CatalogBundleCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogBundleCacheData(
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      versionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_id'],
      )!,
      jsonBlob: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json_blob'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CatalogBundleCacheTable createAlias(String alias) {
    return $CatalogBundleCacheTable(attachedDatabase, alias);
  }
}

class CatalogBundleCacheData extends DataClass
    implements Insertable<CatalogBundleCacheData> {
  final String projectId;
  final String versionId;
  final String jsonBlob;
  final DateTime createdAt;
  const CatalogBundleCacheData({
    required this.projectId,
    required this.versionId,
    required this.jsonBlob,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['project_id'] = Variable<String>(projectId);
    map['version_id'] = Variable<String>(versionId);
    map['json_blob'] = Variable<String>(jsonBlob);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CatalogBundleCacheCompanion toCompanion(bool nullToAbsent) {
    return CatalogBundleCacheCompanion(
      projectId: Value(projectId),
      versionId: Value(versionId),
      jsonBlob: Value(jsonBlob),
      createdAt: Value(createdAt),
    );
  }

  factory CatalogBundleCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogBundleCacheData(
      projectId: serializer.fromJson<String>(json['projectId']),
      versionId: serializer.fromJson<String>(json['versionId']),
      jsonBlob: serializer.fromJson<String>(json['jsonBlob']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'projectId': serializer.toJson<String>(projectId),
      'versionId': serializer.toJson<String>(versionId),
      'jsonBlob': serializer.toJson<String>(jsonBlob),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CatalogBundleCacheData copyWith({
    String? projectId,
    String? versionId,
    String? jsonBlob,
    DateTime? createdAt,
  }) => CatalogBundleCacheData(
    projectId: projectId ?? this.projectId,
    versionId: versionId ?? this.versionId,
    jsonBlob: jsonBlob ?? this.jsonBlob,
    createdAt: createdAt ?? this.createdAt,
  );
  CatalogBundleCacheData copyWithCompanion(CatalogBundleCacheCompanion data) {
    return CatalogBundleCacheData(
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      versionId: data.versionId.present ? data.versionId.value : this.versionId,
      jsonBlob: data.jsonBlob.present ? data.jsonBlob.value : this.jsonBlob,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogBundleCacheData(')
          ..write('projectId: $projectId, ')
          ..write('versionId: $versionId, ')
          ..write('jsonBlob: $jsonBlob, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(projectId, versionId, jsonBlob, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogBundleCacheData &&
          other.projectId == this.projectId &&
          other.versionId == this.versionId &&
          other.jsonBlob == this.jsonBlob &&
          other.createdAt == this.createdAt);
}

class CatalogBundleCacheCompanion
    extends UpdateCompanion<CatalogBundleCacheData> {
  final Value<String> projectId;
  final Value<String> versionId;
  final Value<String> jsonBlob;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CatalogBundleCacheCompanion({
    this.projectId = const Value.absent(),
    this.versionId = const Value.absent(),
    this.jsonBlob = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogBundleCacheCompanion.insert({
    required String projectId,
    required String versionId,
    required String jsonBlob,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : projectId = Value(projectId),
       versionId = Value(versionId),
       jsonBlob = Value(jsonBlob),
       createdAt = Value(createdAt);
  static Insertable<CatalogBundleCacheData> custom({
    Expression<String>? projectId,
    Expression<String>? versionId,
    Expression<String>? jsonBlob,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (projectId != null) 'project_id': projectId,
      if (versionId != null) 'version_id': versionId,
      if (jsonBlob != null) 'json_blob': jsonBlob,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogBundleCacheCompanion copyWith({
    Value<String>? projectId,
    Value<String>? versionId,
    Value<String>? jsonBlob,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CatalogBundleCacheCompanion(
      projectId: projectId ?? this.projectId,
      versionId: versionId ?? this.versionId,
      jsonBlob: jsonBlob ?? this.jsonBlob,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (versionId.present) {
      map['version_id'] = Variable<String>(versionId.value);
    }
    if (jsonBlob.present) {
      map['json_blob'] = Variable<String>(jsonBlob.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogBundleCacheCompanion(')
          ..write('projectId: $projectId, ')
          ..write('versionId: $versionId, ')
          ..write('jsonBlob: $jsonBlob, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActivitiesTable extends Activities
    with TableInfo<$ActivitiesTable, Activity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _segmentIdMeta = const VerificationMeta(
    'segmentId',
  );
  @override
  late final GeneratedColumn<String> segmentId = GeneratedColumn<String>(
    'segment_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES project_segments (id)',
    ),
  );
  static const VerificationMeta _activityTypeIdMeta = const VerificationMeta(
    'activityTypeId',
  );
  @override
  late final GeneratedColumn<String> activityTypeId = GeneratedColumn<String>(
    'activity_type_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES catalog_activity_types (id)',
    ),
  );
  static const VerificationMeta _catalogVersionIdMeta = const VerificationMeta(
    'catalogVersionId',
  );
  @override
  late final GeneratedColumn<String> catalogVersionId = GeneratedColumn<String>(
    'catalog_version_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 140,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pkMeta = const VerificationMeta('pk');
  @override
  late final GeneratedColumn<int> pk = GeneratedColumn<int>(
    'pk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pkRefTypeMeta = const VerificationMeta(
    'pkRefType',
  );
  @override
  late final GeneratedColumn<String> pkRefType = GeneratedColumn<String>(
    'pk_ref_type',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 2,
      maxTextLength: 10,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByUserIdMeta = const VerificationMeta(
    'createdByUserId',
  );
  @override
  late final GeneratedColumn<String> createdByUserId = GeneratedColumn<String>(
    'created_by_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _assignedToUserIdMeta = const VerificationMeta(
    'assignedToUserId',
  );
  @override
  late final GeneratedColumn<String> assignedToUserId = GeneratedColumn<String>(
    'assigned_to_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('DRAFT'),
  );
  static const VerificationMeta _geoLatMeta = const VerificationMeta('geoLat');
  @override
  late final GeneratedColumn<double> geoLat = GeneratedColumn<double>(
    'geo_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _geoLonMeta = const VerificationMeta('geoLon');
  @override
  late final GeneratedColumn<double> geoLon = GeneratedColumn<double>(
    'geo_lon',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _geoAccuracyMeta = const VerificationMeta(
    'geoAccuracy',
  );
  @override
  late final GeneratedColumn<double> geoAccuracy = GeneratedColumn<double>(
    'geo_accuracy',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localRevisionMeta = const VerificationMeta(
    'localRevision',
  );
  @override
  late final GeneratedColumn<int> localRevision = GeneratedColumn<int>(
    'local_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _serverRevisionMeta = const VerificationMeta(
    'serverRevision',
  );
  @override
  late final GeneratedColumn<int> serverRevision = GeneratedColumn<int>(
    'server_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    segmentId,
    activityTypeId,
    catalogVersionId,
    title,
    description,
    pk,
    pkRefType,
    createdAt,
    startedAt,
    finishedAt,
    createdByUserId,
    assignedToUserId,
    status,
    geoLat,
    geoLon,
    geoAccuracy,
    deviceId,
    localRevision,
    serverRevision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activities';
  @override
  VerificationContext validateIntegrity(
    Insertable<Activity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('segment_id')) {
      context.handle(
        _segmentIdMeta,
        segmentId.isAcceptableOrUnknown(data['segment_id']!, _segmentIdMeta),
      );
    }
    if (data.containsKey('activity_type_id')) {
      context.handle(
        _activityTypeIdMeta,
        activityTypeId.isAcceptableOrUnknown(
          data['activity_type_id']!,
          _activityTypeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activityTypeIdMeta);
    }
    if (data.containsKey('catalog_version_id')) {
      context.handle(
        _catalogVersionIdMeta,
        catalogVersionId.isAcceptableOrUnknown(
          data['catalog_version_id']!,
          _catalogVersionIdMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('pk')) {
      context.handle(_pkMeta, pk.isAcceptableOrUnknown(data['pk']!, _pkMeta));
    }
    if (data.containsKey('pk_ref_type')) {
      context.handle(
        _pkRefTypeMeta,
        pkRefType.isAcceptableOrUnknown(data['pk_ref_type']!, _pkRefTypeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('created_by_user_id')) {
      context.handle(
        _createdByUserIdMeta,
        createdByUserId.isAcceptableOrUnknown(
          data['created_by_user_id']!,
          _createdByUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdByUserIdMeta);
    }
    if (data.containsKey('assigned_to_user_id')) {
      context.handle(
        _assignedToUserIdMeta,
        assignedToUserId.isAcceptableOrUnknown(
          data['assigned_to_user_id']!,
          _assignedToUserIdMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('geo_lat')) {
      context.handle(
        _geoLatMeta,
        geoLat.isAcceptableOrUnknown(data['geo_lat']!, _geoLatMeta),
      );
    }
    if (data.containsKey('geo_lon')) {
      context.handle(
        _geoLonMeta,
        geoLon.isAcceptableOrUnknown(data['geo_lon']!, _geoLonMeta),
      );
    }
    if (data.containsKey('geo_accuracy')) {
      context.handle(
        _geoAccuracyMeta,
        geoAccuracy.isAcceptableOrUnknown(
          data['geo_accuracy']!,
          _geoAccuracyMeta,
        ),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('local_revision')) {
      context.handle(
        _localRevisionMeta,
        localRevision.isAcceptableOrUnknown(
          data['local_revision']!,
          _localRevisionMeta,
        ),
      );
    }
    if (data.containsKey('server_revision')) {
      context.handle(
        _serverRevisionMeta,
        serverRevision.isAcceptableOrUnknown(
          data['server_revision']!,
          _serverRevisionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Activity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Activity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      segmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}segment_id'],
      ),
      activityTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_type_id'],
      )!,
      catalogVersionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catalog_version_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pk'],
      ),
      pkRefType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pk_ref_type'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
      createdByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_user_id'],
      )!,
      assignedToUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assigned_to_user_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      geoLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}geo_lat'],
      ),
      geoLon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}geo_lon'],
      ),
      geoAccuracy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}geo_accuracy'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
      localRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_revision'],
      )!,
      serverRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_revision'],
      ),
    );
  }

  @override
  $ActivitiesTable createAlias(String alias) {
    return $ActivitiesTable(attachedDatabase, alias);
  }
}

class Activity extends DataClass implements Insertable<Activity> {
  final String id;
  final String projectId;
  final String? segmentId;
  final String activityTypeId;
  final String? catalogVersionId;
  final String title;
  final String? description;
  final int? pk;
  final String? pkRefType;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String createdByUserId;
  final String? assignedToUserId;
  final String status;
  final double? geoLat;
  final double? geoLon;
  final double? geoAccuracy;
  final String? deviceId;
  final int localRevision;
  final int? serverRevision;
  const Activity({
    required this.id,
    required this.projectId,
    this.segmentId,
    required this.activityTypeId,
    this.catalogVersionId,
    required this.title,
    this.description,
    this.pk,
    this.pkRefType,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    required this.createdByUserId,
    this.assignedToUserId,
    required this.status,
    this.geoLat,
    this.geoLon,
    this.geoAccuracy,
    this.deviceId,
    required this.localRevision,
    this.serverRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    if (!nullToAbsent || segmentId != null) {
      map['segment_id'] = Variable<String>(segmentId);
    }
    map['activity_type_id'] = Variable<String>(activityTypeId);
    if (!nullToAbsent || catalogVersionId != null) {
      map['catalog_version_id'] = Variable<String>(catalogVersionId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || pk != null) {
      map['pk'] = Variable<int>(pk);
    }
    if (!nullToAbsent || pkRefType != null) {
      map['pk_ref_type'] = Variable<String>(pkRefType);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    map['created_by_user_id'] = Variable<String>(createdByUserId);
    if (!nullToAbsent || assignedToUserId != null) {
      map['assigned_to_user_id'] = Variable<String>(assignedToUserId);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || geoLat != null) {
      map['geo_lat'] = Variable<double>(geoLat);
    }
    if (!nullToAbsent || geoLon != null) {
      map['geo_lon'] = Variable<double>(geoLon);
    }
    if (!nullToAbsent || geoAccuracy != null) {
      map['geo_accuracy'] = Variable<double>(geoAccuracy);
    }
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    map['local_revision'] = Variable<int>(localRevision);
    if (!nullToAbsent || serverRevision != null) {
      map['server_revision'] = Variable<int>(serverRevision);
    }
    return map;
  }

  ActivitiesCompanion toCompanion(bool nullToAbsent) {
    return ActivitiesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      segmentId: segmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(segmentId),
      activityTypeId: Value(activityTypeId),
      catalogVersionId: catalogVersionId == null && nullToAbsent
          ? const Value.absent()
          : Value(catalogVersionId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      pk: pk == null && nullToAbsent ? const Value.absent() : Value(pk),
      pkRefType: pkRefType == null && nullToAbsent
          ? const Value.absent()
          : Value(pkRefType),
      createdAt: Value(createdAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      createdByUserId: Value(createdByUserId),
      assignedToUserId: assignedToUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(assignedToUserId),
      status: Value(status),
      geoLat: geoLat == null && nullToAbsent
          ? const Value.absent()
          : Value(geoLat),
      geoLon: geoLon == null && nullToAbsent
          ? const Value.absent()
          : Value(geoLon),
      geoAccuracy: geoAccuracy == null && nullToAbsent
          ? const Value.absent()
          : Value(geoAccuracy),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      localRevision: Value(localRevision),
      serverRevision: serverRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(serverRevision),
    );
  }

  factory Activity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Activity(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      segmentId: serializer.fromJson<String?>(json['segmentId']),
      activityTypeId: serializer.fromJson<String>(json['activityTypeId']),
      catalogVersionId: serializer.fromJson<String?>(json['catalogVersionId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      pk: serializer.fromJson<int?>(json['pk']),
      pkRefType: serializer.fromJson<String?>(json['pkRefType']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      createdByUserId: serializer.fromJson<String>(json['createdByUserId']),
      assignedToUserId: serializer.fromJson<String?>(json['assignedToUserId']),
      status: serializer.fromJson<String>(json['status']),
      geoLat: serializer.fromJson<double?>(json['geoLat']),
      geoLon: serializer.fromJson<double?>(json['geoLon']),
      geoAccuracy: serializer.fromJson<double?>(json['geoAccuracy']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      localRevision: serializer.fromJson<int>(json['localRevision']),
      serverRevision: serializer.fromJson<int?>(json['serverRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'segmentId': serializer.toJson<String?>(segmentId),
      'activityTypeId': serializer.toJson<String>(activityTypeId),
      'catalogVersionId': serializer.toJson<String?>(catalogVersionId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'pk': serializer.toJson<int?>(pk),
      'pkRefType': serializer.toJson<String?>(pkRefType),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'createdByUserId': serializer.toJson<String>(createdByUserId),
      'assignedToUserId': serializer.toJson<String?>(assignedToUserId),
      'status': serializer.toJson<String>(status),
      'geoLat': serializer.toJson<double?>(geoLat),
      'geoLon': serializer.toJson<double?>(geoLon),
      'geoAccuracy': serializer.toJson<double?>(geoAccuracy),
      'deviceId': serializer.toJson<String?>(deviceId),
      'localRevision': serializer.toJson<int>(localRevision),
      'serverRevision': serializer.toJson<int?>(serverRevision),
    };
  }

  Activity copyWith({
    String? id,
    String? projectId,
    Value<String?> segmentId = const Value.absent(),
    String? activityTypeId,
    Value<String?> catalogVersionId = const Value.absent(),
    String? title,
    Value<String?> description = const Value.absent(),
    Value<int?> pk = const Value.absent(),
    Value<String?> pkRefType = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> finishedAt = const Value.absent(),
    String? createdByUserId,
    Value<String?> assignedToUserId = const Value.absent(),
    String? status,
    Value<double?> geoLat = const Value.absent(),
    Value<double?> geoLon = const Value.absent(),
    Value<double?> geoAccuracy = const Value.absent(),
    Value<String?> deviceId = const Value.absent(),
    int? localRevision,
    Value<int?> serverRevision = const Value.absent(),
  }) => Activity(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    segmentId: segmentId.present ? segmentId.value : this.segmentId,
    activityTypeId: activityTypeId ?? this.activityTypeId,
    catalogVersionId: catalogVersionId.present
        ? catalogVersionId.value
        : this.catalogVersionId,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    pk: pk.present ? pk.value : this.pk,
    pkRefType: pkRefType.present ? pkRefType.value : this.pkRefType,
    createdAt: createdAt ?? this.createdAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    createdByUserId: createdByUserId ?? this.createdByUserId,
    assignedToUserId: assignedToUserId.present
        ? assignedToUserId.value
        : this.assignedToUserId,
    status: status ?? this.status,
    geoLat: geoLat.present ? geoLat.value : this.geoLat,
    geoLon: geoLon.present ? geoLon.value : this.geoLon,
    geoAccuracy: geoAccuracy.present ? geoAccuracy.value : this.geoAccuracy,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    localRevision: localRevision ?? this.localRevision,
    serverRevision: serverRevision.present
        ? serverRevision.value
        : this.serverRevision,
  );
  Activity copyWithCompanion(ActivitiesCompanion data) {
    return Activity(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      segmentId: data.segmentId.present ? data.segmentId.value : this.segmentId,
      activityTypeId: data.activityTypeId.present
          ? data.activityTypeId.value
          : this.activityTypeId,
      catalogVersionId: data.catalogVersionId.present
          ? data.catalogVersionId.value
          : this.catalogVersionId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      pk: data.pk.present ? data.pk.value : this.pk,
      pkRefType: data.pkRefType.present ? data.pkRefType.value : this.pkRefType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      createdByUserId: data.createdByUserId.present
          ? data.createdByUserId.value
          : this.createdByUserId,
      assignedToUserId: data.assignedToUserId.present
          ? data.assignedToUserId.value
          : this.assignedToUserId,
      status: data.status.present ? data.status.value : this.status,
      geoLat: data.geoLat.present ? data.geoLat.value : this.geoLat,
      geoLon: data.geoLon.present ? data.geoLon.value : this.geoLon,
      geoAccuracy: data.geoAccuracy.present
          ? data.geoAccuracy.value
          : this.geoAccuracy,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      localRevision: data.localRevision.present
          ? data.localRevision.value
          : this.localRevision,
      serverRevision: data.serverRevision.present
          ? data.serverRevision.value
          : this.serverRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Activity(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('segmentId: $segmentId, ')
          ..write('activityTypeId: $activityTypeId, ')
          ..write('catalogVersionId: $catalogVersionId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('pk: $pk, ')
          ..write('pkRefType: $pkRefType, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('assignedToUserId: $assignedToUserId, ')
          ..write('status: $status, ')
          ..write('geoLat: $geoLat, ')
          ..write('geoLon: $geoLon, ')
          ..write('geoAccuracy: $geoAccuracy, ')
          ..write('deviceId: $deviceId, ')
          ..write('localRevision: $localRevision, ')
          ..write('serverRevision: $serverRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    projectId,
    segmentId,
    activityTypeId,
    catalogVersionId,
    title,
    description,
    pk,
    pkRefType,
    createdAt,
    startedAt,
    finishedAt,
    createdByUserId,
    assignedToUserId,
    status,
    geoLat,
    geoLon,
    geoAccuracy,
    deviceId,
    localRevision,
    serverRevision,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Activity &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.segmentId == this.segmentId &&
          other.activityTypeId == this.activityTypeId &&
          other.catalogVersionId == this.catalogVersionId &&
          other.title == this.title &&
          other.description == this.description &&
          other.pk == this.pk &&
          other.pkRefType == this.pkRefType &&
          other.createdAt == this.createdAt &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.createdByUserId == this.createdByUserId &&
          other.assignedToUserId == this.assignedToUserId &&
          other.status == this.status &&
          other.geoLat == this.geoLat &&
          other.geoLon == this.geoLon &&
          other.geoAccuracy == this.geoAccuracy &&
          other.deviceId == this.deviceId &&
          other.localRevision == this.localRevision &&
          other.serverRevision == this.serverRevision);
}

class ActivitiesCompanion extends UpdateCompanion<Activity> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String?> segmentId;
  final Value<String> activityTypeId;
  final Value<String?> catalogVersionId;
  final Value<String> title;
  final Value<String?> description;
  final Value<int?> pk;
  final Value<String?> pkRefType;
  final Value<DateTime> createdAt;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<String> createdByUserId;
  final Value<String?> assignedToUserId;
  final Value<String> status;
  final Value<double?> geoLat;
  final Value<double?> geoLon;
  final Value<double?> geoAccuracy;
  final Value<String?> deviceId;
  final Value<int> localRevision;
  final Value<int?> serverRevision;
  final Value<int> rowid;
  const ActivitiesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.segmentId = const Value.absent(),
    this.activityTypeId = const Value.absent(),
    this.catalogVersionId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.pk = const Value.absent(),
    this.pkRefType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.createdByUserId = const Value.absent(),
    this.assignedToUserId = const Value.absent(),
    this.status = const Value.absent(),
    this.geoLat = const Value.absent(),
    this.geoLon = const Value.absent(),
    this.geoAccuracy = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.localRevision = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActivitiesCompanion.insert({
    required String id,
    required String projectId,
    this.segmentId = const Value.absent(),
    required String activityTypeId,
    this.catalogVersionId = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    this.pk = const Value.absent(),
    this.pkRefType = const Value.absent(),
    required DateTime createdAt,
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    required String createdByUserId,
    this.assignedToUserId = const Value.absent(),
    this.status = const Value.absent(),
    this.geoLat = const Value.absent(),
    this.geoLon = const Value.absent(),
    this.geoAccuracy = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.localRevision = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       activityTypeId = Value(activityTypeId),
       title = Value(title),
       createdAt = Value(createdAt),
       createdByUserId = Value(createdByUserId);
  static Insertable<Activity> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? segmentId,
    Expression<String>? activityTypeId,
    Expression<String>? catalogVersionId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? pk,
    Expression<String>? pkRefType,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<String>? createdByUserId,
    Expression<String>? assignedToUserId,
    Expression<String>? status,
    Expression<double>? geoLat,
    Expression<double>? geoLon,
    Expression<double>? geoAccuracy,
    Expression<String>? deviceId,
    Expression<int>? localRevision,
    Expression<int>? serverRevision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (segmentId != null) 'segment_id': segmentId,
      if (activityTypeId != null) 'activity_type_id': activityTypeId,
      if (catalogVersionId != null) 'catalog_version_id': catalogVersionId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (pk != null) 'pk': pk,
      if (pkRefType != null) 'pk_ref_type': pkRefType,
      if (createdAt != null) 'created_at': createdAt,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (createdByUserId != null) 'created_by_user_id': createdByUserId,
      if (assignedToUserId != null) 'assigned_to_user_id': assignedToUserId,
      if (status != null) 'status': status,
      if (geoLat != null) 'geo_lat': geoLat,
      if (geoLon != null) 'geo_lon': geoLon,
      if (geoAccuracy != null) 'geo_accuracy': geoAccuracy,
      if (deviceId != null) 'device_id': deviceId,
      if (localRevision != null) 'local_revision': localRevision,
      if (serverRevision != null) 'server_revision': serverRevision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActivitiesCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String?>? segmentId,
    Value<String>? activityTypeId,
    Value<String?>? catalogVersionId,
    Value<String>? title,
    Value<String?>? description,
    Value<int?>? pk,
    Value<String?>? pkRefType,
    Value<DateTime>? createdAt,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<String>? createdByUserId,
    Value<String?>? assignedToUserId,
    Value<String>? status,
    Value<double?>? geoLat,
    Value<double?>? geoLon,
    Value<double?>? geoAccuracy,
    Value<String?>? deviceId,
    Value<int>? localRevision,
    Value<int?>? serverRevision,
    Value<int>? rowid,
  }) {
    return ActivitiesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      segmentId: segmentId ?? this.segmentId,
      activityTypeId: activityTypeId ?? this.activityTypeId,
      catalogVersionId: catalogVersionId ?? this.catalogVersionId,
      title: title ?? this.title,
      description: description ?? this.description,
      pk: pk ?? this.pk,
      pkRefType: pkRefType ?? this.pkRefType,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      assignedToUserId: assignedToUserId ?? this.assignedToUserId,
      status: status ?? this.status,
      geoLat: geoLat ?? this.geoLat,
      geoLon: geoLon ?? this.geoLon,
      geoAccuracy: geoAccuracy ?? this.geoAccuracy,
      deviceId: deviceId ?? this.deviceId,
      localRevision: localRevision ?? this.localRevision,
      serverRevision: serverRevision ?? this.serverRevision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (segmentId.present) {
      map['segment_id'] = Variable<String>(segmentId.value);
    }
    if (activityTypeId.present) {
      map['activity_type_id'] = Variable<String>(activityTypeId.value);
    }
    if (catalogVersionId.present) {
      map['catalog_version_id'] = Variable<String>(catalogVersionId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (pk.present) {
      map['pk'] = Variable<int>(pk.value);
    }
    if (pkRefType.present) {
      map['pk_ref_type'] = Variable<String>(pkRefType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (createdByUserId.present) {
      map['created_by_user_id'] = Variable<String>(createdByUserId.value);
    }
    if (assignedToUserId.present) {
      map['assigned_to_user_id'] = Variable<String>(assignedToUserId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (geoLat.present) {
      map['geo_lat'] = Variable<double>(geoLat.value);
    }
    if (geoLon.present) {
      map['geo_lon'] = Variable<double>(geoLon.value);
    }
    if (geoAccuracy.present) {
      map['geo_accuracy'] = Variable<double>(geoAccuracy.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (localRevision.present) {
      map['local_revision'] = Variable<int>(localRevision.value);
    }
    if (serverRevision.present) {
      map['server_revision'] = Variable<int>(serverRevision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivitiesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('segmentId: $segmentId, ')
          ..write('activityTypeId: $activityTypeId, ')
          ..write('catalogVersionId: $catalogVersionId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('pk: $pk, ')
          ..write('pkRefType: $pkRefType, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('assignedToUserId: $assignedToUserId, ')
          ..write('status: $status, ')
          ..write('geoLat: $geoLat, ')
          ..write('geoLon: $geoLon, ')
          ..write('geoAccuracy: $geoAccuracy, ')
          ..write('deviceId: $deviceId, ')
          ..write('localRevision: $localRevision, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActivityFieldsTable extends ActivityFields
    with TableInfo<$ActivityFieldsTable, ActivityField> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivityFieldsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES activities (id)',
    ),
  );
  static const VerificationMeta _fieldKeyMeta = const VerificationMeta(
    'fieldKey',
  );
  @override
  late final GeneratedColumn<String> fieldKey = GeneratedColumn<String>(
    'field_key',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 60,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueTextMeta = const VerificationMeta(
    'valueText',
  );
  @override
  late final GeneratedColumn<String> valueText = GeneratedColumn<String>(
    'value_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueNumberMeta = const VerificationMeta(
    'valueNumber',
  );
  @override
  late final GeneratedColumn<double> valueNumber = GeneratedColumn<double>(
    'value_number',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueDateMeta = const VerificationMeta(
    'valueDate',
  );
  @override
  late final GeneratedColumn<DateTime> valueDate = GeneratedColumn<DateTime>(
    'value_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    activityId,
    fieldKey,
    valueText,
    valueNumber,
    valueDate,
    valueJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity_fields';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityField> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('field_key')) {
      context.handle(
        _fieldKeyMeta,
        fieldKey.isAcceptableOrUnknown(data['field_key']!, _fieldKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldKeyMeta);
    }
    if (data.containsKey('value_text')) {
      context.handle(
        _valueTextMeta,
        valueText.isAcceptableOrUnknown(data['value_text']!, _valueTextMeta),
      );
    }
    if (data.containsKey('value_number')) {
      context.handle(
        _valueNumberMeta,
        valueNumber.isAcceptableOrUnknown(
          data['value_number']!,
          _valueNumberMeta,
        ),
      );
    }
    if (data.containsKey('value_date')) {
      context.handle(
        _valueDateMeta,
        valueDate.isAcceptableOrUnknown(data['value_date']!, _valueDateMeta),
      );
    }
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivityField map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityField(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      )!,
      fieldKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_key'],
      )!,
      valueText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_text'],
      ),
      valueNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value_number'],
      ),
      valueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}value_date'],
      ),
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      ),
    );
  }

  @override
  $ActivityFieldsTable createAlias(String alias) {
    return $ActivityFieldsTable(attachedDatabase, alias);
  }
}

class ActivityField extends DataClass implements Insertable<ActivityField> {
  final String id;
  final String activityId;
  final String fieldKey;
  final String? valueText;
  final double? valueNumber;
  final DateTime? valueDate;
  final String? valueJson;
  const ActivityField({
    required this.id,
    required this.activityId,
    required this.fieldKey,
    this.valueText,
    this.valueNumber,
    this.valueDate,
    this.valueJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['activity_id'] = Variable<String>(activityId);
    map['field_key'] = Variable<String>(fieldKey);
    if (!nullToAbsent || valueText != null) {
      map['value_text'] = Variable<String>(valueText);
    }
    if (!nullToAbsent || valueNumber != null) {
      map['value_number'] = Variable<double>(valueNumber);
    }
    if (!nullToAbsent || valueDate != null) {
      map['value_date'] = Variable<DateTime>(valueDate);
    }
    if (!nullToAbsent || valueJson != null) {
      map['value_json'] = Variable<String>(valueJson);
    }
    return map;
  }

  ActivityFieldsCompanion toCompanion(bool nullToAbsent) {
    return ActivityFieldsCompanion(
      id: Value(id),
      activityId: Value(activityId),
      fieldKey: Value(fieldKey),
      valueText: valueText == null && nullToAbsent
          ? const Value.absent()
          : Value(valueText),
      valueNumber: valueNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(valueNumber),
      valueDate: valueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(valueDate),
      valueJson: valueJson == null && nullToAbsent
          ? const Value.absent()
          : Value(valueJson),
    );
  }

  factory ActivityField.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityField(
      id: serializer.fromJson<String>(json['id']),
      activityId: serializer.fromJson<String>(json['activityId']),
      fieldKey: serializer.fromJson<String>(json['fieldKey']),
      valueText: serializer.fromJson<String?>(json['valueText']),
      valueNumber: serializer.fromJson<double?>(json['valueNumber']),
      valueDate: serializer.fromJson<DateTime?>(json['valueDate']),
      valueJson: serializer.fromJson<String?>(json['valueJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'activityId': serializer.toJson<String>(activityId),
      'fieldKey': serializer.toJson<String>(fieldKey),
      'valueText': serializer.toJson<String?>(valueText),
      'valueNumber': serializer.toJson<double?>(valueNumber),
      'valueDate': serializer.toJson<DateTime?>(valueDate),
      'valueJson': serializer.toJson<String?>(valueJson),
    };
  }

  ActivityField copyWith({
    String? id,
    String? activityId,
    String? fieldKey,
    Value<String?> valueText = const Value.absent(),
    Value<double?> valueNumber = const Value.absent(),
    Value<DateTime?> valueDate = const Value.absent(),
    Value<String?> valueJson = const Value.absent(),
  }) => ActivityField(
    id: id ?? this.id,
    activityId: activityId ?? this.activityId,
    fieldKey: fieldKey ?? this.fieldKey,
    valueText: valueText.present ? valueText.value : this.valueText,
    valueNumber: valueNumber.present ? valueNumber.value : this.valueNumber,
    valueDate: valueDate.present ? valueDate.value : this.valueDate,
    valueJson: valueJson.present ? valueJson.value : this.valueJson,
  );
  ActivityField copyWithCompanion(ActivityFieldsCompanion data) {
    return ActivityField(
      id: data.id.present ? data.id.value : this.id,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      fieldKey: data.fieldKey.present ? data.fieldKey.value : this.fieldKey,
      valueText: data.valueText.present ? data.valueText.value : this.valueText,
      valueNumber: data.valueNumber.present
          ? data.valueNumber.value
          : this.valueNumber,
      valueDate: data.valueDate.present ? data.valueDate.value : this.valueDate,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityField(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('fieldKey: $fieldKey, ')
          ..write('valueText: $valueText, ')
          ..write('valueNumber: $valueNumber, ')
          ..write('valueDate: $valueDate, ')
          ..write('valueJson: $valueJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    activityId,
    fieldKey,
    valueText,
    valueNumber,
    valueDate,
    valueJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityField &&
          other.id == this.id &&
          other.activityId == this.activityId &&
          other.fieldKey == this.fieldKey &&
          other.valueText == this.valueText &&
          other.valueNumber == this.valueNumber &&
          other.valueDate == this.valueDate &&
          other.valueJson == this.valueJson);
}

class ActivityFieldsCompanion extends UpdateCompanion<ActivityField> {
  final Value<String> id;
  final Value<String> activityId;
  final Value<String> fieldKey;
  final Value<String?> valueText;
  final Value<double?> valueNumber;
  final Value<DateTime?> valueDate;
  final Value<String?> valueJson;
  final Value<int> rowid;
  const ActivityFieldsCompanion({
    this.id = const Value.absent(),
    this.activityId = const Value.absent(),
    this.fieldKey = const Value.absent(),
    this.valueText = const Value.absent(),
    this.valueNumber = const Value.absent(),
    this.valueDate = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActivityFieldsCompanion.insert({
    required String id,
    required String activityId,
    required String fieldKey,
    this.valueText = const Value.absent(),
    this.valueNumber = const Value.absent(),
    this.valueDate = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       activityId = Value(activityId),
       fieldKey = Value(fieldKey);
  static Insertable<ActivityField> custom({
    Expression<String>? id,
    Expression<String>? activityId,
    Expression<String>? fieldKey,
    Expression<String>? valueText,
    Expression<double>? valueNumber,
    Expression<DateTime>? valueDate,
    Expression<String>? valueJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activityId != null) 'activity_id': activityId,
      if (fieldKey != null) 'field_key': fieldKey,
      if (valueText != null) 'value_text': valueText,
      if (valueNumber != null) 'value_number': valueNumber,
      if (valueDate != null) 'value_date': valueDate,
      if (valueJson != null) 'value_json': valueJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActivityFieldsCompanion copyWith({
    Value<String>? id,
    Value<String>? activityId,
    Value<String>? fieldKey,
    Value<String?>? valueText,
    Value<double?>? valueNumber,
    Value<DateTime?>? valueDate,
    Value<String?>? valueJson,
    Value<int>? rowid,
  }) {
    return ActivityFieldsCompanion(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      fieldKey: fieldKey ?? this.fieldKey,
      valueText: valueText ?? this.valueText,
      valueNumber: valueNumber ?? this.valueNumber,
      valueDate: valueDate ?? this.valueDate,
      valueJson: valueJson ?? this.valueJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (fieldKey.present) {
      map['field_key'] = Variable<String>(fieldKey.value);
    }
    if (valueText.present) {
      map['value_text'] = Variable<String>(valueText.value);
    }
    if (valueNumber.present) {
      map['value_number'] = Variable<double>(valueNumber.value);
    }
    if (valueDate.present) {
      map['value_date'] = Variable<DateTime>(valueDate.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivityFieldsCompanion(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('fieldKey: $fieldKey, ')
          ..write('valueText: $valueText, ')
          ..write('valueNumber: $valueNumber, ')
          ..write('valueDate: $valueDate, ')
          ..write('valueJson: $valueJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActivityLogTable extends ActivityLog
    with TableInfo<$ActivityLogTable, ActivityLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivityLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES activities (id)',
    ),
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 30,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    activityId,
    eventType,
    at,
    userId,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivityLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityLogData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $ActivityLogTable createAlias(String alias) {
    return $ActivityLogTable(attachedDatabase, alias);
  }
}

class ActivityLogData extends DataClass implements Insertable<ActivityLogData> {
  final String id;
  final String activityId;
  final String eventType;
  final DateTime at;
  final String userId;
  final String? note;
  const ActivityLogData({
    required this.id,
    required this.activityId,
    required this.eventType,
    required this.at,
    required this.userId,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['activity_id'] = Variable<String>(activityId);
    map['event_type'] = Variable<String>(eventType);
    map['at'] = Variable<DateTime>(at);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  ActivityLogCompanion toCompanion(bool nullToAbsent) {
    return ActivityLogCompanion(
      id: Value(id),
      activityId: Value(activityId),
      eventType: Value(eventType),
      at: Value(at),
      userId: Value(userId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory ActivityLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityLogData(
      id: serializer.fromJson<String>(json['id']),
      activityId: serializer.fromJson<String>(json['activityId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      at: serializer.fromJson<DateTime>(json['at']),
      userId: serializer.fromJson<String>(json['userId']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'activityId': serializer.toJson<String>(activityId),
      'eventType': serializer.toJson<String>(eventType),
      'at': serializer.toJson<DateTime>(at),
      'userId': serializer.toJson<String>(userId),
      'note': serializer.toJson<String?>(note),
    };
  }

  ActivityLogData copyWith({
    String? id,
    String? activityId,
    String? eventType,
    DateTime? at,
    String? userId,
    Value<String?> note = const Value.absent(),
  }) => ActivityLogData(
    id: id ?? this.id,
    activityId: activityId ?? this.activityId,
    eventType: eventType ?? this.eventType,
    at: at ?? this.at,
    userId: userId ?? this.userId,
    note: note.present ? note.value : this.note,
  );
  ActivityLogData copyWithCompanion(ActivityLogCompanion data) {
    return ActivityLogData(
      id: data.id.present ? data.id.value : this.id,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      at: data.at.present ? data.at.value : this.at,
      userId: data.userId.present ? data.userId.value : this.userId,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityLogData(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('eventType: $eventType, ')
          ..write('at: $at, ')
          ..write('userId: $userId, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, activityId, eventType, at, userId, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityLogData &&
          other.id == this.id &&
          other.activityId == this.activityId &&
          other.eventType == this.eventType &&
          other.at == this.at &&
          other.userId == this.userId &&
          other.note == this.note);
}

class ActivityLogCompanion extends UpdateCompanion<ActivityLogData> {
  final Value<String> id;
  final Value<String> activityId;
  final Value<String> eventType;
  final Value<DateTime> at;
  final Value<String> userId;
  final Value<String?> note;
  final Value<int> rowid;
  const ActivityLogCompanion({
    this.id = const Value.absent(),
    this.activityId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.at = const Value.absent(),
    this.userId = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActivityLogCompanion.insert({
    required String id,
    required String activityId,
    required String eventType,
    required DateTime at,
    required String userId,
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       activityId = Value(activityId),
       eventType = Value(eventType),
       at = Value(at),
       userId = Value(userId);
  static Insertable<ActivityLogData> custom({
    Expression<String>? id,
    Expression<String>? activityId,
    Expression<String>? eventType,
    Expression<DateTime>? at,
    Expression<String>? userId,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activityId != null) 'activity_id': activityId,
      if (eventType != null) 'event_type': eventType,
      if (at != null) 'at': at,
      if (userId != null) 'user_id': userId,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActivityLogCompanion copyWith({
    Value<String>? id,
    Value<String>? activityId,
    Value<String>? eventType,
    Value<DateTime>? at,
    Value<String>? userId,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return ActivityLogCompanion(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      eventType: eventType ?? this.eventType,
      at: at ?? this.at,
      userId: userId ?? this.userId,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivityLogCompanion(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('eventType: $eventType, ')
          ..write('at: $at, ')
          ..write('userId: $userId, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAssignmentsTable extends LocalAssignments
    with TableInfo<$LocalAssignmentsTable, LocalAssignment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAssignmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _assigneeUserIdMeta = const VerificationMeta(
    'assigneeUserId',
  );
  @override
  late final GeneratedColumn<String> assigneeUserId = GeneratedColumn<String>(
    'assignee_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _activityTypeCodeMeta = const VerificationMeta(
    'activityTypeCode',
  );
  @override
  late final GeneratedColumn<String> activityTypeCode = GeneratedColumn<String>(
    'activity_type_code',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 200),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _frontIdMeta = const VerificationMeta(
    'frontId',
  );
  @override
  late final GeneratedColumn<String> frontId = GeneratedColumn<String>(
    'front_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES project_segments (id)',
    ),
  );
  static const VerificationMeta _frontRefMeta = const VerificationMeta(
    'frontRef',
  );
  @override
  late final GeneratedColumn<String> frontRef = GeneratedColumn<String>(
    'front_ref',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 255),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estadoMeta = const VerificationMeta('estado');
  @override
  late final GeneratedColumn<String> estado = GeneratedColumn<String>(
    'estado',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 100),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _municipioMeta = const VerificationMeta(
    'municipio',
  );
  @override
  late final GeneratedColumn<String> municipio = GeneratedColumn<String>(
    'municipio',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 100),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coloniaMeta = const VerificationMeta(
    'colonia',
  );
  @override
  late final GeneratedColumn<String> colonia = GeneratedColumn<String>(
    'colonia',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 200),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pkMeta = const VerificationMeta('pk');
  @override
  late final GeneratedColumn<int> pk = GeneratedColumn<int>(
    'pk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _startAtMeta = const VerificationMeta(
    'startAt',
  );
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
    'start_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<DateTime> endAt = GeneratedColumn<DateTime>(
    'end_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _riskMeta = const VerificationMeta('risk');
  @override
  late final GeneratedColumn<String> risk = GeneratedColumn<String>(
    'risk',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 20),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('bajo'),
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('DRAFT'),
  );
  static const VerificationMeta _syncErrorMeta = const VerificationMeta(
    'syncError',
  );
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
    'sync_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncRetryCountMeta = const VerificationMeta(
    'syncRetryCount',
  );
  @override
  late final GeneratedColumn<int> syncRetryCount = GeneratedColumn<int>(
    'sync_retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backendActivityIdMeta = const VerificationMeta(
    'backendActivityId',
  );
  @override
  late final GeneratedColumn<String> backendActivityId =
      GeneratedColumn<String>(
        'backend_activity_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    assigneeUserId,
    activityTypeCode,
    title,
    description,
    frontId,
    frontRef,
    estado,
    municipio,
    colonia,
    pk,
    startAt,
    endAt,
    risk,
    latitude,
    longitude,
    syncStatus,
    syncError,
    syncRetryCount,
    createdAt,
    updatedAt,
    syncedAt,
    backendActivityId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_assignments';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAssignment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('assignee_user_id')) {
      context.handle(
        _assigneeUserIdMeta,
        assigneeUserId.isAcceptableOrUnknown(
          data['assignee_user_id']!,
          _assigneeUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_assigneeUserIdMeta);
    }
    if (data.containsKey('activity_type_code')) {
      context.handle(
        _activityTypeCodeMeta,
        activityTypeCode.isAcceptableOrUnknown(
          data['activity_type_code']!,
          _activityTypeCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activityTypeCodeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('front_id')) {
      context.handle(
        _frontIdMeta,
        frontId.isAcceptableOrUnknown(data['front_id']!, _frontIdMeta),
      );
    }
    if (data.containsKey('front_ref')) {
      context.handle(
        _frontRefMeta,
        frontRef.isAcceptableOrUnknown(data['front_ref']!, _frontRefMeta),
      );
    }
    if (data.containsKey('estado')) {
      context.handle(
        _estadoMeta,
        estado.isAcceptableOrUnknown(data['estado']!, _estadoMeta),
      );
    }
    if (data.containsKey('municipio')) {
      context.handle(
        _municipioMeta,
        municipio.isAcceptableOrUnknown(data['municipio']!, _municipioMeta),
      );
    }
    if (data.containsKey('colonia')) {
      context.handle(
        _coloniaMeta,
        colonia.isAcceptableOrUnknown(data['colonia']!, _coloniaMeta),
      );
    }
    if (data.containsKey('pk')) {
      context.handle(_pkMeta, pk.isAcceptableOrUnknown(data['pk']!, _pkMeta));
    }
    if (data.containsKey('start_at')) {
      context.handle(
        _startAtMeta,
        startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startAtMeta);
    }
    if (data.containsKey('end_at')) {
      context.handle(
        _endAtMeta,
        endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endAtMeta);
    }
    if (data.containsKey('risk')) {
      context.handle(
        _riskMeta,
        risk.isAcceptableOrUnknown(data['risk']!, _riskMeta),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('sync_error')) {
      context.handle(
        _syncErrorMeta,
        syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta),
      );
    }
    if (data.containsKey('sync_retry_count')) {
      context.handle(
        _syncRetryCountMeta,
        syncRetryCount.isAcceptableOrUnknown(
          data['sync_retry_count']!,
          _syncRetryCountMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('backend_activity_id')) {
      context.handle(
        _backendActivityIdMeta,
        backendActivityId.isAcceptableOrUnknown(
          data['backend_activity_id']!,
          _backendActivityIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalAssignment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAssignment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      assigneeUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assignee_user_id'],
      )!,
      activityTypeCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_type_code'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      frontId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}front_id'],
      ),
      frontRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}front_ref'],
      ),
      estado: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estado'],
      ),
      municipio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}municipio'],
      ),
      colonia: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}colonia'],
      ),
      pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pk'],
      )!,
      startAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_at'],
      )!,
      endAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_at'],
      )!,
      risk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}risk'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      syncError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_error'],
      ),
      syncRetryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_retry_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      backendActivityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backend_activity_id'],
      ),
    );
  }

  @override
  $LocalAssignmentsTable createAlias(String alias) {
    return $LocalAssignmentsTable(attachedDatabase, alias);
  }
}

class LocalAssignment extends DataClass implements Insertable<LocalAssignment> {
  final String id;
  final String projectId;
  final String assigneeUserId;
  final String activityTypeCode;
  final String? title;
  final String? description;
  final String? frontId;
  final String? frontRef;
  final String? estado;
  final String? municipio;
  final String? colonia;
  final int pk;
  final DateTime startAt;
  final DateTime endAt;
  final String risk;
  final double? latitude;
  final double? longitude;
  final String syncStatus;
  final String? syncError;
  final int syncRetryCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;
  final String? backendActivityId;
  const LocalAssignment({
    required this.id,
    required this.projectId,
    required this.assigneeUserId,
    required this.activityTypeCode,
    this.title,
    this.description,
    this.frontId,
    this.frontRef,
    this.estado,
    this.municipio,
    this.colonia,
    required this.pk,
    required this.startAt,
    required this.endAt,
    required this.risk,
    this.latitude,
    this.longitude,
    required this.syncStatus,
    this.syncError,
    required this.syncRetryCount,
    required this.createdAt,
    required this.updatedAt,
    this.syncedAt,
    this.backendActivityId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['assignee_user_id'] = Variable<String>(assigneeUserId);
    map['activity_type_code'] = Variable<String>(activityTypeCode);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || frontId != null) {
      map['front_id'] = Variable<String>(frontId);
    }
    if (!nullToAbsent || frontRef != null) {
      map['front_ref'] = Variable<String>(frontRef);
    }
    if (!nullToAbsent || estado != null) {
      map['estado'] = Variable<String>(estado);
    }
    if (!nullToAbsent || municipio != null) {
      map['municipio'] = Variable<String>(municipio);
    }
    if (!nullToAbsent || colonia != null) {
      map['colonia'] = Variable<String>(colonia);
    }
    map['pk'] = Variable<int>(pk);
    map['start_at'] = Variable<DateTime>(startAt);
    map['end_at'] = Variable<DateTime>(endAt);
    map['risk'] = Variable<String>(risk);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    map['sync_retry_count'] = Variable<int>(syncRetryCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    if (!nullToAbsent || backendActivityId != null) {
      map['backend_activity_id'] = Variable<String>(backendActivityId);
    }
    return map;
  }

  LocalAssignmentsCompanion toCompanion(bool nullToAbsent) {
    return LocalAssignmentsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      assigneeUserId: Value(assigneeUserId),
      activityTypeCode: Value(activityTypeCode),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      frontId: frontId == null && nullToAbsent
          ? const Value.absent()
          : Value(frontId),
      frontRef: frontRef == null && nullToAbsent
          ? const Value.absent()
          : Value(frontRef),
      estado: estado == null && nullToAbsent
          ? const Value.absent()
          : Value(estado),
      municipio: municipio == null && nullToAbsent
          ? const Value.absent()
          : Value(municipio),
      colonia: colonia == null && nullToAbsent
          ? const Value.absent()
          : Value(colonia),
      pk: Value(pk),
      startAt: Value(startAt),
      endAt: Value(endAt),
      risk: Value(risk),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      syncStatus: Value(syncStatus),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      syncRetryCount: Value(syncRetryCount),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      backendActivityId: backendActivityId == null && nullToAbsent
          ? const Value.absent()
          : Value(backendActivityId),
    );
  }

  factory LocalAssignment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAssignment(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      assigneeUserId: serializer.fromJson<String>(json['assigneeUserId']),
      activityTypeCode: serializer.fromJson<String>(json['activityTypeCode']),
      title: serializer.fromJson<String?>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      frontId: serializer.fromJson<String?>(json['frontId']),
      frontRef: serializer.fromJson<String?>(json['frontRef']),
      estado: serializer.fromJson<String?>(json['estado']),
      municipio: serializer.fromJson<String?>(json['municipio']),
      colonia: serializer.fromJson<String?>(json['colonia']),
      pk: serializer.fromJson<int>(json['pk']),
      startAt: serializer.fromJson<DateTime>(json['startAt']),
      endAt: serializer.fromJson<DateTime>(json['endAt']),
      risk: serializer.fromJson<String>(json['risk']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      syncRetryCount: serializer.fromJson<int>(json['syncRetryCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      backendActivityId: serializer.fromJson<String?>(
        json['backendActivityId'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'assigneeUserId': serializer.toJson<String>(assigneeUserId),
      'activityTypeCode': serializer.toJson<String>(activityTypeCode),
      'title': serializer.toJson<String?>(title),
      'description': serializer.toJson<String?>(description),
      'frontId': serializer.toJson<String?>(frontId),
      'frontRef': serializer.toJson<String?>(frontRef),
      'estado': serializer.toJson<String?>(estado),
      'municipio': serializer.toJson<String?>(municipio),
      'colonia': serializer.toJson<String?>(colonia),
      'pk': serializer.toJson<int>(pk),
      'startAt': serializer.toJson<DateTime>(startAt),
      'endAt': serializer.toJson<DateTime>(endAt),
      'risk': serializer.toJson<String>(risk),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'syncError': serializer.toJson<String?>(syncError),
      'syncRetryCount': serializer.toJson<int>(syncRetryCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'backendActivityId': serializer.toJson<String?>(backendActivityId),
    };
  }

  LocalAssignment copyWith({
    String? id,
    String? projectId,
    String? assigneeUserId,
    String? activityTypeCode,
    Value<String?> title = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> frontId = const Value.absent(),
    Value<String?> frontRef = const Value.absent(),
    Value<String?> estado = const Value.absent(),
    Value<String?> municipio = const Value.absent(),
    Value<String?> colonia = const Value.absent(),
    int? pk,
    DateTime? startAt,
    DateTime? endAt,
    String? risk,
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    String? syncStatus,
    Value<String?> syncError = const Value.absent(),
    int? syncRetryCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> syncedAt = const Value.absent(),
    Value<String?> backendActivityId = const Value.absent(),
  }) => LocalAssignment(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    assigneeUserId: assigneeUserId ?? this.assigneeUserId,
    activityTypeCode: activityTypeCode ?? this.activityTypeCode,
    title: title.present ? title.value : this.title,
    description: description.present ? description.value : this.description,
    frontId: frontId.present ? frontId.value : this.frontId,
    frontRef: frontRef.present ? frontRef.value : this.frontRef,
    estado: estado.present ? estado.value : this.estado,
    municipio: municipio.present ? municipio.value : this.municipio,
    colonia: colonia.present ? colonia.value : this.colonia,
    pk: pk ?? this.pk,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
    risk: risk ?? this.risk,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    syncStatus: syncStatus ?? this.syncStatus,
    syncError: syncError.present ? syncError.value : this.syncError,
    syncRetryCount: syncRetryCount ?? this.syncRetryCount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    backendActivityId: backendActivityId.present
        ? backendActivityId.value
        : this.backendActivityId,
  );
  LocalAssignment copyWithCompanion(LocalAssignmentsCompanion data) {
    return LocalAssignment(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      assigneeUserId: data.assigneeUserId.present
          ? data.assigneeUserId.value
          : this.assigneeUserId,
      activityTypeCode: data.activityTypeCode.present
          ? data.activityTypeCode.value
          : this.activityTypeCode,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      frontId: data.frontId.present ? data.frontId.value : this.frontId,
      frontRef: data.frontRef.present ? data.frontRef.value : this.frontRef,
      estado: data.estado.present ? data.estado.value : this.estado,
      municipio: data.municipio.present ? data.municipio.value : this.municipio,
      colonia: data.colonia.present ? data.colonia.value : this.colonia,
      pk: data.pk.present ? data.pk.value : this.pk,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      risk: data.risk.present ? data.risk.value : this.risk,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      syncRetryCount: data.syncRetryCount.present
          ? data.syncRetryCount.value
          : this.syncRetryCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      backendActivityId: data.backendActivityId.present
          ? data.backendActivityId.value
          : this.backendActivityId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAssignment(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('assigneeUserId: $assigneeUserId, ')
          ..write('activityTypeCode: $activityTypeCode, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('frontId: $frontId, ')
          ..write('frontRef: $frontRef, ')
          ..write('estado: $estado, ')
          ..write('municipio: $municipio, ')
          ..write('colonia: $colonia, ')
          ..write('pk: $pk, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('risk: $risk, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError, ')
          ..write('syncRetryCount: $syncRetryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('backendActivityId: $backendActivityId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    projectId,
    assigneeUserId,
    activityTypeCode,
    title,
    description,
    frontId,
    frontRef,
    estado,
    municipio,
    colonia,
    pk,
    startAt,
    endAt,
    risk,
    latitude,
    longitude,
    syncStatus,
    syncError,
    syncRetryCount,
    createdAt,
    updatedAt,
    syncedAt,
    backendActivityId,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAssignment &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.assigneeUserId == this.assigneeUserId &&
          other.activityTypeCode == this.activityTypeCode &&
          other.title == this.title &&
          other.description == this.description &&
          other.frontId == this.frontId &&
          other.frontRef == this.frontRef &&
          other.estado == this.estado &&
          other.municipio == this.municipio &&
          other.colonia == this.colonia &&
          other.pk == this.pk &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt &&
          other.risk == this.risk &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.syncStatus == this.syncStatus &&
          other.syncError == this.syncError &&
          other.syncRetryCount == this.syncRetryCount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncedAt == this.syncedAt &&
          other.backendActivityId == this.backendActivityId);
}

class LocalAssignmentsCompanion extends UpdateCompanion<LocalAssignment> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> assigneeUserId;
  final Value<String> activityTypeCode;
  final Value<String?> title;
  final Value<String?> description;
  final Value<String?> frontId;
  final Value<String?> frontRef;
  final Value<String?> estado;
  final Value<String?> municipio;
  final Value<String?> colonia;
  final Value<int> pk;
  final Value<DateTime> startAt;
  final Value<DateTime> endAt;
  final Value<String> risk;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<String> syncStatus;
  final Value<String?> syncError;
  final Value<int> syncRetryCount;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> syncedAt;
  final Value<String?> backendActivityId;
  final Value<int> rowid;
  const LocalAssignmentsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.assigneeUserId = const Value.absent(),
    this.activityTypeCode = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.frontId = const Value.absent(),
    this.frontRef = const Value.absent(),
    this.estado = const Value.absent(),
    this.municipio = const Value.absent(),
    this.colonia = const Value.absent(),
    this.pk = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.risk = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncRetryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.backendActivityId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAssignmentsCompanion.insert({
    required String id,
    required String projectId,
    required String assigneeUserId,
    required String activityTypeCode,
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.frontId = const Value.absent(),
    this.frontRef = const Value.absent(),
    this.estado = const Value.absent(),
    this.municipio = const Value.absent(),
    this.colonia = const Value.absent(),
    this.pk = const Value.absent(),
    required DateTime startAt,
    required DateTime endAt,
    this.risk = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncRetryCount = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.syncedAt = const Value.absent(),
    this.backendActivityId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       assigneeUserId = Value(assigneeUserId),
       activityTypeCode = Value(activityTypeCode),
       startAt = Value(startAt),
       endAt = Value(endAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalAssignment> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? assigneeUserId,
    Expression<String>? activityTypeCode,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? frontId,
    Expression<String>? frontRef,
    Expression<String>? estado,
    Expression<String>? municipio,
    Expression<String>? colonia,
    Expression<int>? pk,
    Expression<DateTime>? startAt,
    Expression<DateTime>? endAt,
    Expression<String>? risk,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? syncStatus,
    Expression<String>? syncError,
    Expression<int>? syncRetryCount,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? syncedAt,
    Expression<String>? backendActivityId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (assigneeUserId != null) 'assignee_user_id': assigneeUserId,
      if (activityTypeCode != null) 'activity_type_code': activityTypeCode,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (frontId != null) 'front_id': frontId,
      if (frontRef != null) 'front_ref': frontRef,
      if (estado != null) 'estado': estado,
      if (municipio != null) 'municipio': municipio,
      if (colonia != null) 'colonia': colonia,
      if (pk != null) 'pk': pk,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (risk != null) 'risk': risk,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncError != null) 'sync_error': syncError,
      if (syncRetryCount != null) 'sync_retry_count': syncRetryCount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (backendActivityId != null) 'backend_activity_id': backendActivityId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAssignmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? assigneeUserId,
    Value<String>? activityTypeCode,
    Value<String?>? title,
    Value<String?>? description,
    Value<String?>? frontId,
    Value<String?>? frontRef,
    Value<String?>? estado,
    Value<String?>? municipio,
    Value<String?>? colonia,
    Value<int>? pk,
    Value<DateTime>? startAt,
    Value<DateTime>? endAt,
    Value<String>? risk,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<String>? syncStatus,
    Value<String?>? syncError,
    Value<int>? syncRetryCount,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? syncedAt,
    Value<String?>? backendActivityId,
    Value<int>? rowid,
  }) {
    return LocalAssignmentsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      assigneeUserId: assigneeUserId ?? this.assigneeUserId,
      activityTypeCode: activityTypeCode ?? this.activityTypeCode,
      title: title ?? this.title,
      description: description ?? this.description,
      frontId: frontId ?? this.frontId,
      frontRef: frontRef ?? this.frontRef,
      estado: estado ?? this.estado,
      municipio: municipio ?? this.municipio,
      colonia: colonia ?? this.colonia,
      pk: pk ?? this.pk,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      risk: risk ?? this.risk,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
      syncRetryCount: syncRetryCount ?? this.syncRetryCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      backendActivityId: backendActivityId ?? this.backendActivityId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (assigneeUserId.present) {
      map['assignee_user_id'] = Variable<String>(assigneeUserId.value);
    }
    if (activityTypeCode.present) {
      map['activity_type_code'] = Variable<String>(activityTypeCode.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (frontId.present) {
      map['front_id'] = Variable<String>(frontId.value);
    }
    if (frontRef.present) {
      map['front_ref'] = Variable<String>(frontRef.value);
    }
    if (estado.present) {
      map['estado'] = Variable<String>(estado.value);
    }
    if (municipio.present) {
      map['municipio'] = Variable<String>(municipio.value);
    }
    if (colonia.present) {
      map['colonia'] = Variable<String>(colonia.value);
    }
    if (pk.present) {
      map['pk'] = Variable<int>(pk.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<DateTime>(endAt.value);
    }
    if (risk.present) {
      map['risk'] = Variable<String>(risk.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (syncRetryCount.present) {
      map['sync_retry_count'] = Variable<int>(syncRetryCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (backendActivityId.present) {
      map['backend_activity_id'] = Variable<String>(backendActivityId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAssignmentsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('assigneeUserId: $assigneeUserId, ')
          ..write('activityTypeCode: $activityTypeCode, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('frontId: $frontId, ')
          ..write('frontRef: $frontRef, ')
          ..write('estado: $estado, ')
          ..write('municipio: $municipio, ')
          ..write('colonia: $colonia, ')
          ..write('pk: $pk, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('risk: $risk, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError, ')
          ..write('syncRetryCount: $syncRetryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('backendActivityId: $backendActivityId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EvidencesTable extends Evidences
    with TableInfo<$EvidencesTable, Evidence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EvidencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES activities (id)',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 10,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathLocalMeta = const VerificationMeta(
    'filePathLocal',
  );
  @override
  late final GeneratedColumn<String> filePathLocal = GeneratedColumn<String>(
    'file_path_local',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileHashMeta = const VerificationMeta(
    'fileHash',
  );
  @override
  late final GeneratedColumn<String> fileHash = GeneratedColumn<String>(
    'file_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _takenAtMeta = const VerificationMeta(
    'takenAt',
  );
  @override
  late final GeneratedColumn<DateTime> takenAt = GeneratedColumn<DateTime>(
    'taken_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _geoLatMeta = const VerificationMeta('geoLat');
  @override
  late final GeneratedColumn<double> geoLat = GeneratedColumn<double>(
    'geo_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _geoLonMeta = const VerificationMeta('geoLon');
  @override
  late final GeneratedColumn<double> geoLon = GeneratedColumn<double>(
    'geo_lon',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _captionMeta = const VerificationMeta(
    'caption',
  );
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
    'caption',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    defaultValue: const Constant('LOCAL_ONLY'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    activityId,
    type,
    filePathLocal,
    fileHash,
    takenAt,
    geoLat,
    geoLon,
    caption,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'evidences';
  @override
  VerificationContext validateIntegrity(
    Insertable<Evidence> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('file_path_local')) {
      context.handle(
        _filePathLocalMeta,
        filePathLocal.isAcceptableOrUnknown(
          data['file_path_local']!,
          _filePathLocalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_filePathLocalMeta);
    }
    if (data.containsKey('file_hash')) {
      context.handle(
        _fileHashMeta,
        fileHash.isAcceptableOrUnknown(data['file_hash']!, _fileHashMeta),
      );
    }
    if (data.containsKey('taken_at')) {
      context.handle(
        _takenAtMeta,
        takenAt.isAcceptableOrUnknown(data['taken_at']!, _takenAtMeta),
      );
    }
    if (data.containsKey('geo_lat')) {
      context.handle(
        _geoLatMeta,
        geoLat.isAcceptableOrUnknown(data['geo_lat']!, _geoLatMeta),
      );
    }
    if (data.containsKey('geo_lon')) {
      context.handle(
        _geoLonMeta,
        geoLon.isAcceptableOrUnknown(data['geo_lon']!, _geoLonMeta),
      );
    }
    if (data.containsKey('caption')) {
      context.handle(
        _captionMeta,
        caption.isAcceptableOrUnknown(data['caption']!, _captionMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Evidence map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Evidence(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      filePathLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path_local'],
      )!,
      fileHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_hash'],
      ),
      takenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}taken_at'],
      ),
      geoLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}geo_lat'],
      ),
      geoLon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}geo_lon'],
      ),
      caption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caption'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $EvidencesTable createAlias(String alias) {
    return $EvidencesTable(attachedDatabase, alias);
  }
}

class Evidence extends DataClass implements Insertable<Evidence> {
  final String id;
  final String activityId;
  final String type;
  final String filePathLocal;
  final String? fileHash;
  final DateTime? takenAt;
  final double? geoLat;
  final double? geoLon;
  final String? caption;
  final String status;
  const Evidence({
    required this.id,
    required this.activityId,
    required this.type,
    required this.filePathLocal,
    this.fileHash,
    this.takenAt,
    this.geoLat,
    this.geoLon,
    this.caption,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['activity_id'] = Variable<String>(activityId);
    map['type'] = Variable<String>(type);
    map['file_path_local'] = Variable<String>(filePathLocal);
    if (!nullToAbsent || fileHash != null) {
      map['file_hash'] = Variable<String>(fileHash);
    }
    if (!nullToAbsent || takenAt != null) {
      map['taken_at'] = Variable<DateTime>(takenAt);
    }
    if (!nullToAbsent || geoLat != null) {
      map['geo_lat'] = Variable<double>(geoLat);
    }
    if (!nullToAbsent || geoLon != null) {
      map['geo_lon'] = Variable<double>(geoLon);
    }
    if (!nullToAbsent || caption != null) {
      map['caption'] = Variable<String>(caption);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  EvidencesCompanion toCompanion(bool nullToAbsent) {
    return EvidencesCompanion(
      id: Value(id),
      activityId: Value(activityId),
      type: Value(type),
      filePathLocal: Value(filePathLocal),
      fileHash: fileHash == null && nullToAbsent
          ? const Value.absent()
          : Value(fileHash),
      takenAt: takenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(takenAt),
      geoLat: geoLat == null && nullToAbsent
          ? const Value.absent()
          : Value(geoLat),
      geoLon: geoLon == null && nullToAbsent
          ? const Value.absent()
          : Value(geoLon),
      caption: caption == null && nullToAbsent
          ? const Value.absent()
          : Value(caption),
      status: Value(status),
    );
  }

  factory Evidence.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Evidence(
      id: serializer.fromJson<String>(json['id']),
      activityId: serializer.fromJson<String>(json['activityId']),
      type: serializer.fromJson<String>(json['type']),
      filePathLocal: serializer.fromJson<String>(json['filePathLocal']),
      fileHash: serializer.fromJson<String?>(json['fileHash']),
      takenAt: serializer.fromJson<DateTime?>(json['takenAt']),
      geoLat: serializer.fromJson<double?>(json['geoLat']),
      geoLon: serializer.fromJson<double?>(json['geoLon']),
      caption: serializer.fromJson<String?>(json['caption']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'activityId': serializer.toJson<String>(activityId),
      'type': serializer.toJson<String>(type),
      'filePathLocal': serializer.toJson<String>(filePathLocal),
      'fileHash': serializer.toJson<String?>(fileHash),
      'takenAt': serializer.toJson<DateTime?>(takenAt),
      'geoLat': serializer.toJson<double?>(geoLat),
      'geoLon': serializer.toJson<double?>(geoLon),
      'caption': serializer.toJson<String?>(caption),
      'status': serializer.toJson<String>(status),
    };
  }

  Evidence copyWith({
    String? id,
    String? activityId,
    String? type,
    String? filePathLocal,
    Value<String?> fileHash = const Value.absent(),
    Value<DateTime?> takenAt = const Value.absent(),
    Value<double?> geoLat = const Value.absent(),
    Value<double?> geoLon = const Value.absent(),
    Value<String?> caption = const Value.absent(),
    String? status,
  }) => Evidence(
    id: id ?? this.id,
    activityId: activityId ?? this.activityId,
    type: type ?? this.type,
    filePathLocal: filePathLocal ?? this.filePathLocal,
    fileHash: fileHash.present ? fileHash.value : this.fileHash,
    takenAt: takenAt.present ? takenAt.value : this.takenAt,
    geoLat: geoLat.present ? geoLat.value : this.geoLat,
    geoLon: geoLon.present ? geoLon.value : this.geoLon,
    caption: caption.present ? caption.value : this.caption,
    status: status ?? this.status,
  );
  Evidence copyWithCompanion(EvidencesCompanion data) {
    return Evidence(
      id: data.id.present ? data.id.value : this.id,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      type: data.type.present ? data.type.value : this.type,
      filePathLocal: data.filePathLocal.present
          ? data.filePathLocal.value
          : this.filePathLocal,
      fileHash: data.fileHash.present ? data.fileHash.value : this.fileHash,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
      geoLat: data.geoLat.present ? data.geoLat.value : this.geoLat,
      geoLon: data.geoLon.present ? data.geoLon.value : this.geoLon,
      caption: data.caption.present ? data.caption.value : this.caption,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Evidence(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('type: $type, ')
          ..write('filePathLocal: $filePathLocal, ')
          ..write('fileHash: $fileHash, ')
          ..write('takenAt: $takenAt, ')
          ..write('geoLat: $geoLat, ')
          ..write('geoLon: $geoLon, ')
          ..write('caption: $caption, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    activityId,
    type,
    filePathLocal,
    fileHash,
    takenAt,
    geoLat,
    geoLon,
    caption,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Evidence &&
          other.id == this.id &&
          other.activityId == this.activityId &&
          other.type == this.type &&
          other.filePathLocal == this.filePathLocal &&
          other.fileHash == this.fileHash &&
          other.takenAt == this.takenAt &&
          other.geoLat == this.geoLat &&
          other.geoLon == this.geoLon &&
          other.caption == this.caption &&
          other.status == this.status);
}

class EvidencesCompanion extends UpdateCompanion<Evidence> {
  final Value<String> id;
  final Value<String> activityId;
  final Value<String> type;
  final Value<String> filePathLocal;
  final Value<String?> fileHash;
  final Value<DateTime?> takenAt;
  final Value<double?> geoLat;
  final Value<double?> geoLon;
  final Value<String?> caption;
  final Value<String> status;
  final Value<int> rowid;
  const EvidencesCompanion({
    this.id = const Value.absent(),
    this.activityId = const Value.absent(),
    this.type = const Value.absent(),
    this.filePathLocal = const Value.absent(),
    this.fileHash = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.geoLat = const Value.absent(),
    this.geoLon = const Value.absent(),
    this.caption = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EvidencesCompanion.insert({
    required String id,
    required String activityId,
    required String type,
    required String filePathLocal,
    this.fileHash = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.geoLat = const Value.absent(),
    this.geoLon = const Value.absent(),
    this.caption = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       activityId = Value(activityId),
       type = Value(type),
       filePathLocal = Value(filePathLocal);
  static Insertable<Evidence> custom({
    Expression<String>? id,
    Expression<String>? activityId,
    Expression<String>? type,
    Expression<String>? filePathLocal,
    Expression<String>? fileHash,
    Expression<DateTime>? takenAt,
    Expression<double>? geoLat,
    Expression<double>? geoLon,
    Expression<String>? caption,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activityId != null) 'activity_id': activityId,
      if (type != null) 'type': type,
      if (filePathLocal != null) 'file_path_local': filePathLocal,
      if (fileHash != null) 'file_hash': fileHash,
      if (takenAt != null) 'taken_at': takenAt,
      if (geoLat != null) 'geo_lat': geoLat,
      if (geoLon != null) 'geo_lon': geoLon,
      if (caption != null) 'caption': caption,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EvidencesCompanion copyWith({
    Value<String>? id,
    Value<String>? activityId,
    Value<String>? type,
    Value<String>? filePathLocal,
    Value<String?>? fileHash,
    Value<DateTime?>? takenAt,
    Value<double?>? geoLat,
    Value<double?>? geoLon,
    Value<String?>? caption,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return EvidencesCompanion(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      type: type ?? this.type,
      filePathLocal: filePathLocal ?? this.filePathLocal,
      fileHash: fileHash ?? this.fileHash,
      takenAt: takenAt ?? this.takenAt,
      geoLat: geoLat ?? this.geoLat,
      geoLon: geoLon ?? this.geoLon,
      caption: caption ?? this.caption,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (filePathLocal.present) {
      map['file_path_local'] = Variable<String>(filePathLocal.value);
    }
    if (fileHash.present) {
      map['file_hash'] = Variable<String>(fileHash.value);
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<DateTime>(takenAt.value);
    }
    if (geoLat.present) {
      map['geo_lat'] = Variable<double>(geoLat.value);
    }
    if (geoLon.present) {
      map['geo_lon'] = Variable<double>(geoLon.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EvidencesCompanion(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('type: $type, ')
          ..write('filePathLocal: $filePathLocal, ')
          ..write('fileHash: $fileHash, ')
          ..write('takenAt: $takenAt, ')
          ..write('geoLat: $geoLat, ')
          ..write('geoLon: $geoLon, ')
          ..write('caption: $caption, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingUploadsTable extends PendingUploads
    with TableInfo<$PendingUploadsTable, PendingUpload> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingUploadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _evidenceIdMeta = const VerificationMeta(
    'evidenceId',
  );
  @override
  late final GeneratedColumn<String> evidenceId = GeneratedColumn<String>(
    'evidence_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _objectPathMeta = const VerificationMeta(
    'objectPath',
  );
  @override
  late final GeneratedColumn<String> objectPath = GeneratedColumn<String>(
    'object_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _signedUrlMeta = const VerificationMeta(
    'signedUrl',
  );
  @override
  late final GeneratedColumn<String> signedUrl = GeneratedColumn<String>(
    'signed_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    defaultValue: const Constant('PENDING_INIT'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    activityId,
    localPath,
    fileName,
    mimeType,
    sizeBytes,
    evidenceId,
    objectPath,
    signedUrl,
    status,
    attempts,
    nextRetryAt,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_uploads';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingUpload> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('evidence_id')) {
      context.handle(
        _evidenceIdMeta,
        evidenceId.isAcceptableOrUnknown(data['evidence_id']!, _evidenceIdMeta),
      );
    }
    if (data.containsKey('object_path')) {
      context.handle(
        _objectPathMeta,
        objectPath.isAcceptableOrUnknown(data['object_path']!, _objectPathMeta),
      );
    }
    if (data.containsKey('signed_url')) {
      context.handle(
        _signedUrlMeta,
        signedUrl.isAcceptableOrUnknown(data['signed_url']!, _signedUrlMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingUpload map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingUpload(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      evidenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence_id'],
      ),
      objectPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}object_path'],
      ),
      signedUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signed_url'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_retry_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PendingUploadsTable createAlias(String alias) {
    return $PendingUploadsTable(attachedDatabase, alias);
  }
}

class PendingUpload extends DataClass implements Insertable<PendingUpload> {
  final String id;
  final String activityId;
  final String localPath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String? evidenceId;
  final String? objectPath;
  final String? signedUrl;
  final String status;
  final int attempts;
  final DateTime? nextRetryAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PendingUpload({
    required this.id,
    required this.activityId,
    required this.localPath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.evidenceId,
    this.objectPath,
    this.signedUrl,
    required this.status,
    required this.attempts,
    this.nextRetryAt,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['activity_id'] = Variable<String>(activityId);
    map['local_path'] = Variable<String>(localPath);
    map['file_name'] = Variable<String>(fileName);
    map['mime_type'] = Variable<String>(mimeType);
    map['size_bytes'] = Variable<int>(sizeBytes);
    if (!nullToAbsent || evidenceId != null) {
      map['evidence_id'] = Variable<String>(evidenceId);
    }
    if (!nullToAbsent || objectPath != null) {
      map['object_path'] = Variable<String>(objectPath);
    }
    if (!nullToAbsent || signedUrl != null) {
      map['signed_url'] = Variable<String>(signedUrl);
    }
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PendingUploadsCompanion toCompanion(bool nullToAbsent) {
    return PendingUploadsCompanion(
      id: Value(id),
      activityId: Value(activityId),
      localPath: Value(localPath),
      fileName: Value(fileName),
      mimeType: Value(mimeType),
      sizeBytes: Value(sizeBytes),
      evidenceId: evidenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(evidenceId),
      objectPath: objectPath == null && nullToAbsent
          ? const Value.absent()
          : Value(objectPath),
      signedUrl: signedUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(signedUrl),
      status: Value(status),
      attempts: Value(attempts),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PendingUpload.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingUpload(
      id: serializer.fromJson<String>(json['id']),
      activityId: serializer.fromJson<String>(json['activityId']),
      localPath: serializer.fromJson<String>(json['localPath']),
      fileName: serializer.fromJson<String>(json['fileName']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      evidenceId: serializer.fromJson<String?>(json['evidenceId']),
      objectPath: serializer.fromJson<String?>(json['objectPath']),
      signedUrl: serializer.fromJson<String?>(json['signedUrl']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'activityId': serializer.toJson<String>(activityId),
      'localPath': serializer.toJson<String>(localPath),
      'fileName': serializer.toJson<String>(fileName),
      'mimeType': serializer.toJson<String>(mimeType),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'evidenceId': serializer.toJson<String?>(evidenceId),
      'objectPath': serializer.toJson<String?>(objectPath),
      'signedUrl': serializer.toJson<String?>(signedUrl),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PendingUpload copyWith({
    String? id,
    String? activityId,
    String? localPath,
    String? fileName,
    String? mimeType,
    int? sizeBytes,
    Value<String?> evidenceId = const Value.absent(),
    Value<String?> objectPath = const Value.absent(),
    Value<String?> signedUrl = const Value.absent(),
    String? status,
    int? attempts,
    Value<DateTime?> nextRetryAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PendingUpload(
    id: id ?? this.id,
    activityId: activityId ?? this.activityId,
    localPath: localPath ?? this.localPath,
    fileName: fileName ?? this.fileName,
    mimeType: mimeType ?? this.mimeType,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    evidenceId: evidenceId.present ? evidenceId.value : this.evidenceId,
    objectPath: objectPath.present ? objectPath.value : this.objectPath,
    signedUrl: signedUrl.present ? signedUrl.value : this.signedUrl,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PendingUpload copyWithCompanion(PendingUploadsCompanion data) {
    return PendingUpload(
      id: data.id.present ? data.id.value : this.id,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      evidenceId: data.evidenceId.present
          ? data.evidenceId.value
          : this.evidenceId,
      objectPath: data.objectPath.present
          ? data.objectPath.value
          : this.objectPath,
      signedUrl: data.signedUrl.present ? data.signedUrl.value : this.signedUrl,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingUpload(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('localPath: $localPath, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('evidenceId: $evidenceId, ')
          ..write('objectPath: $objectPath, ')
          ..write('signedUrl: $signedUrl, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    activityId,
    localPath,
    fileName,
    mimeType,
    sizeBytes,
    evidenceId,
    objectPath,
    signedUrl,
    status,
    attempts,
    nextRetryAt,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingUpload &&
          other.id == this.id &&
          other.activityId == this.activityId &&
          other.localPath == this.localPath &&
          other.fileName == this.fileName &&
          other.mimeType == this.mimeType &&
          other.sizeBytes == this.sizeBytes &&
          other.evidenceId == this.evidenceId &&
          other.objectPath == this.objectPath &&
          other.signedUrl == this.signedUrl &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.nextRetryAt == this.nextRetryAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PendingUploadsCompanion extends UpdateCompanion<PendingUpload> {
  final Value<String> id;
  final Value<String> activityId;
  final Value<String> localPath;
  final Value<String> fileName;
  final Value<String> mimeType;
  final Value<int> sizeBytes;
  final Value<String?> evidenceId;
  final Value<String?> objectPath;
  final Value<String?> signedUrl;
  final Value<String> status;
  final Value<int> attempts;
  final Value<DateTime?> nextRetryAt;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PendingUploadsCompanion({
    this.id = const Value.absent(),
    this.activityId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.fileName = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.evidenceId = const Value.absent(),
    this.objectPath = const Value.absent(),
    this.signedUrl = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingUploadsCompanion.insert({
    required String id,
    required String activityId,
    required String localPath,
    required String fileName,
    required String mimeType,
    required int sizeBytes,
    this.evidenceId = const Value.absent(),
    this.objectPath = const Value.absent(),
    this.signedUrl = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       activityId = Value(activityId),
       localPath = Value(localPath),
       fileName = Value(fileName),
       mimeType = Value(mimeType),
       sizeBytes = Value(sizeBytes);
  static Insertable<PendingUpload> custom({
    Expression<String>? id,
    Expression<String>? activityId,
    Expression<String>? localPath,
    Expression<String>? fileName,
    Expression<String>? mimeType,
    Expression<int>? sizeBytes,
    Expression<String>? evidenceId,
    Expression<String>? objectPath,
    Expression<String>? signedUrl,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<DateTime>? nextRetryAt,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activityId != null) 'activity_id': activityId,
      if (localPath != null) 'local_path': localPath,
      if (fileName != null) 'file_name': fileName,
      if (mimeType != null) 'mime_type': mimeType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (evidenceId != null) 'evidence_id': evidenceId,
      if (objectPath != null) 'object_path': objectPath,
      if (signedUrl != null) 'signed_url': signedUrl,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingUploadsCompanion copyWith({
    Value<String>? id,
    Value<String>? activityId,
    Value<String>? localPath,
    Value<String>? fileName,
    Value<String>? mimeType,
    Value<int>? sizeBytes,
    Value<String?>? evidenceId,
    Value<String?>? objectPath,
    Value<String?>? signedUrl,
    Value<String>? status,
    Value<int>? attempts,
    Value<DateTime?>? nextRetryAt,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PendingUploadsCompanion(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      localPath: localPath ?? this.localPath,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      evidenceId: evidenceId ?? this.evidenceId,
      objectPath: objectPath ?? this.objectPath,
      signedUrl: signedUrl ?? this.signedUrl,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (evidenceId.present) {
      map['evidence_id'] = Variable<String>(evidenceId.value);
    }
    if (objectPath.present) {
      map['object_path'] = Variable<String>(objectPath.value);
    }
    if (signedUrl.present) {
      map['signed_url'] = Variable<String>(signedUrl.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingUploadsCompanion(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('localPath: $localPath, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('evidenceId: $evidenceId, ')
          ..write('objectPath: $objectPath, ')
          ..write('signedUrl: $signedUrl, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 20,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 10,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(50),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retryableMeta = const VerificationMeta(
    'retryable',
  );
  @override
  late final GeneratedColumn<bool> retryable = GeneratedColumn<bool>(
    'retryable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("retryable" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _suggestedActionMeta = const VerificationMeta(
    'suggestedAction',
  );
  @override
  late final GeneratedColumn<String> suggestedAction = GeneratedColumn<String>(
    'suggested_action',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    defaultValue: const Constant('PENDING'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entity,
    entityId,
    action,
    payloadJson,
    priority,
    attempts,
    lastAttemptAt,
    errorCode,
    retryable,
    suggestedAction,
    lastError,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('retryable')) {
      context.handle(
        _retryableMeta,
        retryable.isAcceptableOrUnknown(data['retryable']!, _retryableMeta),
      );
    }
    if (data.containsKey('suggested_action')) {
      context.handle(
        _suggestedActionMeta,
        suggestedAction.isAcceptableOrUnknown(
          data['suggested_action']!,
          _suggestedActionMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      retryable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}retryable'],
      )!,
      suggestedAction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_action'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueData extends DataClass implements Insertable<SyncQueueData> {
  final String id;
  final String entity;
  final String entityId;
  final String action;
  final String payloadJson;
  final int priority;
  final int attempts;
  final DateTime? lastAttemptAt;
  final String? errorCode;
  final bool retryable;
  final String? suggestedAction;
  final String? lastError;
  final String status;
  const SyncQueueData({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.action,
    required this.payloadJson,
    required this.priority,
    required this.attempts,
    this.lastAttemptAt,
    this.errorCode,
    required this.retryable,
    this.suggestedAction,
    this.lastError,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<String>(entityId);
    map['action'] = Variable<String>(action);
    map['payload_json'] = Variable<String>(payloadJson);
    map['priority'] = Variable<int>(priority);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    map['retryable'] = Variable<bool>(retryable);
    if (!nullToAbsent || suggestedAction != null) {
      map['suggested_action'] = Variable<String>(suggestedAction);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      entity: Value(entity),
      entityId: Value(entityId),
      action: Value(action),
      payloadJson: Value(payloadJson),
      priority: Value(priority),
      attempts: Value(attempts),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      retryable: Value(retryable),
      suggestedAction: suggestedAction == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedAction),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      status: Value(status),
    );
  }

  factory SyncQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueData(
      id: serializer.fromJson<String>(json['id']),
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<String>(json['entityId']),
      action: serializer.fromJson<String>(json['action']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      priority: serializer.fromJson<int>(json['priority']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      retryable: serializer.fromJson<bool>(json['retryable']),
      suggestedAction: serializer.fromJson<String?>(json['suggestedAction']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entity': serializer.toJson<String>(entity),
      'entityId': serializer.toJson<String>(entityId),
      'action': serializer.toJson<String>(action),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'priority': serializer.toJson<int>(priority),
      'attempts': serializer.toJson<int>(attempts),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'errorCode': serializer.toJson<String?>(errorCode),
      'retryable': serializer.toJson<bool>(retryable),
      'suggestedAction': serializer.toJson<String?>(suggestedAction),
      'lastError': serializer.toJson<String?>(lastError),
      'status': serializer.toJson<String>(status),
    };
  }

  SyncQueueData copyWith({
    String? id,
    String? entity,
    String? entityId,
    String? action,
    String? payloadJson,
    int? priority,
    int? attempts,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<String?> errorCode = const Value.absent(),
    bool? retryable,
    Value<String?> suggestedAction = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    String? status,
  }) => SyncQueueData(
    id: id ?? this.id,
    entity: entity ?? this.entity,
    entityId: entityId ?? this.entityId,
    action: action ?? this.action,
    payloadJson: payloadJson ?? this.payloadJson,
    priority: priority ?? this.priority,
    attempts: attempts ?? this.attempts,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    retryable: retryable ?? this.retryable,
    suggestedAction: suggestedAction.present
        ? suggestedAction.value
        : this.suggestedAction,
    lastError: lastError.present ? lastError.value : this.lastError,
    status: status ?? this.status,
  );
  SyncQueueData copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      action: data.action.present ? data.action.value : this.action,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      priority: data.priority.present ? data.priority.value : this.priority,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      retryable: data.retryable.present ? data.retryable.value : this.retryable,
      suggestedAction: data.suggestedAction.present
          ? data.suggestedAction.value
          : this.suggestedAction,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueData(')
          ..write('id: $id, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('action: $action, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('priority: $priority, ')
          ..write('attempts: $attempts, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('errorCode: $errorCode, ')
          ..write('retryable: $retryable, ')
          ..write('suggestedAction: $suggestedAction, ')
          ..write('lastError: $lastError, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entity,
    entityId,
    action,
    payloadJson,
    priority,
    attempts,
    lastAttemptAt,
    errorCode,
    retryable,
    suggestedAction,
    lastError,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.id == this.id &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.action == this.action &&
          other.payloadJson == this.payloadJson &&
          other.priority == this.priority &&
          other.attempts == this.attempts &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.errorCode == this.errorCode &&
          other.retryable == this.retryable &&
          other.suggestedAction == this.suggestedAction &&
          other.lastError == this.lastError &&
          other.status == this.status);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<String> id;
  final Value<String> entity;
  final Value<String> entityId;
  final Value<String> action;
  final Value<String> payloadJson;
  final Value<int> priority;
  final Value<int> attempts;
  final Value<DateTime?> lastAttemptAt;
  final Value<String?> errorCode;
  final Value<bool> retryable;
  final Value<String?> suggestedAction;
  final Value<String?> lastError;
  final Value<String> status;
  final Value<int> rowid;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.action = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.priority = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.retryable = const Value.absent(),
    this.suggestedAction = const Value.absent(),
    this.lastError = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    required String id,
    required String entity,
    required String entityId,
    required String action,
    required String payloadJson,
    this.priority = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.retryable = const Value.absent(),
    this.suggestedAction = const Value.absent(),
    this.lastError = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entity = Value(entity),
       entityId = Value(entityId),
       action = Value(action),
       payloadJson = Value(payloadJson);
  static Insertable<SyncQueueData> custom({
    Expression<String>? id,
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<String>? action,
    Expression<String>? payloadJson,
    Expression<int>? priority,
    Expression<int>? attempts,
    Expression<DateTime>? lastAttemptAt,
    Expression<String>? errorCode,
    Expression<bool>? retryable,
    Expression<String>? suggestedAction,
    Expression<String>? lastError,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (action != null) 'action': action,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (priority != null) 'priority': priority,
      if (attempts != null) 'attempts': attempts,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (errorCode != null) 'error_code': errorCode,
      if (retryable != null) 'retryable': retryable,
      if (suggestedAction != null) 'suggested_action': suggestedAction,
      if (lastError != null) 'last_error': lastError,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncQueueCompanion copyWith({
    Value<String>? id,
    Value<String>? entity,
    Value<String>? entityId,
    Value<String>? action,
    Value<String>? payloadJson,
    Value<int>? priority,
    Value<int>? attempts,
    Value<DateTime?>? lastAttemptAt,
    Value<String?>? errorCode,
    Value<bool>? retryable,
    Value<String?>? suggestedAction,
    Value<String?>? lastError,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      action: action ?? this.action,
      payloadJson: payloadJson ?? this.payloadJson,
      priority: priority ?? this.priority,
      attempts: attempts ?? this.attempts,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      errorCode: errorCode ?? this.errorCode,
      retryable: retryable ?? this.retryable,
      suggestedAction: suggestedAction ?? this.suggestedAction,
      lastError: lastError ?? this.lastError,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (retryable.present) {
      map['retryable'] = Variable<bool>(retryable.value);
    }
    if (suggestedAction.present) {
      map['suggested_action'] = Variable<String>(suggestedAction.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('action: $action, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('priority: $priority, ')
          ..write('attempts: $attempts, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('errorCode: $errorCode, ')
          ..write('retryable: $retryable, ')
          ..write('suggestedAction: $suggestedAction, ')
          ..write('lastError: $lastError, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
    'last_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastServerCursorMeta = const VerificationMeta(
    'lastServerCursor',
  );
  @override
  late final GeneratedColumn<String> lastServerCursor = GeneratedColumn<String>(
    'last_server_cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastCatalogVersionByProjectJsonMeta =
      const VerificationMeta('lastCatalogVersionByProjectJson');
  @override
  late final GeneratedColumn<String> lastCatalogVersionByProjectJson =
      GeneratedColumn<String>(
        'last_catalog_version_by_project_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lastSyncAt,
    lastServerCursor,
    lastCatalogVersionByProjectJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    }
    if (data.containsKey('last_server_cursor')) {
      context.handle(
        _lastServerCursorMeta,
        lastServerCursor.isAcceptableOrUnknown(
          data['last_server_cursor']!,
          _lastServerCursorMeta,
        ),
      );
    }
    if (data.containsKey('last_catalog_version_by_project_json')) {
      context.handle(
        _lastCatalogVersionByProjectJsonMeta,
        lastCatalogVersionByProjectJson.isAcceptableOrUnknown(
          data['last_catalog_version_by_project_json']!,
          _lastCatalogVersionByProjectJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_sync_at'],
      ),
      lastServerCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_server_cursor'],
      ),
      lastCatalogVersionByProjectJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_catalog_version_by_project_json'],
      )!,
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final int id;
  final DateTime? lastSyncAt;
  final String? lastServerCursor;
  final String lastCatalogVersionByProjectJson;
  const SyncStateData({
    required this.id,
    this.lastSyncAt,
    this.lastServerCursor,
    required this.lastCatalogVersionByProjectJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt);
    }
    if (!nullToAbsent || lastServerCursor != null) {
      map['last_server_cursor'] = Variable<String>(lastServerCursor);
    }
    map['last_catalog_version_by_project_json'] = Variable<String>(
      lastCatalogVersionByProjectJson,
    );
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      id: Value(id),
      lastSyncAt: lastSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAt),
      lastServerCursor: lastServerCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(lastServerCursor),
      lastCatalogVersionByProjectJson: Value(lastCatalogVersionByProjectJson),
    );
  }

  factory SyncStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      id: serializer.fromJson<int>(json['id']),
      lastSyncAt: serializer.fromJson<DateTime?>(json['lastSyncAt']),
      lastServerCursor: serializer.fromJson<String?>(json['lastServerCursor']),
      lastCatalogVersionByProjectJson: serializer.fromJson<String>(
        json['lastCatalogVersionByProjectJson'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lastSyncAt': serializer.toJson<DateTime?>(lastSyncAt),
      'lastServerCursor': serializer.toJson<String?>(lastServerCursor),
      'lastCatalogVersionByProjectJson': serializer.toJson<String>(
        lastCatalogVersionByProjectJson,
      ),
    };
  }

  SyncStateData copyWith({
    int? id,
    Value<DateTime?> lastSyncAt = const Value.absent(),
    Value<String?> lastServerCursor = const Value.absent(),
    String? lastCatalogVersionByProjectJson,
  }) => SyncStateData(
    id: id ?? this.id,
    lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
    lastServerCursor: lastServerCursor.present
        ? lastServerCursor.value
        : this.lastServerCursor,
    lastCatalogVersionByProjectJson:
        lastCatalogVersionByProjectJson ?? this.lastCatalogVersionByProjectJson,
  );
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      id: data.id.present ? data.id.value : this.id,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
      lastServerCursor: data.lastServerCursor.present
          ? data.lastServerCursor.value
          : this.lastServerCursor,
      lastCatalogVersionByProjectJson:
          data.lastCatalogVersionByProjectJson.present
          ? data.lastCatalogVersionByProjectJson.value
          : this.lastCatalogVersionByProjectJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('id: $id, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastServerCursor: $lastServerCursor, ')
          ..write(
            'lastCatalogVersionByProjectJson: $lastCatalogVersionByProjectJson',
          )
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lastSyncAt,
    lastServerCursor,
    lastCatalogVersionByProjectJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.id == this.id &&
          other.lastSyncAt == this.lastSyncAt &&
          other.lastServerCursor == this.lastServerCursor &&
          other.lastCatalogVersionByProjectJson ==
              this.lastCatalogVersionByProjectJson);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<int> id;
  final Value<DateTime?> lastSyncAt;
  final Value<String?> lastServerCursor;
  final Value<String> lastCatalogVersionByProjectJson;
  const SyncStateCompanion({
    this.id = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastServerCursor = const Value.absent(),
    this.lastCatalogVersionByProjectJson = const Value.absent(),
  });
  SyncStateCompanion.insert({
    this.id = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastServerCursor = const Value.absent(),
    this.lastCatalogVersionByProjectJson = const Value.absent(),
  });
  static Insertable<SyncStateData> custom({
    Expression<int>? id,
    Expression<DateTime>? lastSyncAt,
    Expression<String>? lastServerCursor,
    Expression<String>? lastCatalogVersionByProjectJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (lastServerCursor != null) 'last_server_cursor': lastServerCursor,
      if (lastCatalogVersionByProjectJson != null)
        'last_catalog_version_by_project_json': lastCatalogVersionByProjectJson,
    });
  }

  SyncStateCompanion copyWith({
    Value<int>? id,
    Value<DateTime?>? lastSyncAt,
    Value<String?>? lastServerCursor,
    Value<String>? lastCatalogVersionByProjectJson,
  }) {
    return SyncStateCompanion(
      id: id ?? this.id,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastServerCursor: lastServerCursor ?? this.lastServerCursor,
      lastCatalogVersionByProjectJson:
          lastCatalogVersionByProjectJson ??
          this.lastCatalogVersionByProjectJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt.value);
    }
    if (lastServerCursor.present) {
      map['last_server_cursor'] = Variable<String>(lastServerCursor.value);
    }
    if (lastCatalogVersionByProjectJson.present) {
      map['last_catalog_version_by_project_json'] = Variable<String>(
        lastCatalogVersionByProjectJson.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('id: $id, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastServerCursor: $lastServerCursor, ')
          ..write(
            'lastCatalogVersionByProjectJson: $lastCatalogVersionByProjectJson',
          )
          ..write(')'))
        .toString();
  }
}

class $LocalEventsTable extends LocalEvents
    with TableInfo<$LocalEventsTable, LocalEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTypeCodeMeta = const VerificationMeta(
    'eventTypeCode',
  );
  @override
  late final GeneratedColumn<String> eventTypeCode = GeneratedColumn<String>(
    'event_type_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _severityMeta = const VerificationMeta(
    'severity',
  );
  @override
  late final GeneratedColumn<String> severity = GeneratedColumn<String>(
    'severity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('MEDIUM'),
  );
  static const VerificationMeta _locationPkMetersMeta = const VerificationMeta(
    'locationPkMeters',
  );
  @override
  late final GeneratedColumn<int> locationPkMeters = GeneratedColumn<int>(
    'location_pk_meters',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reportedByUserIdMeta = const VerificationMeta(
    'reportedByUserId',
  );
  @override
  late final GeneratedColumn<String> reportedByUserId = GeneratedColumn<String>(
    'reported_by_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formFieldsJsonMeta = const VerificationMeta(
    'formFieldsJson',
  );
  @override
  late final GeneratedColumn<String> formFieldsJson = GeneratedColumn<String>(
    'form_fields_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncVersionMeta = const VerificationMeta(
    'syncVersion',
  );
  @override
  late final GeneratedColumn<int> syncVersion = GeneratedColumn<int>(
    'sync_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('LOCAL_PENDING'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    eventTypeCode,
    title,
    description,
    severity,
    locationPkMeters,
    occurredAt,
    resolvedAt,
    deletedAt,
    reportedByUserId,
    formFieldsJson,
    syncVersion,
    serverId,
    syncStatus,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('event_type_code')) {
      context.handle(
        _eventTypeCodeMeta,
        eventTypeCode.isAcceptableOrUnknown(
          data['event_type_code']!,
          _eventTypeCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_eventTypeCodeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('severity')) {
      context.handle(
        _severityMeta,
        severity.isAcceptableOrUnknown(data['severity']!, _severityMeta),
      );
    }
    if (data.containsKey('location_pk_meters')) {
      context.handle(
        _locationPkMetersMeta,
        locationPkMeters.isAcceptableOrUnknown(
          data['location_pk_meters']!,
          _locationPkMetersMeta,
        ),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('reported_by_user_id')) {
      context.handle(
        _reportedByUserIdMeta,
        reportedByUserId.isAcceptableOrUnknown(
          data['reported_by_user_id']!,
          _reportedByUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reportedByUserIdMeta);
    }
    if (data.containsKey('form_fields_json')) {
      context.handle(
        _formFieldsJsonMeta,
        formFieldsJson.isAcceptableOrUnknown(
          data['form_fields_json']!,
          _formFieldsJsonMeta,
        ),
      );
    }
    if (data.containsKey('sync_version')) {
      context.handle(
        _syncVersionMeta,
        syncVersion.isAcceptableOrUnknown(
          data['sync_version']!,
          _syncVersionMeta,
        ),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      eventTypeCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type_code'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      severity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}severity'],
      )!,
      locationPkMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}location_pk_meters'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      reportedByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reported_by_user_id'],
      )!,
      formFieldsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}form_fields_json'],
      ),
      syncVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_version'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalEventsTable createAlias(String alias) {
    return $LocalEventsTable(attachedDatabase, alias);
  }
}

class LocalEvent extends DataClass implements Insertable<LocalEvent> {
  final String id;
  final String projectId;
  final String eventTypeCode;
  final String title;
  final String? description;
  final String severity;
  final int? locationPkMeters;
  final DateTime occurredAt;
  final DateTime? resolvedAt;
  final DateTime? deletedAt;
  final String reportedByUserId;
  final String? formFieldsJson;
  final int syncVersion;
  final int? serverId;
  final String syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LocalEvent({
    required this.id,
    required this.projectId,
    required this.eventTypeCode,
    required this.title,
    this.description,
    required this.severity,
    this.locationPkMeters,
    required this.occurredAt,
    this.resolvedAt,
    this.deletedAt,
    required this.reportedByUserId,
    this.formFieldsJson,
    required this.syncVersion,
    this.serverId,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['event_type_code'] = Variable<String>(eventTypeCode);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['severity'] = Variable<String>(severity);
    if (!nullToAbsent || locationPkMeters != null) {
      map['location_pk_meters'] = Variable<int>(locationPkMeters);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['reported_by_user_id'] = Variable<String>(reportedByUserId);
    if (!nullToAbsent || formFieldsJson != null) {
      map['form_fields_json'] = Variable<String>(formFieldsJson);
    }
    map['sync_version'] = Variable<int>(syncVersion);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalEventsCompanion toCompanion(bool nullToAbsent) {
    return LocalEventsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      eventTypeCode: Value(eventTypeCode),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      severity: Value(severity),
      locationPkMeters: locationPkMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(locationPkMeters),
      occurredAt: Value(occurredAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      reportedByUserId: Value(reportedByUserId),
      formFieldsJson: formFieldsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(formFieldsJson),
      syncVersion: Value(syncVersion),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalEvent(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      eventTypeCode: serializer.fromJson<String>(json['eventTypeCode']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      severity: serializer.fromJson<String>(json['severity']),
      locationPkMeters: serializer.fromJson<int?>(json['locationPkMeters']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      reportedByUserId: serializer.fromJson<String>(json['reportedByUserId']),
      formFieldsJson: serializer.fromJson<String?>(json['formFieldsJson']),
      syncVersion: serializer.fromJson<int>(json['syncVersion']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'eventTypeCode': serializer.toJson<String>(eventTypeCode),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'severity': serializer.toJson<String>(severity),
      'locationPkMeters': serializer.toJson<int?>(locationPkMeters),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'reportedByUserId': serializer.toJson<String>(reportedByUserId),
      'formFieldsJson': serializer.toJson<String?>(formFieldsJson),
      'syncVersion': serializer.toJson<int>(syncVersion),
      'serverId': serializer.toJson<int?>(serverId),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalEvent copyWith({
    String? id,
    String? projectId,
    String? eventTypeCode,
    String? title,
    Value<String?> description = const Value.absent(),
    String? severity,
    Value<int?> locationPkMeters = const Value.absent(),
    DateTime? occurredAt,
    Value<DateTime?> resolvedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    String? reportedByUserId,
    Value<String?> formFieldsJson = const Value.absent(),
    int? syncVersion,
    Value<int?> serverId = const Value.absent(),
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LocalEvent(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    eventTypeCode: eventTypeCode ?? this.eventTypeCode,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    severity: severity ?? this.severity,
    locationPkMeters: locationPkMeters.present
        ? locationPkMeters.value
        : this.locationPkMeters,
    occurredAt: occurredAt ?? this.occurredAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    reportedByUserId: reportedByUserId ?? this.reportedByUserId,
    formFieldsJson: formFieldsJson.present
        ? formFieldsJson.value
        : this.formFieldsJson,
    syncVersion: syncVersion ?? this.syncVersion,
    serverId: serverId.present ? serverId.value : this.serverId,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalEvent copyWithCompanion(LocalEventsCompanion data) {
    return LocalEvent(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      eventTypeCode: data.eventTypeCode.present
          ? data.eventTypeCode.value
          : this.eventTypeCode,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      severity: data.severity.present ? data.severity.value : this.severity,
      locationPkMeters: data.locationPkMeters.present
          ? data.locationPkMeters.value
          : this.locationPkMeters,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      reportedByUserId: data.reportedByUserId.present
          ? data.reportedByUserId.value
          : this.reportedByUserId,
      formFieldsJson: data.formFieldsJson.present
          ? data.formFieldsJson.value
          : this.formFieldsJson,
      syncVersion: data.syncVersion.present
          ? data.syncVersion.value
          : this.syncVersion,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalEvent(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('eventTypeCode: $eventTypeCode, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('severity: $severity, ')
          ..write('locationPkMeters: $locationPkMeters, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('reportedByUserId: $reportedByUserId, ')
          ..write('formFieldsJson: $formFieldsJson, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    eventTypeCode,
    title,
    description,
    severity,
    locationPkMeters,
    occurredAt,
    resolvedAt,
    deletedAt,
    reportedByUserId,
    formFieldsJson,
    syncVersion,
    serverId,
    syncStatus,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalEvent &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.eventTypeCode == this.eventTypeCode &&
          other.title == this.title &&
          other.description == this.description &&
          other.severity == this.severity &&
          other.locationPkMeters == this.locationPkMeters &&
          other.occurredAt == this.occurredAt &&
          other.resolvedAt == this.resolvedAt &&
          other.deletedAt == this.deletedAt &&
          other.reportedByUserId == this.reportedByUserId &&
          other.formFieldsJson == this.formFieldsJson &&
          other.syncVersion == this.syncVersion &&
          other.serverId == this.serverId &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalEventsCompanion extends UpdateCompanion<LocalEvent> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> eventTypeCode;
  final Value<String> title;
  final Value<String?> description;
  final Value<String> severity;
  final Value<int?> locationPkMeters;
  final Value<DateTime> occurredAt;
  final Value<DateTime?> resolvedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> reportedByUserId;
  final Value<String?> formFieldsJson;
  final Value<int> syncVersion;
  final Value<int?> serverId;
  final Value<String> syncStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalEventsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.eventTypeCode = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.severity = const Value.absent(),
    this.locationPkMeters = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.reportedByUserId = const Value.absent(),
    this.formFieldsJson = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalEventsCompanion.insert({
    required String id,
    required String projectId,
    required String eventTypeCode,
    required String title,
    this.description = const Value.absent(),
    this.severity = const Value.absent(),
    this.locationPkMeters = const Value.absent(),
    required DateTime occurredAt,
    this.resolvedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String reportedByUserId,
    this.formFieldsJson = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       eventTypeCode = Value(eventTypeCode),
       title = Value(title),
       occurredAt = Value(occurredAt),
       reportedByUserId = Value(reportedByUserId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalEvent> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? eventTypeCode,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? severity,
    Expression<int>? locationPkMeters,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? resolvedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? reportedByUserId,
    Expression<String>? formFieldsJson,
    Expression<int>? syncVersion,
    Expression<int>? serverId,
    Expression<String>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (eventTypeCode != null) 'event_type_code': eventTypeCode,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (severity != null) 'severity': severity,
      if (locationPkMeters != null) 'location_pk_meters': locationPkMeters,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (reportedByUserId != null) 'reported_by_user_id': reportedByUserId,
      if (formFieldsJson != null) 'form_fields_json': formFieldsJson,
      if (syncVersion != null) 'sync_version': syncVersion,
      if (serverId != null) 'server_id': serverId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? eventTypeCode,
    Value<String>? title,
    Value<String?>? description,
    Value<String>? severity,
    Value<int?>? locationPkMeters,
    Value<DateTime>? occurredAt,
    Value<DateTime?>? resolvedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? reportedByUserId,
    Value<String?>? formFieldsJson,
    Value<int>? syncVersion,
    Value<int?>? serverId,
    Value<String>? syncStatus,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalEventsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      eventTypeCode: eventTypeCode ?? this.eventTypeCode,
      title: title ?? this.title,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      locationPkMeters: locationPkMeters ?? this.locationPkMeters,
      occurredAt: occurredAt ?? this.occurredAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      reportedByUserId: reportedByUserId ?? this.reportedByUserId,
      formFieldsJson: formFieldsJson ?? this.formFieldsJson,
      syncVersion: syncVersion ?? this.syncVersion,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (eventTypeCode.present) {
      map['event_type_code'] = Variable<String>(eventTypeCode.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (severity.present) {
      map['severity'] = Variable<String>(severity.value);
    }
    if (locationPkMeters.present) {
      map['location_pk_meters'] = Variable<int>(locationPkMeters.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (reportedByUserId.present) {
      map['reported_by_user_id'] = Variable<String>(reportedByUserId.value);
    }
    if (formFieldsJson.present) {
      map['form_fields_json'] = Variable<String>(formFieldsJson.value);
    }
    if (syncVersion.present) {
      map['sync_version'] = Variable<int>(syncVersion.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEventsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('eventTypeCode: $eventTypeCode, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('severity: $severity, ')
          ..write('locationPkMeters: $locationPkMeters, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('reportedByUserId: $reportedByUserId, ')
          ..write('formFieldsJson: $formFieldsJson, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AgendaAssignmentsTable extends AgendaAssignments
    with TableInfo<$AgendaAssignmentsTable, AgendaAssignment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgendaAssignmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resourceIdMeta = const VerificationMeta(
    'resourceId',
  );
  @override
  late final GeneratedColumn<String> resourceId = GeneratedColumn<String>(
    'resource_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frenteMeta = const VerificationMeta('frente');
  @override
  late final GeneratedColumn<String> frente = GeneratedColumn<String>(
    'frente',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _municipioMeta = const VerificationMeta(
    'municipio',
  );
  @override
  late final GeneratedColumn<String> municipio = GeneratedColumn<String>(
    'municipio',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _estadoMeta = const VerificationMeta('estado');
  @override
  late final GeneratedColumn<String> estado = GeneratedColumn<String>(
    'estado',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pkMeta = const VerificationMeta('pk');
  @override
  late final GeneratedColumn<int> pk = GeneratedColumn<int>(
    'pk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startAtMeta = const VerificationMeta(
    'startAt',
  );
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
    'start_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<DateTime> endAt = GeneratedColumn<DateTime>(
    'end_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _riskMeta = const VerificationMeta('risk');
  @override
  late final GeneratedColumn<String> risk = GeneratedColumn<String>(
    'risk',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('bajo'),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    resourceId,
    activityId,
    title,
    frente,
    municipio,
    estado,
    pk,
    startAt,
    endAt,
    risk,
    syncStatus,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agenda_assignments';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgendaAssignment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('resource_id')) {
      context.handle(
        _resourceIdMeta,
        resourceId.isAcceptableOrUnknown(data['resource_id']!, _resourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_resourceIdMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('frente')) {
      context.handle(
        _frenteMeta,
        frente.isAcceptableOrUnknown(data['frente']!, _frenteMeta),
      );
    }
    if (data.containsKey('municipio')) {
      context.handle(
        _municipioMeta,
        municipio.isAcceptableOrUnknown(data['municipio']!, _municipioMeta),
      );
    }
    if (data.containsKey('estado')) {
      context.handle(
        _estadoMeta,
        estado.isAcceptableOrUnknown(data['estado']!, _estadoMeta),
      );
    }
    if (data.containsKey('pk')) {
      context.handle(_pkMeta, pk.isAcceptableOrUnknown(data['pk']!, _pkMeta));
    }
    if (data.containsKey('start_at')) {
      context.handle(
        _startAtMeta,
        startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startAtMeta);
    }
    if (data.containsKey('end_at')) {
      context.handle(
        _endAtMeta,
        endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endAtMeta);
    }
    if (data.containsKey('risk')) {
      context.handle(
        _riskMeta,
        risk.isAcceptableOrUnknown(data['risk']!, _riskMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AgendaAssignment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgendaAssignment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      resourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      frente: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frente'],
      )!,
      municipio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}municipio'],
      )!,
      estado: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estado'],
      )!,
      pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pk'],
      ),
      startAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_at'],
      )!,
      endAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_at'],
      )!,
      risk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}risk'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AgendaAssignmentsTable createAlias(String alias) {
    return $AgendaAssignmentsTable(attachedDatabase, alias);
  }
}

class AgendaAssignment extends DataClass
    implements Insertable<AgendaAssignment> {
  final String id;
  final String projectId;
  final String resourceId;
  final String? activityId;
  final String title;
  final String frente;
  final String municipio;
  final String estado;
  final int? pk;
  final DateTime startAt;
  final DateTime endAt;
  final String risk;
  final String syncStatus;
  final DateTime updatedAt;
  const AgendaAssignment({
    required this.id,
    required this.projectId,
    required this.resourceId,
    this.activityId,
    required this.title,
    required this.frente,
    required this.municipio,
    required this.estado,
    this.pk,
    required this.startAt,
    required this.endAt,
    required this.risk,
    required this.syncStatus,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['resource_id'] = Variable<String>(resourceId);
    if (!nullToAbsent || activityId != null) {
      map['activity_id'] = Variable<String>(activityId);
    }
    map['title'] = Variable<String>(title);
    map['frente'] = Variable<String>(frente);
    map['municipio'] = Variable<String>(municipio);
    map['estado'] = Variable<String>(estado);
    if (!nullToAbsent || pk != null) {
      map['pk'] = Variable<int>(pk);
    }
    map['start_at'] = Variable<DateTime>(startAt);
    map['end_at'] = Variable<DateTime>(endAt);
    map['risk'] = Variable<String>(risk);
    map['sync_status'] = Variable<String>(syncStatus);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AgendaAssignmentsCompanion toCompanion(bool nullToAbsent) {
    return AgendaAssignmentsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      resourceId: Value(resourceId),
      activityId: activityId == null && nullToAbsent
          ? const Value.absent()
          : Value(activityId),
      title: Value(title),
      frente: Value(frente),
      municipio: Value(municipio),
      estado: Value(estado),
      pk: pk == null && nullToAbsent ? const Value.absent() : Value(pk),
      startAt: Value(startAt),
      endAt: Value(endAt),
      risk: Value(risk),
      syncStatus: Value(syncStatus),
      updatedAt: Value(updatedAt),
    );
  }

  factory AgendaAssignment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgendaAssignment(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      resourceId: serializer.fromJson<String>(json['resourceId']),
      activityId: serializer.fromJson<String?>(json['activityId']),
      title: serializer.fromJson<String>(json['title']),
      frente: serializer.fromJson<String>(json['frente']),
      municipio: serializer.fromJson<String>(json['municipio']),
      estado: serializer.fromJson<String>(json['estado']),
      pk: serializer.fromJson<int?>(json['pk']),
      startAt: serializer.fromJson<DateTime>(json['startAt']),
      endAt: serializer.fromJson<DateTime>(json['endAt']),
      risk: serializer.fromJson<String>(json['risk']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'resourceId': serializer.toJson<String>(resourceId),
      'activityId': serializer.toJson<String?>(activityId),
      'title': serializer.toJson<String>(title),
      'frente': serializer.toJson<String>(frente),
      'municipio': serializer.toJson<String>(municipio),
      'estado': serializer.toJson<String>(estado),
      'pk': serializer.toJson<int?>(pk),
      'startAt': serializer.toJson<DateTime>(startAt),
      'endAt': serializer.toJson<DateTime>(endAt),
      'risk': serializer.toJson<String>(risk),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AgendaAssignment copyWith({
    String? id,
    String? projectId,
    String? resourceId,
    Value<String?> activityId = const Value.absent(),
    String? title,
    String? frente,
    String? municipio,
    String? estado,
    Value<int?> pk = const Value.absent(),
    DateTime? startAt,
    DateTime? endAt,
    String? risk,
    String? syncStatus,
    DateTime? updatedAt,
  }) => AgendaAssignment(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    resourceId: resourceId ?? this.resourceId,
    activityId: activityId.present ? activityId.value : this.activityId,
    title: title ?? this.title,
    frente: frente ?? this.frente,
    municipio: municipio ?? this.municipio,
    estado: estado ?? this.estado,
    pk: pk.present ? pk.value : this.pk,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
    risk: risk ?? this.risk,
    syncStatus: syncStatus ?? this.syncStatus,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AgendaAssignment copyWithCompanion(AgendaAssignmentsCompanion data) {
    return AgendaAssignment(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      resourceId: data.resourceId.present
          ? data.resourceId.value
          : this.resourceId,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      title: data.title.present ? data.title.value : this.title,
      frente: data.frente.present ? data.frente.value : this.frente,
      municipio: data.municipio.present ? data.municipio.value : this.municipio,
      estado: data.estado.present ? data.estado.value : this.estado,
      pk: data.pk.present ? data.pk.value : this.pk,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      risk: data.risk.present ? data.risk.value : this.risk,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgendaAssignment(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('resourceId: $resourceId, ')
          ..write('activityId: $activityId, ')
          ..write('title: $title, ')
          ..write('frente: $frente, ')
          ..write('municipio: $municipio, ')
          ..write('estado: $estado, ')
          ..write('pk: $pk, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('risk: $risk, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    resourceId,
    activityId,
    title,
    frente,
    municipio,
    estado,
    pk,
    startAt,
    endAt,
    risk,
    syncStatus,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgendaAssignment &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.resourceId == this.resourceId &&
          other.activityId == this.activityId &&
          other.title == this.title &&
          other.frente == this.frente &&
          other.municipio == this.municipio &&
          other.estado == this.estado &&
          other.pk == this.pk &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt &&
          other.risk == this.risk &&
          other.syncStatus == this.syncStatus &&
          other.updatedAt == this.updatedAt);
}

class AgendaAssignmentsCompanion extends UpdateCompanion<AgendaAssignment> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> resourceId;
  final Value<String?> activityId;
  final Value<String> title;
  final Value<String> frente;
  final Value<String> municipio;
  final Value<String> estado;
  final Value<int?> pk;
  final Value<DateTime> startAt;
  final Value<DateTime> endAt;
  final Value<String> risk;
  final Value<String> syncStatus;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AgendaAssignmentsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.resourceId = const Value.absent(),
    this.activityId = const Value.absent(),
    this.title = const Value.absent(),
    this.frente = const Value.absent(),
    this.municipio = const Value.absent(),
    this.estado = const Value.absent(),
    this.pk = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.risk = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgendaAssignmentsCompanion.insert({
    required String id,
    required String projectId,
    required String resourceId,
    this.activityId = const Value.absent(),
    required String title,
    this.frente = const Value.absent(),
    this.municipio = const Value.absent(),
    this.estado = const Value.absent(),
    this.pk = const Value.absent(),
    required DateTime startAt,
    required DateTime endAt,
    this.risk = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       resourceId = Value(resourceId),
       title = Value(title),
       startAt = Value(startAt),
       endAt = Value(endAt);
  static Insertable<AgendaAssignment> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? resourceId,
    Expression<String>? activityId,
    Expression<String>? title,
    Expression<String>? frente,
    Expression<String>? municipio,
    Expression<String>? estado,
    Expression<int>? pk,
    Expression<DateTime>? startAt,
    Expression<DateTime>? endAt,
    Expression<String>? risk,
    Expression<String>? syncStatus,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (resourceId != null) 'resource_id': resourceId,
      if (activityId != null) 'activity_id': activityId,
      if (title != null) 'title': title,
      if (frente != null) 'frente': frente,
      if (municipio != null) 'municipio': municipio,
      if (estado != null) 'estado': estado,
      if (pk != null) 'pk': pk,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (risk != null) 'risk': risk,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgendaAssignmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? resourceId,
    Value<String?>? activityId,
    Value<String>? title,
    Value<String>? frente,
    Value<String>? municipio,
    Value<String>? estado,
    Value<int?>? pk,
    Value<DateTime>? startAt,
    Value<DateTime>? endAt,
    Value<String>? risk,
    Value<String>? syncStatus,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AgendaAssignmentsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      resourceId: resourceId ?? this.resourceId,
      activityId: activityId ?? this.activityId,
      title: title ?? this.title,
      frente: frente ?? this.frente,
      municipio: municipio ?? this.municipio,
      estado: estado ?? this.estado,
      pk: pk ?? this.pk,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      risk: risk ?? this.risk,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (resourceId.present) {
      map['resource_id'] = Variable<String>(resourceId.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (frente.present) {
      map['frente'] = Variable<String>(frente.value);
    }
    if (municipio.present) {
      map['municipio'] = Variable<String>(municipio.value);
    }
    if (estado.present) {
      map['estado'] = Variable<String>(estado.value);
    }
    if (pk.present) {
      map['pk'] = Variable<int>(pk.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<DateTime>(endAt.value);
    }
    if (risk.present) {
      map['risk'] = Variable<String>(risk.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgendaAssignmentsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('resourceId: $resourceId, ')
          ..write('activityId: $activityId, ')
          ..write('title: $title, ')
          ..write('frente: $frente, ')
          ..write('municipio: $municipio, ')
          ..write('estado: $estado, ')
          ..write('pk: $pk, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('risk: $risk, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $RolesTable roles = $RolesTable(this);
  late final $UsersTable users = $UsersTable(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $ProjectSegmentsTable projectSegments = $ProjectSegmentsTable(
    this,
  );
  late final $CatalogVersionsTable catalogVersions = $CatalogVersionsTable(
    this,
  );
  late final $CatalogActivityTypesTable catalogActivityTypes =
      $CatalogActivityTypesTable(this);
  late final $CatalogFieldsTable catalogFields = $CatalogFieldsTable(this);
  late final $CatActivitiesTable catActivities = $CatActivitiesTable(this);
  late final $CatSubcategoriesTable catSubcategories = $CatSubcategoriesTable(
    this,
  );
  late final $CatPurposesTable catPurposes = $CatPurposesTable(this);
  late final $CatTopicsTable catTopics = $CatTopicsTable(this);
  late final $CatRelActivityTopicsTable catRelActivityTopics =
      $CatRelActivityTopicsTable(this);
  late final $CatResultsTable catResults = $CatResultsTable(this);
  late final $CatAttendeesTable catAttendees = $CatAttendeesTable(this);
  late final $CatalogIndexTable catalogIndex = $CatalogIndexTable(this);
  late final $CatalogBundleCacheTable catalogBundleCache =
      $CatalogBundleCacheTable(this);
  late final $ActivitiesTable activities = $ActivitiesTable(this);
  late final $ActivityFieldsTable activityFields = $ActivityFieldsTable(this);
  late final $ActivityLogTable activityLog = $ActivityLogTable(this);
  late final $LocalAssignmentsTable localAssignments = $LocalAssignmentsTable(
    this,
  );
  late final $EvidencesTable evidences = $EvidencesTable(this);
  late final $PendingUploadsTable pendingUploads = $PendingUploadsTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $LocalEventsTable localEvents = $LocalEventsTable(this);
  late final $AgendaAssignmentsTable agendaAssignments =
      $AgendaAssignmentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    roles,
    users,
    projects,
    projectSegments,
    catalogVersions,
    catalogActivityTypes,
    catalogFields,
    catActivities,
    catSubcategories,
    catPurposes,
    catTopics,
    catRelActivityTopics,
    catResults,
    catAttendees,
    catalogIndex,
    catalogBundleCache,
    activities,
    activityFields,
    activityLog,
    localAssignments,
    evidences,
    pendingUploads,
    syncQueue,
    syncState,
    localEvents,
    agendaAssignments,
  ];
}

typedef $$RolesTableCreateCompanionBuilder =
    RolesCompanion Function({
      Value<int> id,
      required String name,
      Value<String> permissionsJson,
    });
typedef $$RolesTableUpdateCompanionBuilder =
    RolesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> permissionsJson,
    });

final class $$RolesTableReferences
    extends BaseReferences<_$AppDb, $RolesTable, Role> {
  $$RolesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$UsersTable, List<User>> _usersRefsTable(
    _$AppDb db,
  ) => MultiTypedResultKey.fromTable(
    db.users,
    aliasName: $_aliasNameGenerator(db.roles.id, db.users.roleId),
  );

  $$UsersTableProcessedTableManager get usersRefs {
    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.roleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_usersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RolesTableFilterComposer extends Composer<_$AppDb, $RolesTable> {
  $$RolesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get permissionsJson => $composableBuilder(
    column: $table.permissionsJson,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> usersRefs(
    Expression<bool> Function($$UsersTableFilterComposer f) f,
  ) {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.roleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RolesTableOrderingComposer extends Composer<_$AppDb, $RolesTable> {
  $$RolesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get permissionsJson => $composableBuilder(
    column: $table.permissionsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RolesTableAnnotationComposer extends Composer<_$AppDb, $RolesTable> {
  $$RolesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get permissionsJson => $composableBuilder(
    column: $table.permissionsJson,
    builder: (column) => column,
  );

  Expression<T> usersRefs<T extends Object>(
    Expression<T> Function($$UsersTableAnnotationComposer a) f,
  ) {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.roleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RolesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $RolesTable,
          Role,
          $$RolesTableFilterComposer,
          $$RolesTableOrderingComposer,
          $$RolesTableAnnotationComposer,
          $$RolesTableCreateCompanionBuilder,
          $$RolesTableUpdateCompanionBuilder,
          (Role, $$RolesTableReferences),
          Role,
          PrefetchHooks Function({bool usersRefs})
        > {
  $$RolesTableTableManager(_$AppDb db, $RolesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RolesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RolesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RolesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> permissionsJson = const Value.absent(),
              }) => RolesCompanion(
                id: id,
                name: name,
                permissionsJson: permissionsJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> permissionsJson = const Value.absent(),
              }) => RolesCompanion.insert(
                id: id,
                name: name,
                permissionsJson: permissionsJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$RolesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({usersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (usersRefs) db.users],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (usersRefs)
                    await $_getPrefetchedData<Role, $RolesTable, User>(
                      currentTable: table,
                      referencedTable: $$RolesTableReferences._usersRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$RolesTableReferences(db, table, p0).usersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.roleId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RolesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $RolesTable,
      Role,
      $$RolesTableFilterComposer,
      $$RolesTableOrderingComposer,
      $$RolesTableAnnotationComposer,
      $$RolesTableCreateCompanionBuilder,
      $$RolesTableUpdateCompanionBuilder,
      (Role, $$RolesTableReferences),
      Role,
      PrefetchHooks Function({bool usersRefs})
    >;
typedef $$UsersTableCreateCompanionBuilder =
    UsersCompanion Function({
      required String id,
      required String name,
      required int roleId,
      Value<bool> isActive,
      Value<DateTime?> lastLoginAt,
      Value<int> rowid,
    });
typedef $$UsersTableUpdateCompanionBuilder =
    UsersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> roleId,
      Value<bool> isActive,
      Value<DateTime?> lastLoginAt,
      Value<int> rowid,
    });

final class $$UsersTableReferences
    extends BaseReferences<_$AppDb, $UsersTable, User> {
  $$UsersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RolesTable _roleIdTable(_$AppDb db) =>
      db.roles.createAlias($_aliasNameGenerator(db.users.roleId, db.roles.id));

  $$RolesTableProcessedTableManager get roleId {
    final $_column = $_itemColumn<int>('role_id')!;

    final manager = $$RolesTableTableManager(
      $_db,
      $_db.roles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_roleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ActivityLogTable, List<ActivityLogData>>
  _activityLogRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.activityLog,
    aliasName: $_aliasNameGenerator(db.users.id, db.activityLog.userId),
  );

  $$ActivityLogTableProcessedTableManager get activityLogRefs {
    final manager = $$ActivityLogTableTableManager(
      $_db,
      $_db.activityLog,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_activityLogRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LocalAssignmentsTable, List<LocalAssignment>>
  _localAssignmentsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.localAssignments,
    aliasName: $_aliasNameGenerator(
      db.users.id,
      db.localAssignments.assigneeUserId,
    ),
  );

  $$LocalAssignmentsTableProcessedTableManager get localAssignmentsRefs {
    final manager = $$LocalAssignmentsTableTableManager(
      $_db,
      $_db.localAssignments,
    ).filter((f) => f.assigneeUserId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localAssignmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$UsersTableFilterComposer extends Composer<_$AppDb, $UsersTable> {
  $$UsersTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastLoginAt => $composableBuilder(
    column: $table.lastLoginAt,
    builder: (column) => ColumnFilters(column),
  );

  $$RolesTableFilterComposer get roleId {
    final $$RolesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableFilterComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> activityLogRefs(
    Expression<bool> Function($$ActivityLogTableFilterComposer f) f,
  ) {
    final $$ActivityLogTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activityLog,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivityLogTableFilterComposer(
            $db: $db,
            $table: $db.activityLog,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> localAssignmentsRefs(
    Expression<bool> Function($$LocalAssignmentsTableFilterComposer f) f,
  ) {
    final $$LocalAssignmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localAssignments,
      getReferencedColumn: (t) => t.assigneeUserId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalAssignmentsTableFilterComposer(
            $db: $db,
            $table: $db.localAssignments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UsersTableOrderingComposer extends Composer<_$AppDb, $UsersTable> {
  $$UsersTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastLoginAt => $composableBuilder(
    column: $table.lastLoginAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$RolesTableOrderingComposer get roleId {
    final $$RolesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableOrderingComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UsersTableAnnotationComposer extends Composer<_$AppDb, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get lastLoginAt => $composableBuilder(
    column: $table.lastLoginAt,
    builder: (column) => column,
  );

  $$RolesTableAnnotationComposer get roleId {
    final $$RolesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableAnnotationComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> activityLogRefs<T extends Object>(
    Expression<T> Function($$ActivityLogTableAnnotationComposer a) f,
  ) {
    final $$ActivityLogTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activityLog,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivityLogTableAnnotationComposer(
            $db: $db,
            $table: $db.activityLog,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> localAssignmentsRefs<T extends Object>(
    Expression<T> Function($$LocalAssignmentsTableAnnotationComposer a) f,
  ) {
    final $$LocalAssignmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localAssignments,
      getReferencedColumn: (t) => t.assigneeUserId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalAssignmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.localAssignments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UsersTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $UsersTable,
          User,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (User, $$UsersTableReferences),
          User,
          PrefetchHooks Function({
            bool roleId,
            bool activityLogRefs,
            bool localAssignmentsRefs,
          })
        > {
  $$UsersTableTableManager(_$AppDb db, $UsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> roleId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime?> lastLoginAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion(
                id: id,
                name: name,
                roleId: roleId,
                isActive: isActive,
                lastLoginAt: lastLoginAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int roleId,
                Value<bool> isActive = const Value.absent(),
                Value<DateTime?> lastLoginAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion.insert(
                id: id,
                name: name,
                roleId: roleId,
                isActive: isActive,
                lastLoginAt: lastLoginAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$UsersTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                roleId = false,
                activityLogRefs = false,
                localAssignmentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (activityLogRefs) db.activityLog,
                    if (localAssignmentsRefs) db.localAssignments,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (roleId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.roleId,
                                    referencedTable: $$UsersTableReferences
                                        ._roleIdTable(db),
                                    referencedColumn: $$UsersTableReferences
                                        ._roleIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (activityLogRefs)
                        await $_getPrefetchedData<
                          User,
                          $UsersTable,
                          ActivityLogData
                        >(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._activityLogRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).activityLogRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (localAssignmentsRefs)
                        await $_getPrefetchedData<
                          User,
                          $UsersTable,
                          LocalAssignment
                        >(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._localAssignmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).localAssignmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.assigneeUserId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$UsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $UsersTable,
      User,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (User, $$UsersTableReferences),
      User,
      PrefetchHooks Function({
        bool roleId,
        bool activityLogRefs,
        bool localAssignmentsRefs,
      })
    >;
typedef $$ProjectsTableCreateCompanionBuilder =
    ProjectsCompanion Function({
      required String id,
      required String code,
      required String name,
      Value<bool> isActive,
      Value<int> rowid,
    });
typedef $$ProjectsTableUpdateCompanionBuilder =
    ProjectsCompanion Function({
      Value<String> id,
      Value<String> code,
      Value<String> name,
      Value<bool> isActive,
      Value<int> rowid,
    });

final class $$ProjectsTableReferences
    extends BaseReferences<_$AppDb, $ProjectsTable, Project> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ProjectSegmentsTable, List<ProjectSegment>>
  _projectSegmentsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.projectSegments,
    aliasName: $_aliasNameGenerator(
      db.projects.id,
      db.projectSegments.projectId,
    ),
  );

  $$ProjectSegmentsTableProcessedTableManager get projectSegmentsRefs {
    final manager = $$ProjectSegmentsTableTableManager(
      $_db,
      $_db.projectSegments,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _projectSegmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CatalogVersionsTable, List<CatalogVersion>>
  _catalogVersionsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.catalogVersions,
    aliasName: $_aliasNameGenerator(
      db.projects.id,
      db.catalogVersions.projectId,
    ),
  );

  $$CatalogVersionsTableProcessedTableManager get catalogVersionsRefs {
    final manager = $$CatalogVersionsTableTableManager(
      $_db,
      $_db.catalogVersions,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _catalogVersionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ActivitiesTable, List<Activity>>
  _activitiesRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.activities,
    aliasName: $_aliasNameGenerator(db.projects.id, db.activities.projectId),
  );

  $$ActivitiesTableProcessedTableManager get activitiesRefs {
    final manager = $$ActivitiesTableTableManager(
      $_db,
      $_db.activities,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_activitiesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LocalAssignmentsTable, List<LocalAssignment>>
  _localAssignmentsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.localAssignments,
    aliasName: $_aliasNameGenerator(
      db.projects.id,
      db.localAssignments.projectId,
    ),
  );

  $$LocalAssignmentsTableProcessedTableManager get localAssignmentsRefs {
    final manager = $$LocalAssignmentsTableTableManager(
      $_db,
      $_db.localAssignments,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localAssignmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectsTableFilterComposer extends Composer<_$AppDb, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
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

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> projectSegmentsRefs(
    Expression<bool> Function($$ProjectSegmentsTableFilterComposer f) f,
  ) {
    final $$ProjectSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projectSegments,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.projectSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> catalogVersionsRefs(
    Expression<bool> Function($$CatalogVersionsTableFilterComposer f) f,
  ) {
    final $$CatalogVersionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.catalogVersions,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogVersionsTableFilterComposer(
            $db: $db,
            $table: $db.catalogVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> activitiesRefs(
    Expression<bool> Function($$ActivitiesTableFilterComposer f) f,
  ) {
    final $$ActivitiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableFilterComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> localAssignmentsRefs(
    Expression<bool> Function($$LocalAssignmentsTableFilterComposer f) f,
  ) {
    final $$LocalAssignmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localAssignments,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalAssignmentsTableFilterComposer(
            $db: $db,
            $table: $db.localAssignments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDb, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
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

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDb, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  Expression<T> projectSegmentsRefs<T extends Object>(
    Expression<T> Function($$ProjectSegmentsTableAnnotationComposer a) f,
  ) {
    final $$ProjectSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projectSegments,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.projectSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> catalogVersionsRefs<T extends Object>(
    Expression<T> Function($$CatalogVersionsTableAnnotationComposer a) f,
  ) {
    final $$CatalogVersionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.catalogVersions,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogVersionsTableAnnotationComposer(
            $db: $db,
            $table: $db.catalogVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> activitiesRefs<T extends Object>(
    Expression<T> Function($$ActivitiesTableAnnotationComposer a) f,
  ) {
    final $$ActivitiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableAnnotationComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> localAssignmentsRefs<T extends Object>(
    Expression<T> Function($$LocalAssignmentsTableAnnotationComposer a) f,
  ) {
    final $$LocalAssignmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localAssignments,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalAssignmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.localAssignments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ProjectsTable,
          Project,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (Project, $$ProjectsTableReferences),
          Project,
          PrefetchHooks Function({
            bool projectSegmentsRefs,
            bool catalogVersionsRefs,
            bool activitiesRefs,
            bool localAssignmentsRefs,
          })
        > {
  $$ProjectsTableTableManager(_$AppDb db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                code: code,
                name: name,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String code,
                required String name,
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                code: code,
                name: name,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                projectSegmentsRefs = false,
                catalogVersionsRefs = false,
                activitiesRefs = false,
                localAssignmentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (projectSegmentsRefs) db.projectSegments,
                    if (catalogVersionsRefs) db.catalogVersions,
                    if (activitiesRefs) db.activities,
                    if (localAssignmentsRefs) db.localAssignments,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (projectSegmentsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          ProjectSegment
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._projectSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).projectSegmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (catalogVersionsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          CatalogVersion
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._catalogVersionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).catalogVersionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (activitiesRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          Activity
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._activitiesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).activitiesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (localAssignmentsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          LocalAssignment
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._localAssignmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).localAssignmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ProjectsTable,
      Project,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (Project, $$ProjectsTableReferences),
      Project,
      PrefetchHooks Function({
        bool projectSegmentsRefs,
        bool catalogVersionsRefs,
        bool activitiesRefs,
        bool localAssignmentsRefs,
      })
    >;
typedef $$ProjectSegmentsTableCreateCompanionBuilder =
    ProjectSegmentsCompanion Function({
      required String id,
      required String projectId,
      required String segmentName,
      Value<int?> pkStart,
      Value<int?> pkEnd,
      Value<bool> isActive,
      Value<int> rowid,
    });
typedef $$ProjectSegmentsTableUpdateCompanionBuilder =
    ProjectSegmentsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> segmentName,
      Value<int?> pkStart,
      Value<int?> pkEnd,
      Value<bool> isActive,
      Value<int> rowid,
    });

final class $$ProjectSegmentsTableReferences
    extends BaseReferences<_$AppDb, $ProjectSegmentsTable, ProjectSegment> {
  $$ProjectSegmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTable _projectIdTable(_$AppDb db) => db.projects.createAlias(
    $_aliasNameGenerator(db.projectSegments.projectId, db.projects.id),
  );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ActivitiesTable, List<Activity>>
  _activitiesRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.activities,
    aliasName: $_aliasNameGenerator(
      db.projectSegments.id,
      db.activities.segmentId,
    ),
  );

  $$ActivitiesTableProcessedTableManager get activitiesRefs {
    final manager = $$ActivitiesTableTableManager(
      $_db,
      $_db.activities,
    ).filter((f) => f.segmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_activitiesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LocalAssignmentsTable, List<LocalAssignment>>
  _localAssignmentsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.localAssignments,
    aliasName: $_aliasNameGenerator(
      db.projectSegments.id,
      db.localAssignments.frontId,
    ),
  );

  $$LocalAssignmentsTableProcessedTableManager get localAssignmentsRefs {
    final manager = $$LocalAssignmentsTableTableManager(
      $_db,
      $_db.localAssignments,
    ).filter((f) => f.frontId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localAssignmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectSegmentsTableFilterComposer
    extends Composer<_$AppDb, $ProjectSegmentsTable> {
  $$ProjectSegmentsTableFilterComposer({
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

  ColumnFilters<String> get segmentName => $composableBuilder(
    column: $table.segmentName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pkStart => $composableBuilder(
    column: $table.pkStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pkEnd => $composableBuilder(
    column: $table.pkEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> activitiesRefs(
    Expression<bool> Function($$ActivitiesTableFilterComposer f) f,
  ) {
    final $$ActivitiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.segmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableFilterComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> localAssignmentsRefs(
    Expression<bool> Function($$LocalAssignmentsTableFilterComposer f) f,
  ) {
    final $$LocalAssignmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localAssignments,
      getReferencedColumn: (t) => t.frontId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalAssignmentsTableFilterComposer(
            $db: $db,
            $table: $db.localAssignments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectSegmentsTableOrderingComposer
    extends Composer<_$AppDb, $ProjectSegmentsTable> {
  $$ProjectSegmentsTableOrderingComposer({
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

  ColumnOrderings<String> get segmentName => $composableBuilder(
    column: $table.segmentName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pkStart => $composableBuilder(
    column: $table.pkStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pkEnd => $composableBuilder(
    column: $table.pkEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectSegmentsTableAnnotationComposer
    extends Composer<_$AppDb, $ProjectSegmentsTable> {
  $$ProjectSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get segmentName => $composableBuilder(
    column: $table.segmentName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pkStart =>
      $composableBuilder(column: $table.pkStart, builder: (column) => column);

  GeneratedColumn<int> get pkEnd =>
      $composableBuilder(column: $table.pkEnd, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> activitiesRefs<T extends Object>(
    Expression<T> Function($$ActivitiesTableAnnotationComposer a) f,
  ) {
    final $$ActivitiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.segmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableAnnotationComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> localAssignmentsRefs<T extends Object>(
    Expression<T> Function($$LocalAssignmentsTableAnnotationComposer a) f,
  ) {
    final $$LocalAssignmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localAssignments,
      getReferencedColumn: (t) => t.frontId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalAssignmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.localAssignments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectSegmentsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ProjectSegmentsTable,
          ProjectSegment,
          $$ProjectSegmentsTableFilterComposer,
          $$ProjectSegmentsTableOrderingComposer,
          $$ProjectSegmentsTableAnnotationComposer,
          $$ProjectSegmentsTableCreateCompanionBuilder,
          $$ProjectSegmentsTableUpdateCompanionBuilder,
          (ProjectSegment, $$ProjectSegmentsTableReferences),
          ProjectSegment,
          PrefetchHooks Function({
            bool projectId,
            bool activitiesRefs,
            bool localAssignmentsRefs,
          })
        > {
  $$ProjectSegmentsTableTableManager(_$AppDb db, $ProjectSegmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectSegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> segmentName = const Value.absent(),
                Value<int?> pkStart = const Value.absent(),
                Value<int?> pkEnd = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectSegmentsCompanion(
                id: id,
                projectId: projectId,
                segmentName: segmentName,
                pkStart: pkStart,
                pkEnd: pkEnd,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String segmentName,
                Value<int?> pkStart = const Value.absent(),
                Value<int?> pkEnd = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectSegmentsCompanion.insert(
                id: id,
                projectId: projectId,
                segmentName: segmentName,
                pkStart: pkStart,
                pkEnd: pkEnd,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectSegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                projectId = false,
                activitiesRefs = false,
                localAssignmentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (activitiesRefs) db.activities,
                    if (localAssignmentsRefs) db.localAssignments,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable:
                                        $$ProjectSegmentsTableReferences
                                            ._projectIdTable(db),
                                    referencedColumn:
                                        $$ProjectSegmentsTableReferences
                                            ._projectIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (activitiesRefs)
                        await $_getPrefetchedData<
                          ProjectSegment,
                          $ProjectSegmentsTable,
                          Activity
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectSegmentsTableReferences
                              ._activitiesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectSegmentsTableReferences(
                                db,
                                table,
                                p0,
                              ).activitiesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.segmentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (localAssignmentsRefs)
                        await $_getPrefetchedData<
                          ProjectSegment,
                          $ProjectSegmentsTable,
                          LocalAssignment
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectSegmentsTableReferences
                              ._localAssignmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectSegmentsTableReferences(
                                db,
                                table,
                                p0,
                              ).localAssignmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.frontId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProjectSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ProjectSegmentsTable,
      ProjectSegment,
      $$ProjectSegmentsTableFilterComposer,
      $$ProjectSegmentsTableOrderingComposer,
      $$ProjectSegmentsTableAnnotationComposer,
      $$ProjectSegmentsTableCreateCompanionBuilder,
      $$ProjectSegmentsTableUpdateCompanionBuilder,
      (ProjectSegment, $$ProjectSegmentsTableReferences),
      ProjectSegment,
      PrefetchHooks Function({
        bool projectId,
        bool activitiesRefs,
        bool localAssignmentsRefs,
      })
    >;
typedef $$CatalogVersionsTableCreateCompanionBuilder =
    CatalogVersionsCompanion Function({
      required String id,
      Value<String?> projectId,
      required int versionNumber,
      Value<DateTime?> publishedAt,
      Value<String?> checksum,
      Value<String?> notes,
      Value<int> rowid,
    });
typedef $$CatalogVersionsTableUpdateCompanionBuilder =
    CatalogVersionsCompanion Function({
      Value<String> id,
      Value<String?> projectId,
      Value<int> versionNumber,
      Value<DateTime?> publishedAt,
      Value<String?> checksum,
      Value<String?> notes,
      Value<int> rowid,
    });

final class $$CatalogVersionsTableReferences
    extends BaseReferences<_$AppDb, $CatalogVersionsTable, CatalogVersion> {
  $$CatalogVersionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTable _projectIdTable(_$AppDb db) => db.projects.createAlias(
    $_aliasNameGenerator(db.catalogVersions.projectId, db.projects.id),
  );

  $$ProjectsTableProcessedTableManager? get projectId {
    final $_column = $_itemColumn<String>('project_id');
    if ($_column == null) return null;
    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CatalogVersionsTableFilterComposer
    extends Composer<_$AppDb, $CatalogVersionsTable> {
  $$CatalogVersionsTableFilterComposer({
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

  ColumnFilters<int> get versionNumber => $composableBuilder(
    column: $table.versionNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CatalogVersionsTableOrderingComposer
    extends Composer<_$AppDb, $CatalogVersionsTable> {
  $$CatalogVersionsTableOrderingComposer({
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

  ColumnOrderings<int> get versionNumber => $composableBuilder(
    column: $table.versionNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CatalogVersionsTableAnnotationComposer
    extends Composer<_$AppDb, $CatalogVersionsTable> {
  $$CatalogVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get versionNumber => $composableBuilder(
    column: $table.versionNumber,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CatalogVersionsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $CatalogVersionsTable,
          CatalogVersion,
          $$CatalogVersionsTableFilterComposer,
          $$CatalogVersionsTableOrderingComposer,
          $$CatalogVersionsTableAnnotationComposer,
          $$CatalogVersionsTableCreateCompanionBuilder,
          $$CatalogVersionsTableUpdateCompanionBuilder,
          (CatalogVersion, $$CatalogVersionsTableReferences),
          CatalogVersion,
          PrefetchHooks Function({bool projectId})
        > {
  $$CatalogVersionsTableTableManager(_$AppDb db, $CatalogVersionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                Value<int> versionNumber = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<String?> checksum = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogVersionsCompanion(
                id: id,
                projectId: projectId,
                versionNumber: versionNumber,
                publishedAt: publishedAt,
                checksum: checksum,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> projectId = const Value.absent(),
                required int versionNumber,
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<String?> checksum = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogVersionsCompanion.insert(
                id: id,
                projectId: projectId,
                versionNumber: versionNumber,
                publishedAt: publishedAt,
                checksum: checksum,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CatalogVersionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable:
                                    $$CatalogVersionsTableReferences
                                        ._projectIdTable(db),
                                referencedColumn:
                                    $$CatalogVersionsTableReferences
                                        ._projectIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CatalogVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $CatalogVersionsTable,
      CatalogVersion,
      $$CatalogVersionsTableFilterComposer,
      $$CatalogVersionsTableOrderingComposer,
      $$CatalogVersionsTableAnnotationComposer,
      $$CatalogVersionsTableCreateCompanionBuilder,
      $$CatalogVersionsTableUpdateCompanionBuilder,
      (CatalogVersion, $$CatalogVersionsTableReferences),
      CatalogVersion,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$CatalogActivityTypesTableCreateCompanionBuilder =
    CatalogActivityTypesCompanion Function({
      required String id,
      required String code,
      required String name,
      Value<bool> requiresPk,
      Value<bool> requiresGeo,
      Value<bool> requiresMinuta,
      Value<bool> requiresEvidence,
      Value<bool> isActive,
      Value<int> catalogVersion,
      Value<int> rowid,
    });
typedef $$CatalogActivityTypesTableUpdateCompanionBuilder =
    CatalogActivityTypesCompanion Function({
      Value<String> id,
      Value<String> code,
      Value<String> name,
      Value<bool> requiresPk,
      Value<bool> requiresGeo,
      Value<bool> requiresMinuta,
      Value<bool> requiresEvidence,
      Value<bool> isActive,
      Value<int> catalogVersion,
      Value<int> rowid,
    });

final class $$CatalogActivityTypesTableReferences
    extends
        BaseReferences<
          _$AppDb,
          $CatalogActivityTypesTable,
          CatalogActivityType
        > {
  $$CatalogActivityTypesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$CatalogFieldsTable, List<CatalogField>>
  _catalogFieldsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.catalogFields,
    aliasName: $_aliasNameGenerator(
      db.catalogActivityTypes.id,
      db.catalogFields.activityTypeId,
    ),
  );

  $$CatalogFieldsTableProcessedTableManager get catalogFieldsRefs {
    final manager = $$CatalogFieldsTableTableManager(
      $_db,
      $_db.catalogFields,
    ).filter((f) => f.activityTypeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_catalogFieldsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ActivitiesTable, List<Activity>>
  _activitiesRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.activities,
    aliasName: $_aliasNameGenerator(
      db.catalogActivityTypes.id,
      db.activities.activityTypeId,
    ),
  );

  $$ActivitiesTableProcessedTableManager get activitiesRefs {
    final manager = $$ActivitiesTableTableManager(
      $_db,
      $_db.activities,
    ).filter((f) => f.activityTypeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_activitiesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CatalogActivityTypesTableFilterComposer
    extends Composer<_$AppDb, $CatalogActivityTypesTable> {
  $$CatalogActivityTypesTableFilterComposer({
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

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiresPk => $composableBuilder(
    column: $table.requiresPk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiresGeo => $composableBuilder(
    column: $table.requiresGeo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiresMinuta => $composableBuilder(
    column: $table.requiresMinuta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiresEvidence => $composableBuilder(
    column: $table.requiresEvidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get catalogVersion => $composableBuilder(
    column: $table.catalogVersion,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> catalogFieldsRefs(
    Expression<bool> Function($$CatalogFieldsTableFilterComposer f) f,
  ) {
    final $$CatalogFieldsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.catalogFields,
      getReferencedColumn: (t) => t.activityTypeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogFieldsTableFilterComposer(
            $db: $db,
            $table: $db.catalogFields,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> activitiesRefs(
    Expression<bool> Function($$ActivitiesTableFilterComposer f) f,
  ) {
    final $$ActivitiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.activityTypeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableFilterComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CatalogActivityTypesTableOrderingComposer
    extends Composer<_$AppDb, $CatalogActivityTypesTable> {
  $$CatalogActivityTypesTableOrderingComposer({
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

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiresPk => $composableBuilder(
    column: $table.requiresPk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiresGeo => $composableBuilder(
    column: $table.requiresGeo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiresMinuta => $composableBuilder(
    column: $table.requiresMinuta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiresEvidence => $composableBuilder(
    column: $table.requiresEvidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get catalogVersion => $composableBuilder(
    column: $table.catalogVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatalogActivityTypesTableAnnotationComposer
    extends Composer<_$AppDb, $CatalogActivityTypesTable> {
  $$CatalogActivityTypesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get requiresPk => $composableBuilder(
    column: $table.requiresPk,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get requiresGeo => $composableBuilder(
    column: $table.requiresGeo,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get requiresMinuta => $composableBuilder(
    column: $table.requiresMinuta,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get requiresEvidence => $composableBuilder(
    column: $table.requiresEvidence,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get catalogVersion => $composableBuilder(
    column: $table.catalogVersion,
    builder: (column) => column,
  );

  Expression<T> catalogFieldsRefs<T extends Object>(
    Expression<T> Function($$CatalogFieldsTableAnnotationComposer a) f,
  ) {
    final $$CatalogFieldsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.catalogFields,
      getReferencedColumn: (t) => t.activityTypeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogFieldsTableAnnotationComposer(
            $db: $db,
            $table: $db.catalogFields,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> activitiesRefs<T extends Object>(
    Expression<T> Function($$ActivitiesTableAnnotationComposer a) f,
  ) {
    final $$ActivitiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.activityTypeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableAnnotationComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CatalogActivityTypesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $CatalogActivityTypesTable,
          CatalogActivityType,
          $$CatalogActivityTypesTableFilterComposer,
          $$CatalogActivityTypesTableOrderingComposer,
          $$CatalogActivityTypesTableAnnotationComposer,
          $$CatalogActivityTypesTableCreateCompanionBuilder,
          $$CatalogActivityTypesTableUpdateCompanionBuilder,
          (CatalogActivityType, $$CatalogActivityTypesTableReferences),
          CatalogActivityType,
          PrefetchHooks Function({bool catalogFieldsRefs, bool activitiesRefs})
        > {
  $$CatalogActivityTypesTableTableManager(
    _$AppDb db,
    $CatalogActivityTypesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogActivityTypesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogActivityTypesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CatalogActivityTypesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> requiresPk = const Value.absent(),
                Value<bool> requiresGeo = const Value.absent(),
                Value<bool> requiresMinuta = const Value.absent(),
                Value<bool> requiresEvidence = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> catalogVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogActivityTypesCompanion(
                id: id,
                code: code,
                name: name,
                requiresPk: requiresPk,
                requiresGeo: requiresGeo,
                requiresMinuta: requiresMinuta,
                requiresEvidence: requiresEvidence,
                isActive: isActive,
                catalogVersion: catalogVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String code,
                required String name,
                Value<bool> requiresPk = const Value.absent(),
                Value<bool> requiresGeo = const Value.absent(),
                Value<bool> requiresMinuta = const Value.absent(),
                Value<bool> requiresEvidence = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> catalogVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogActivityTypesCompanion.insert(
                id: id,
                code: code,
                name: name,
                requiresPk: requiresPk,
                requiresGeo: requiresGeo,
                requiresMinuta: requiresMinuta,
                requiresEvidence: requiresEvidence,
                isActive: isActive,
                catalogVersion: catalogVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CatalogActivityTypesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({catalogFieldsRefs = false, activitiesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (catalogFieldsRefs) db.catalogFields,
                    if (activitiesRefs) db.activities,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (catalogFieldsRefs)
                        await $_getPrefetchedData<
                          CatalogActivityType,
                          $CatalogActivityTypesTable,
                          CatalogField
                        >(
                          currentTable: table,
                          referencedTable: $$CatalogActivityTypesTableReferences
                              ._catalogFieldsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CatalogActivityTypesTableReferences(
                                db,
                                table,
                                p0,
                              ).catalogFieldsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.activityTypeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (activitiesRefs)
                        await $_getPrefetchedData<
                          CatalogActivityType,
                          $CatalogActivityTypesTable,
                          Activity
                        >(
                          currentTable: table,
                          referencedTable: $$CatalogActivityTypesTableReferences
                              ._activitiesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CatalogActivityTypesTableReferences(
                                db,
                                table,
                                p0,
                              ).activitiesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.activityTypeId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CatalogActivityTypesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $CatalogActivityTypesTable,
      CatalogActivityType,
      $$CatalogActivityTypesTableFilterComposer,
      $$CatalogActivityTypesTableOrderingComposer,
      $$CatalogActivityTypesTableAnnotationComposer,
      $$CatalogActivityTypesTableCreateCompanionBuilder,
      $$CatalogActivityTypesTableUpdateCompanionBuilder,
      (CatalogActivityType, $$CatalogActivityTypesTableReferences),
      CatalogActivityType,
      PrefetchHooks Function({bool catalogFieldsRefs, bool activitiesRefs})
    >;
typedef $$CatalogFieldsTableCreateCompanionBuilder =
    CatalogFieldsCompanion Function({
      required String id,
      required String activityTypeId,
      required String fieldKey,
      required String fieldLabel,
      required String fieldType,
      Value<String?> optionsJson,
      Value<bool> requiredField,
      Value<int> orderIndex,
      Value<bool> isActive,
      Value<int> catalogVersion,
      Value<int> rowid,
    });
typedef $$CatalogFieldsTableUpdateCompanionBuilder =
    CatalogFieldsCompanion Function({
      Value<String> id,
      Value<String> activityTypeId,
      Value<String> fieldKey,
      Value<String> fieldLabel,
      Value<String> fieldType,
      Value<String?> optionsJson,
      Value<bool> requiredField,
      Value<int> orderIndex,
      Value<bool> isActive,
      Value<int> catalogVersion,
      Value<int> rowid,
    });

final class $$CatalogFieldsTableReferences
    extends BaseReferences<_$AppDb, $CatalogFieldsTable, CatalogField> {
  $$CatalogFieldsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CatalogActivityTypesTable _activityTypeIdTable(_$AppDb db) =>
      db.catalogActivityTypes.createAlias(
        $_aliasNameGenerator(
          db.catalogFields.activityTypeId,
          db.catalogActivityTypes.id,
        ),
      );

  $$CatalogActivityTypesTableProcessedTableManager get activityTypeId {
    final $_column = $_itemColumn<String>('activity_type_id')!;

    final manager = $$CatalogActivityTypesTableTableManager(
      $_db,
      $_db.catalogActivityTypes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_activityTypeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CatalogFieldsTableFilterComposer
    extends Composer<_$AppDb, $CatalogFieldsTable> {
  $$CatalogFieldsTableFilterComposer({
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

  ColumnFilters<String> get fieldKey => $composableBuilder(
    column: $table.fieldKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldLabel => $composableBuilder(
    column: $table.fieldLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldType => $composableBuilder(
    column: $table.fieldType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiredField => $composableBuilder(
    column: $table.requiredField,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get catalogVersion => $composableBuilder(
    column: $table.catalogVersion,
    builder: (column) => ColumnFilters(column),
  );

  $$CatalogActivityTypesTableFilterComposer get activityTypeId {
    final $$CatalogActivityTypesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityTypeId,
      referencedTable: $db.catalogActivityTypes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogActivityTypesTableFilterComposer(
            $db: $db,
            $table: $db.catalogActivityTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CatalogFieldsTableOrderingComposer
    extends Composer<_$AppDb, $CatalogFieldsTable> {
  $$CatalogFieldsTableOrderingComposer({
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

  ColumnOrderings<String> get fieldKey => $composableBuilder(
    column: $table.fieldKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldLabel => $composableBuilder(
    column: $table.fieldLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldType => $composableBuilder(
    column: $table.fieldType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiredField => $composableBuilder(
    column: $table.requiredField,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get catalogVersion => $composableBuilder(
    column: $table.catalogVersion,
    builder: (column) => ColumnOrderings(column),
  );

  $$CatalogActivityTypesTableOrderingComposer get activityTypeId {
    final $$CatalogActivityTypesTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.activityTypeId,
          referencedTable: $db.catalogActivityTypes,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CatalogActivityTypesTableOrderingComposer(
                $db: $db,
                $table: $db.catalogActivityTypes,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$CatalogFieldsTableAnnotationComposer
    extends Composer<_$AppDb, $CatalogFieldsTable> {
  $$CatalogFieldsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fieldKey =>
      $composableBuilder(column: $table.fieldKey, builder: (column) => column);

  GeneratedColumn<String> get fieldLabel => $composableBuilder(
    column: $table.fieldLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fieldType =>
      $composableBuilder(column: $table.fieldType, builder: (column) => column);

  GeneratedColumn<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get requiredField => $composableBuilder(
    column: $table.requiredField,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get catalogVersion => $composableBuilder(
    column: $table.catalogVersion,
    builder: (column) => column,
  );

  $$CatalogActivityTypesTableAnnotationComposer get activityTypeId {
    final $$CatalogActivityTypesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.activityTypeId,
          referencedTable: $db.catalogActivityTypes,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CatalogActivityTypesTableAnnotationComposer(
                $db: $db,
                $table: $db.catalogActivityTypes,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$CatalogFieldsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $CatalogFieldsTable,
          CatalogField,
          $$CatalogFieldsTableFilterComposer,
          $$CatalogFieldsTableOrderingComposer,
          $$CatalogFieldsTableAnnotationComposer,
          $$CatalogFieldsTableCreateCompanionBuilder,
          $$CatalogFieldsTableUpdateCompanionBuilder,
          (CatalogField, $$CatalogFieldsTableReferences),
          CatalogField,
          PrefetchHooks Function({bool activityTypeId})
        > {
  $$CatalogFieldsTableTableManager(_$AppDb db, $CatalogFieldsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogFieldsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogFieldsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogFieldsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> activityTypeId = const Value.absent(),
                Value<String> fieldKey = const Value.absent(),
                Value<String> fieldLabel = const Value.absent(),
                Value<String> fieldType = const Value.absent(),
                Value<String?> optionsJson = const Value.absent(),
                Value<bool> requiredField = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> catalogVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogFieldsCompanion(
                id: id,
                activityTypeId: activityTypeId,
                fieldKey: fieldKey,
                fieldLabel: fieldLabel,
                fieldType: fieldType,
                optionsJson: optionsJson,
                requiredField: requiredField,
                orderIndex: orderIndex,
                isActive: isActive,
                catalogVersion: catalogVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String activityTypeId,
                required String fieldKey,
                required String fieldLabel,
                required String fieldType,
                Value<String?> optionsJson = const Value.absent(),
                Value<bool> requiredField = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> catalogVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogFieldsCompanion.insert(
                id: id,
                activityTypeId: activityTypeId,
                fieldKey: fieldKey,
                fieldLabel: fieldLabel,
                fieldType: fieldType,
                optionsJson: optionsJson,
                requiredField: requiredField,
                orderIndex: orderIndex,
                isActive: isActive,
                catalogVersion: catalogVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CatalogFieldsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({activityTypeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (activityTypeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.activityTypeId,
                                referencedTable: $$CatalogFieldsTableReferences
                                    ._activityTypeIdTable(db),
                                referencedColumn: $$CatalogFieldsTableReferences
                                    ._activityTypeIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CatalogFieldsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $CatalogFieldsTable,
      CatalogField,
      $$CatalogFieldsTableFilterComposer,
      $$CatalogFieldsTableOrderingComposer,
      $$CatalogFieldsTableAnnotationComposer,
      $$CatalogFieldsTableCreateCompanionBuilder,
      $$CatalogFieldsTableUpdateCompanionBuilder,
      (CatalogField, $$CatalogFieldsTableReferences),
      CatalogField,
      PrefetchHooks Function({bool activityTypeId})
    >;
typedef $$CatActivitiesTableCreateCompanionBuilder =
    CatActivitiesCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      Value<bool> isEnabled,
      Value<int> sortOrder,
      required String versionId,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CatActivitiesTableUpdateCompanionBuilder =
    CatActivitiesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<bool> isEnabled,
      Value<int> sortOrder,
      Value<String> versionId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CatActivitiesTableFilterComposer
    extends Composer<_$AppDb, $CatActivitiesTable> {
  $$CatActivitiesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatActivitiesTableOrderingComposer
    extends Composer<_$AppDb, $CatActivitiesTable> {
  $$CatActivitiesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatActivitiesTableAnnotationComposer
    extends Composer<_$AppDb, $CatActivitiesTable> {
  $$CatActivitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get versionId =>
      $composableBuilder(column: $table.versionId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CatActivitiesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $CatActivitiesTable,
          CatActivity,
          $$CatActivitiesTableFilterComposer,
          $$CatActivitiesTableOrderingComposer,
          $$CatActivitiesTableAnnotationComposer,
          $$CatActivitiesTableCreateCompanionBuilder,
          $$CatActivitiesTableUpdateCompanionBuilder,
          (
            CatActivity,
            BaseReferences<_$AppDb, $CatActivitiesTable, CatActivity>,
          ),
          CatActivity,
          PrefetchHooks Function()
        > {
  $$CatActivitiesTableTableManager(_$AppDb db, $CatActivitiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatActivitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatActivitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatActivitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> versionId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatActivitiesCompanion(
                id: id,
                name: name,
                description: description,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
                versionId: versionId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required String versionId,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CatActivitiesCompanion.insert(
                id: id,
                name: name,
                description: description,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
                versionId: versionId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatActivitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $CatActivitiesTable,
      CatActivity,
      $$CatActivitiesTableFilterComposer,
      $$CatActivitiesTableOrderingComposer,
      $$CatActivitiesTableAnnotationComposer,
      $$CatActivitiesTableCreateCompanionBuilder,
      $$CatActivitiesTableUpdateCompanionBuilder,
      (CatActivity, BaseReferences<_$AppDb, $CatActivitiesTable, CatActivity>),
      CatActivity,
      PrefetchHooks Function()
    >;
typedef $$CatSubcategoriesTableCreateCompanionBuilder =
    CatSubcategoriesCompanion Function({
      required String id,
      required String activityId,
      required String name,
      Value<String?> description,
      Value<bool> isEnabled,
      Value<int> sortOrder,
      required String versionId,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CatSubcategoriesTableUpdateCompanionBuilder =
    CatSubcategoriesCompanion Function({
      Value<String> id,
      Value<String> activityId,
      Value<String> name,
      Value<String?> description,
      Value<bool> isEnabled,
      Value<int> sortOrder,
      Value<String> versionId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CatSubcategoriesTableFilterComposer
    extends Composer<_$AppDb, $CatSubcategoriesTable> {
  $$CatSubcategoriesTableFilterComposer({
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

  ColumnFilters<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatSubcategoriesTableOrderingComposer
    extends Composer<_$AppDb, $CatSubcategoriesTable> {
  $$CatSubcategoriesTableOrderingComposer({
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

  ColumnOrderings<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatSubcategoriesTableAnnotationComposer
    extends Composer<_$AppDb, $CatSubcategoriesTable> {
  $$CatSubcategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get versionId =>
      $composableBuilder(column: $table.versionId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CatSubcategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $CatSubcategoriesTable,
          CatSubcategory,
          $$CatSubcategoriesTableFilterComposer,
          $$CatSubcategoriesTableOrderingComposer,
          $$CatSubcategoriesTableAnnotationComposer,
          $$CatSubcategoriesTableCreateCompanionBuilder,
          $$CatSubcategoriesTableUpdateCompanionBuilder,
          (
            CatSubcategory,
            BaseReferences<_$AppDb, $CatSubcategoriesTable, CatSubcategory>,
          ),
          CatSubcategory,
          PrefetchHooks Function()
        > {
  $$CatSubcategoriesTableTableManager(_$AppDb db, $CatSubcategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatSubcategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatSubcategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatSubcategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> activityId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> versionId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatSubcategoriesCompanion(
                id: id,
                activityId: activityId,
                name: name,
                description: description,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
                versionId: versionId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String activityId,
                required String name,
                Value<String?> description = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required String versionId,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CatSubcategoriesCompanion.insert(
                id: id,
                activityId: activityId,
                name: name,
                description: description,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
                versionId: versionId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatSubcategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $CatSubcategoriesTable,
      CatSubcategory,
      $$CatSubcategoriesTableFilterComposer,
      $$CatSubcategoriesTableOrderingComposer,
      $$CatSubcategoriesTableAnnotationComposer,
      $$CatSubcategoriesTableCreateCompanionBuilder,
      $$CatSubcategoriesTableUpdateCompanionBuilder,
      (
        CatSubcategory,
        BaseReferences<_$AppDb, $CatSubcategoriesTable, CatSubcategory>,
      ),
      CatSubcategory,
      PrefetchHooks Function()
    >;
typedef $$CatPurposesTableCreateCompanionBuilder =
    CatPurposesCompanion Function({
      required String id,
      required String activityId,
      Value<String?> subcategoryId,
      required String name,
      Value<bool> isEnabled,
      Value<int> sortOrder,
      required String versionId,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CatPurposesTableUpdateCompanionBuilder =
    CatPurposesCompanion Function({
      Value<String> id,
      Value<String> activityId,
      Value<String?> subcategoryId,
      Value<String> name,
      Value<bool> isEnabled,
      Value<int> sortOrder,
      Value<String> versionId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CatPurposesTableFilterComposer
    extends Composer<_$AppDb, $CatPurposesTable> {
  $$CatPurposesTableFilterComposer({
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

  ColumnFilters<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subcategoryId => $composableBuilder(
    column: $table.subcategoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatPurposesTableOrderingComposer
    extends Composer<_$AppDb, $CatPurposesTable> {
  $$CatPurposesTableOrderingComposer({
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

  ColumnOrderings<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subcategoryId => $composableBuilder(
    column: $table.subcategoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatPurposesTableAnnotationComposer
    extends Composer<_$AppDb, $CatPurposesTable> {
  $$CatPurposesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subcategoryId => $composableBuilder(
    column: $table.subcategoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get versionId =>
      $composableBuilder(column: $table.versionId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CatPurposesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $CatPurposesTable,
          CatPurpose,
          $$CatPurposesTableFilterComposer,
          $$CatPurposesTableOrderingComposer,
          $$CatPurposesTableAnnotationComposer,
          $$CatPurposesTableCreateCompanionBuilder,
          $$CatPurposesTableUpdateCompanionBuilder,
          (CatPurpose, BaseReferences<_$AppDb, $CatPurposesTable, CatPurpose>),
          CatPurpose,
          PrefetchHooks Function()
        > {
  $$CatPurposesTableTableManager(_$AppDb db, $CatPurposesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatPurposesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatPurposesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatPurposesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> activityId = const Value.absent(),
                Value<String?> subcategoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> versionId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatPurposesCompanion(
                id: id,
                activityId: activityId,
                subcategoryId: subcategoryId,
                name: name,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
                versionId: versionId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String activityId,
                Value<String?> subcategoryId = const Value.absent(),
                required String name,
                Value<bool> isEnabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required String versionId,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CatPurposesCompanion.insert(
                id: id,
                activityId: activityId,
                subcategoryId: subcategoryId,
                name: name,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
                versionId: versionId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatPurposesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $CatPurposesTable,
      CatPurpose,
      $$CatPurposesTableFilterComposer,
      $$CatPurposesTableOrderingComposer,
      $$CatPurposesTableAnnotationComposer,
      $$CatPurposesTableCreateCompanionBuilder,
      $$CatPurposesTableUpdateCompanionBuilder,
      (CatPurpose, BaseReferences<_$AppDb, $CatPurposesTable, CatPurpose>),
      CatPurpose,
      PrefetchHooks Function()
    >;
typedef $$CatTopicsTableCreateCompanionBuilder =
    CatTopicsCompanion Function({
      required String id,
      Value<String?> type,
      Value<String?> description,
      required String name,
      Value<bool> isEnabled,
      Value<int> sortOrder,
      required String versionId,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CatTopicsTableUpdateCompanionBuilder =
    CatTopicsCompanion Function({
      Value<String> id,
      Value<String?> type,
      Value<String?> description,
      Value<String> name,
      Value<bool> isEnabled,
      Value<int> sortOrder,
      Value<String> versionId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CatTopicsTableFilterComposer
    extends Composer<_$AppDb, $CatTopicsTable> {
  $$CatTopicsTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatTopicsTableOrderingComposer
    extends Composer<_$AppDb, $CatTopicsTable> {
  $$CatTopicsTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatTopicsTableAnnotationComposer
    extends Composer<_$AppDb, $CatTopicsTable> {
  $$CatTopicsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get versionId =>
      $composableBuilder(column: $table.versionId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CatTopicsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $CatTopicsTable,
          CatTopic,
          $$CatTopicsTableFilterComposer,
          $$CatTopicsTableOrderingComposer,
          $$CatTopicsTableAnnotationComposer,
          $$CatTopicsTableCreateCompanionBuilder,
          $$CatTopicsTableUpdateCompanionBuilder,
          (CatTopic, BaseReferences<_$AppDb, $CatTopicsTable, CatTopic>),
          CatTopic,
          PrefetchHooks Function()
        > {
  $$CatTopicsTableTableManager(_$AppDb db, $CatTopicsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatTopicsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatTopicsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatTopicsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> versionId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatTopicsCompanion(
                id: id,
                type: type,
                description: description,
                name: name,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
                versionId: versionId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> type = const Value.absent(),
                Value<String?> description = const Value.absent(),
                required String name,
                Value<bool> isEnabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required String versionId,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CatTopicsCompanion.insert(
                id: id,
                type: type,
                description: description,
                name: name,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
                versionId: versionId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatTopicsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $CatTopicsTable,
      CatTopic,
      $$CatTopicsTableFilterComposer,
      $$CatTopicsTableOrderingComposer,
      $$CatTopicsTableAnnotationComposer,
      $$CatTopicsTableCreateCompanionBuilder,
      $$CatTopicsTableUpdateCompanionBuilder,
      (CatTopic, BaseReferences<_$AppDb, $CatTopicsTable, CatTopic>),
      CatTopic,
      PrefetchHooks Function()
    >;
typedef $$CatRelActivityTopicsTableCreateCompanionBuilder =
    CatRelActivityTopicsCompanion Function({
      required String activityId,
      required String topicId,
      Value<bool> isEnabled,
      required String versionId,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CatRelActivityTopicsTableUpdateCompanionBuilder =
    CatRelActivityTopicsCompanion Function({
      Value<String> activityId,
      Value<String> topicId,
      Value<bool> isEnabled,
      Value<String> versionId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CatRelActivityTopicsTableFilterComposer
    extends Composer<_$AppDb, $CatRelActivityTopicsTable> {
  $$CatRelActivityTopicsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatRelActivityTopicsTableOrderingComposer
    extends Composer<_$AppDb, $CatRelActivityTopicsTable> {
  $$CatRelActivityTopicsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatRelActivityTopicsTableAnnotationComposer
    extends Composer<_$AppDb, $CatRelActivityTopicsTable> {
  $$CatRelActivityTopicsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get topicId =>
      $composableBuilder(column: $table.topicId, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<String> get versionId =>
      $composableBuilder(column: $table.versionId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CatRelActivityTopicsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $CatRelActivityTopicsTable,
          CatRelActivityTopic,
          $$CatRelActivityTopicsTableFilterComposer,
          $$CatRelActivityTopicsTableOrderingComposer,
          $$CatRelActivityTopicsTableAnnotationComposer,
          $$CatRelActivityTopicsTableCreateCompanionBuilder,
          $$CatRelActivityTopicsTableUpdateCompanionBuilder,
          (
            CatRelActivityTopic,
            BaseReferences<
              _$AppDb,
              $CatRelActivityTopicsTable,
              CatRelActivityTopic
            >,
          ),
          CatRelActivityTopic,
          PrefetchHooks Function()
        > {
  $$CatRelActivityTopicsTableTableManager(
    _$AppDb db,
    $CatRelActivityTopicsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatRelActivityTopicsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatRelActivityTopicsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CatRelActivityTopicsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> activityId = const Value.absent(),
                Value<String> topicId = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<String> versionId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatRelActivityTopicsCompanion(
                activityId: activityId,
                topicId: topicId,
                isEnabled: isEnabled,
                versionId: versionId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String activityId,
                required String topicId,
                Value<bool> isEnabled = const Value.absent(),
                required String versionId,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CatRelActivityTopicsCompanion.insert(
                activityId: activityId,
                topicId: topicId,
                isEnabled: isEnabled,
                versionId: versionId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatRelActivityTopicsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $CatRelActivityTopicsTable,
      CatRelActivityTopic,
      $$CatRelActivityTopicsTableFilterComposer,
      $$CatRelActivityTopicsTableOrderingComposer,
      $$CatRelActivityTopicsTableAnnotationComposer,
      $$CatRelActivityTopicsTableCreateCompanionBuilder,
      $$CatRelActivityTopicsTableUpdateCompanionBuilder,
      (
        CatRelActivityTopic,
        BaseReferences<
          _$AppDb,
          $CatRelActivityTopicsTable,
          CatRelActivityTopic
        >,
      ),
      CatRelActivityTopic,
      PrefetchHooks Function()
    >;
typedef $$CatResultsTableCreateCompanionBuilder =
    CatResultsCompanion Function({
      required String id,
      required String name,
      Value<String?> category,
      Value<String?> severity,
      Value<bool> isEnabled,
      Value<int> sortOrder,
      required String versionId,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CatResultsTableUpdateCompanionBuilder =
    CatResultsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> category,
      Value<String?> severity,
      Value<bool> isEnabled,
      Value<int> sortOrder,
      Value<String> versionId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CatResultsTableFilterComposer
    extends Composer<_$AppDb, $CatResultsTable> {
  $$CatResultsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatResultsTableOrderingComposer
    extends Composer<_$AppDb, $CatResultsTable> {
  $$CatResultsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatResultsTableAnnotationComposer
    extends Composer<_$AppDb, $CatResultsTable> {
  $$CatResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get versionId =>
      $composableBuilder(column: $table.versionId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CatResultsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $CatResultsTable,
          CatResult,
          $$CatResultsTableFilterComposer,
          $$CatResultsTableOrderingComposer,
          $$CatResultsTableAnnotationComposer,
          $$CatResultsTableCreateCompanionBuilder,
          $$CatResultsTableUpdateCompanionBuilder,
          (CatResult, BaseReferences<_$AppDb, $CatResultsTable, CatResult>),
          CatResult,
          PrefetchHooks Function()
        > {
  $$CatResultsTableTableManager(_$AppDb db, $CatResultsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> severity = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> versionId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatResultsCompanion(
                id: id,
                name: name,
                category: category,
                severity: severity,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
                versionId: versionId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> category = const Value.absent(),
                Value<String?> severity = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required String versionId,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CatResultsCompanion.insert(
                id: id,
                name: name,
                category: category,
                severity: severity,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
                versionId: versionId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $CatResultsTable,
      CatResult,
      $$CatResultsTableFilterComposer,
      $$CatResultsTableOrderingComposer,
      $$CatResultsTableAnnotationComposer,
      $$CatResultsTableCreateCompanionBuilder,
      $$CatResultsTableUpdateCompanionBuilder,
      (CatResult, BaseReferences<_$AppDb, $CatResultsTable, CatResult>),
      CatResult,
      PrefetchHooks Function()
    >;
typedef $$CatAttendeesTableCreateCompanionBuilder =
    CatAttendeesCompanion Function({
      required String id,
      required String type,
      Value<String?> description,
      required String name,
      Value<bool> isEnabled,
      Value<int> sortOrder,
      required String versionId,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CatAttendeesTableUpdateCompanionBuilder =
    CatAttendeesCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String?> description,
      Value<String> name,
      Value<bool> isEnabled,
      Value<int> sortOrder,
      Value<String> versionId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CatAttendeesTableFilterComposer
    extends Composer<_$AppDb, $CatAttendeesTable> {
  $$CatAttendeesTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatAttendeesTableOrderingComposer
    extends Composer<_$AppDb, $CatAttendeesTable> {
  $$CatAttendeesTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatAttendeesTableAnnotationComposer
    extends Composer<_$AppDb, $CatAttendeesTable> {
  $$CatAttendeesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get versionId =>
      $composableBuilder(column: $table.versionId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CatAttendeesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $CatAttendeesTable,
          CatAttendee,
          $$CatAttendeesTableFilterComposer,
          $$CatAttendeesTableOrderingComposer,
          $$CatAttendeesTableAnnotationComposer,
          $$CatAttendeesTableCreateCompanionBuilder,
          $$CatAttendeesTableUpdateCompanionBuilder,
          (
            CatAttendee,
            BaseReferences<_$AppDb, $CatAttendeesTable, CatAttendee>,
          ),
          CatAttendee,
          PrefetchHooks Function()
        > {
  $$CatAttendeesTableTableManager(_$AppDb db, $CatAttendeesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatAttendeesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatAttendeesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatAttendeesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> versionId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatAttendeesCompanion(
                id: id,
                type: type,
                description: description,
                name: name,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
                versionId: versionId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                Value<String?> description = const Value.absent(),
                required String name,
                Value<bool> isEnabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required String versionId,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CatAttendeesCompanion.insert(
                id: id,
                type: type,
                description: description,
                name: name,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
                versionId: versionId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatAttendeesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $CatAttendeesTable,
      CatAttendee,
      $$CatAttendeesTableFilterComposer,
      $$CatAttendeesTableOrderingComposer,
      $$CatAttendeesTableAnnotationComposer,
      $$CatAttendeesTableCreateCompanionBuilder,
      $$CatAttendeesTableUpdateCompanionBuilder,
      (CatAttendee, BaseReferences<_$AppDb, $CatAttendeesTable, CatAttendee>),
      CatAttendee,
      PrefetchHooks Function()
    >;
typedef $$CatalogIndexTableCreateCompanionBuilder =
    CatalogIndexCompanion Function({
      required String projectId,
      required String activeVersionId,
      Value<String?> hash,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CatalogIndexTableUpdateCompanionBuilder =
    CatalogIndexCompanion Function({
      Value<String> projectId,
      Value<String> activeVersionId,
      Value<String?> hash,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CatalogIndexTableFilterComposer
    extends Composer<_$AppDb, $CatalogIndexTable> {
  $$CatalogIndexTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeVersionId => $composableBuilder(
    column: $table.activeVersionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatalogIndexTableOrderingComposer
    extends Composer<_$AppDb, $CatalogIndexTable> {
  $$CatalogIndexTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeVersionId => $composableBuilder(
    column: $table.activeVersionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatalogIndexTableAnnotationComposer
    extends Composer<_$AppDb, $CatalogIndexTable> {
  $$CatalogIndexTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get activeVersionId => $composableBuilder(
    column: $table.activeVersionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CatalogIndexTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $CatalogIndexTable,
          CatalogIndexData,
          $$CatalogIndexTableFilterComposer,
          $$CatalogIndexTableOrderingComposer,
          $$CatalogIndexTableAnnotationComposer,
          $$CatalogIndexTableCreateCompanionBuilder,
          $$CatalogIndexTableUpdateCompanionBuilder,
          (
            CatalogIndexData,
            BaseReferences<_$AppDb, $CatalogIndexTable, CatalogIndexData>,
          ),
          CatalogIndexData,
          PrefetchHooks Function()
        > {
  $$CatalogIndexTableTableManager(_$AppDb db, $CatalogIndexTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogIndexTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogIndexTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogIndexTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> projectId = const Value.absent(),
                Value<String> activeVersionId = const Value.absent(),
                Value<String?> hash = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogIndexCompanion(
                projectId: projectId,
                activeVersionId: activeVersionId,
                hash: hash,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String projectId,
                required String activeVersionId,
                Value<String?> hash = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CatalogIndexCompanion.insert(
                projectId: projectId,
                activeVersionId: activeVersionId,
                hash: hash,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatalogIndexTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $CatalogIndexTable,
      CatalogIndexData,
      $$CatalogIndexTableFilterComposer,
      $$CatalogIndexTableOrderingComposer,
      $$CatalogIndexTableAnnotationComposer,
      $$CatalogIndexTableCreateCompanionBuilder,
      $$CatalogIndexTableUpdateCompanionBuilder,
      (
        CatalogIndexData,
        BaseReferences<_$AppDb, $CatalogIndexTable, CatalogIndexData>,
      ),
      CatalogIndexData,
      PrefetchHooks Function()
    >;
typedef $$CatalogBundleCacheTableCreateCompanionBuilder =
    CatalogBundleCacheCompanion Function({
      required String projectId,
      required String versionId,
      required String jsonBlob,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$CatalogBundleCacheTableUpdateCompanionBuilder =
    CatalogBundleCacheCompanion Function({
      Value<String> projectId,
      Value<String> versionId,
      Value<String> jsonBlob,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$CatalogBundleCacheTableFilterComposer
    extends Composer<_$AppDb, $CatalogBundleCacheTable> {
  $$CatalogBundleCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jsonBlob => $composableBuilder(
    column: $table.jsonBlob,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatalogBundleCacheTableOrderingComposer
    extends Composer<_$AppDb, $CatalogBundleCacheTable> {
  $$CatalogBundleCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jsonBlob => $composableBuilder(
    column: $table.jsonBlob,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatalogBundleCacheTableAnnotationComposer
    extends Composer<_$AppDb, $CatalogBundleCacheTable> {
  $$CatalogBundleCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get versionId =>
      $composableBuilder(column: $table.versionId, builder: (column) => column);

  GeneratedColumn<String> get jsonBlob =>
      $composableBuilder(column: $table.jsonBlob, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CatalogBundleCacheTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $CatalogBundleCacheTable,
          CatalogBundleCacheData,
          $$CatalogBundleCacheTableFilterComposer,
          $$CatalogBundleCacheTableOrderingComposer,
          $$CatalogBundleCacheTableAnnotationComposer,
          $$CatalogBundleCacheTableCreateCompanionBuilder,
          $$CatalogBundleCacheTableUpdateCompanionBuilder,
          (
            CatalogBundleCacheData,
            BaseReferences<
              _$AppDb,
              $CatalogBundleCacheTable,
              CatalogBundleCacheData
            >,
          ),
          CatalogBundleCacheData,
          PrefetchHooks Function()
        > {
  $$CatalogBundleCacheTableTableManager(
    _$AppDb db,
    $CatalogBundleCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogBundleCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogBundleCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogBundleCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> projectId = const Value.absent(),
                Value<String> versionId = const Value.absent(),
                Value<String> jsonBlob = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogBundleCacheCompanion(
                projectId: projectId,
                versionId: versionId,
                jsonBlob: jsonBlob,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String projectId,
                required String versionId,
                required String jsonBlob,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => CatalogBundleCacheCompanion.insert(
                projectId: projectId,
                versionId: versionId,
                jsonBlob: jsonBlob,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatalogBundleCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $CatalogBundleCacheTable,
      CatalogBundleCacheData,
      $$CatalogBundleCacheTableFilterComposer,
      $$CatalogBundleCacheTableOrderingComposer,
      $$CatalogBundleCacheTableAnnotationComposer,
      $$CatalogBundleCacheTableCreateCompanionBuilder,
      $$CatalogBundleCacheTableUpdateCompanionBuilder,
      (
        CatalogBundleCacheData,
        BaseReferences<
          _$AppDb,
          $CatalogBundleCacheTable,
          CatalogBundleCacheData
        >,
      ),
      CatalogBundleCacheData,
      PrefetchHooks Function()
    >;
typedef $$ActivitiesTableCreateCompanionBuilder =
    ActivitiesCompanion Function({
      required String id,
      required String projectId,
      Value<String?> segmentId,
      required String activityTypeId,
      Value<String?> catalogVersionId,
      required String title,
      Value<String?> description,
      Value<int?> pk,
      Value<String?> pkRefType,
      required DateTime createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> finishedAt,
      required String createdByUserId,
      Value<String?> assignedToUserId,
      Value<String> status,
      Value<double?> geoLat,
      Value<double?> geoLon,
      Value<double?> geoAccuracy,
      Value<String?> deviceId,
      Value<int> localRevision,
      Value<int?> serverRevision,
      Value<int> rowid,
    });
typedef $$ActivitiesTableUpdateCompanionBuilder =
    ActivitiesCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String?> segmentId,
      Value<String> activityTypeId,
      Value<String?> catalogVersionId,
      Value<String> title,
      Value<String?> description,
      Value<int?> pk,
      Value<String?> pkRefType,
      Value<DateTime> createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> finishedAt,
      Value<String> createdByUserId,
      Value<String?> assignedToUserId,
      Value<String> status,
      Value<double?> geoLat,
      Value<double?> geoLon,
      Value<double?> geoAccuracy,
      Value<String?> deviceId,
      Value<int> localRevision,
      Value<int?> serverRevision,
      Value<int> rowid,
    });

final class $$ActivitiesTableReferences
    extends BaseReferences<_$AppDb, $ActivitiesTable, Activity> {
  $$ActivitiesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDb db) => db.projects.createAlias(
    $_aliasNameGenerator(db.activities.projectId, db.projects.id),
  );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProjectSegmentsTable _segmentIdTable(_$AppDb db) =>
      db.projectSegments.createAlias(
        $_aliasNameGenerator(db.activities.segmentId, db.projectSegments.id),
      );

  $$ProjectSegmentsTableProcessedTableManager? get segmentId {
    final $_column = $_itemColumn<String>('segment_id');
    if ($_column == null) return null;
    final manager = $$ProjectSegmentsTableTableManager(
      $_db,
      $_db.projectSegments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_segmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CatalogActivityTypesTable _activityTypeIdTable(_$AppDb db) =>
      db.catalogActivityTypes.createAlias(
        $_aliasNameGenerator(
          db.activities.activityTypeId,
          db.catalogActivityTypes.id,
        ),
      );

  $$CatalogActivityTypesTableProcessedTableManager get activityTypeId {
    final $_column = $_itemColumn<String>('activity_type_id')!;

    final manager = $$CatalogActivityTypesTableTableManager(
      $_db,
      $_db.catalogActivityTypes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_activityTypeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UsersTable _createdByUserIdTable(_$AppDb db) => db.users.createAlias(
    $_aliasNameGenerator(db.activities.createdByUserId, db.users.id),
  );

  $$UsersTableProcessedTableManager get createdByUserId {
    final $_column = $_itemColumn<String>('created_by_user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_createdByUserIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UsersTable _assignedToUserIdTable(_$AppDb db) => db.users.createAlias(
    $_aliasNameGenerator(db.activities.assignedToUserId, db.users.id),
  );

  $$UsersTableProcessedTableManager? get assignedToUserId {
    final $_column = $_itemColumn<String>('assigned_to_user_id');
    if ($_column == null) return null;
    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_assignedToUserIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ActivityFieldsTable, List<ActivityField>>
  _activityFieldsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.activityFields,
    aliasName: $_aliasNameGenerator(
      db.activities.id,
      db.activityFields.activityId,
    ),
  );

  $$ActivityFieldsTableProcessedTableManager get activityFieldsRefs {
    final manager = $$ActivityFieldsTableTableManager(
      $_db,
      $_db.activityFields,
    ).filter((f) => f.activityId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_activityFieldsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ActivityLogTable, List<ActivityLogData>>
  _activityLogRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.activityLog,
    aliasName: $_aliasNameGenerator(
      db.activities.id,
      db.activityLog.activityId,
    ),
  );

  $$ActivityLogTableProcessedTableManager get activityLogRefs {
    final manager = $$ActivityLogTableTableManager(
      $_db,
      $_db.activityLog,
    ).filter((f) => f.activityId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_activityLogRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EvidencesTable, List<Evidence>>
  _evidencesRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.evidences,
    aliasName: $_aliasNameGenerator(db.activities.id, db.evidences.activityId),
  );

  $$EvidencesTableProcessedTableManager get evidencesRefs {
    final manager = $$EvidencesTableTableManager(
      $_db,
      $_db.evidences,
    ).filter((f) => f.activityId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_evidencesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ActivitiesTableFilterComposer
    extends Composer<_$AppDb, $ActivitiesTable> {
  $$ActivitiesTableFilterComposer({
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

  ColumnFilters<String> get catalogVersionId => $composableBuilder(
    column: $table.catalogVersionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pk => $composableBuilder(
    column: $table.pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pkRefType => $composableBuilder(
    column: $table.pkRefType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get geoLat => $composableBuilder(
    column: $table.geoLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get geoLon => $composableBuilder(
    column: $table.geoLon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get geoAccuracy => $composableBuilder(
    column: $table.geoAccuracy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localRevision => $composableBuilder(
    column: $table.localRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectSegmentsTableFilterComposer get segmentId {
    final $$ProjectSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.segmentId,
      referencedTable: $db.projectSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.projectSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CatalogActivityTypesTableFilterComposer get activityTypeId {
    final $$CatalogActivityTypesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityTypeId,
      referencedTable: $db.catalogActivityTypes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogActivityTypesTableFilterComposer(
            $db: $db,
            $table: $db.catalogActivityTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableFilterComposer get createdByUserId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.createdByUserId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableFilterComposer get assignedToUserId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assignedToUserId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> activityFieldsRefs(
    Expression<bool> Function($$ActivityFieldsTableFilterComposer f) f,
  ) {
    final $$ActivityFieldsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activityFields,
      getReferencedColumn: (t) => t.activityId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivityFieldsTableFilterComposer(
            $db: $db,
            $table: $db.activityFields,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> activityLogRefs(
    Expression<bool> Function($$ActivityLogTableFilterComposer f) f,
  ) {
    final $$ActivityLogTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activityLog,
      getReferencedColumn: (t) => t.activityId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivityLogTableFilterComposer(
            $db: $db,
            $table: $db.activityLog,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> evidencesRefs(
    Expression<bool> Function($$EvidencesTableFilterComposer f) f,
  ) {
    final $$EvidencesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.evidences,
      getReferencedColumn: (t) => t.activityId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EvidencesTableFilterComposer(
            $db: $db,
            $table: $db.evidences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ActivitiesTableOrderingComposer
    extends Composer<_$AppDb, $ActivitiesTable> {
  $$ActivitiesTableOrderingComposer({
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

  ColumnOrderings<String> get catalogVersionId => $composableBuilder(
    column: $table.catalogVersionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pk => $composableBuilder(
    column: $table.pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pkRefType => $composableBuilder(
    column: $table.pkRefType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get geoLat => $composableBuilder(
    column: $table.geoLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get geoLon => $composableBuilder(
    column: $table.geoLon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get geoAccuracy => $composableBuilder(
    column: $table.geoAccuracy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localRevision => $composableBuilder(
    column: $table.localRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectSegmentsTableOrderingComposer get segmentId {
    final $$ProjectSegmentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.segmentId,
      referencedTable: $db.projectSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectSegmentsTableOrderingComposer(
            $db: $db,
            $table: $db.projectSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CatalogActivityTypesTableOrderingComposer get activityTypeId {
    final $$CatalogActivityTypesTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.activityTypeId,
          referencedTable: $db.catalogActivityTypes,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CatalogActivityTypesTableOrderingComposer(
                $db: $db,
                $table: $db.catalogActivityTypes,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$UsersTableOrderingComposer get createdByUserId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.createdByUserId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableOrderingComposer get assignedToUserId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assignedToUserId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActivitiesTableAnnotationComposer
    extends Composer<_$AppDb, $ActivitiesTable> {
  $$ActivitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get catalogVersionId => $composableBuilder(
    column: $table.catalogVersionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pk =>
      $composableBuilder(column: $table.pk, builder: (column) => column);

  GeneratedColumn<String> get pkRefType =>
      $composableBuilder(column: $table.pkRefType, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get geoLat =>
      $composableBuilder(column: $table.geoLat, builder: (column) => column);

  GeneratedColumn<double> get geoLon =>
      $composableBuilder(column: $table.geoLon, builder: (column) => column);

  GeneratedColumn<double> get geoAccuracy => $composableBuilder(
    column: $table.geoAccuracy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get localRevision => $composableBuilder(
    column: $table.localRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => column,
  );

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectSegmentsTableAnnotationComposer get segmentId {
    final $$ProjectSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.segmentId,
      referencedTable: $db.projectSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.projectSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CatalogActivityTypesTableAnnotationComposer get activityTypeId {
    final $$CatalogActivityTypesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.activityTypeId,
          referencedTable: $db.catalogActivityTypes,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CatalogActivityTypesTableAnnotationComposer(
                $db: $db,
                $table: $db.catalogActivityTypes,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$UsersTableAnnotationComposer get createdByUserId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.createdByUserId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableAnnotationComposer get assignedToUserId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assignedToUserId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> activityFieldsRefs<T extends Object>(
    Expression<T> Function($$ActivityFieldsTableAnnotationComposer a) f,
  ) {
    final $$ActivityFieldsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activityFields,
      getReferencedColumn: (t) => t.activityId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivityFieldsTableAnnotationComposer(
            $db: $db,
            $table: $db.activityFields,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> activityLogRefs<T extends Object>(
    Expression<T> Function($$ActivityLogTableAnnotationComposer a) f,
  ) {
    final $$ActivityLogTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activityLog,
      getReferencedColumn: (t) => t.activityId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivityLogTableAnnotationComposer(
            $db: $db,
            $table: $db.activityLog,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> evidencesRefs<T extends Object>(
    Expression<T> Function($$EvidencesTableAnnotationComposer a) f,
  ) {
    final $$EvidencesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.evidences,
      getReferencedColumn: (t) => t.activityId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EvidencesTableAnnotationComposer(
            $db: $db,
            $table: $db.evidences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ActivitiesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ActivitiesTable,
          Activity,
          $$ActivitiesTableFilterComposer,
          $$ActivitiesTableOrderingComposer,
          $$ActivitiesTableAnnotationComposer,
          $$ActivitiesTableCreateCompanionBuilder,
          $$ActivitiesTableUpdateCompanionBuilder,
          (Activity, $$ActivitiesTableReferences),
          Activity,
          PrefetchHooks Function({
            bool projectId,
            bool segmentId,
            bool activityTypeId,
            bool createdByUserId,
            bool assignedToUserId,
            bool activityFieldsRefs,
            bool activityLogRefs,
            bool evidencesRefs,
          })
        > {
  $$ActivitiesTableTableManager(_$AppDb db, $ActivitiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String?> segmentId = const Value.absent(),
                Value<String> activityTypeId = const Value.absent(),
                Value<String?> catalogVersionId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int?> pk = const Value.absent(),
                Value<String?> pkRefType = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<String> createdByUserId = const Value.absent(),
                Value<String?> assignedToUserId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double?> geoLat = const Value.absent(),
                Value<double?> geoLon = const Value.absent(),
                Value<double?> geoAccuracy = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<int> localRevision = const Value.absent(),
                Value<int?> serverRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivitiesCompanion(
                id: id,
                projectId: projectId,
                segmentId: segmentId,
                activityTypeId: activityTypeId,
                catalogVersionId: catalogVersionId,
                title: title,
                description: description,
                pk: pk,
                pkRefType: pkRefType,
                createdAt: createdAt,
                startedAt: startedAt,
                finishedAt: finishedAt,
                createdByUserId: createdByUserId,
                assignedToUserId: assignedToUserId,
                status: status,
                geoLat: geoLat,
                geoLon: geoLon,
                geoAccuracy: geoAccuracy,
                deviceId: deviceId,
                localRevision: localRevision,
                serverRevision: serverRevision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                Value<String?> segmentId = const Value.absent(),
                required String activityTypeId,
                Value<String?> catalogVersionId = const Value.absent(),
                required String title,
                Value<String?> description = const Value.absent(),
                Value<int?> pk = const Value.absent(),
                Value<String?> pkRefType = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                required String createdByUserId,
                Value<String?> assignedToUserId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double?> geoLat = const Value.absent(),
                Value<double?> geoLon = const Value.absent(),
                Value<double?> geoAccuracy = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<int> localRevision = const Value.absent(),
                Value<int?> serverRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivitiesCompanion.insert(
                id: id,
                projectId: projectId,
                segmentId: segmentId,
                activityTypeId: activityTypeId,
                catalogVersionId: catalogVersionId,
                title: title,
                description: description,
                pk: pk,
                pkRefType: pkRefType,
                createdAt: createdAt,
                startedAt: startedAt,
                finishedAt: finishedAt,
                createdByUserId: createdByUserId,
                assignedToUserId: assignedToUserId,
                status: status,
                geoLat: geoLat,
                geoLon: geoLon,
                geoAccuracy: geoAccuracy,
                deviceId: deviceId,
                localRevision: localRevision,
                serverRevision: serverRevision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ActivitiesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                projectId = false,
                segmentId = false,
                activityTypeId = false,
                createdByUserId = false,
                assignedToUserId = false,
                activityFieldsRefs = false,
                activityLogRefs = false,
                evidencesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (activityFieldsRefs) db.activityFields,
                    if (activityLogRefs) db.activityLog,
                    if (evidencesRefs) db.evidences,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable: $$ActivitiesTableReferences
                                        ._projectIdTable(db),
                                    referencedColumn:
                                        $$ActivitiesTableReferences
                                            ._projectIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (segmentId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.segmentId,
                                    referencedTable: $$ActivitiesTableReferences
                                        ._segmentIdTable(db),
                                    referencedColumn:
                                        $$ActivitiesTableReferences
                                            ._segmentIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (activityTypeId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.activityTypeId,
                                    referencedTable: $$ActivitiesTableReferences
                                        ._activityTypeIdTable(db),
                                    referencedColumn:
                                        $$ActivitiesTableReferences
                                            ._activityTypeIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (createdByUserId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.createdByUserId,
                                    referencedTable: $$ActivitiesTableReferences
                                        ._createdByUserIdTable(db),
                                    referencedColumn:
                                        $$ActivitiesTableReferences
                                            ._createdByUserIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (assignedToUserId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.assignedToUserId,
                                    referencedTable: $$ActivitiesTableReferences
                                        ._assignedToUserIdTable(db),
                                    referencedColumn:
                                        $$ActivitiesTableReferences
                                            ._assignedToUserIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (activityFieldsRefs)
                        await $_getPrefetchedData<
                          Activity,
                          $ActivitiesTable,
                          ActivityField
                        >(
                          currentTable: table,
                          referencedTable: $$ActivitiesTableReferences
                              ._activityFieldsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ActivitiesTableReferences(
                                db,
                                table,
                                p0,
                              ).activityFieldsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.activityId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (activityLogRefs)
                        await $_getPrefetchedData<
                          Activity,
                          $ActivitiesTable,
                          ActivityLogData
                        >(
                          currentTable: table,
                          referencedTable: $$ActivitiesTableReferences
                              ._activityLogRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ActivitiesTableReferences(
                                db,
                                table,
                                p0,
                              ).activityLogRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.activityId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (evidencesRefs)
                        await $_getPrefetchedData<
                          Activity,
                          $ActivitiesTable,
                          Evidence
                        >(
                          currentTable: table,
                          referencedTable: $$ActivitiesTableReferences
                              ._evidencesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ActivitiesTableReferences(
                                db,
                                table,
                                p0,
                              ).evidencesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.activityId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ActivitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ActivitiesTable,
      Activity,
      $$ActivitiesTableFilterComposer,
      $$ActivitiesTableOrderingComposer,
      $$ActivitiesTableAnnotationComposer,
      $$ActivitiesTableCreateCompanionBuilder,
      $$ActivitiesTableUpdateCompanionBuilder,
      (Activity, $$ActivitiesTableReferences),
      Activity,
      PrefetchHooks Function({
        bool projectId,
        bool segmentId,
        bool activityTypeId,
        bool createdByUserId,
        bool assignedToUserId,
        bool activityFieldsRefs,
        bool activityLogRefs,
        bool evidencesRefs,
      })
    >;
typedef $$ActivityFieldsTableCreateCompanionBuilder =
    ActivityFieldsCompanion Function({
      required String id,
      required String activityId,
      required String fieldKey,
      Value<String?> valueText,
      Value<double?> valueNumber,
      Value<DateTime?> valueDate,
      Value<String?> valueJson,
      Value<int> rowid,
    });
typedef $$ActivityFieldsTableUpdateCompanionBuilder =
    ActivityFieldsCompanion Function({
      Value<String> id,
      Value<String> activityId,
      Value<String> fieldKey,
      Value<String?> valueText,
      Value<double?> valueNumber,
      Value<DateTime?> valueDate,
      Value<String?> valueJson,
      Value<int> rowid,
    });

final class $$ActivityFieldsTableReferences
    extends BaseReferences<_$AppDb, $ActivityFieldsTable, ActivityField> {
  $$ActivityFieldsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ActivitiesTable _activityIdTable(_$AppDb db) =>
      db.activities.createAlias(
        $_aliasNameGenerator(db.activityFields.activityId, db.activities.id),
      );

  $$ActivitiesTableProcessedTableManager get activityId {
    final $_column = $_itemColumn<String>('activity_id')!;

    final manager = $$ActivitiesTableTableManager(
      $_db,
      $_db.activities,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_activityIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ActivityFieldsTableFilterComposer
    extends Composer<_$AppDb, $ActivityFieldsTable> {
  $$ActivityFieldsTableFilterComposer({
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

  ColumnFilters<String> get fieldKey => $composableBuilder(
    column: $table.fieldKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueText => $composableBuilder(
    column: $table.valueText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get valueNumber => $composableBuilder(
    column: $table.valueNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get valueDate => $composableBuilder(
    column: $table.valueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );

  $$ActivitiesTableFilterComposer get activityId {
    final $$ActivitiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableFilterComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActivityFieldsTableOrderingComposer
    extends Composer<_$AppDb, $ActivityFieldsTable> {
  $$ActivityFieldsTableOrderingComposer({
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

  ColumnOrderings<String> get fieldKey => $composableBuilder(
    column: $table.fieldKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueText => $composableBuilder(
    column: $table.valueText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get valueNumber => $composableBuilder(
    column: $table.valueNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get valueDate => $composableBuilder(
    column: $table.valueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$ActivitiesTableOrderingComposer get activityId {
    final $$ActivitiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableOrderingComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActivityFieldsTableAnnotationComposer
    extends Composer<_$AppDb, $ActivityFieldsTable> {
  $$ActivityFieldsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fieldKey =>
      $composableBuilder(column: $table.fieldKey, builder: (column) => column);

  GeneratedColumn<String> get valueText =>
      $composableBuilder(column: $table.valueText, builder: (column) => column);

  GeneratedColumn<double> get valueNumber => $composableBuilder(
    column: $table.valueNumber,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get valueDate =>
      $composableBuilder(column: $table.valueDate, builder: (column) => column);

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);

  $$ActivitiesTableAnnotationComposer get activityId {
    final $$ActivitiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableAnnotationComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActivityFieldsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ActivityFieldsTable,
          ActivityField,
          $$ActivityFieldsTableFilterComposer,
          $$ActivityFieldsTableOrderingComposer,
          $$ActivityFieldsTableAnnotationComposer,
          $$ActivityFieldsTableCreateCompanionBuilder,
          $$ActivityFieldsTableUpdateCompanionBuilder,
          (ActivityField, $$ActivityFieldsTableReferences),
          ActivityField,
          PrefetchHooks Function({bool activityId})
        > {
  $$ActivityFieldsTableTableManager(_$AppDb db, $ActivityFieldsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivityFieldsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivityFieldsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivityFieldsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> activityId = const Value.absent(),
                Value<String> fieldKey = const Value.absent(),
                Value<String?> valueText = const Value.absent(),
                Value<double?> valueNumber = const Value.absent(),
                Value<DateTime?> valueDate = const Value.absent(),
                Value<String?> valueJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivityFieldsCompanion(
                id: id,
                activityId: activityId,
                fieldKey: fieldKey,
                valueText: valueText,
                valueNumber: valueNumber,
                valueDate: valueDate,
                valueJson: valueJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String activityId,
                required String fieldKey,
                Value<String?> valueText = const Value.absent(),
                Value<double?> valueNumber = const Value.absent(),
                Value<DateTime?> valueDate = const Value.absent(),
                Value<String?> valueJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivityFieldsCompanion.insert(
                id: id,
                activityId: activityId,
                fieldKey: fieldKey,
                valueText: valueText,
                valueNumber: valueNumber,
                valueDate: valueDate,
                valueJson: valueJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ActivityFieldsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({activityId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (activityId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.activityId,
                                referencedTable: $$ActivityFieldsTableReferences
                                    ._activityIdTable(db),
                                referencedColumn:
                                    $$ActivityFieldsTableReferences
                                        ._activityIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ActivityFieldsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ActivityFieldsTable,
      ActivityField,
      $$ActivityFieldsTableFilterComposer,
      $$ActivityFieldsTableOrderingComposer,
      $$ActivityFieldsTableAnnotationComposer,
      $$ActivityFieldsTableCreateCompanionBuilder,
      $$ActivityFieldsTableUpdateCompanionBuilder,
      (ActivityField, $$ActivityFieldsTableReferences),
      ActivityField,
      PrefetchHooks Function({bool activityId})
    >;
typedef $$ActivityLogTableCreateCompanionBuilder =
    ActivityLogCompanion Function({
      required String id,
      required String activityId,
      required String eventType,
      required DateTime at,
      required String userId,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$ActivityLogTableUpdateCompanionBuilder =
    ActivityLogCompanion Function({
      Value<String> id,
      Value<String> activityId,
      Value<String> eventType,
      Value<DateTime> at,
      Value<String> userId,
      Value<String?> note,
      Value<int> rowid,
    });

final class $$ActivityLogTableReferences
    extends BaseReferences<_$AppDb, $ActivityLogTable, ActivityLogData> {
  $$ActivityLogTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ActivitiesTable _activityIdTable(_$AppDb db) =>
      db.activities.createAlias(
        $_aliasNameGenerator(db.activityLog.activityId, db.activities.id),
      );

  $$ActivitiesTableProcessedTableManager get activityId {
    final $_column = $_itemColumn<String>('activity_id')!;

    final manager = $$ActivitiesTableTableManager(
      $_db,
      $_db.activities,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_activityIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UsersTable _userIdTable(_$AppDb db) => db.users.createAlias(
    $_aliasNameGenerator(db.activityLog.userId, db.users.id),
  );

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ActivityLogTableFilterComposer
    extends Composer<_$AppDb, $ActivityLogTable> {
  $$ActivityLogTableFilterComposer({
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

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$ActivitiesTableFilterComposer get activityId {
    final $$ActivitiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableFilterComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActivityLogTableOrderingComposer
    extends Composer<_$AppDb, $ActivityLogTable> {
  $$ActivityLogTableOrderingComposer({
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

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$ActivitiesTableOrderingComposer get activityId {
    final $$ActivitiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableOrderingComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActivityLogTableAnnotationComposer
    extends Composer<_$AppDb, $ActivityLogTable> {
  $$ActivityLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$ActivitiesTableAnnotationComposer get activityId {
    final $$ActivitiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableAnnotationComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActivityLogTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ActivityLogTable,
          ActivityLogData,
          $$ActivityLogTableFilterComposer,
          $$ActivityLogTableOrderingComposer,
          $$ActivityLogTableAnnotationComposer,
          $$ActivityLogTableCreateCompanionBuilder,
          $$ActivityLogTableUpdateCompanionBuilder,
          (ActivityLogData, $$ActivityLogTableReferences),
          ActivityLogData,
          PrefetchHooks Function({bool activityId, bool userId})
        > {
  $$ActivityLogTableTableManager(_$AppDb db, $ActivityLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivityLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivityLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivityLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> activityId = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivityLogCompanion(
                id: id,
                activityId: activityId,
                eventType: eventType,
                at: at,
                userId: userId,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String activityId,
                required String eventType,
                required DateTime at,
                required String userId,
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivityLogCompanion.insert(
                id: id,
                activityId: activityId,
                eventType: eventType,
                at: at,
                userId: userId,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ActivityLogTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({activityId = false, userId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (activityId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.activityId,
                                referencedTable: $$ActivityLogTableReferences
                                    ._activityIdTable(db),
                                referencedColumn: $$ActivityLogTableReferences
                                    ._activityIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$ActivityLogTableReferences
                                    ._userIdTable(db),
                                referencedColumn: $$ActivityLogTableReferences
                                    ._userIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ActivityLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ActivityLogTable,
      ActivityLogData,
      $$ActivityLogTableFilterComposer,
      $$ActivityLogTableOrderingComposer,
      $$ActivityLogTableAnnotationComposer,
      $$ActivityLogTableCreateCompanionBuilder,
      $$ActivityLogTableUpdateCompanionBuilder,
      (ActivityLogData, $$ActivityLogTableReferences),
      ActivityLogData,
      PrefetchHooks Function({bool activityId, bool userId})
    >;
typedef $$LocalAssignmentsTableCreateCompanionBuilder =
    LocalAssignmentsCompanion Function({
      required String id,
      required String projectId,
      required String assigneeUserId,
      required String activityTypeCode,
      Value<String?> title,
      Value<String?> description,
      Value<String?> frontId,
      Value<String?> frontRef,
      Value<String?> estado,
      Value<String?> municipio,
      Value<String?> colonia,
      Value<int> pk,
      required DateTime startAt,
      required DateTime endAt,
      Value<String> risk,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<String> syncStatus,
      Value<String?> syncError,
      Value<int> syncRetryCount,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> syncedAt,
      Value<String?> backendActivityId,
      Value<int> rowid,
    });
typedef $$LocalAssignmentsTableUpdateCompanionBuilder =
    LocalAssignmentsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> assigneeUserId,
      Value<String> activityTypeCode,
      Value<String?> title,
      Value<String?> description,
      Value<String?> frontId,
      Value<String?> frontRef,
      Value<String?> estado,
      Value<String?> municipio,
      Value<String?> colonia,
      Value<int> pk,
      Value<DateTime> startAt,
      Value<DateTime> endAt,
      Value<String> risk,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<String> syncStatus,
      Value<String?> syncError,
      Value<int> syncRetryCount,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> syncedAt,
      Value<String?> backendActivityId,
      Value<int> rowid,
    });

final class $$LocalAssignmentsTableReferences
    extends BaseReferences<_$AppDb, $LocalAssignmentsTable, LocalAssignment> {
  $$LocalAssignmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTable _projectIdTable(_$AppDb db) => db.projects.createAlias(
    $_aliasNameGenerator(db.localAssignments.projectId, db.projects.id),
  );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UsersTable _assigneeUserIdTable(_$AppDb db) => db.users.createAlias(
    $_aliasNameGenerator(db.localAssignments.assigneeUserId, db.users.id),
  );

  $$UsersTableProcessedTableManager get assigneeUserId {
    final $_column = $_itemColumn<String>('assignee_user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_assigneeUserIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProjectSegmentsTable _frontIdTable(_$AppDb db) =>
      db.projectSegments.createAlias(
        $_aliasNameGenerator(
          db.localAssignments.frontId,
          db.projectSegments.id,
        ),
      );

  $$ProjectSegmentsTableProcessedTableManager? get frontId {
    final $_column = $_itemColumn<String>('front_id');
    if ($_column == null) return null;
    final manager = $$ProjectSegmentsTableTableManager(
      $_db,
      $_db.projectSegments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_frontIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalAssignmentsTableFilterComposer
    extends Composer<_$AppDb, $LocalAssignmentsTable> {
  $$LocalAssignmentsTableFilterComposer({
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

  ColumnFilters<String> get activityTypeCode => $composableBuilder(
    column: $table.activityTypeCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frontRef => $composableBuilder(
    column: $table.frontRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get municipio => $composableBuilder(
    column: $table.municipio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colonia => $composableBuilder(
    column: $table.colonia,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pk => $composableBuilder(
    column: $table.pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get risk => $composableBuilder(
    column: $table.risk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncRetryCount => $composableBuilder(
    column: $table.syncRetryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backendActivityId => $composableBuilder(
    column: $table.backendActivityId,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableFilterComposer get assigneeUserId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assigneeUserId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectSegmentsTableFilterComposer get frontId {
    final $$ProjectSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.frontId,
      referencedTable: $db.projectSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.projectSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalAssignmentsTableOrderingComposer
    extends Composer<_$AppDb, $LocalAssignmentsTable> {
  $$LocalAssignmentsTableOrderingComposer({
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

  ColumnOrderings<String> get activityTypeCode => $composableBuilder(
    column: $table.activityTypeCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frontRef => $composableBuilder(
    column: $table.frontRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get municipio => $composableBuilder(
    column: $table.municipio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colonia => $composableBuilder(
    column: $table.colonia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pk => $composableBuilder(
    column: $table.pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get risk => $composableBuilder(
    column: $table.risk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncRetryCount => $composableBuilder(
    column: $table.syncRetryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backendActivityId => $composableBuilder(
    column: $table.backendActivityId,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableOrderingComposer get assigneeUserId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assigneeUserId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectSegmentsTableOrderingComposer get frontId {
    final $$ProjectSegmentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.frontId,
      referencedTable: $db.projectSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectSegmentsTableOrderingComposer(
            $db: $db,
            $table: $db.projectSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalAssignmentsTableAnnotationComposer
    extends Composer<_$AppDb, $LocalAssignmentsTable> {
  $$LocalAssignmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get activityTypeCode => $composableBuilder(
    column: $table.activityTypeCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get frontRef =>
      $composableBuilder(column: $table.frontRef, builder: (column) => column);

  GeneratedColumn<String> get estado =>
      $composableBuilder(column: $table.estado, builder: (column) => column);

  GeneratedColumn<String> get municipio =>
      $composableBuilder(column: $table.municipio, builder: (column) => column);

  GeneratedColumn<String> get colonia =>
      $composableBuilder(column: $table.colonia, builder: (column) => column);

  GeneratedColumn<int> get pk =>
      $composableBuilder(column: $table.pk, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<String> get risk =>
      $composableBuilder(column: $table.risk, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<int> get syncRetryCount => $composableBuilder(
    column: $table.syncRetryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get backendActivityId => $composableBuilder(
    column: $table.backendActivityId,
    builder: (column) => column,
  );

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableAnnotationComposer get assigneeUserId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assigneeUserId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectSegmentsTableAnnotationComposer get frontId {
    final $$ProjectSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.frontId,
      referencedTable: $db.projectSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.projectSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalAssignmentsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $LocalAssignmentsTable,
          LocalAssignment,
          $$LocalAssignmentsTableFilterComposer,
          $$LocalAssignmentsTableOrderingComposer,
          $$LocalAssignmentsTableAnnotationComposer,
          $$LocalAssignmentsTableCreateCompanionBuilder,
          $$LocalAssignmentsTableUpdateCompanionBuilder,
          (LocalAssignment, $$LocalAssignmentsTableReferences),
          LocalAssignment,
          PrefetchHooks Function({
            bool projectId,
            bool assigneeUserId,
            bool frontId,
          })
        > {
  $$LocalAssignmentsTableTableManager(_$AppDb db, $LocalAssignmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAssignmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAssignmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAssignmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> assigneeUserId = const Value.absent(),
                Value<String> activityTypeCode = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> frontId = const Value.absent(),
                Value<String?> frontRef = const Value.absent(),
                Value<String?> estado = const Value.absent(),
                Value<String?> municipio = const Value.absent(),
                Value<String?> colonia = const Value.absent(),
                Value<int> pk = const Value.absent(),
                Value<DateTime> startAt = const Value.absent(),
                Value<DateTime> endAt = const Value.absent(),
                Value<String> risk = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<int> syncRetryCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<String?> backendActivityId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAssignmentsCompanion(
                id: id,
                projectId: projectId,
                assigneeUserId: assigneeUserId,
                activityTypeCode: activityTypeCode,
                title: title,
                description: description,
                frontId: frontId,
                frontRef: frontRef,
                estado: estado,
                municipio: municipio,
                colonia: colonia,
                pk: pk,
                startAt: startAt,
                endAt: endAt,
                risk: risk,
                latitude: latitude,
                longitude: longitude,
                syncStatus: syncStatus,
                syncError: syncError,
                syncRetryCount: syncRetryCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncedAt: syncedAt,
                backendActivityId: backendActivityId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String assigneeUserId,
                required String activityTypeCode,
                Value<String?> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> frontId = const Value.absent(),
                Value<String?> frontRef = const Value.absent(),
                Value<String?> estado = const Value.absent(),
                Value<String?> municipio = const Value.absent(),
                Value<String?> colonia = const Value.absent(),
                Value<int> pk = const Value.absent(),
                required DateTime startAt,
                required DateTime endAt,
                Value<String> risk = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<int> syncRetryCount = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<String?> backendActivityId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAssignmentsCompanion.insert(
                id: id,
                projectId: projectId,
                assigneeUserId: assigneeUserId,
                activityTypeCode: activityTypeCode,
                title: title,
                description: description,
                frontId: frontId,
                frontRef: frontRef,
                estado: estado,
                municipio: municipio,
                colonia: colonia,
                pk: pk,
                startAt: startAt,
                endAt: endAt,
                risk: risk,
                latitude: latitude,
                longitude: longitude,
                syncStatus: syncStatus,
                syncError: syncError,
                syncRetryCount: syncRetryCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncedAt: syncedAt,
                backendActivityId: backendActivityId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalAssignmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({projectId = false, assigneeUserId = false, frontId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable:
                                        $$LocalAssignmentsTableReferences
                                            ._projectIdTable(db),
                                    referencedColumn:
                                        $$LocalAssignmentsTableReferences
                                            ._projectIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (assigneeUserId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.assigneeUserId,
                                    referencedTable:
                                        $$LocalAssignmentsTableReferences
                                            ._assigneeUserIdTable(db),
                                    referencedColumn:
                                        $$LocalAssignmentsTableReferences
                                            ._assigneeUserIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (frontId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.frontId,
                                    referencedTable:
                                        $$LocalAssignmentsTableReferences
                                            ._frontIdTable(db),
                                    referencedColumn:
                                        $$LocalAssignmentsTableReferences
                                            ._frontIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$LocalAssignmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $LocalAssignmentsTable,
      LocalAssignment,
      $$LocalAssignmentsTableFilterComposer,
      $$LocalAssignmentsTableOrderingComposer,
      $$LocalAssignmentsTableAnnotationComposer,
      $$LocalAssignmentsTableCreateCompanionBuilder,
      $$LocalAssignmentsTableUpdateCompanionBuilder,
      (LocalAssignment, $$LocalAssignmentsTableReferences),
      LocalAssignment,
      PrefetchHooks Function({
        bool projectId,
        bool assigneeUserId,
        bool frontId,
      })
    >;
typedef $$EvidencesTableCreateCompanionBuilder =
    EvidencesCompanion Function({
      required String id,
      required String activityId,
      required String type,
      required String filePathLocal,
      Value<String?> fileHash,
      Value<DateTime?> takenAt,
      Value<double?> geoLat,
      Value<double?> geoLon,
      Value<String?> caption,
      Value<String> status,
      Value<int> rowid,
    });
typedef $$EvidencesTableUpdateCompanionBuilder =
    EvidencesCompanion Function({
      Value<String> id,
      Value<String> activityId,
      Value<String> type,
      Value<String> filePathLocal,
      Value<String?> fileHash,
      Value<DateTime?> takenAt,
      Value<double?> geoLat,
      Value<double?> geoLon,
      Value<String?> caption,
      Value<String> status,
      Value<int> rowid,
    });

final class $$EvidencesTableReferences
    extends BaseReferences<_$AppDb, $EvidencesTable, Evidence> {
  $$EvidencesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ActivitiesTable _activityIdTable(_$AppDb db) =>
      db.activities.createAlias(
        $_aliasNameGenerator(db.evidences.activityId, db.activities.id),
      );

  $$ActivitiesTableProcessedTableManager get activityId {
    final $_column = $_itemColumn<String>('activity_id')!;

    final manager = $$ActivitiesTableTableManager(
      $_db,
      $_db.activities,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_activityIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EvidencesTableFilterComposer
    extends Composer<_$AppDb, $EvidencesTable> {
  $$EvidencesTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePathLocal => $composableBuilder(
    column: $table.filePathLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get geoLat => $composableBuilder(
    column: $table.geoLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get geoLon => $composableBuilder(
    column: $table.geoLon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  $$ActivitiesTableFilterComposer get activityId {
    final $$ActivitiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableFilterComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EvidencesTableOrderingComposer
    extends Composer<_$AppDb, $EvidencesTable> {
  $$EvidencesTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePathLocal => $composableBuilder(
    column: $table.filePathLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get geoLat => $composableBuilder(
    column: $table.geoLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get geoLon => $composableBuilder(
    column: $table.geoLon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  $$ActivitiesTableOrderingComposer get activityId {
    final $$ActivitiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableOrderingComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EvidencesTableAnnotationComposer
    extends Composer<_$AppDb, $EvidencesTable> {
  $$EvidencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get filePathLocal => $composableBuilder(
    column: $table.filePathLocal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileHash =>
      $composableBuilder(column: $table.fileHash, builder: (column) => column);

  GeneratedColumn<DateTime> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);

  GeneratedColumn<double> get geoLat =>
      $composableBuilder(column: $table.geoLat, builder: (column) => column);

  GeneratedColumn<double> get geoLon =>
      $composableBuilder(column: $table.geoLon, builder: (column) => column);

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  $$ActivitiesTableAnnotationComposer get activityId {
    final $$ActivitiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableAnnotationComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EvidencesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $EvidencesTable,
          Evidence,
          $$EvidencesTableFilterComposer,
          $$EvidencesTableOrderingComposer,
          $$EvidencesTableAnnotationComposer,
          $$EvidencesTableCreateCompanionBuilder,
          $$EvidencesTableUpdateCompanionBuilder,
          (Evidence, $$EvidencesTableReferences),
          Evidence,
          PrefetchHooks Function({bool activityId})
        > {
  $$EvidencesTableTableManager(_$AppDb db, $EvidencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EvidencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EvidencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EvidencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> activityId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> filePathLocal = const Value.absent(),
                Value<String?> fileHash = const Value.absent(),
                Value<DateTime?> takenAt = const Value.absent(),
                Value<double?> geoLat = const Value.absent(),
                Value<double?> geoLon = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EvidencesCompanion(
                id: id,
                activityId: activityId,
                type: type,
                filePathLocal: filePathLocal,
                fileHash: fileHash,
                takenAt: takenAt,
                geoLat: geoLat,
                geoLon: geoLon,
                caption: caption,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String activityId,
                required String type,
                required String filePathLocal,
                Value<String?> fileHash = const Value.absent(),
                Value<DateTime?> takenAt = const Value.absent(),
                Value<double?> geoLat = const Value.absent(),
                Value<double?> geoLon = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EvidencesCompanion.insert(
                id: id,
                activityId: activityId,
                type: type,
                filePathLocal: filePathLocal,
                fileHash: fileHash,
                takenAt: takenAt,
                geoLat: geoLat,
                geoLon: geoLon,
                caption: caption,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EvidencesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({activityId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (activityId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.activityId,
                                referencedTable: $$EvidencesTableReferences
                                    ._activityIdTable(db),
                                referencedColumn: $$EvidencesTableReferences
                                    ._activityIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EvidencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $EvidencesTable,
      Evidence,
      $$EvidencesTableFilterComposer,
      $$EvidencesTableOrderingComposer,
      $$EvidencesTableAnnotationComposer,
      $$EvidencesTableCreateCompanionBuilder,
      $$EvidencesTableUpdateCompanionBuilder,
      (Evidence, $$EvidencesTableReferences),
      Evidence,
      PrefetchHooks Function({bool activityId})
    >;
typedef $$PendingUploadsTableCreateCompanionBuilder =
    PendingUploadsCompanion Function({
      required String id,
      required String activityId,
      required String localPath,
      required String fileName,
      required String mimeType,
      required int sizeBytes,
      Value<String?> evidenceId,
      Value<String?> objectPath,
      Value<String?> signedUrl,
      Value<String> status,
      Value<int> attempts,
      Value<DateTime?> nextRetryAt,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$PendingUploadsTableUpdateCompanionBuilder =
    PendingUploadsCompanion Function({
      Value<String> id,
      Value<String> activityId,
      Value<String> localPath,
      Value<String> fileName,
      Value<String> mimeType,
      Value<int> sizeBytes,
      Value<String?> evidenceId,
      Value<String?> objectPath,
      Value<String?> signedUrl,
      Value<String> status,
      Value<int> attempts,
      Value<DateTime?> nextRetryAt,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PendingUploadsTableFilterComposer
    extends Composer<_$AppDb, $PendingUploadsTable> {
  $$PendingUploadsTableFilterComposer({
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

  ColumnFilters<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidenceId => $composableBuilder(
    column: $table.evidenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get objectPath => $composableBuilder(
    column: $table.objectPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signedUrl => $composableBuilder(
    column: $table.signedUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingUploadsTableOrderingComposer
    extends Composer<_$AppDb, $PendingUploadsTable> {
  $$PendingUploadsTableOrderingComposer({
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

  ColumnOrderings<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidenceId => $composableBuilder(
    column: $table.evidenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get objectPath => $composableBuilder(
    column: $table.objectPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signedUrl => $composableBuilder(
    column: $table.signedUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingUploadsTableAnnotationComposer
    extends Composer<_$AppDb, $PendingUploadsTable> {
  $$PendingUploadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get evidenceId => $composableBuilder(
    column: $table.evidenceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get objectPath => $composableBuilder(
    column: $table.objectPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get signedUrl =>
      $composableBuilder(column: $table.signedUrl, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PendingUploadsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $PendingUploadsTable,
          PendingUpload,
          $$PendingUploadsTableFilterComposer,
          $$PendingUploadsTableOrderingComposer,
          $$PendingUploadsTableAnnotationComposer,
          $$PendingUploadsTableCreateCompanionBuilder,
          $$PendingUploadsTableUpdateCompanionBuilder,
          (
            PendingUpload,
            BaseReferences<_$AppDb, $PendingUploadsTable, PendingUpload>,
          ),
          PendingUpload,
          PrefetchHooks Function()
        > {
  $$PendingUploadsTableTableManager(_$AppDb db, $PendingUploadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingUploadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingUploadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingUploadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> activityId = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String?> evidenceId = const Value.absent(),
                Value<String?> objectPath = const Value.absent(),
                Value<String?> signedUrl = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingUploadsCompanion(
                id: id,
                activityId: activityId,
                localPath: localPath,
                fileName: fileName,
                mimeType: mimeType,
                sizeBytes: sizeBytes,
                evidenceId: evidenceId,
                objectPath: objectPath,
                signedUrl: signedUrl,
                status: status,
                attempts: attempts,
                nextRetryAt: nextRetryAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String activityId,
                required String localPath,
                required String fileName,
                required String mimeType,
                required int sizeBytes,
                Value<String?> evidenceId = const Value.absent(),
                Value<String?> objectPath = const Value.absent(),
                Value<String?> signedUrl = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingUploadsCompanion.insert(
                id: id,
                activityId: activityId,
                localPath: localPath,
                fileName: fileName,
                mimeType: mimeType,
                sizeBytes: sizeBytes,
                evidenceId: evidenceId,
                objectPath: objectPath,
                signedUrl: signedUrl,
                status: status,
                attempts: attempts,
                nextRetryAt: nextRetryAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingUploadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $PendingUploadsTable,
      PendingUpload,
      $$PendingUploadsTableFilterComposer,
      $$PendingUploadsTableOrderingComposer,
      $$PendingUploadsTableAnnotationComposer,
      $$PendingUploadsTableCreateCompanionBuilder,
      $$PendingUploadsTableUpdateCompanionBuilder,
      (
        PendingUpload,
        BaseReferences<_$AppDb, $PendingUploadsTable, PendingUpload>,
      ),
      PendingUpload,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableCreateCompanionBuilder =
    SyncQueueCompanion Function({
      required String id,
      required String entity,
      required String entityId,
      required String action,
      required String payloadJson,
      Value<int> priority,
      Value<int> attempts,
      Value<DateTime?> lastAttemptAt,
      Value<String?> errorCode,
      Value<bool> retryable,
      Value<String?> suggestedAction,
      Value<String?> lastError,
      Value<String> status,
      Value<int> rowid,
    });
typedef $$SyncQueueTableUpdateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<String> id,
      Value<String> entity,
      Value<String> entityId,
      Value<String> action,
      Value<String> payloadJson,
      Value<int> priority,
      Value<int> attempts,
      Value<DateTime?> lastAttemptAt,
      Value<String?> errorCode,
      Value<bool> retryable,
      Value<String?> suggestedAction,
      Value<String?> lastError,
      Value<String> status,
      Value<int> rowid,
    });

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDb, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
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

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get retryable => $composableBuilder(
    column: $table.retryable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedAction => $composableBuilder(
    column: $table.suggestedAction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDb, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
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

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get retryable => $composableBuilder(
    column: $table.retryable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedAction => $composableBuilder(
    column: $table.suggestedAction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDb, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<bool> get retryable =>
      $composableBuilder(column: $table.retryable, builder: (column) => column);

  GeneratedColumn<String> get suggestedAction => $composableBuilder(
    column: $table.suggestedAction,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SyncQueueTable,
          SyncQueueData,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueData,
            BaseReferences<_$AppDb, $SyncQueueTable, SyncQueueData>,
          ),
          SyncQueueData,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$AppDb db, $SyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<bool> retryable = const Value.absent(),
                Value<String?> suggestedAction = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueCompanion(
                id: id,
                entity: entity,
                entityId: entityId,
                action: action,
                payloadJson: payloadJson,
                priority: priority,
                attempts: attempts,
                lastAttemptAt: lastAttemptAt,
                errorCode: errorCode,
                retryable: retryable,
                suggestedAction: suggestedAction,
                lastError: lastError,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String entity,
                required String entityId,
                required String action,
                required String payloadJson,
                Value<int> priority = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<bool> retryable = const Value.absent(),
                Value<String?> suggestedAction = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                id: id,
                entity: entity,
                entityId: entityId,
                action: action,
                payloadJson: payloadJson,
                priority: priority,
                attempts: attempts,
                lastAttemptAt: lastAttemptAt,
                errorCode: errorCode,
                retryable: retryable,
                suggestedAction: suggestedAction,
                lastError: lastError,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SyncQueueTable,
      SyncQueueData,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (SyncQueueData, BaseReferences<_$AppDb, $SyncQueueTable, SyncQueueData>),
      SyncQueueData,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder =
    SyncStateCompanion Function({
      Value<int> id,
      Value<DateTime?> lastSyncAt,
      Value<String?> lastServerCursor,
      Value<String> lastCatalogVersionByProjectJson,
    });
typedef $$SyncStateTableUpdateCompanionBuilder =
    SyncStateCompanion Function({
      Value<int> id,
      Value<DateTime?> lastSyncAt,
      Value<String?> lastServerCursor,
      Value<String> lastCatalogVersionByProjectJson,
    });

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDb, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
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

  ColumnFilters<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastServerCursor => $composableBuilder(
    column: $table.lastServerCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastCatalogVersionByProjectJson =>
      $composableBuilder(
        column: $table.lastCatalogVersionByProjectJson,
        builder: (column) => ColumnFilters(column),
      );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDb, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
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

  ColumnOrderings<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastServerCursor => $composableBuilder(
    column: $table.lastServerCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastCatalogVersionByProjectJson =>
      $composableBuilder(
        column: $table.lastCatalogVersionByProjectJson,
        builder: (column) => ColumnOrderings(column),
      );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDb, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastServerCursor => $composableBuilder(
    column: $table.lastServerCursor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastCatalogVersionByProjectJson =>
      $composableBuilder(
        column: $table.lastCatalogVersionByProjectJson,
        builder: (column) => column,
      );
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SyncStateTable,
          SyncStateData,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateData,
            BaseReferences<_$AppDb, $SyncStateTable, SyncStateData>,
          ),
          SyncStateData,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDb db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
                Value<String?> lastServerCursor = const Value.absent(),
                Value<String> lastCatalogVersionByProjectJson =
                    const Value.absent(),
              }) => SyncStateCompanion(
                id: id,
                lastSyncAt: lastSyncAt,
                lastServerCursor: lastServerCursor,
                lastCatalogVersionByProjectJson:
                    lastCatalogVersionByProjectJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
                Value<String?> lastServerCursor = const Value.absent(),
                Value<String> lastCatalogVersionByProjectJson =
                    const Value.absent(),
              }) => SyncStateCompanion.insert(
                id: id,
                lastSyncAt: lastSyncAt,
                lastServerCursor: lastServerCursor,
                lastCatalogVersionByProjectJson:
                    lastCatalogVersionByProjectJson,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SyncStateTable,
      SyncStateData,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (SyncStateData, BaseReferences<_$AppDb, $SyncStateTable, SyncStateData>),
      SyncStateData,
      PrefetchHooks Function()
    >;
typedef $$LocalEventsTableCreateCompanionBuilder =
    LocalEventsCompanion Function({
      required String id,
      required String projectId,
      required String eventTypeCode,
      required String title,
      Value<String?> description,
      Value<String> severity,
      Value<int?> locationPkMeters,
      required DateTime occurredAt,
      Value<DateTime?> resolvedAt,
      Value<DateTime?> deletedAt,
      required String reportedByUserId,
      Value<String?> formFieldsJson,
      Value<int> syncVersion,
      Value<int?> serverId,
      Value<String> syncStatus,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalEventsTableUpdateCompanionBuilder =
    LocalEventsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> eventTypeCode,
      Value<String> title,
      Value<String?> description,
      Value<String> severity,
      Value<int?> locationPkMeters,
      Value<DateTime> occurredAt,
      Value<DateTime?> resolvedAt,
      Value<DateTime?> deletedAt,
      Value<String> reportedByUserId,
      Value<String?> formFieldsJson,
      Value<int> syncVersion,
      Value<int?> serverId,
      Value<String> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalEventsTableFilterComposer
    extends Composer<_$AppDb, $LocalEventsTable> {
  $$LocalEventsTableFilterComposer({
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

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventTypeCode => $composableBuilder(
    column: $table.eventTypeCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get locationPkMeters => $composableBuilder(
    column: $table.locationPkMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reportedByUserId => $composableBuilder(
    column: $table.reportedByUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formFieldsJson => $composableBuilder(
    column: $table.formFieldsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalEventsTableOrderingComposer
    extends Composer<_$AppDb, $LocalEventsTable> {
  $$LocalEventsTableOrderingComposer({
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

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventTypeCode => $composableBuilder(
    column: $table.eventTypeCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get locationPkMeters => $composableBuilder(
    column: $table.locationPkMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reportedByUserId => $composableBuilder(
    column: $table.reportedByUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formFieldsJson => $composableBuilder(
    column: $table.formFieldsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalEventsTableAnnotationComposer
    extends Composer<_$AppDb, $LocalEventsTable> {
  $$LocalEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get eventTypeCode => $composableBuilder(
    column: $table.eventTypeCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<int> get locationPkMeters => $composableBuilder(
    column: $table.locationPkMeters,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get reportedByUserId => $composableBuilder(
    column: $table.reportedByUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get formFieldsJson => $composableBuilder(
    column: $table.formFieldsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalEventsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $LocalEventsTable,
          LocalEvent,
          $$LocalEventsTableFilterComposer,
          $$LocalEventsTableOrderingComposer,
          $$LocalEventsTableAnnotationComposer,
          $$LocalEventsTableCreateCompanionBuilder,
          $$LocalEventsTableUpdateCompanionBuilder,
          (LocalEvent, BaseReferences<_$AppDb, $LocalEventsTable, LocalEvent>),
          LocalEvent,
          PrefetchHooks Function()
        > {
  $$LocalEventsTableTableManager(_$AppDb db, $LocalEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> eventTypeCode = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> severity = const Value.absent(),
                Value<int?> locationPkMeters = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> reportedByUserId = const Value.absent(),
                Value<String?> formFieldsJson = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEventsCompanion(
                id: id,
                projectId: projectId,
                eventTypeCode: eventTypeCode,
                title: title,
                description: description,
                severity: severity,
                locationPkMeters: locationPkMeters,
                occurredAt: occurredAt,
                resolvedAt: resolvedAt,
                deletedAt: deletedAt,
                reportedByUserId: reportedByUserId,
                formFieldsJson: formFieldsJson,
                syncVersion: syncVersion,
                serverId: serverId,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String eventTypeCode,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<String> severity = const Value.absent(),
                Value<int?> locationPkMeters = const Value.absent(),
                required DateTime occurredAt,
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                required String reportedByUserId,
                Value<String?> formFieldsJson = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalEventsCompanion.insert(
                id: id,
                projectId: projectId,
                eventTypeCode: eventTypeCode,
                title: title,
                description: description,
                severity: severity,
                locationPkMeters: locationPkMeters,
                occurredAt: occurredAt,
                resolvedAt: resolvedAt,
                deletedAt: deletedAt,
                reportedByUserId: reportedByUserId,
                formFieldsJson: formFieldsJson,
                syncVersion: syncVersion,
                serverId: serverId,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $LocalEventsTable,
      LocalEvent,
      $$LocalEventsTableFilterComposer,
      $$LocalEventsTableOrderingComposer,
      $$LocalEventsTableAnnotationComposer,
      $$LocalEventsTableCreateCompanionBuilder,
      $$LocalEventsTableUpdateCompanionBuilder,
      (LocalEvent, BaseReferences<_$AppDb, $LocalEventsTable, LocalEvent>),
      LocalEvent,
      PrefetchHooks Function()
    >;
typedef $$AgendaAssignmentsTableCreateCompanionBuilder =
    AgendaAssignmentsCompanion Function({
      required String id,
      required String projectId,
      required String resourceId,
      Value<String?> activityId,
      required String title,
      Value<String> frente,
      Value<String> municipio,
      Value<String> estado,
      Value<int?> pk,
      required DateTime startAt,
      required DateTime endAt,
      Value<String> risk,
      Value<String> syncStatus,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$AgendaAssignmentsTableUpdateCompanionBuilder =
    AgendaAssignmentsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> resourceId,
      Value<String?> activityId,
      Value<String> title,
      Value<String> frente,
      Value<String> municipio,
      Value<String> estado,
      Value<int?> pk,
      Value<DateTime> startAt,
      Value<DateTime> endAt,
      Value<String> risk,
      Value<String> syncStatus,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AgendaAssignmentsTableFilterComposer
    extends Composer<_$AppDb, $AgendaAssignmentsTable> {
  $$AgendaAssignmentsTableFilterComposer({
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

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frente => $composableBuilder(
    column: $table.frente,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get municipio => $composableBuilder(
    column: $table.municipio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pk => $composableBuilder(
    column: $table.pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get risk => $composableBuilder(
    column: $table.risk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AgendaAssignmentsTableOrderingComposer
    extends Composer<_$AppDb, $AgendaAssignmentsTable> {
  $$AgendaAssignmentsTableOrderingComposer({
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

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frente => $composableBuilder(
    column: $table.frente,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get municipio => $composableBuilder(
    column: $table.municipio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pk => $composableBuilder(
    column: $table.pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get risk => $composableBuilder(
    column: $table.risk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AgendaAssignmentsTableAnnotationComposer
    extends Composer<_$AppDb, $AgendaAssignmentsTable> {
  $$AgendaAssignmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get frente =>
      $composableBuilder(column: $table.frente, builder: (column) => column);

  GeneratedColumn<String> get municipio =>
      $composableBuilder(column: $table.municipio, builder: (column) => column);

  GeneratedColumn<String> get estado =>
      $composableBuilder(column: $table.estado, builder: (column) => column);

  GeneratedColumn<int> get pk =>
      $composableBuilder(column: $table.pk, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<String> get risk =>
      $composableBuilder(column: $table.risk, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AgendaAssignmentsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $AgendaAssignmentsTable,
          AgendaAssignment,
          $$AgendaAssignmentsTableFilterComposer,
          $$AgendaAssignmentsTableOrderingComposer,
          $$AgendaAssignmentsTableAnnotationComposer,
          $$AgendaAssignmentsTableCreateCompanionBuilder,
          $$AgendaAssignmentsTableUpdateCompanionBuilder,
          (
            AgendaAssignment,
            BaseReferences<_$AppDb, $AgendaAssignmentsTable, AgendaAssignment>,
          ),
          AgendaAssignment,
          PrefetchHooks Function()
        > {
  $$AgendaAssignmentsTableTableManager(
    _$AppDb db,
    $AgendaAssignmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgendaAssignmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgendaAssignmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgendaAssignmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> resourceId = const Value.absent(),
                Value<String?> activityId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> frente = const Value.absent(),
                Value<String> municipio = const Value.absent(),
                Value<String> estado = const Value.absent(),
                Value<int?> pk = const Value.absent(),
                Value<DateTime> startAt = const Value.absent(),
                Value<DateTime> endAt = const Value.absent(),
                Value<String> risk = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgendaAssignmentsCompanion(
                id: id,
                projectId: projectId,
                resourceId: resourceId,
                activityId: activityId,
                title: title,
                frente: frente,
                municipio: municipio,
                estado: estado,
                pk: pk,
                startAt: startAt,
                endAt: endAt,
                risk: risk,
                syncStatus: syncStatus,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String resourceId,
                Value<String?> activityId = const Value.absent(),
                required String title,
                Value<String> frente = const Value.absent(),
                Value<String> municipio = const Value.absent(),
                Value<String> estado = const Value.absent(),
                Value<int?> pk = const Value.absent(),
                required DateTime startAt,
                required DateTime endAt,
                Value<String> risk = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgendaAssignmentsCompanion.insert(
                id: id,
                projectId: projectId,
                resourceId: resourceId,
                activityId: activityId,
                title: title,
                frente: frente,
                municipio: municipio,
                estado: estado,
                pk: pk,
                startAt: startAt,
                endAt: endAt,
                risk: risk,
                syncStatus: syncStatus,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AgendaAssignmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $AgendaAssignmentsTable,
      AgendaAssignment,
      $$AgendaAssignmentsTableFilterComposer,
      $$AgendaAssignmentsTableOrderingComposer,
      $$AgendaAssignmentsTableAnnotationComposer,
      $$AgendaAssignmentsTableCreateCompanionBuilder,
      $$AgendaAssignmentsTableUpdateCompanionBuilder,
      (
        AgendaAssignment,
        BaseReferences<_$AppDb, $AgendaAssignmentsTable, AgendaAssignment>,
      ),
      AgendaAssignment,
      PrefetchHooks Function()
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db, _db.roles);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$ProjectSegmentsTableTableManager get projectSegments =>
      $$ProjectSegmentsTableTableManager(_db, _db.projectSegments);
  $$CatalogVersionsTableTableManager get catalogVersions =>
      $$CatalogVersionsTableTableManager(_db, _db.catalogVersions);
  $$CatalogActivityTypesTableTableManager get catalogActivityTypes =>
      $$CatalogActivityTypesTableTableManager(_db, _db.catalogActivityTypes);
  $$CatalogFieldsTableTableManager get catalogFields =>
      $$CatalogFieldsTableTableManager(_db, _db.catalogFields);
  $$CatActivitiesTableTableManager get catActivities =>
      $$CatActivitiesTableTableManager(_db, _db.catActivities);
  $$CatSubcategoriesTableTableManager get catSubcategories =>
      $$CatSubcategoriesTableTableManager(_db, _db.catSubcategories);
  $$CatPurposesTableTableManager get catPurposes =>
      $$CatPurposesTableTableManager(_db, _db.catPurposes);
  $$CatTopicsTableTableManager get catTopics =>
      $$CatTopicsTableTableManager(_db, _db.catTopics);
  $$CatRelActivityTopicsTableTableManager get catRelActivityTopics =>
      $$CatRelActivityTopicsTableTableManager(_db, _db.catRelActivityTopics);
  $$CatResultsTableTableManager get catResults =>
      $$CatResultsTableTableManager(_db, _db.catResults);
  $$CatAttendeesTableTableManager get catAttendees =>
      $$CatAttendeesTableTableManager(_db, _db.catAttendees);
  $$CatalogIndexTableTableManager get catalogIndex =>
      $$CatalogIndexTableTableManager(_db, _db.catalogIndex);
  $$CatalogBundleCacheTableTableManager get catalogBundleCache =>
      $$CatalogBundleCacheTableTableManager(_db, _db.catalogBundleCache);
  $$ActivitiesTableTableManager get activities =>
      $$ActivitiesTableTableManager(_db, _db.activities);
  $$ActivityFieldsTableTableManager get activityFields =>
      $$ActivityFieldsTableTableManager(_db, _db.activityFields);
  $$ActivityLogTableTableManager get activityLog =>
      $$ActivityLogTableTableManager(_db, _db.activityLog);
  $$LocalAssignmentsTableTableManager get localAssignments =>
      $$LocalAssignmentsTableTableManager(_db, _db.localAssignments);
  $$EvidencesTableTableManager get evidences =>
      $$EvidencesTableTableManager(_db, _db.evidences);
  $$PendingUploadsTableTableManager get pendingUploads =>
      $$PendingUploadsTableTableManager(_db, _db.pendingUploads);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$LocalEventsTableTableManager get localEvents =>
      $$LocalEventsTableTableManager(_db, _db.localEvents);
  $$AgendaAssignmentsTableTableManager get agendaAssignments =>
      $$AgendaAssignmentsTableTableManager(_db, _db.agendaAssignments);
}
