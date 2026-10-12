// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ProjectsTable extends Projects
    with TableInfo<$ProjectsTable, ProjectRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _identifierMeta = const VerificationMeta(
    'identifier',
  );
  @override
  late final GeneratedColumn<String> identifier = GeneratedColumn<String>(
    'identifier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hexColorMeta = const VerificationMeta(
    'hexColor',
  );
  @override
  late final GeneratedColumn<String> hexColor = GeneratedColumn<String>(
    'hex_color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentProjectIdMeta = const VerificationMeta(
    'parentProjectId',
  );
  @override
  late final GeneratedColumn<int> parentProjectId = GeneratedColumn<int>(
    'parent_project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<double> position = GeneratedColumn<double>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<int> ownerId = GeneratedColumn<int>(
    'owner_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> created =
      GeneratedColumn<int>(
        'created',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($ProjectsTable.$convertercreatedn);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> updated =
      GeneratedColumn<int>(
        'updated',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($ProjectsTable.$converterupdatedn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    identifier,
    hexColor,
    parentProjectId,
    isArchived,
    isFavorite,
    position,
    ownerId,
    created,
    updated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
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
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('identifier')) {
      context.handle(
        _identifierMeta,
        identifier.isAcceptableOrUnknown(data['identifier']!, _identifierMeta),
      );
    } else if (isInserting) {
      context.missing(_identifierMeta);
    }
    if (data.containsKey('hex_color')) {
      context.handle(
        _hexColorMeta,
        hexColor.isAcceptableOrUnknown(data['hex_color']!, _hexColorMeta),
      );
    } else if (isInserting) {
      context.missing(_hexColorMeta);
    }
    if (data.containsKey('parent_project_id')) {
      context.handle(
        _parentProjectIdMeta,
        parentProjectId.isAcceptableOrUnknown(
          data['parent_project_id']!,
          _parentProjectIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parentProjectIdMeta);
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    } else if (isInserting) {
      context.missing(_isArchivedMeta);
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    } else if (isInserting) {
      context.missing(_isFavoriteMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      identifier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}identifier'],
      )!,
      hexColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hex_color'],
      )!,
      parentProjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_project_id'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}position'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}owner_id'],
      ),
      created: $ProjectsTable.$convertercreatedn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created'],
        ),
      ),
      updated: $ProjectsTable.$converterupdatedn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated'],
        ),
      ),
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreated = const EpochMillis();
  static TypeConverter<DateTime?, int?> $convertercreatedn =
      NullAwareTypeConverter.wrap($convertercreated);
  static TypeConverter<DateTime, int> $converterupdated = const EpochMillis();
  static TypeConverter<DateTime?, int?> $converterupdatedn =
      NullAwareTypeConverter.wrap($converterupdated);
}

class ProjectRow extends DataClass implements Insertable<ProjectRow> {
  final int id;
  final String title;
  final String description;
  final String identifier;
  final String hexColor;
  final int parentProjectId;
  final bool isArchived;
  final bool isFavorite;
  final double position;
  final int? ownerId;
  final DateTime? created;
  final DateTime? updated;
  const ProjectRow({
    required this.id,
    required this.title,
    required this.description,
    required this.identifier,
    required this.hexColor,
    required this.parentProjectId,
    required this.isArchived,
    required this.isFavorite,
    required this.position,
    this.ownerId,
    this.created,
    this.updated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['identifier'] = Variable<String>(identifier);
    map['hex_color'] = Variable<String>(hexColor);
    map['parent_project_id'] = Variable<int>(parentProjectId);
    map['is_archived'] = Variable<bool>(isArchived);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['position'] = Variable<double>(position);
    if (!nullToAbsent || ownerId != null) {
      map['owner_id'] = Variable<int>(ownerId);
    }
    if (!nullToAbsent || created != null) {
      map['created'] = Variable<int>(
        $ProjectsTable.$convertercreatedn.toSql(created),
      );
    }
    if (!nullToAbsent || updated != null) {
      map['updated'] = Variable<int>(
        $ProjectsTable.$converterupdatedn.toSql(updated),
      );
    }
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      identifier: Value(identifier),
      hexColor: Value(hexColor),
      parentProjectId: Value(parentProjectId),
      isArchived: Value(isArchived),
      isFavorite: Value(isFavorite),
      position: Value(position),
      ownerId: ownerId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerId),
      created: created == null && nullToAbsent
          ? const Value.absent()
          : Value(created),
      updated: updated == null && nullToAbsent
          ? const Value.absent()
          : Value(updated),
    );
  }

  factory ProjectRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectRow(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      identifier: serializer.fromJson<String>(json['identifier']),
      hexColor: serializer.fromJson<String>(json['hexColor']),
      parentProjectId: serializer.fromJson<int>(json['parentProjectId']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      position: serializer.fromJson<double>(json['position']),
      ownerId: serializer.fromJson<int?>(json['ownerId']),
      created: serializer.fromJson<DateTime?>(json['created']),
      updated: serializer.fromJson<DateTime?>(json['updated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'identifier': serializer.toJson<String>(identifier),
      'hexColor': serializer.toJson<String>(hexColor),
      'parentProjectId': serializer.toJson<int>(parentProjectId),
      'isArchived': serializer.toJson<bool>(isArchived),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'position': serializer.toJson<double>(position),
      'ownerId': serializer.toJson<int?>(ownerId),
      'created': serializer.toJson<DateTime?>(created),
      'updated': serializer.toJson<DateTime?>(updated),
    };
  }

  ProjectRow copyWith({
    int? id,
    String? title,
    String? description,
    String? identifier,
    String? hexColor,
    int? parentProjectId,
    bool? isArchived,
    bool? isFavorite,
    double? position,
    Value<int?> ownerId = const Value.absent(),
    Value<DateTime?> created = const Value.absent(),
    Value<DateTime?> updated = const Value.absent(),
  }) => ProjectRow(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    identifier: identifier ?? this.identifier,
    hexColor: hexColor ?? this.hexColor,
    parentProjectId: parentProjectId ?? this.parentProjectId,
    isArchived: isArchived ?? this.isArchived,
    isFavorite: isFavorite ?? this.isFavorite,
    position: position ?? this.position,
    ownerId: ownerId.present ? ownerId.value : this.ownerId,
    created: created.present ? created.value : this.created,
    updated: updated.present ? updated.value : this.updated,
  );
  ProjectRow copyWithCompanion(ProjectsCompanion data) {
    return ProjectRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      identifier: data.identifier.present
          ? data.identifier.value
          : this.identifier,
      hexColor: data.hexColor.present ? data.hexColor.value : this.hexColor,
      parentProjectId: data.parentProjectId.present
          ? data.parentProjectId.value
          : this.parentProjectId,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      position: data.position.present ? data.position.value : this.position,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      created: data.created.present ? data.created.value : this.created,
      updated: data.updated.present ? data.updated.value : this.updated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('identifier: $identifier, ')
          ..write('hexColor: $hexColor, ')
          ..write('parentProjectId: $parentProjectId, ')
          ..write('isArchived: $isArchived, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('position: $position, ')
          ..write('ownerId: $ownerId, ')
          ..write('created: $created, ')
          ..write('updated: $updated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    identifier,
    hexColor,
    parentProjectId,
    isArchived,
    isFavorite,
    position,
    ownerId,
    created,
    updated,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.identifier == this.identifier &&
          other.hexColor == this.hexColor &&
          other.parentProjectId == this.parentProjectId &&
          other.isArchived == this.isArchived &&
          other.isFavorite == this.isFavorite &&
          other.position == this.position &&
          other.ownerId == this.ownerId &&
          other.created == this.created &&
          other.updated == this.updated);
}

class ProjectsCompanion extends UpdateCompanion<ProjectRow> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> description;
  final Value<String> identifier;
  final Value<String> hexColor;
  final Value<int> parentProjectId;
  final Value<bool> isArchived;
  final Value<bool> isFavorite;
  final Value<double> position;
  final Value<int?> ownerId;
  final Value<DateTime?> created;
  final Value<DateTime?> updated;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.identifier = const Value.absent(),
    this.hexColor = const Value.absent(),
    this.parentProjectId = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.position = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.created = const Value.absent(),
    this.updated = const Value.absent(),
  });
  ProjectsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String description,
    required String identifier,
    required String hexColor,
    required int parentProjectId,
    required bool isArchived,
    required bool isFavorite,
    required double position,
    this.ownerId = const Value.absent(),
    this.created = const Value.absent(),
    this.updated = const Value.absent(),
  }) : title = Value(title),
       description = Value(description),
       identifier = Value(identifier),
       hexColor = Value(hexColor),
       parentProjectId = Value(parentProjectId),
       isArchived = Value(isArchived),
       isFavorite = Value(isFavorite),
       position = Value(position);
  static Insertable<ProjectRow> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? identifier,
    Expression<String>? hexColor,
    Expression<int>? parentProjectId,
    Expression<bool>? isArchived,
    Expression<bool>? isFavorite,
    Expression<double>? position,
    Expression<int>? ownerId,
    Expression<int>? created,
    Expression<int>? updated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (identifier != null) 'identifier': identifier,
      if (hexColor != null) 'hex_color': hexColor,
      if (parentProjectId != null) 'parent_project_id': parentProjectId,
      if (isArchived != null) 'is_archived': isArchived,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (position != null) 'position': position,
      if (ownerId != null) 'owner_id': ownerId,
      if (created != null) 'created': created,
      if (updated != null) 'updated': updated,
    });
  }

  ProjectsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? description,
    Value<String>? identifier,
    Value<String>? hexColor,
    Value<int>? parentProjectId,
    Value<bool>? isArchived,
    Value<bool>? isFavorite,
    Value<double>? position,
    Value<int?>? ownerId,
    Value<DateTime?>? created,
    Value<DateTime?>? updated,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      identifier: identifier ?? this.identifier,
      hexColor: hexColor ?? this.hexColor,
      parentProjectId: parentProjectId ?? this.parentProjectId,
      isArchived: isArchived ?? this.isArchived,
      isFavorite: isFavorite ?? this.isFavorite,
      position: position ?? this.position,
      ownerId: ownerId ?? this.ownerId,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (identifier.present) {
      map['identifier'] = Variable<String>(identifier.value);
    }
    if (hexColor.present) {
      map['hex_color'] = Variable<String>(hexColor.value);
    }
    if (parentProjectId.present) {
      map['parent_project_id'] = Variable<int>(parentProjectId.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (position.present) {
      map['position'] = Variable<double>(position.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<int>(ownerId.value);
    }
    if (created.present) {
      map['created'] = Variable<int>(
        $ProjectsTable.$convertercreatedn.toSql(created.value),
      );
    }
    if (updated.present) {
      map['updated'] = Variable<int>(
        $ProjectsTable.$converterupdatedn.toSql(updated.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('identifier: $identifier, ')
          ..write('hexColor: $hexColor, ')
          ..write('parentProjectId: $parentProjectId, ')
          ..write('isArchived: $isArchived, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('position: $position, ')
          ..write('ownerId: $ownerId, ')
          ..write('created: $created, ')
          ..write('updated: $updated')
          ..write(')'))
        .toString();
  }
}

class $ProjectViewsTable extends ProjectViews
    with TableInfo<$ProjectViewsTable, ProjectViewRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectViewsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<double> position = GeneratedColumn<double>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filterJsonMeta = const VerificationMeta(
    'filterJson',
  );
  @override
  late final GeneratedColumn<String> filterJson = GeneratedColumn<String>(
    'filter_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bucketConfigurationModeMeta =
      const VerificationMeta('bucketConfigurationMode');
  @override
  late final GeneratedColumn<String> bucketConfigurationMode =
      GeneratedColumn<String>(
        'bucket_configuration_mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _defaultBucketIdMeta = const VerificationMeta(
    'defaultBucketId',
  );
  @override
  late final GeneratedColumn<int> defaultBucketId = GeneratedColumn<int>(
    'default_bucket_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doneBucketIdMeta = const VerificationMeta(
    'doneBucketId',
  );
  @override
  late final GeneratedColumn<int> doneBucketId = GeneratedColumn<int>(
    'done_bucket_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    title,
    kind,
    position,
    filterJson,
    bucketConfigurationMode,
    defaultBucketId,
    doneBucketId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_views';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectViewRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('filter_json')) {
      context.handle(
        _filterJsonMeta,
        filterJson.isAcceptableOrUnknown(data['filter_json']!, _filterJsonMeta),
      );
    }
    if (data.containsKey('bucket_configuration_mode')) {
      context.handle(
        _bucketConfigurationModeMeta,
        bucketConfigurationMode.isAcceptableOrUnknown(
          data['bucket_configuration_mode']!,
          _bucketConfigurationModeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bucketConfigurationModeMeta);
    }
    if (data.containsKey('default_bucket_id')) {
      context.handle(
        _defaultBucketIdMeta,
        defaultBucketId.isAcceptableOrUnknown(
          data['default_bucket_id']!,
          _defaultBucketIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_defaultBucketIdMeta);
    }
    if (data.containsKey('done_bucket_id')) {
      context.handle(
        _doneBucketIdMeta,
        doneBucketId.isAcceptableOrUnknown(
          data['done_bucket_id']!,
          _doneBucketIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_doneBucketIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectViewRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectViewRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}position'],
      )!,
      filterJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filter_json'],
      ),
      bucketConfigurationMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bucket_configuration_mode'],
      )!,
      defaultBucketId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_bucket_id'],
      )!,
      doneBucketId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}done_bucket_id'],
      )!,
    );
  }

  @override
  $ProjectViewsTable createAlias(String alias) {
    return $ProjectViewsTable(attachedDatabase, alias);
  }
}

class ProjectViewRow extends DataClass implements Insertable<ProjectViewRow> {
  final int id;
  final int projectId;
  final String title;

  /// `ProjectViewKind.wireName`.
  final String kind;
  final double position;

  /// The view's `ViewFilter` as the server's JSON, null for none.
  final String? filterJson;

  /// `BucketConfigurationMode.wireName`.
  final String bucketConfigurationMode;
  final int defaultBucketId;
  final int doneBucketId;
  const ProjectViewRow({
    required this.id,
    required this.projectId,
    required this.title,
    required this.kind,
    required this.position,
    this.filterJson,
    required this.bucketConfigurationMode,
    required this.defaultBucketId,
    required this.doneBucketId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    map['title'] = Variable<String>(title);
    map['kind'] = Variable<String>(kind);
    map['position'] = Variable<double>(position);
    if (!nullToAbsent || filterJson != null) {
      map['filter_json'] = Variable<String>(filterJson);
    }
    map['bucket_configuration_mode'] = Variable<String>(
      bucketConfigurationMode,
    );
    map['default_bucket_id'] = Variable<int>(defaultBucketId);
    map['done_bucket_id'] = Variable<int>(doneBucketId);
    return map;
  }

  ProjectViewsCompanion toCompanion(bool nullToAbsent) {
    return ProjectViewsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      title: Value(title),
      kind: Value(kind),
      position: Value(position),
      filterJson: filterJson == null && nullToAbsent
          ? const Value.absent()
          : Value(filterJson),
      bucketConfigurationMode: Value(bucketConfigurationMode),
      defaultBucketId: Value(defaultBucketId),
      doneBucketId: Value(doneBucketId),
    );
  }

  factory ProjectViewRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectViewRow(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      title: serializer.fromJson<String>(json['title']),
      kind: serializer.fromJson<String>(json['kind']),
      position: serializer.fromJson<double>(json['position']),
      filterJson: serializer.fromJson<String?>(json['filterJson']),
      bucketConfigurationMode: serializer.fromJson<String>(
        json['bucketConfigurationMode'],
      ),
      defaultBucketId: serializer.fromJson<int>(json['defaultBucketId']),
      doneBucketId: serializer.fromJson<int>(json['doneBucketId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'title': serializer.toJson<String>(title),
      'kind': serializer.toJson<String>(kind),
      'position': serializer.toJson<double>(position),
      'filterJson': serializer.toJson<String?>(filterJson),
      'bucketConfigurationMode': serializer.toJson<String>(
        bucketConfigurationMode,
      ),
      'defaultBucketId': serializer.toJson<int>(defaultBucketId),
      'doneBucketId': serializer.toJson<int>(doneBucketId),
    };
  }

  ProjectViewRow copyWith({
    int? id,
    int? projectId,
    String? title,
    String? kind,
    double? position,
    Value<String?> filterJson = const Value.absent(),
    String? bucketConfigurationMode,
    int? defaultBucketId,
    int? doneBucketId,
  }) => ProjectViewRow(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    position: position ?? this.position,
    filterJson: filterJson.present ? filterJson.value : this.filterJson,
    bucketConfigurationMode:
        bucketConfigurationMode ?? this.bucketConfigurationMode,
    defaultBucketId: defaultBucketId ?? this.defaultBucketId,
    doneBucketId: doneBucketId ?? this.doneBucketId,
  );
  ProjectViewRow copyWithCompanion(ProjectViewsCompanion data) {
    return ProjectViewRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      title: data.title.present ? data.title.value : this.title,
      kind: data.kind.present ? data.kind.value : this.kind,
      position: data.position.present ? data.position.value : this.position,
      filterJson: data.filterJson.present
          ? data.filterJson.value
          : this.filterJson,
      bucketConfigurationMode: data.bucketConfigurationMode.present
          ? data.bucketConfigurationMode.value
          : this.bucketConfigurationMode,
      defaultBucketId: data.defaultBucketId.present
          ? data.defaultBucketId.value
          : this.defaultBucketId,
      doneBucketId: data.doneBucketId.present
          ? data.doneBucketId.value
          : this.doneBucketId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectViewRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('position: $position, ')
          ..write('filterJson: $filterJson, ')
          ..write('bucketConfigurationMode: $bucketConfigurationMode, ')
          ..write('defaultBucketId: $defaultBucketId, ')
          ..write('doneBucketId: $doneBucketId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    title,
    kind,
    position,
    filterJson,
    bucketConfigurationMode,
    defaultBucketId,
    doneBucketId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectViewRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.title == this.title &&
          other.kind == this.kind &&
          other.position == this.position &&
          other.filterJson == this.filterJson &&
          other.bucketConfigurationMode == this.bucketConfigurationMode &&
          other.defaultBucketId == this.defaultBucketId &&
          other.doneBucketId == this.doneBucketId);
}

class ProjectViewsCompanion extends UpdateCompanion<ProjectViewRow> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<String> title;
  final Value<String> kind;
  final Value<double> position;
  final Value<String?> filterJson;
  final Value<String> bucketConfigurationMode;
  final Value<int> defaultBucketId;
  final Value<int> doneBucketId;
  const ProjectViewsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.title = const Value.absent(),
    this.kind = const Value.absent(),
    this.position = const Value.absent(),
    this.filterJson = const Value.absent(),
    this.bucketConfigurationMode = const Value.absent(),
    this.defaultBucketId = const Value.absent(),
    this.doneBucketId = const Value.absent(),
  });
  ProjectViewsCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    required String title,
    required String kind,
    required double position,
    this.filterJson = const Value.absent(),
    required String bucketConfigurationMode,
    required int defaultBucketId,
    required int doneBucketId,
  }) : projectId = Value(projectId),
       title = Value(title),
       kind = Value(kind),
       position = Value(position),
       bucketConfigurationMode = Value(bucketConfigurationMode),
       defaultBucketId = Value(defaultBucketId),
       doneBucketId = Value(doneBucketId);
  static Insertable<ProjectViewRow> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<String>? title,
    Expression<String>? kind,
    Expression<double>? position,
    Expression<String>? filterJson,
    Expression<String>? bucketConfigurationMode,
    Expression<int>? defaultBucketId,
    Expression<int>? doneBucketId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (title != null) 'title': title,
      if (kind != null) 'kind': kind,
      if (position != null) 'position': position,
      if (filterJson != null) 'filter_json': filterJson,
      if (bucketConfigurationMode != null)
        'bucket_configuration_mode': bucketConfigurationMode,
      if (defaultBucketId != null) 'default_bucket_id': defaultBucketId,
      if (doneBucketId != null) 'done_bucket_id': doneBucketId,
    });
  }

  ProjectViewsCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<String>? title,
    Value<String>? kind,
    Value<double>? position,
    Value<String?>? filterJson,
    Value<String>? bucketConfigurationMode,
    Value<int>? defaultBucketId,
    Value<int>? doneBucketId,
  }) {
    return ProjectViewsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      position: position ?? this.position,
      filterJson: filterJson ?? this.filterJson,
      bucketConfigurationMode:
          bucketConfigurationMode ?? this.bucketConfigurationMode,
      defaultBucketId: defaultBucketId ?? this.defaultBucketId,
      doneBucketId: doneBucketId ?? this.doneBucketId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (position.present) {
      map['position'] = Variable<double>(position.value);
    }
    if (filterJson.present) {
      map['filter_json'] = Variable<String>(filterJson.value);
    }
    if (bucketConfigurationMode.present) {
      map['bucket_configuration_mode'] = Variable<String>(
        bucketConfigurationMode.value,
      );
    }
    if (defaultBucketId.present) {
      map['default_bucket_id'] = Variable<int>(defaultBucketId.value);
    }
    if (doneBucketId.present) {
      map['done_bucket_id'] = Variable<int>(doneBucketId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectViewsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('position: $position, ')
          ..write('filterJson: $filterJson, ')
          ..write('bucketConfigurationMode: $bucketConfigurationMode, ')
          ..write('defaultBucketId: $defaultBucketId, ')
          ..write('doneBucketId: $doneBucketId')
          ..write(')'))
        .toString();
  }
}

class $LabelsTable extends Labels with TableInfo<$LabelsTable, LabelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LabelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hexColorMeta = const VerificationMeta(
    'hexColor',
  );
  @override
  late final GeneratedColumn<String> hexColor = GeneratedColumn<String>(
    'hex_color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByIdMeta = const VerificationMeta(
    'createdById',
  );
  @override
  late final GeneratedColumn<int> createdById = GeneratedColumn<int>(
    'created_by_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> created =
      GeneratedColumn<int>(
        'created',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($LabelsTable.$convertercreatedn);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> updated =
      GeneratedColumn<int>(
        'updated',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($LabelsTable.$converterupdatedn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    hexColor,
    createdById,
    created,
    updated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'labels';
  @override
  VerificationContext validateIntegrity(
    Insertable<LabelRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
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
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('hex_color')) {
      context.handle(
        _hexColorMeta,
        hexColor.isAcceptableOrUnknown(data['hex_color']!, _hexColorMeta),
      );
    } else if (isInserting) {
      context.missing(_hexColorMeta);
    }
    if (data.containsKey('created_by_id')) {
      context.handle(
        _createdByIdMeta,
        createdById.isAcceptableOrUnknown(
          data['created_by_id']!,
          _createdByIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LabelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LabelRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      hexColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hex_color'],
      )!,
      createdById: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by_id'],
      ),
      created: $LabelsTable.$convertercreatedn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created'],
        ),
      ),
      updated: $LabelsTable.$converterupdatedn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated'],
        ),
      ),
    );
  }

  @override
  $LabelsTable createAlias(String alias) {
    return $LabelsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreated = const EpochMillis();
  static TypeConverter<DateTime?, int?> $convertercreatedn =
      NullAwareTypeConverter.wrap($convertercreated);
  static TypeConverter<DateTime, int> $converterupdated = const EpochMillis();
  static TypeConverter<DateTime?, int?> $converterupdatedn =
      NullAwareTypeConverter.wrap($converterupdated);
}

class LabelRow extends DataClass implements Insertable<LabelRow> {
  final int id;
  final String title;
  final String description;
  final String hexColor;
  final int? createdById;
  final DateTime? created;
  final DateTime? updated;
  const LabelRow({
    required this.id,
    required this.title,
    required this.description,
    required this.hexColor,
    this.createdById,
    this.created,
    this.updated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['hex_color'] = Variable<String>(hexColor);
    if (!nullToAbsent || createdById != null) {
      map['created_by_id'] = Variable<int>(createdById);
    }
    if (!nullToAbsent || created != null) {
      map['created'] = Variable<int>(
        $LabelsTable.$convertercreatedn.toSql(created),
      );
    }
    if (!nullToAbsent || updated != null) {
      map['updated'] = Variable<int>(
        $LabelsTable.$converterupdatedn.toSql(updated),
      );
    }
    return map;
  }

  LabelsCompanion toCompanion(bool nullToAbsent) {
    return LabelsCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      hexColor: Value(hexColor),
      createdById: createdById == null && nullToAbsent
          ? const Value.absent()
          : Value(createdById),
      created: created == null && nullToAbsent
          ? const Value.absent()
          : Value(created),
      updated: updated == null && nullToAbsent
          ? const Value.absent()
          : Value(updated),
    );
  }

  factory LabelRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LabelRow(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      hexColor: serializer.fromJson<String>(json['hexColor']),
      createdById: serializer.fromJson<int?>(json['createdById']),
      created: serializer.fromJson<DateTime?>(json['created']),
      updated: serializer.fromJson<DateTime?>(json['updated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'hexColor': serializer.toJson<String>(hexColor),
      'createdById': serializer.toJson<int?>(createdById),
      'created': serializer.toJson<DateTime?>(created),
      'updated': serializer.toJson<DateTime?>(updated),
    };
  }

  LabelRow copyWith({
    int? id,
    String? title,
    String? description,
    String? hexColor,
    Value<int?> createdById = const Value.absent(),
    Value<DateTime?> created = const Value.absent(),
    Value<DateTime?> updated = const Value.absent(),
  }) => LabelRow(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    hexColor: hexColor ?? this.hexColor,
    createdById: createdById.present ? createdById.value : this.createdById,
    created: created.present ? created.value : this.created,
    updated: updated.present ? updated.value : this.updated,
  );
  LabelRow copyWithCompanion(LabelsCompanion data) {
    return LabelRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      hexColor: data.hexColor.present ? data.hexColor.value : this.hexColor,
      createdById: data.createdById.present
          ? data.createdById.value
          : this.createdById,
      created: data.created.present ? data.created.value : this.created,
      updated: data.updated.present ? data.updated.value : this.updated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LabelRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('hexColor: $hexColor, ')
          ..write('createdById: $createdById, ')
          ..write('created: $created, ')
          ..write('updated: $updated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    hexColor,
    createdById,
    created,
    updated,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LabelRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.hexColor == this.hexColor &&
          other.createdById == this.createdById &&
          other.created == this.created &&
          other.updated == this.updated);
}

class LabelsCompanion extends UpdateCompanion<LabelRow> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> description;
  final Value<String> hexColor;
  final Value<int?> createdById;
  final Value<DateTime?> created;
  final Value<DateTime?> updated;
  const LabelsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.hexColor = const Value.absent(),
    this.createdById = const Value.absent(),
    this.created = const Value.absent(),
    this.updated = const Value.absent(),
  });
  LabelsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String description,
    required String hexColor,
    this.createdById = const Value.absent(),
    this.created = const Value.absent(),
    this.updated = const Value.absent(),
  }) : title = Value(title),
       description = Value(description),
       hexColor = Value(hexColor);
  static Insertable<LabelRow> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? hexColor,
    Expression<int>? createdById,
    Expression<int>? created,
    Expression<int>? updated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (hexColor != null) 'hex_color': hexColor,
      if (createdById != null) 'created_by_id': createdById,
      if (created != null) 'created': created,
      if (updated != null) 'updated': updated,
    });
  }

  LabelsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? description,
    Value<String>? hexColor,
    Value<int?>? createdById,
    Value<DateTime?>? created,
    Value<DateTime?>? updated,
  }) {
    return LabelsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      hexColor: hexColor ?? this.hexColor,
      createdById: createdById ?? this.createdById,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (hexColor.present) {
      map['hex_color'] = Variable<String>(hexColor.value);
    }
    if (createdById.present) {
      map['created_by_id'] = Variable<int>(createdById.value);
    }
    if (created.present) {
      map['created'] = Variable<int>(
        $LabelsTable.$convertercreatedn.toSql(created.value),
      );
    }
    if (updated.present) {
      map['updated'] = Variable<int>(
        $LabelsTable.$converterupdatedn.toSql(updated.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LabelsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('hexColor: $hexColor, ')
          ..write('createdById: $createdById, ')
          ..write('created: $created, ')
          ..write('updated: $updated')
          ..write(')'))
        .toString();
  }
}

class $UsersTable extends Users with TableInfo<$UsersTable, UserRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
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
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, username, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class UserRow extends DataClass implements Insertable<UserRow> {
  final int id;
  final String username;
  final String name;
  const UserRow({required this.id, required this.username, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['username'] = Variable<String>(username);
    map['name'] = Variable<String>(name);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      username: Value(username),
      name: Value(name),
    );
  }

  factory UserRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserRow(
      id: serializer.fromJson<int>(json['id']),
      username: serializer.fromJson<String>(json['username']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'username': serializer.toJson<String>(username),
      'name': serializer.toJson<String>(name),
    };
  }

  UserRow copyWith({int? id, String? username, String? name}) => UserRow(
    id: id ?? this.id,
    username: username ?? this.username,
    name: name ?? this.name,
  );
  UserRow copyWithCompanion(UsersCompanion data) {
    return UserRow(
      id: data.id.present ? data.id.value : this.id,
      username: data.username.present ? data.username.value : this.username,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserRow(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, username, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserRow &&
          other.id == this.id &&
          other.username == this.username &&
          other.name == this.name);
}

class UsersCompanion extends UpdateCompanion<UserRow> {
  final Value<int> id;
  final Value<String> username;
  final Value<String> name;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.username = const Value.absent(),
    this.name = const Value.absent(),
  });
  UsersCompanion.insert({
    this.id = const Value.absent(),
    required String username,
    required String name,
  }) : username = Value(username),
       name = Value(name);
  static Insertable<UserRow> custom({
    Expression<int>? id,
    Expression<String>? username,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (username != null) 'username': username,
      if (name != null) 'name': name,
    });
  }

  UsersCompanion copyWith({
    Value<int>? id,
    Value<String>? username,
    Value<String>? name,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, TaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> doneAt =
      GeneratedColumn<int>(
        'done_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($TasksTable.$converterdoneAtn);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> dueDate =
      GeneratedColumn<int>(
        'due_date',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($TasksTable.$converterdueDaten);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> startDate =
      GeneratedColumn<int>(
        'start_date',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($TasksTable.$converterstartDaten);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> endDate =
      GeneratedColumn<int>(
        'end_date',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($TasksTable.$converterendDaten);
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _percentDoneMeta = const VerificationMeta(
    'percentDone',
  );
  @override
  late final GeneratedColumn<double> percentDone = GeneratedColumn<double>(
    'percent_done',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hexColorMeta = const VerificationMeta(
    'hexColor',
  );
  @override
  late final GeneratedColumn<String> hexColor = GeneratedColumn<String>(
    'hex_color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _identifierMeta = const VerificationMeta(
    'identifier',
  );
  @override
  late final GeneratedColumn<String> identifier = GeneratedColumn<String>(
    'identifier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIndexMeta = const VerificationMeta(
    'taskIndex',
  );
  @override
  late final GeneratedColumn<int> taskIndex = GeneratedColumn<int>(
    'index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<double> position = GeneratedColumn<double>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repeatAfterMeta = const VerificationMeta(
    'repeatAfter',
  );
  @override
  late final GeneratedColumn<int> repeatAfter = GeneratedColumn<int>(
    'repeat_after',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repeatModeMeta = const VerificationMeta(
    'repeatMode',
  );
  @override
  late final GeneratedColumn<int> repeatMode = GeneratedColumn<int>(
    'repeat_mode',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bucketIdMeta = const VerificationMeta(
    'bucketId',
  );
  @override
  late final GeneratedColumn<int> bucketId = GeneratedColumn<int>(
    'bucket_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByIdMeta = const VerificationMeta(
    'createdById',
  );
  @override
  late final GeneratedColumn<int> createdById = GeneratedColumn<int>(
    'created_by_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> created =
      GeneratedColumn<int>(
        'created',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($TasksTable.$convertercreatedn);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> updated =
      GeneratedColumn<int>(
        'updated',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($TasksTable.$converterupdatedn);
  static const VerificationMeta _syncRunIdMeta = const VerificationMeta(
    'syncRunId',
  );
  @override
  late final GeneratedColumn<String> syncRunId = GeneratedColumn<String>(
    'sync_run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pendingChangesMeta = const VerificationMeta(
    'pendingChanges',
  );
  @override
  late final GeneratedColumn<String> pendingChanges = GeneratedColumn<String>(
    'pending_changes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pendingDeleteMeta = const VerificationMeta(
    'pendingDelete',
  );
  @override
  late final GeneratedColumn<bool> pendingDelete = GeneratedColumn<bool>(
    'pending_delete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending_delete" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    title,
    description,
    done,
    doneAt,
    dueDate,
    startDate,
    endDate,
    priority,
    percentDone,
    hexColor,
    identifier,
    taskIndex,
    isFavorite,
    position,
    repeatAfter,
    repeatMode,
    bucketId,
    createdById,
    created,
    updated,
    syncRunId,
    pendingChanges,
    pendingDelete,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
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
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    } else if (isInserting) {
      context.missing(_doneMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('percent_done')) {
      context.handle(
        _percentDoneMeta,
        percentDone.isAcceptableOrUnknown(
          data['percent_done']!,
          _percentDoneMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_percentDoneMeta);
    }
    if (data.containsKey('hex_color')) {
      context.handle(
        _hexColorMeta,
        hexColor.isAcceptableOrUnknown(data['hex_color']!, _hexColorMeta),
      );
    } else if (isInserting) {
      context.missing(_hexColorMeta);
    }
    if (data.containsKey('identifier')) {
      context.handle(
        _identifierMeta,
        identifier.isAcceptableOrUnknown(data['identifier']!, _identifierMeta),
      );
    } else if (isInserting) {
      context.missing(_identifierMeta);
    }
    if (data.containsKey('index')) {
      context.handle(
        _taskIndexMeta,
        taskIndex.isAcceptableOrUnknown(data['index']!, _taskIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIndexMeta);
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    } else if (isInserting) {
      context.missing(_isFavoriteMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('repeat_after')) {
      context.handle(
        _repeatAfterMeta,
        repeatAfter.isAcceptableOrUnknown(
          data['repeat_after']!,
          _repeatAfterMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repeatAfterMeta);
    }
    if (data.containsKey('repeat_mode')) {
      context.handle(
        _repeatModeMeta,
        repeatMode.isAcceptableOrUnknown(data['repeat_mode']!, _repeatModeMeta),
      );
    } else if (isInserting) {
      context.missing(_repeatModeMeta);
    }
    if (data.containsKey('bucket_id')) {
      context.handle(
        _bucketIdMeta,
        bucketId.isAcceptableOrUnknown(data['bucket_id']!, _bucketIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bucketIdMeta);
    }
    if (data.containsKey('created_by_id')) {
      context.handle(
        _createdByIdMeta,
        createdById.isAcceptableOrUnknown(
          data['created_by_id']!,
          _createdByIdMeta,
        ),
      );
    }
    if (data.containsKey('sync_run_id')) {
      context.handle(
        _syncRunIdMeta,
        syncRunId.isAcceptableOrUnknown(data['sync_run_id']!, _syncRunIdMeta),
      );
    }
    if (data.containsKey('pending_changes')) {
      context.handle(
        _pendingChangesMeta,
        pendingChanges.isAcceptableOrUnknown(
          data['pending_changes']!,
          _pendingChangesMeta,
        ),
      );
    }
    if (data.containsKey('pending_delete')) {
      context.handle(
        _pendingDeleteMeta,
        pendingDelete.isAcceptableOrUnknown(
          data['pending_delete']!,
          _pendingDeleteMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
      doneAt: $TasksTable.$converterdoneAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}done_at'],
        ),
      ),
      dueDate: $TasksTable.$converterdueDaten.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}due_date'],
        ),
      ),
      startDate: $TasksTable.$converterstartDaten.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}start_date'],
        ),
      ),
      endDate: $TasksTable.$converterendDaten.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}end_date'],
        ),
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      percentDone: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}percent_done'],
      )!,
      hexColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hex_color'],
      )!,
      identifier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}identifier'],
      )!,
      taskIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}index'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}position'],
      )!,
      repeatAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repeat_after'],
      )!,
      repeatMode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repeat_mode'],
      )!,
      bucketId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bucket_id'],
      )!,
      createdById: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by_id'],
      ),
      created: $TasksTable.$convertercreatedn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created'],
        ),
      ),
      updated: $TasksTable.$converterupdatedn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated'],
        ),
      ),
      syncRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_run_id'],
      ),
      pendingChanges: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pending_changes'],
      ),
      pendingDelete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending_delete'],
      )!,
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterdoneAt = const EpochMillis();
  static TypeConverter<DateTime?, int?> $converterdoneAtn =
      NullAwareTypeConverter.wrap($converterdoneAt);
  static TypeConverter<DateTime, int> $converterdueDate = const EpochMillis();
  static TypeConverter<DateTime?, int?> $converterdueDaten =
      NullAwareTypeConverter.wrap($converterdueDate);
  static TypeConverter<DateTime, int> $converterstartDate = const EpochMillis();
  static TypeConverter<DateTime?, int?> $converterstartDaten =
      NullAwareTypeConverter.wrap($converterstartDate);
  static TypeConverter<DateTime, int> $converterendDate = const EpochMillis();
  static TypeConverter<DateTime?, int?> $converterendDaten =
      NullAwareTypeConverter.wrap($converterendDate);
  static TypeConverter<DateTime, int> $convertercreated = const EpochMillis();
  static TypeConverter<DateTime?, int?> $convertercreatedn =
      NullAwareTypeConverter.wrap($convertercreated);
  static TypeConverter<DateTime, int> $converterupdated = const EpochMillis();
  static TypeConverter<DateTime?, int?> $converterupdatedn =
      NullAwareTypeConverter.wrap($converterupdated);
}

class TaskRow extends DataClass implements Insertable<TaskRow> {
  final int id;
  final int projectId;
  final String title;
  final String description;
  final bool done;
  final DateTime? doneAt;
  final DateTime? dueDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final int priority;
  final double percentDone;
  final String hexColor;
  final String identifier;
  final int taskIndex;
  final bool isFavorite;
  final double position;

  /// Seconds.
  final int repeatAfter;
  final int repeatMode;
  final int bucketId;
  final int? createdById;
  final DateTime? created;
  final DateTime? updated;

  /// The sync run that last returned this task; the finishing phase purges
  /// every task the run did not touch. Survives a restart, unlike a set of
  /// seen ids in memory.
  final String? syncRunId;

  /// The merged `TaskChanges` of this task's unsent outbox ops as JSON; the
  /// sync's upserts keep these fields. Null once everything is sent.
  final String? pendingChanges;

  /// A queued delete: the row is hidden from every query and count until
  /// the server confirms.
  final bool pendingDelete;
  const TaskRow({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.done,
    this.doneAt,
    this.dueDate,
    this.startDate,
    this.endDate,
    required this.priority,
    required this.percentDone,
    required this.hexColor,
    required this.identifier,
    required this.taskIndex,
    required this.isFavorite,
    required this.position,
    required this.repeatAfter,
    required this.repeatMode,
    required this.bucketId,
    this.createdById,
    this.created,
    this.updated,
    this.syncRunId,
    this.pendingChanges,
    required this.pendingDelete,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['done'] = Variable<bool>(done);
    if (!nullToAbsent || doneAt != null) {
      map['done_at'] = Variable<int>(
        $TasksTable.$converterdoneAtn.toSql(doneAt),
      );
    }
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<int>(
        $TasksTable.$converterdueDaten.toSql(dueDate),
      );
    }
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<int>(
        $TasksTable.$converterstartDaten.toSql(startDate),
      );
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<int>(
        $TasksTable.$converterendDaten.toSql(endDate),
      );
    }
    map['priority'] = Variable<int>(priority);
    map['percent_done'] = Variable<double>(percentDone);
    map['hex_color'] = Variable<String>(hexColor);
    map['identifier'] = Variable<String>(identifier);
    map['index'] = Variable<int>(taskIndex);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['position'] = Variable<double>(position);
    map['repeat_after'] = Variable<int>(repeatAfter);
    map['repeat_mode'] = Variable<int>(repeatMode);
    map['bucket_id'] = Variable<int>(bucketId);
    if (!nullToAbsent || createdById != null) {
      map['created_by_id'] = Variable<int>(createdById);
    }
    if (!nullToAbsent || created != null) {
      map['created'] = Variable<int>(
        $TasksTable.$convertercreatedn.toSql(created),
      );
    }
    if (!nullToAbsent || updated != null) {
      map['updated'] = Variable<int>(
        $TasksTable.$converterupdatedn.toSql(updated),
      );
    }
    if (!nullToAbsent || syncRunId != null) {
      map['sync_run_id'] = Variable<String>(syncRunId);
    }
    if (!nullToAbsent || pendingChanges != null) {
      map['pending_changes'] = Variable<String>(pendingChanges);
    }
    map['pending_delete'] = Variable<bool>(pendingDelete);
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      projectId: Value(projectId),
      title: Value(title),
      description: Value(description),
      done: Value(done),
      doneAt: doneAt == null && nullToAbsent
          ? const Value.absent()
          : Value(doneAt),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      priority: Value(priority),
      percentDone: Value(percentDone),
      hexColor: Value(hexColor),
      identifier: Value(identifier),
      taskIndex: Value(taskIndex),
      isFavorite: Value(isFavorite),
      position: Value(position),
      repeatAfter: Value(repeatAfter),
      repeatMode: Value(repeatMode),
      bucketId: Value(bucketId),
      createdById: createdById == null && nullToAbsent
          ? const Value.absent()
          : Value(createdById),
      created: created == null && nullToAbsent
          ? const Value.absent()
          : Value(created),
      updated: updated == null && nullToAbsent
          ? const Value.absent()
          : Value(updated),
      syncRunId: syncRunId == null && nullToAbsent
          ? const Value.absent()
          : Value(syncRunId),
      pendingChanges: pendingChanges == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingChanges),
      pendingDelete: Value(pendingDelete),
    );
  }

  factory TaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRow(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      done: serializer.fromJson<bool>(json['done']),
      doneAt: serializer.fromJson<DateTime?>(json['doneAt']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      priority: serializer.fromJson<int>(json['priority']),
      percentDone: serializer.fromJson<double>(json['percentDone']),
      hexColor: serializer.fromJson<String>(json['hexColor']),
      identifier: serializer.fromJson<String>(json['identifier']),
      taskIndex: serializer.fromJson<int>(json['taskIndex']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      position: serializer.fromJson<double>(json['position']),
      repeatAfter: serializer.fromJson<int>(json['repeatAfter']),
      repeatMode: serializer.fromJson<int>(json['repeatMode']),
      bucketId: serializer.fromJson<int>(json['bucketId']),
      createdById: serializer.fromJson<int?>(json['createdById']),
      created: serializer.fromJson<DateTime?>(json['created']),
      updated: serializer.fromJson<DateTime?>(json['updated']),
      syncRunId: serializer.fromJson<String?>(json['syncRunId']),
      pendingChanges: serializer.fromJson<String?>(json['pendingChanges']),
      pendingDelete: serializer.fromJson<bool>(json['pendingDelete']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'done': serializer.toJson<bool>(done),
      'doneAt': serializer.toJson<DateTime?>(doneAt),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'priority': serializer.toJson<int>(priority),
      'percentDone': serializer.toJson<double>(percentDone),
      'hexColor': serializer.toJson<String>(hexColor),
      'identifier': serializer.toJson<String>(identifier),
      'taskIndex': serializer.toJson<int>(taskIndex),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'position': serializer.toJson<double>(position),
      'repeatAfter': serializer.toJson<int>(repeatAfter),
      'repeatMode': serializer.toJson<int>(repeatMode),
      'bucketId': serializer.toJson<int>(bucketId),
      'createdById': serializer.toJson<int?>(createdById),
      'created': serializer.toJson<DateTime?>(created),
      'updated': serializer.toJson<DateTime?>(updated),
      'syncRunId': serializer.toJson<String?>(syncRunId),
      'pendingChanges': serializer.toJson<String?>(pendingChanges),
      'pendingDelete': serializer.toJson<bool>(pendingDelete),
    };
  }

  TaskRow copyWith({
    int? id,
    int? projectId,
    String? title,
    String? description,
    bool? done,
    Value<DateTime?> doneAt = const Value.absent(),
    Value<DateTime?> dueDate = const Value.absent(),
    Value<DateTime?> startDate = const Value.absent(),
    Value<DateTime?> endDate = const Value.absent(),
    int? priority,
    double? percentDone,
    String? hexColor,
    String? identifier,
    int? taskIndex,
    bool? isFavorite,
    double? position,
    int? repeatAfter,
    int? repeatMode,
    int? bucketId,
    Value<int?> createdById = const Value.absent(),
    Value<DateTime?> created = const Value.absent(),
    Value<DateTime?> updated = const Value.absent(),
    Value<String?> syncRunId = const Value.absent(),
    Value<String?> pendingChanges = const Value.absent(),
    bool? pendingDelete,
  }) => TaskRow(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    title: title ?? this.title,
    description: description ?? this.description,
    done: done ?? this.done,
    doneAt: doneAt.present ? doneAt.value : this.doneAt,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    startDate: startDate.present ? startDate.value : this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    priority: priority ?? this.priority,
    percentDone: percentDone ?? this.percentDone,
    hexColor: hexColor ?? this.hexColor,
    identifier: identifier ?? this.identifier,
    taskIndex: taskIndex ?? this.taskIndex,
    isFavorite: isFavorite ?? this.isFavorite,
    position: position ?? this.position,
    repeatAfter: repeatAfter ?? this.repeatAfter,
    repeatMode: repeatMode ?? this.repeatMode,
    bucketId: bucketId ?? this.bucketId,
    createdById: createdById.present ? createdById.value : this.createdById,
    created: created.present ? created.value : this.created,
    updated: updated.present ? updated.value : this.updated,
    syncRunId: syncRunId.present ? syncRunId.value : this.syncRunId,
    pendingChanges: pendingChanges.present
        ? pendingChanges.value
        : this.pendingChanges,
    pendingDelete: pendingDelete ?? this.pendingDelete,
  );
  TaskRow copyWithCompanion(TasksCompanion data) {
    return TaskRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      done: data.done.present ? data.done.value : this.done,
      doneAt: data.doneAt.present ? data.doneAt.value : this.doneAt,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      priority: data.priority.present ? data.priority.value : this.priority,
      percentDone: data.percentDone.present
          ? data.percentDone.value
          : this.percentDone,
      hexColor: data.hexColor.present ? data.hexColor.value : this.hexColor,
      identifier: data.identifier.present
          ? data.identifier.value
          : this.identifier,
      taskIndex: data.taskIndex.present ? data.taskIndex.value : this.taskIndex,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      position: data.position.present ? data.position.value : this.position,
      repeatAfter: data.repeatAfter.present
          ? data.repeatAfter.value
          : this.repeatAfter,
      repeatMode: data.repeatMode.present
          ? data.repeatMode.value
          : this.repeatMode,
      bucketId: data.bucketId.present ? data.bucketId.value : this.bucketId,
      createdById: data.createdById.present
          ? data.createdById.value
          : this.createdById,
      created: data.created.present ? data.created.value : this.created,
      updated: data.updated.present ? data.updated.value : this.updated,
      syncRunId: data.syncRunId.present ? data.syncRunId.value : this.syncRunId,
      pendingChanges: data.pendingChanges.present
          ? data.pendingChanges.value
          : this.pendingChanges,
      pendingDelete: data.pendingDelete.present
          ? data.pendingDelete.value
          : this.pendingDelete,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('done: $done, ')
          ..write('doneAt: $doneAt, ')
          ..write('dueDate: $dueDate, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('priority: $priority, ')
          ..write('percentDone: $percentDone, ')
          ..write('hexColor: $hexColor, ')
          ..write('identifier: $identifier, ')
          ..write('taskIndex: $taskIndex, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('position: $position, ')
          ..write('repeatAfter: $repeatAfter, ')
          ..write('repeatMode: $repeatMode, ')
          ..write('bucketId: $bucketId, ')
          ..write('createdById: $createdById, ')
          ..write('created: $created, ')
          ..write('updated: $updated, ')
          ..write('syncRunId: $syncRunId, ')
          ..write('pendingChanges: $pendingChanges, ')
          ..write('pendingDelete: $pendingDelete')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    projectId,
    title,
    description,
    done,
    doneAt,
    dueDate,
    startDate,
    endDate,
    priority,
    percentDone,
    hexColor,
    identifier,
    taskIndex,
    isFavorite,
    position,
    repeatAfter,
    repeatMode,
    bucketId,
    createdById,
    created,
    updated,
    syncRunId,
    pendingChanges,
    pendingDelete,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.title == this.title &&
          other.description == this.description &&
          other.done == this.done &&
          other.doneAt == this.doneAt &&
          other.dueDate == this.dueDate &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.priority == this.priority &&
          other.percentDone == this.percentDone &&
          other.hexColor == this.hexColor &&
          other.identifier == this.identifier &&
          other.taskIndex == this.taskIndex &&
          other.isFavorite == this.isFavorite &&
          other.position == this.position &&
          other.repeatAfter == this.repeatAfter &&
          other.repeatMode == this.repeatMode &&
          other.bucketId == this.bucketId &&
          other.createdById == this.createdById &&
          other.created == this.created &&
          other.updated == this.updated &&
          other.syncRunId == this.syncRunId &&
          other.pendingChanges == this.pendingChanges &&
          other.pendingDelete == this.pendingDelete);
}

class TasksCompanion extends UpdateCompanion<TaskRow> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<String> title;
  final Value<String> description;
  final Value<bool> done;
  final Value<DateTime?> doneAt;
  final Value<DateTime?> dueDate;
  final Value<DateTime?> startDate;
  final Value<DateTime?> endDate;
  final Value<int> priority;
  final Value<double> percentDone;
  final Value<String> hexColor;
  final Value<String> identifier;
  final Value<int> taskIndex;
  final Value<bool> isFavorite;
  final Value<double> position;
  final Value<int> repeatAfter;
  final Value<int> repeatMode;
  final Value<int> bucketId;
  final Value<int?> createdById;
  final Value<DateTime?> created;
  final Value<DateTime?> updated;
  final Value<String?> syncRunId;
  final Value<String?> pendingChanges;
  final Value<bool> pendingDelete;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.done = const Value.absent(),
    this.doneAt = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.priority = const Value.absent(),
    this.percentDone = const Value.absent(),
    this.hexColor = const Value.absent(),
    this.identifier = const Value.absent(),
    this.taskIndex = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.position = const Value.absent(),
    this.repeatAfter = const Value.absent(),
    this.repeatMode = const Value.absent(),
    this.bucketId = const Value.absent(),
    this.createdById = const Value.absent(),
    this.created = const Value.absent(),
    this.updated = const Value.absent(),
    this.syncRunId = const Value.absent(),
    this.pendingChanges = const Value.absent(),
    this.pendingDelete = const Value.absent(),
  });
  TasksCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    required String title,
    required String description,
    required bool done,
    this.doneAt = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    required int priority,
    required double percentDone,
    required String hexColor,
    required String identifier,
    required int taskIndex,
    required bool isFavorite,
    required double position,
    required int repeatAfter,
    required int repeatMode,
    required int bucketId,
    this.createdById = const Value.absent(),
    this.created = const Value.absent(),
    this.updated = const Value.absent(),
    this.syncRunId = const Value.absent(),
    this.pendingChanges = const Value.absent(),
    this.pendingDelete = const Value.absent(),
  }) : projectId = Value(projectId),
       title = Value(title),
       description = Value(description),
       done = Value(done),
       priority = Value(priority),
       percentDone = Value(percentDone),
       hexColor = Value(hexColor),
       identifier = Value(identifier),
       taskIndex = Value(taskIndex),
       isFavorite = Value(isFavorite),
       position = Value(position),
       repeatAfter = Value(repeatAfter),
       repeatMode = Value(repeatMode),
       bucketId = Value(bucketId);
  static Insertable<TaskRow> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<bool>? done,
    Expression<int>? doneAt,
    Expression<int>? dueDate,
    Expression<int>? startDate,
    Expression<int>? endDate,
    Expression<int>? priority,
    Expression<double>? percentDone,
    Expression<String>? hexColor,
    Expression<String>? identifier,
    Expression<int>? taskIndex,
    Expression<bool>? isFavorite,
    Expression<double>? position,
    Expression<int>? repeatAfter,
    Expression<int>? repeatMode,
    Expression<int>? bucketId,
    Expression<int>? createdById,
    Expression<int>? created,
    Expression<int>? updated,
    Expression<String>? syncRunId,
    Expression<String>? pendingChanges,
    Expression<bool>? pendingDelete,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (done != null) 'done': done,
      if (doneAt != null) 'done_at': doneAt,
      if (dueDate != null) 'due_date': dueDate,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (priority != null) 'priority': priority,
      if (percentDone != null) 'percent_done': percentDone,
      if (hexColor != null) 'hex_color': hexColor,
      if (identifier != null) 'identifier': identifier,
      if (taskIndex != null) 'index': taskIndex,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (position != null) 'position': position,
      if (repeatAfter != null) 'repeat_after': repeatAfter,
      if (repeatMode != null) 'repeat_mode': repeatMode,
      if (bucketId != null) 'bucket_id': bucketId,
      if (createdById != null) 'created_by_id': createdById,
      if (created != null) 'created': created,
      if (updated != null) 'updated': updated,
      if (syncRunId != null) 'sync_run_id': syncRunId,
      if (pendingChanges != null) 'pending_changes': pendingChanges,
      if (pendingDelete != null) 'pending_delete': pendingDelete,
    });
  }

  TasksCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<String>? title,
    Value<String>? description,
    Value<bool>? done,
    Value<DateTime?>? doneAt,
    Value<DateTime?>? dueDate,
    Value<DateTime?>? startDate,
    Value<DateTime?>? endDate,
    Value<int>? priority,
    Value<double>? percentDone,
    Value<String>? hexColor,
    Value<String>? identifier,
    Value<int>? taskIndex,
    Value<bool>? isFavorite,
    Value<double>? position,
    Value<int>? repeatAfter,
    Value<int>? repeatMode,
    Value<int>? bucketId,
    Value<int?>? createdById,
    Value<DateTime?>? created,
    Value<DateTime?>? updated,
    Value<String?>? syncRunId,
    Value<String?>? pendingChanges,
    Value<bool>? pendingDelete,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      done: done ?? this.done,
      doneAt: doneAt ?? this.doneAt,
      dueDate: dueDate ?? this.dueDate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      priority: priority ?? this.priority,
      percentDone: percentDone ?? this.percentDone,
      hexColor: hexColor ?? this.hexColor,
      identifier: identifier ?? this.identifier,
      taskIndex: taskIndex ?? this.taskIndex,
      isFavorite: isFavorite ?? this.isFavorite,
      position: position ?? this.position,
      repeatAfter: repeatAfter ?? this.repeatAfter,
      repeatMode: repeatMode ?? this.repeatMode,
      bucketId: bucketId ?? this.bucketId,
      createdById: createdById ?? this.createdById,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      syncRunId: syncRunId ?? this.syncRunId,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      pendingDelete: pendingDelete ?? this.pendingDelete,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (doneAt.present) {
      map['done_at'] = Variable<int>(
        $TasksTable.$converterdoneAtn.toSql(doneAt.value),
      );
    }
    if (dueDate.present) {
      map['due_date'] = Variable<int>(
        $TasksTable.$converterdueDaten.toSql(dueDate.value),
      );
    }
    if (startDate.present) {
      map['start_date'] = Variable<int>(
        $TasksTable.$converterstartDaten.toSql(startDate.value),
      );
    }
    if (endDate.present) {
      map['end_date'] = Variable<int>(
        $TasksTable.$converterendDaten.toSql(endDate.value),
      );
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (percentDone.present) {
      map['percent_done'] = Variable<double>(percentDone.value);
    }
    if (hexColor.present) {
      map['hex_color'] = Variable<String>(hexColor.value);
    }
    if (identifier.present) {
      map['identifier'] = Variable<String>(identifier.value);
    }
    if (taskIndex.present) {
      map['index'] = Variable<int>(taskIndex.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (position.present) {
      map['position'] = Variable<double>(position.value);
    }
    if (repeatAfter.present) {
      map['repeat_after'] = Variable<int>(repeatAfter.value);
    }
    if (repeatMode.present) {
      map['repeat_mode'] = Variable<int>(repeatMode.value);
    }
    if (bucketId.present) {
      map['bucket_id'] = Variable<int>(bucketId.value);
    }
    if (createdById.present) {
      map['created_by_id'] = Variable<int>(createdById.value);
    }
    if (created.present) {
      map['created'] = Variable<int>(
        $TasksTable.$convertercreatedn.toSql(created.value),
      );
    }
    if (updated.present) {
      map['updated'] = Variable<int>(
        $TasksTable.$converterupdatedn.toSql(updated.value),
      );
    }
    if (syncRunId.present) {
      map['sync_run_id'] = Variable<String>(syncRunId.value);
    }
    if (pendingChanges.present) {
      map['pending_changes'] = Variable<String>(pendingChanges.value);
    }
    if (pendingDelete.present) {
      map['pending_delete'] = Variable<bool>(pendingDelete.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('done: $done, ')
          ..write('doneAt: $doneAt, ')
          ..write('dueDate: $dueDate, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('priority: $priority, ')
          ..write('percentDone: $percentDone, ')
          ..write('hexColor: $hexColor, ')
          ..write('identifier: $identifier, ')
          ..write('taskIndex: $taskIndex, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('position: $position, ')
          ..write('repeatAfter: $repeatAfter, ')
          ..write('repeatMode: $repeatMode, ')
          ..write('bucketId: $bucketId, ')
          ..write('createdById: $createdById, ')
          ..write('created: $created, ')
          ..write('updated: $updated, ')
          ..write('syncRunId: $syncRunId, ')
          ..write('pendingChanges: $pendingChanges, ')
          ..write('pendingDelete: $pendingDelete')
          ..write(')'))
        .toString();
  }
}

class $TaskLabelsTable extends TaskLabels
    with TableInfo<$TaskLabelsTable, TaskLabelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskLabelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<int> taskId = GeneratedColumn<int>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelIdMeta = const VerificationMeta(
    'labelId',
  );
  @override
  late final GeneratedColumn<int> labelId = GeneratedColumn<int>(
    'label_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES labels (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [taskId, labelId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_labels';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskLabelRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('label_id')) {
      context.handle(
        _labelIdMeta,
        labelId.isAcceptableOrUnknown(data['label_id']!, _labelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_labelIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId, labelId};
  @override
  TaskLabelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskLabelRow(
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_id'],
      )!,
      labelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}label_id'],
      )!,
    );
  }

  @override
  $TaskLabelsTable createAlias(String alias) {
    return $TaskLabelsTable(attachedDatabase, alias);
  }
}

class TaskLabelRow extends DataClass implements Insertable<TaskLabelRow> {
  final int taskId;
  final int labelId;
  const TaskLabelRow({required this.taskId, required this.labelId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_id'] = Variable<int>(taskId);
    map['label_id'] = Variable<int>(labelId);
    return map;
  }

  TaskLabelsCompanion toCompanion(bool nullToAbsent) {
    return TaskLabelsCompanion(taskId: Value(taskId), labelId: Value(labelId));
  }

  factory TaskLabelRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskLabelRow(
      taskId: serializer.fromJson<int>(json['taskId']),
      labelId: serializer.fromJson<int>(json['labelId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'taskId': serializer.toJson<int>(taskId),
      'labelId': serializer.toJson<int>(labelId),
    };
  }

  TaskLabelRow copyWith({int? taskId, int? labelId}) => TaskLabelRow(
    taskId: taskId ?? this.taskId,
    labelId: labelId ?? this.labelId,
  );
  TaskLabelRow copyWithCompanion(TaskLabelsCompanion data) {
    return TaskLabelRow(
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      labelId: data.labelId.present ? data.labelId.value : this.labelId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskLabelRow(')
          ..write('taskId: $taskId, ')
          ..write('labelId: $labelId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(taskId, labelId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskLabelRow &&
          other.taskId == this.taskId &&
          other.labelId == this.labelId);
}

class TaskLabelsCompanion extends UpdateCompanion<TaskLabelRow> {
  final Value<int> taskId;
  final Value<int> labelId;
  final Value<int> rowid;
  const TaskLabelsCompanion({
    this.taskId = const Value.absent(),
    this.labelId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskLabelsCompanion.insert({
    required int taskId,
    required int labelId,
    this.rowid = const Value.absent(),
  }) : taskId = Value(taskId),
       labelId = Value(labelId);
  static Insertable<TaskLabelRow> custom({
    Expression<int>? taskId,
    Expression<int>? labelId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (taskId != null) 'task_id': taskId,
      if (labelId != null) 'label_id': labelId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskLabelsCompanion copyWith({
    Value<int>? taskId,
    Value<int>? labelId,
    Value<int>? rowid,
  }) {
    return TaskLabelsCompanion(
      taskId: taskId ?? this.taskId,
      labelId: labelId ?? this.labelId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskId.present) {
      map['task_id'] = Variable<int>(taskId.value);
    }
    if (labelId.present) {
      map['label_id'] = Variable<int>(labelId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskLabelsCompanion(')
          ..write('taskId: $taskId, ')
          ..write('labelId: $labelId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskAssigneesTable extends TaskAssignees
    with TableInfo<$TaskAssigneesTable, TaskAssigneeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskAssigneesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<int> taskId = GeneratedColumn<int>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [taskId, userId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_assignees';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskAssigneeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId, userId};
  @override
  TaskAssigneeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskAssigneeRow(
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
    );
  }

  @override
  $TaskAssigneesTable createAlias(String alias) {
    return $TaskAssigneesTable(attachedDatabase, alias);
  }
}

class TaskAssigneeRow extends DataClass implements Insertable<TaskAssigneeRow> {
  final int taskId;
  final int userId;
  const TaskAssigneeRow({required this.taskId, required this.userId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_id'] = Variable<int>(taskId);
    map['user_id'] = Variable<int>(userId);
    return map;
  }

  TaskAssigneesCompanion toCompanion(bool nullToAbsent) {
    return TaskAssigneesCompanion(taskId: Value(taskId), userId: Value(userId));
  }

  factory TaskAssigneeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskAssigneeRow(
      taskId: serializer.fromJson<int>(json['taskId']),
      userId: serializer.fromJson<int>(json['userId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'taskId': serializer.toJson<int>(taskId),
      'userId': serializer.toJson<int>(userId),
    };
  }

  TaskAssigneeRow copyWith({int? taskId, int? userId}) => TaskAssigneeRow(
    taskId: taskId ?? this.taskId,
    userId: userId ?? this.userId,
  );
  TaskAssigneeRow copyWithCompanion(TaskAssigneesCompanion data) {
    return TaskAssigneeRow(
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      userId: data.userId.present ? data.userId.value : this.userId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskAssigneeRow(')
          ..write('taskId: $taskId, ')
          ..write('userId: $userId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(taskId, userId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskAssigneeRow &&
          other.taskId == this.taskId &&
          other.userId == this.userId);
}

class TaskAssigneesCompanion extends UpdateCompanion<TaskAssigneeRow> {
  final Value<int> taskId;
  final Value<int> userId;
  final Value<int> rowid;
  const TaskAssigneesCompanion({
    this.taskId = const Value.absent(),
    this.userId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskAssigneesCompanion.insert({
    required int taskId,
    required int userId,
    this.rowid = const Value.absent(),
  }) : taskId = Value(taskId),
       userId = Value(userId);
  static Insertable<TaskAssigneeRow> custom({
    Expression<int>? taskId,
    Expression<int>? userId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (taskId != null) 'task_id': taskId,
      if (userId != null) 'user_id': userId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskAssigneesCompanion copyWith({
    Value<int>? taskId,
    Value<int>? userId,
    Value<int>? rowid,
  }) {
    return TaskAssigneesCompanion(
      taskId: taskId ?? this.taskId,
      userId: userId ?? this.userId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskId.present) {
      map['task_id'] = Variable<int>(taskId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskAssigneesCompanion(')
          ..write('taskId: $taskId, ')
          ..write('userId: $userId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskRemindersTable extends TaskReminders
    with TableInfo<$TaskRemindersTable, TaskReminderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskRemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<int> taskId = GeneratedColumn<int>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> reminder =
      GeneratedColumn<int>(
        'reminder',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($TaskRemindersTable.$converterremindern);
  static const VerificationMeta _relativePeriodMeta = const VerificationMeta(
    'relativePeriod',
  );
  @override
  late final GeneratedColumn<int> relativePeriod = GeneratedColumn<int>(
    'relative_period',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativeToMeta = const VerificationMeta(
    'relativeTo',
  );
  @override
  late final GeneratedColumn<String> relativeTo = GeneratedColumn<String>(
    'relative_to',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    taskId,
    ordinal,
    reminder,
    relativePeriod,
    relativeTo,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskReminderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('relative_period')) {
      context.handle(
        _relativePeriodMeta,
        relativePeriod.isAcceptableOrUnknown(
          data['relative_period']!,
          _relativePeriodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePeriodMeta);
    }
    if (data.containsKey('relative_to')) {
      context.handle(
        _relativeToMeta,
        relativeTo.isAcceptableOrUnknown(data['relative_to']!, _relativeToMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId, ordinal};
  @override
  TaskReminderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskReminderRow(
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_id'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      reminder: $TaskRemindersTable.$converterremindern.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}reminder'],
        ),
      ),
      relativePeriod: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}relative_period'],
      )!,
      relativeTo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_to'],
      ),
    );
  }

  @override
  $TaskRemindersTable createAlias(String alias) {
    return $TaskRemindersTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterreminder = const EpochMillis();
  static TypeConverter<DateTime?, int?> $converterremindern =
      NullAwareTypeConverter.wrap($converterreminder);
}

class TaskReminderRow extends DataClass implements Insertable<TaskReminderRow> {
  final int taskId;
  final int ordinal;
  final DateTime? reminder;

  /// Seconds, negative before the referenced date.
  final int relativePeriod;

  /// `ReminderRelativeTo.wireName`, null for an absolute reminder.
  final String? relativeTo;
  const TaskReminderRow({
    required this.taskId,
    required this.ordinal,
    this.reminder,
    required this.relativePeriod,
    this.relativeTo,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_id'] = Variable<int>(taskId);
    map['ordinal'] = Variable<int>(ordinal);
    if (!nullToAbsent || reminder != null) {
      map['reminder'] = Variable<int>(
        $TaskRemindersTable.$converterremindern.toSql(reminder),
      );
    }
    map['relative_period'] = Variable<int>(relativePeriod);
    if (!nullToAbsent || relativeTo != null) {
      map['relative_to'] = Variable<String>(relativeTo);
    }
    return map;
  }

  TaskRemindersCompanion toCompanion(bool nullToAbsent) {
    return TaskRemindersCompanion(
      taskId: Value(taskId),
      ordinal: Value(ordinal),
      reminder: reminder == null && nullToAbsent
          ? const Value.absent()
          : Value(reminder),
      relativePeriod: Value(relativePeriod),
      relativeTo: relativeTo == null && nullToAbsent
          ? const Value.absent()
          : Value(relativeTo),
    );
  }

  factory TaskReminderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskReminderRow(
      taskId: serializer.fromJson<int>(json['taskId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      reminder: serializer.fromJson<DateTime?>(json['reminder']),
      relativePeriod: serializer.fromJson<int>(json['relativePeriod']),
      relativeTo: serializer.fromJson<String?>(json['relativeTo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'taskId': serializer.toJson<int>(taskId),
      'ordinal': serializer.toJson<int>(ordinal),
      'reminder': serializer.toJson<DateTime?>(reminder),
      'relativePeriod': serializer.toJson<int>(relativePeriod),
      'relativeTo': serializer.toJson<String?>(relativeTo),
    };
  }

  TaskReminderRow copyWith({
    int? taskId,
    int? ordinal,
    Value<DateTime?> reminder = const Value.absent(),
    int? relativePeriod,
    Value<String?> relativeTo = const Value.absent(),
  }) => TaskReminderRow(
    taskId: taskId ?? this.taskId,
    ordinal: ordinal ?? this.ordinal,
    reminder: reminder.present ? reminder.value : this.reminder,
    relativePeriod: relativePeriod ?? this.relativePeriod,
    relativeTo: relativeTo.present ? relativeTo.value : this.relativeTo,
  );
  TaskReminderRow copyWithCompanion(TaskRemindersCompanion data) {
    return TaskReminderRow(
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      reminder: data.reminder.present ? data.reminder.value : this.reminder,
      relativePeriod: data.relativePeriod.present
          ? data.relativePeriod.value
          : this.relativePeriod,
      relativeTo: data.relativeTo.present
          ? data.relativeTo.value
          : this.relativeTo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskReminderRow(')
          ..write('taskId: $taskId, ')
          ..write('ordinal: $ordinal, ')
          ..write('reminder: $reminder, ')
          ..write('relativePeriod: $relativePeriod, ')
          ..write('relativeTo: $relativeTo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(taskId, ordinal, reminder, relativePeriod, relativeTo);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskReminderRow &&
          other.taskId == this.taskId &&
          other.ordinal == this.ordinal &&
          other.reminder == this.reminder &&
          other.relativePeriod == this.relativePeriod &&
          other.relativeTo == this.relativeTo);
}

class TaskRemindersCompanion extends UpdateCompanion<TaskReminderRow> {
  final Value<int> taskId;
  final Value<int> ordinal;
  final Value<DateTime?> reminder;
  final Value<int> relativePeriod;
  final Value<String?> relativeTo;
  final Value<int> rowid;
  const TaskRemindersCompanion({
    this.taskId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.reminder = const Value.absent(),
    this.relativePeriod = const Value.absent(),
    this.relativeTo = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskRemindersCompanion.insert({
    required int taskId,
    required int ordinal,
    this.reminder = const Value.absent(),
    required int relativePeriod,
    this.relativeTo = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : taskId = Value(taskId),
       ordinal = Value(ordinal),
       relativePeriod = Value(relativePeriod);
  static Insertable<TaskReminderRow> custom({
    Expression<int>? taskId,
    Expression<int>? ordinal,
    Expression<int>? reminder,
    Expression<int>? relativePeriod,
    Expression<String>? relativeTo,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (taskId != null) 'task_id': taskId,
      if (ordinal != null) 'ordinal': ordinal,
      if (reminder != null) 'reminder': reminder,
      if (relativePeriod != null) 'relative_period': relativePeriod,
      if (relativeTo != null) 'relative_to': relativeTo,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskRemindersCompanion copyWith({
    Value<int>? taskId,
    Value<int>? ordinal,
    Value<DateTime?>? reminder,
    Value<int>? relativePeriod,
    Value<String?>? relativeTo,
    Value<int>? rowid,
  }) {
    return TaskRemindersCompanion(
      taskId: taskId ?? this.taskId,
      ordinal: ordinal ?? this.ordinal,
      reminder: reminder ?? this.reminder,
      relativePeriod: relativePeriod ?? this.relativePeriod,
      relativeTo: relativeTo ?? this.relativeTo,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskId.present) {
      map['task_id'] = Variable<int>(taskId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (reminder.present) {
      map['reminder'] = Variable<int>(
        $TaskRemindersTable.$converterremindern.toSql(reminder.value),
      );
    }
    if (relativePeriod.present) {
      map['relative_period'] = Variable<int>(relativePeriod.value);
    }
    if (relativeTo.present) {
      map['relative_to'] = Variable<String>(relativeTo.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskRemindersCompanion(')
          ..write('taskId: $taskId, ')
          ..write('ordinal: $ordinal, ')
          ..write('reminder: $reminder, ')
          ..write('relativePeriod: $relativePeriod, ')
          ..write('relativeTo: $relativeTo, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskRelationsTable extends TaskRelations
    with TableInfo<$TaskRelationsTable, TaskRelationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskRelationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<int> taskId = GeneratedColumn<int>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _otherTaskIdMeta = const VerificationMeta(
    'otherTaskId',
  );
  @override
  late final GeneratedColumn<int> otherTaskId = GeneratedColumn<int>(
    'other_task_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [taskId, otherTaskId, kind];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_relations';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRelationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('other_task_id')) {
      context.handle(
        _otherTaskIdMeta,
        otherTaskId.isAcceptableOrUnknown(
          data['other_task_id']!,
          _otherTaskIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_otherTaskIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId, otherTaskId, kind};
  @override
  TaskRelationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRelationRow(
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_id'],
      )!,
      otherTaskId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}other_task_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
    );
  }

  @override
  $TaskRelationsTable createAlias(String alias) {
    return $TaskRelationsTable(attachedDatabase, alias);
  }
}

class TaskRelationRow extends DataClass implements Insertable<TaskRelationRow> {
  final int taskId;
  final int otherTaskId;

  /// `TaskRelationKind.wireName`.
  final String kind;
  const TaskRelationRow({
    required this.taskId,
    required this.otherTaskId,
    required this.kind,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_id'] = Variable<int>(taskId);
    map['other_task_id'] = Variable<int>(otherTaskId);
    map['kind'] = Variable<String>(kind);
    return map;
  }

  TaskRelationsCompanion toCompanion(bool nullToAbsent) {
    return TaskRelationsCompanion(
      taskId: Value(taskId),
      otherTaskId: Value(otherTaskId),
      kind: Value(kind),
    );
  }

  factory TaskRelationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRelationRow(
      taskId: serializer.fromJson<int>(json['taskId']),
      otherTaskId: serializer.fromJson<int>(json['otherTaskId']),
      kind: serializer.fromJson<String>(json['kind']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'taskId': serializer.toJson<int>(taskId),
      'otherTaskId': serializer.toJson<int>(otherTaskId),
      'kind': serializer.toJson<String>(kind),
    };
  }

  TaskRelationRow copyWith({int? taskId, int? otherTaskId, String? kind}) =>
      TaskRelationRow(
        taskId: taskId ?? this.taskId,
        otherTaskId: otherTaskId ?? this.otherTaskId,
        kind: kind ?? this.kind,
      );
  TaskRelationRow copyWithCompanion(TaskRelationsCompanion data) {
    return TaskRelationRow(
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      otherTaskId: data.otherTaskId.present
          ? data.otherTaskId.value
          : this.otherTaskId,
      kind: data.kind.present ? data.kind.value : this.kind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRelationRow(')
          ..write('taskId: $taskId, ')
          ..write('otherTaskId: $otherTaskId, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(taskId, otherTaskId, kind);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRelationRow &&
          other.taskId == this.taskId &&
          other.otherTaskId == this.otherTaskId &&
          other.kind == this.kind);
}

class TaskRelationsCompanion extends UpdateCompanion<TaskRelationRow> {
  final Value<int> taskId;
  final Value<int> otherTaskId;
  final Value<String> kind;
  final Value<int> rowid;
  const TaskRelationsCompanion({
    this.taskId = const Value.absent(),
    this.otherTaskId = const Value.absent(),
    this.kind = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskRelationsCompanion.insert({
    required int taskId,
    required int otherTaskId,
    required String kind,
    this.rowid = const Value.absent(),
  }) : taskId = Value(taskId),
       otherTaskId = Value(otherTaskId),
       kind = Value(kind);
  static Insertable<TaskRelationRow> custom({
    Expression<int>? taskId,
    Expression<int>? otherTaskId,
    Expression<String>? kind,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (taskId != null) 'task_id': taskId,
      if (otherTaskId != null) 'other_task_id': otherTaskId,
      if (kind != null) 'kind': kind,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskRelationsCompanion copyWith({
    Value<int>? taskId,
    Value<int>? otherTaskId,
    Value<String>? kind,
    Value<int>? rowid,
  }) {
    return TaskRelationsCompanion(
      taskId: taskId ?? this.taskId,
      otherTaskId: otherTaskId ?? this.otherTaskId,
      kind: kind ?? this.kind,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskId.present) {
      map['task_id'] = Variable<int>(taskId.value);
    }
    if (otherTaskId.present) {
      map['other_task_id'] = Variable<int>(otherTaskId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskRelationsCompanion(')
          ..write('taskId: $taskId, ')
          ..write('otherTaskId: $otherTaskId, ')
          ..write('kind: $kind, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  final String key;
  final String value;
  const SyncStateRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(key: Value(key), value: Value(value));
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncStateRow copyWith({String? key, String? value}) =>
      SyncStateRow(key: key ?? this.key, value: value ?? this.value);
  SyncStateRow copyWithCompanion(SyncStateCompanion data) {
    return SyncStateRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncStateRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<int> taskId = GeneratedColumn<int>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($OutboxTable.$convertercreatedAt);
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> nextAttemptAt =
      GeneratedColumn<int>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($OutboxTable.$converternextAttemptAtn);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> lastAttemptAt =
      GeneratedColumn<int>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($OutboxTable.$converterlastAttemptAtn);
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> sentAt =
      GeneratedColumn<int>(
        'sent_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($OutboxTable.$convertersentAtn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sequence,
    kind,
    taskId,
    payload,
    createdAt,
    attempts,
    nextAttemptAt,
    lastAttemptAt,
    state,
    lastError,
    sentAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    } else if (isInserting) {
      context.missing(_attemptsMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: $OutboxTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextAttemptAt: $OutboxTable.$converternextAttemptAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}next_attempt_at'],
        ),
      ),
      lastAttemptAt: $OutboxTable.$converterlastAttemptAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_attempt_at'],
        ),
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      sentAt: $OutboxTable.$convertersentAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}sent_at'],
        ),
      ),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt = const EpochMillis();
  static TypeConverter<DateTime, int> $converternextAttemptAt =
      const EpochMillis();
  static TypeConverter<DateTime?, int?> $converternextAttemptAtn =
      NullAwareTypeConverter.wrap($converternextAttemptAt);
  static TypeConverter<DateTime, int> $converterlastAttemptAt =
      const EpochMillis();
  static TypeConverter<DateTime?, int?> $converterlastAttemptAtn =
      NullAwareTypeConverter.wrap($converterlastAttemptAt);
  static TypeConverter<DateTime, int> $convertersentAt = const EpochMillis();
  static TypeConverter<DateTime?, int?> $convertersentAtn =
      NullAwareTypeConverter.wrap($convertersentAt);
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  /// A UUID, so a retry or discard names exactly one op.
  final String id;

  /// Strictly increasing per database; the send order.
  final int sequence;

  /// `OutboxOperationKind.name`.
  final String kind;

  /// Negative for a task created here that the server has not named yet.
  final int taskId;

  /// The `TaskChanges` as JSON, the `NewTask` for a create; empty for a
  /// delete.
  final String payload;
  final DateTime createdAt;
  final int attempts;
  final DateTime? nextAttemptAt;
  final DateTime? lastAttemptAt;
  final String state;

  /// The normalized `VikunjaFailure` of the last attempt as JSON.
  final String? lastError;

  /// When a create's request may have reached the server although no
  /// answer came back: set on the first such attempt, so the next one looks
  /// for the task before sending it again. Null for every other op and for
  /// a create the server rejected.
  final DateTime? sentAt;
  const OutboxRow({
    required this.id,
    required this.sequence,
    required this.kind,
    required this.taskId,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    this.nextAttemptAt,
    this.lastAttemptAt,
    required this.state,
    this.lastError,
    this.sentAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sequence'] = Variable<int>(sequence);
    map['kind'] = Variable<String>(kind);
    map['task_id'] = Variable<int>(taskId);
    map['payload'] = Variable<String>(payload);
    {
      map['created_at'] = Variable<int>(
        $OutboxTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<int>(
        $OutboxTable.$converternextAttemptAtn.toSql(nextAttemptAt),
      );
    }
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<int>(
        $OutboxTable.$converterlastAttemptAtn.toSql(lastAttemptAt),
      );
    }
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || sentAt != null) {
      map['sent_at'] = Variable<int>(
        $OutboxTable.$convertersentAtn.toSql(sentAt),
      );
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      sequence: Value(sequence),
      kind: Value(kind),
      taskId: Value(taskId),
      payload: Value(payload),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      state: Value(state),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      sentAt: sentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(sentAt),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      id: serializer.fromJson<String>(json['id']),
      sequence: serializer.fromJson<int>(json['sequence']),
      kind: serializer.fromJson<String>(json['kind']),
      taskId: serializer.fromJson<int>(json['taskId']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      state: serializer.fromJson<String>(json['state']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      sentAt: serializer.fromJson<DateTime?>(json['sentAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sequence': serializer.toJson<int>(sequence),
      'kind': serializer.toJson<String>(kind),
      'taskId': serializer.toJson<int>(taskId),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'state': serializer.toJson<String>(state),
      'lastError': serializer.toJson<String?>(lastError),
      'sentAt': serializer.toJson<DateTime?>(sentAt),
    };
  }

  OutboxRow copyWith({
    String? id,
    int? sequence,
    String? kind,
    int? taskId,
    String? payload,
    DateTime? createdAt,
    int? attempts,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    String? state,
    Value<String?> lastError = const Value.absent(),
    Value<DateTime?> sentAt = const Value.absent(),
  }) => OutboxRow(
    id: id ?? this.id,
    sequence: sequence ?? this.sequence,
    kind: kind ?? this.kind,
    taskId: taskId ?? this.taskId,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    state: state ?? this.state,
    lastError: lastError.present ? lastError.value : this.lastError,
    sentAt: sentAt.present ? sentAt.value : this.sentAt,
  );
  OutboxRow copyWithCompanion(OutboxCompanion data) {
    return OutboxRow(
      id: data.id.present ? data.id.value : this.id,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      kind: data.kind.present ? data.kind.value : this.kind,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      state: data.state.present ? data.state.value : this.state,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('id: $id, ')
          ..write('sequence: $sequence, ')
          ..write('kind: $kind, ')
          ..write('taskId: $taskId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('state: $state, ')
          ..write('lastError: $lastError, ')
          ..write('sentAt: $sentAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sequence,
    kind,
    taskId,
    payload,
    createdAt,
    attempts,
    nextAttemptAt,
    lastAttemptAt,
    state,
    lastError,
    sentAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.id == this.id &&
          other.sequence == this.sequence &&
          other.kind == this.kind &&
          other.taskId == this.taskId &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.state == this.state &&
          other.lastError == this.lastError &&
          other.sentAt == this.sentAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxRow> {
  final Value<String> id;
  final Value<int> sequence;
  final Value<String> kind;
  final Value<int> taskId;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<int> attempts;
  final Value<DateTime?> nextAttemptAt;
  final Value<DateTime?> lastAttemptAt;
  final Value<String> state;
  final Value<String?> lastError;
  final Value<DateTime?> sentAt;
  final Value<int> rowid;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.sequence = const Value.absent(),
    this.kind = const Value.absent(),
    this.taskId = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.state = const Value.absent(),
    this.lastError = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String id,
    required int sequence,
    required String kind,
    required int taskId,
    required String payload,
    required DateTime createdAt,
    required int attempts,
    this.nextAttemptAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    required String state,
    this.lastError = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sequence = Value(sequence),
       kind = Value(kind),
       taskId = Value(taskId),
       payload = Value(payload),
       createdAt = Value(createdAt),
       attempts = Value(attempts),
       state = Value(state);
  static Insertable<OutboxRow> custom({
    Expression<String>? id,
    Expression<int>? sequence,
    Expression<String>? kind,
    Expression<int>? taskId,
    Expression<String>? payload,
    Expression<int>? createdAt,
    Expression<int>? attempts,
    Expression<int>? nextAttemptAt,
    Expression<int>? lastAttemptAt,
    Expression<String>? state,
    Expression<String>? lastError,
    Expression<int>? sentAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sequence != null) 'sequence': sequence,
      if (kind != null) 'kind': kind,
      if (taskId != null) 'task_id': taskId,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (state != null) 'state': state,
      if (lastError != null) 'last_error': lastError,
      if (sentAt != null) 'sent_at': sentAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? id,
    Value<int>? sequence,
    Value<String>? kind,
    Value<int>? taskId,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<int>? attempts,
    Value<DateTime?>? nextAttemptAt,
    Value<DateTime?>? lastAttemptAt,
    Value<String>? state,
    Value<String?>? lastError,
    Value<DateTime?>? sentAt,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      sequence: sequence ?? this.sequence,
      kind: kind ?? this.kind,
      taskId: taskId ?? this.taskId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      state: state ?? this.state,
      lastError: lastError ?? this.lastError,
      sentAt: sentAt ?? this.sentAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<int>(taskId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $OutboxTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<int>(
        $OutboxTable.$converternextAttemptAtn.toSql(nextAttemptAt.value),
      );
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<int>(
        $OutboxTable.$converterlastAttemptAtn.toSql(lastAttemptAt.value),
      );
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<int>(
        $OutboxTable.$convertersentAtn.toSql(sentAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('sequence: $sequence, ')
          ..write('kind: $kind, ')
          ..write('taskId: $taskId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('state: $state, ')
          ..write('lastError: $lastError, ')
          ..write('sentAt: $sentAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskIdRemapsTable extends TaskIdRemaps
    with TableInfo<$TaskIdRemapsTable, TaskIdRemapRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskIdRemapsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<int> localId = GeneratedColumn<int>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> at =
      GeneratedColumn<int>(
        'at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($TaskIdRemapsTable.$converterat);
  @override
  List<GeneratedColumn> get $columns => [localId, serverId, at];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_id_remaps';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskIdRemapRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  TaskIdRemapRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskIdRemapRow(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      )!,
      at: $TaskIdRemapsTable.$converterat.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}at'],
        )!,
      ),
    );
  }

  @override
  $TaskIdRemapsTable createAlias(String alias) {
    return $TaskIdRemapsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterat = const EpochMillis();
}

class TaskIdRemapRow extends DataClass implements Insertable<TaskIdRemapRow> {
  final int localId;
  final int serverId;
  final DateTime at;
  const TaskIdRemapRow({
    required this.localId,
    required this.serverId,
    required this.at,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<int>(localId);
    map['server_id'] = Variable<int>(serverId);
    {
      map['at'] = Variable<int>($TaskIdRemapsTable.$converterat.toSql(at));
    }
    return map;
  }

  TaskIdRemapsCompanion toCompanion(bool nullToAbsent) {
    return TaskIdRemapsCompanion(
      localId: Value(localId),
      serverId: Value(serverId),
      at: Value(at),
    );
  }

  factory TaskIdRemapRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskIdRemapRow(
      localId: serializer.fromJson<int>(json['localId']),
      serverId: serializer.fromJson<int>(json['serverId']),
      at: serializer.fromJson<DateTime>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<int>(localId),
      'serverId': serializer.toJson<int>(serverId),
      'at': serializer.toJson<DateTime>(at),
    };
  }

  TaskIdRemapRow copyWith({int? localId, int? serverId, DateTime? at}) =>
      TaskIdRemapRow(
        localId: localId ?? this.localId,
        serverId: serverId ?? this.serverId,
        at: at ?? this.at,
      );
  TaskIdRemapRow copyWithCompanion(TaskIdRemapsCompanion data) {
    return TaskIdRemapRow(
      localId: data.localId.present ? data.localId.value : this.localId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskIdRemapRow(')
          ..write('localId: $localId, ')
          ..write('serverId: $serverId, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(localId, serverId, at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskIdRemapRow &&
          other.localId == this.localId &&
          other.serverId == this.serverId &&
          other.at == this.at);
}

class TaskIdRemapsCompanion extends UpdateCompanion<TaskIdRemapRow> {
  final Value<int> localId;
  final Value<int> serverId;
  final Value<DateTime> at;
  const TaskIdRemapsCompanion({
    this.localId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.at = const Value.absent(),
  });
  TaskIdRemapsCompanion.insert({
    this.localId = const Value.absent(),
    required int serverId,
    required DateTime at,
  }) : serverId = Value(serverId),
       at = Value(at);
  static Insertable<TaskIdRemapRow> custom({
    Expression<int>? localId,
    Expression<int>? serverId,
    Expression<int>? at,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (serverId != null) 'server_id': serverId,
      if (at != null) 'at': at,
    });
  }

  TaskIdRemapsCompanion copyWith({
    Value<int>? localId,
    Value<int>? serverId,
    Value<DateTime>? at,
  }) {
    return TaskIdRemapsCompanion(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      at: at ?? this.at,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<int>(localId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(
        $TaskIdRemapsTable.$converterat.toSql(at.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskIdRemapsCompanion(')
          ..write('localId: $localId, ')
          ..write('serverId: $serverId, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }
}

class $ScheduledNotificationsTable extends ScheduledNotifications
    with TableInfo<$ScheduledNotificationsTable, ScheduledNotificationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduledNotificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _osIdMeta = const VerificationMeta('osId');
  @override
  late final GeneratedColumn<int> osId = GeneratedColumn<int>(
    'os_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<int> taskId = GeneratedColumn<int>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> fireAt =
      GeneratedColumn<int>(
        'fire_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ScheduledNotificationsTable.$converterfireAt);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> snoozedUntil =
      GeneratedColumn<int>(
        'snoozed_until',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>(
        $ScheduledNotificationsTable.$convertersnoozedUntiln,
      );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int>
  snoozeOriginalFireAt =
      GeneratedColumn<int>(
        'snooze_original_fire_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>(
        $ScheduledNotificationsTable.$convertersnoozeOriginalFireAtn,
      );
  static const VerificationMeta _exactMeta = const VerificationMeta('exact');
  @override
  late final GeneratedColumn<bool> exact = GeneratedColumn<bool>(
    'exact',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("exact" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    osId,
    taskId,
    kind,
    fireAt,
    title,
    body,
    snoozedUntil,
    snoozeOriginalFireAt,
    exact,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scheduled_notifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduledNotificationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('os_id')) {
      context.handle(
        _osIdMeta,
        osId.isAcceptableOrUnknown(data['os_id']!, _osIdMeta),
      );
    } else if (isInserting) {
      context.missing(_osIdMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('exact')) {
      context.handle(
        _exactMeta,
        exact.isAcceptableOrUnknown(data['exact']!, _exactMeta),
      );
    } else if (isInserting) {
      context.missing(_exactMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  ScheduledNotificationRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduledNotificationRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      osId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}os_id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      fireAt: $ScheduledNotificationsTable.$converterfireAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}fire_at'],
        )!,
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      snoozedUntil: $ScheduledNotificationsTable.$convertersnoozedUntiln
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.int,
              data['${effectivePrefix}snoozed_until'],
            ),
          ),
      snoozeOriginalFireAt: $ScheduledNotificationsTable
          .$convertersnoozeOriginalFireAtn
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.int,
              data['${effectivePrefix}snooze_original_fire_at'],
            ),
          ),
      exact: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}exact'],
      )!,
    );
  }

  @override
  $ScheduledNotificationsTable createAlias(String alias) {
    return $ScheduledNotificationsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterfireAt = const EpochMillis();
  static TypeConverter<DateTime, int> $convertersnoozedUntil =
      const EpochMillis();
  static TypeConverter<DateTime?, int?> $convertersnoozedUntiln =
      NullAwareTypeConverter.wrap($convertersnoozedUntil);
  static TypeConverter<DateTime, int> $convertersnoozeOriginalFireAt =
      const EpochMillis();
  static TypeConverter<DateTime?, int?> $convertersnoozeOriginalFireAtn =
      NullAwareTypeConverter.wrap($convertersnoozeOriginalFireAt);
}

class ScheduledNotificationRow extends DataClass
    implements Insertable<ScheduledNotificationRow> {
  final String key;
  final int osId;
  final int taskId;

  /// `ScheduledNotificationKind.name`.
  final String kind;

  /// When the OS will show it: the task's instant, or [snoozedUntil].
  final DateTime fireAt;
  final String title;
  final String body;

  /// A snooze the user chose from the notification; it holds until the
  /// task's own instant no longer equals [snoozeOriginalFireAt].
  final DateTime? snoozedUntil;
  final DateTime? snoozeOriginalFireAt;

  /// Whether the OS was given an exact alarm. Part of the diff: a granted
  /// or revoked exact-alarm permission re-registers the whole window.
  final bool exact;
  const ScheduledNotificationRow({
    required this.key,
    required this.osId,
    required this.taskId,
    required this.kind,
    required this.fireAt,
    required this.title,
    required this.body,
    this.snoozedUntil,
    this.snoozeOriginalFireAt,
    required this.exact,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['os_id'] = Variable<int>(osId);
    map['task_id'] = Variable<int>(taskId);
    map['kind'] = Variable<String>(kind);
    {
      map['fire_at'] = Variable<int>(
        $ScheduledNotificationsTable.$converterfireAt.toSql(fireAt),
      );
    }
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || snoozedUntil != null) {
      map['snoozed_until'] = Variable<int>(
        $ScheduledNotificationsTable.$convertersnoozedUntiln.toSql(
          snoozedUntil,
        ),
      );
    }
    if (!nullToAbsent || snoozeOriginalFireAt != null) {
      map['snooze_original_fire_at'] = Variable<int>(
        $ScheduledNotificationsTable.$convertersnoozeOriginalFireAtn.toSql(
          snoozeOriginalFireAt,
        ),
      );
    }
    map['exact'] = Variable<bool>(exact);
    return map;
  }

  ScheduledNotificationsCompanion toCompanion(bool nullToAbsent) {
    return ScheduledNotificationsCompanion(
      key: Value(key),
      osId: Value(osId),
      taskId: Value(taskId),
      kind: Value(kind),
      fireAt: Value(fireAt),
      title: Value(title),
      body: Value(body),
      snoozedUntil: snoozedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozedUntil),
      snoozeOriginalFireAt: snoozeOriginalFireAt == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozeOriginalFireAt),
      exact: Value(exact),
    );
  }

  factory ScheduledNotificationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduledNotificationRow(
      key: serializer.fromJson<String>(json['key']),
      osId: serializer.fromJson<int>(json['osId']),
      taskId: serializer.fromJson<int>(json['taskId']),
      kind: serializer.fromJson<String>(json['kind']),
      fireAt: serializer.fromJson<DateTime>(json['fireAt']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      snoozedUntil: serializer.fromJson<DateTime?>(json['snoozedUntil']),
      snoozeOriginalFireAt: serializer.fromJson<DateTime?>(
        json['snoozeOriginalFireAt'],
      ),
      exact: serializer.fromJson<bool>(json['exact']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'osId': serializer.toJson<int>(osId),
      'taskId': serializer.toJson<int>(taskId),
      'kind': serializer.toJson<String>(kind),
      'fireAt': serializer.toJson<DateTime>(fireAt),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'snoozedUntil': serializer.toJson<DateTime?>(snoozedUntil),
      'snoozeOriginalFireAt': serializer.toJson<DateTime?>(
        snoozeOriginalFireAt,
      ),
      'exact': serializer.toJson<bool>(exact),
    };
  }

  ScheduledNotificationRow copyWith({
    String? key,
    int? osId,
    int? taskId,
    String? kind,
    DateTime? fireAt,
    String? title,
    String? body,
    Value<DateTime?> snoozedUntil = const Value.absent(),
    Value<DateTime?> snoozeOriginalFireAt = const Value.absent(),
    bool? exact,
  }) => ScheduledNotificationRow(
    key: key ?? this.key,
    osId: osId ?? this.osId,
    taskId: taskId ?? this.taskId,
    kind: kind ?? this.kind,
    fireAt: fireAt ?? this.fireAt,
    title: title ?? this.title,
    body: body ?? this.body,
    snoozedUntil: snoozedUntil.present ? snoozedUntil.value : this.snoozedUntil,
    snoozeOriginalFireAt: snoozeOriginalFireAt.present
        ? snoozeOriginalFireAt.value
        : this.snoozeOriginalFireAt,
    exact: exact ?? this.exact,
  );
  ScheduledNotificationRow copyWithCompanion(
    ScheduledNotificationsCompanion data,
  ) {
    return ScheduledNotificationRow(
      key: data.key.present ? data.key.value : this.key,
      osId: data.osId.present ? data.osId.value : this.osId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      kind: data.kind.present ? data.kind.value : this.kind,
      fireAt: data.fireAt.present ? data.fireAt.value : this.fireAt,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      snoozedUntil: data.snoozedUntil.present
          ? data.snoozedUntil.value
          : this.snoozedUntil,
      snoozeOriginalFireAt: data.snoozeOriginalFireAt.present
          ? data.snoozeOriginalFireAt.value
          : this.snoozeOriginalFireAt,
      exact: data.exact.present ? data.exact.value : this.exact,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledNotificationRow(')
          ..write('key: $key, ')
          ..write('osId: $osId, ')
          ..write('taskId: $taskId, ')
          ..write('kind: $kind, ')
          ..write('fireAt: $fireAt, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('snoozeOriginalFireAt: $snoozeOriginalFireAt, ')
          ..write('exact: $exact')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    key,
    osId,
    taskId,
    kind,
    fireAt,
    title,
    body,
    snoozedUntil,
    snoozeOriginalFireAt,
    exact,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduledNotificationRow &&
          other.key == this.key &&
          other.osId == this.osId &&
          other.taskId == this.taskId &&
          other.kind == this.kind &&
          other.fireAt == this.fireAt &&
          other.title == this.title &&
          other.body == this.body &&
          other.snoozedUntil == this.snoozedUntil &&
          other.snoozeOriginalFireAt == this.snoozeOriginalFireAt &&
          other.exact == this.exact);
}

class ScheduledNotificationsCompanion
    extends UpdateCompanion<ScheduledNotificationRow> {
  final Value<String> key;
  final Value<int> osId;
  final Value<int> taskId;
  final Value<String> kind;
  final Value<DateTime> fireAt;
  final Value<String> title;
  final Value<String> body;
  final Value<DateTime?> snoozedUntil;
  final Value<DateTime?> snoozeOriginalFireAt;
  final Value<bool> exact;
  final Value<int> rowid;
  const ScheduledNotificationsCompanion({
    this.key = const Value.absent(),
    this.osId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.kind = const Value.absent(),
    this.fireAt = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.snoozeOriginalFireAt = const Value.absent(),
    this.exact = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScheduledNotificationsCompanion.insert({
    required String key,
    required int osId,
    required int taskId,
    required String kind,
    required DateTime fireAt,
    required String title,
    required String body,
    this.snoozedUntil = const Value.absent(),
    this.snoozeOriginalFireAt = const Value.absent(),
    required bool exact,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       osId = Value(osId),
       taskId = Value(taskId),
       kind = Value(kind),
       fireAt = Value(fireAt),
       title = Value(title),
       body = Value(body),
       exact = Value(exact);
  static Insertable<ScheduledNotificationRow> custom({
    Expression<String>? key,
    Expression<int>? osId,
    Expression<int>? taskId,
    Expression<String>? kind,
    Expression<int>? fireAt,
    Expression<String>? title,
    Expression<String>? body,
    Expression<int>? snoozedUntil,
    Expression<int>? snoozeOriginalFireAt,
    Expression<bool>? exact,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (osId != null) 'os_id': osId,
      if (taskId != null) 'task_id': taskId,
      if (kind != null) 'kind': kind,
      if (fireAt != null) 'fire_at': fireAt,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (snoozedUntil != null) 'snoozed_until': snoozedUntil,
      if (snoozeOriginalFireAt != null)
        'snooze_original_fire_at': snoozeOriginalFireAt,
      if (exact != null) 'exact': exact,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScheduledNotificationsCompanion copyWith({
    Value<String>? key,
    Value<int>? osId,
    Value<int>? taskId,
    Value<String>? kind,
    Value<DateTime>? fireAt,
    Value<String>? title,
    Value<String>? body,
    Value<DateTime?>? snoozedUntil,
    Value<DateTime?>? snoozeOriginalFireAt,
    Value<bool>? exact,
    Value<int>? rowid,
  }) {
    return ScheduledNotificationsCompanion(
      key: key ?? this.key,
      osId: osId ?? this.osId,
      taskId: taskId ?? this.taskId,
      kind: kind ?? this.kind,
      fireAt: fireAt ?? this.fireAt,
      title: title ?? this.title,
      body: body ?? this.body,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      snoozeOriginalFireAt: snoozeOriginalFireAt ?? this.snoozeOriginalFireAt,
      exact: exact ?? this.exact,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (osId.present) {
      map['os_id'] = Variable<int>(osId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<int>(taskId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (fireAt.present) {
      map['fire_at'] = Variable<int>(
        $ScheduledNotificationsTable.$converterfireAt.toSql(fireAt.value),
      );
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (snoozedUntil.present) {
      map['snoozed_until'] = Variable<int>(
        $ScheduledNotificationsTable.$convertersnoozedUntiln.toSql(
          snoozedUntil.value,
        ),
      );
    }
    if (snoozeOriginalFireAt.present) {
      map['snooze_original_fire_at'] = Variable<int>(
        $ScheduledNotificationsTable.$convertersnoozeOriginalFireAtn.toSql(
          snoozeOriginalFireAt.value,
        ),
      );
    }
    if (exact.present) {
      map['exact'] = Variable<bool>(exact.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledNotificationsCompanion(')
          ..write('key: $key, ')
          ..write('osId: $osId, ')
          ..write('taskId: $taskId, ')
          ..write('kind: $kind, ')
          ..write('fireAt: $fireAt, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('snoozeOriginalFireAt: $snoozeOriginalFireAt, ')
          ..write('exact: $exact, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $ProjectViewsTable projectViews = $ProjectViewsTable(this);
  late final $LabelsTable labels = $LabelsTable(this);
  late final $UsersTable users = $UsersTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $TaskLabelsTable taskLabels = $TaskLabelsTable(this);
  late final $TaskAssigneesTable taskAssignees = $TaskAssigneesTable(this);
  late final $TaskRemindersTable taskReminders = $TaskRemindersTable(this);
  late final $TaskRelationsTable taskRelations = $TaskRelationsTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $TaskIdRemapsTable taskIdRemaps = $TaskIdRemapsTable(this);
  late final $ScheduledNotificationsTable scheduledNotifications =
      $ScheduledNotificationsTable(this);
  late final Index projectViewsProject = Index(
    'project_views_project',
    'CREATE INDEX project_views_project ON project_views (project_id)',
  );
  late final Index tasksProject = Index(
    'tasks_project',
    'CREATE INDEX tasks_project ON tasks (project_id)',
  );
  late final Index tasksDoneDue = Index(
    'tasks_done_due',
    'CREATE INDEX tasks_done_due ON tasks (done, due_date)',
  );
  late final Index outboxStateSequence = Index(
    'outbox_state_sequence',
    'CREATE INDEX outbox_state_sequence ON outbox (state, sequence)',
  );
  late final ProjectsDao projectsDao = ProjectsDao(this as AppDatabase);
  late final LabelsDao labelsDao = LabelsDao(this as AppDatabase);
  late final UsersDao usersDao = UsersDao(this as AppDatabase);
  late final TasksDao tasksDao = TasksDao(this as AppDatabase);
  late final SyncStateDao syncStateDao = SyncStateDao(this as AppDatabase);
  late final OutboxDao outboxDao = OutboxDao(this as AppDatabase);
  late final ScheduledNotificationsDao scheduledNotificationsDao =
      ScheduledNotificationsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    projects,
    projectViews,
    labels,
    users,
    tasks,
    taskLabels,
    taskAssignees,
    taskReminders,
    taskRelations,
    syncState,
    outbox,
    taskIdRemaps,
    scheduledNotifications,
    projectViewsProject,
    tasksProject,
    tasksDoneDue,
    outboxStateSequence,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('project_views', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_labels', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'labels',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_labels', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_assignees', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'users',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_assignees', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_reminders', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_relations', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ProjectsTableCreateCompanionBuilder = ProjectsCompanion Function({
  Value<int> id,
  required String title,
  required String description,
  required String identifier,
  required String hexColor,
  required int parentProjectId,
  required bool isArchived,
  required bool isFavorite,
  required double position,
  Value<int?> ownerId,
  Value<DateTime?> created,
  Value<DateTime?> updated,
});
typedef $$ProjectsTableUpdateCompanionBuilder = ProjectsCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String> description,
  Value<String> identifier,
  Value<String> hexColor,
  Value<int> parentProjectId,
  Value<bool> isArchived,
  Value<bool> isFavorite,
  Value<double> position,
  Value<int?> ownerId,
  Value<DateTime?> created,
  Value<DateTime?> updated,
});

final class $$ProjectsTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectsTable, ProjectRow> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ProjectViewsTable, List<ProjectViewRow>>
  _projectViewsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.projectViews,
    aliasName: 'projects__id__project_views__project_id',
  );

  $$ProjectViewsTableProcessedTableManager get projectViewsRefs {
    final manager = $$ProjectViewsTableTableManager(
      $_db,
      $_db.projectViews,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_projectViewsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get identifier => $composableBuilder(
    column: $table.identifier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hexColor => $composableBuilder(
    column: $table.hexColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parentProjectId => $composableBuilder(
    column: $table.parentProjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get created =>
      $composableBuilder(
        column: $table.created,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get updated =>
      $composableBuilder(
        column: $table.updated,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  Expression<bool> projectViewsRefs(
    Expression<bool> Function($$ProjectViewsTableFilterComposer f) f,
  ) {
    final $$ProjectViewsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projectViews,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectViewsTableFilterComposer(
            $db: $db,
            $table: $db.projectViews,
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
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get identifier => $composableBuilder(
    column: $table.identifier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hexColor => $composableBuilder(
    column: $table.hexColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parentProjectId => $composableBuilder(
    column: $table.parentProjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updated => $composableBuilder(
    column: $table.updated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get identifier => $composableBuilder(
    column: $table.identifier,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hexColor =>
      $composableBuilder(column: $table.hexColor, builder: (column) => column);

  GeneratedColumn<int> get parentProjectId => $composableBuilder(
    column: $table.parentProjectId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<double> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get updated =>
      $composableBuilder(column: $table.updated, builder: (column) => column);

  Expression<T> projectViewsRefs<T extends Object>(
    Expression<T> Function($$ProjectViewsTableAnnotationComposer a) f,
  ) {
    final $$ProjectViewsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projectViews,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectViewsTableAnnotationComposer(
            $db: $db,
            $table: $db.projectViews,
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
          _$AppDatabase,
          $ProjectsTable,
          ProjectRow,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (ProjectRow, $$ProjectsTableReferences),
          ProjectRow,
          PrefetchHooks Function({bool projectViewsRefs})
        > {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
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
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> identifier = const Value.absent(),
                Value<String> hexColor = const Value.absent(),
                Value<int> parentProjectId = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<double> position = const Value.absent(),
                Value<int?> ownerId = const Value.absent(),
                Value<DateTime?> created = const Value.absent(),
                Value<DateTime?> updated = const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                title: title,
                description: description,
                identifier: identifier,
                hexColor: hexColor,
                parentProjectId: parentProjectId,
                isArchived: isArchived,
                isFavorite: isFavorite,
                position: position,
                ownerId: ownerId,
                created: created,
                updated: updated,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String description,
                required String identifier,
                required String hexColor,
                required int parentProjectId,
                required bool isArchived,
                required bool isFavorite,
                required double position,
                Value<int?> ownerId = const Value.absent(),
                Value<DateTime?> created = const Value.absent(),
                Value<DateTime?> updated = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                title: title,
                description: description,
                identifier: identifier,
                hexColor: hexColor,
                parentProjectId: parentProjectId,
                isArchived: isArchived,
                isFavorite: isFavorite,
                position: position,
                ownerId: ownerId,
                created: created,
                updated: updated,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProjectsTable, ProjectRow>(table),
                  $$ProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectViewsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (projectViewsRefs) db.projectViews],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (projectViewsRefs)
                    await $_getPrefetchedData<
                      ProjectRow,
                      $ProjectsTable,
                      ProjectViewRow
                    >(
                      currentTable: table,
                      referencedTable: $$ProjectsTableReferences
                          ._projectViewsRefsTable(db),
                      managerFromTypedResult: (p0) => $$ProjectsTableReferences(
                        db,
                        table,
                        p0,
                      ).projectViewsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.projectId == item.id),
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
      _$AppDatabase,
      $ProjectsTable,
      ProjectRow,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (ProjectRow, $$ProjectsTableReferences),
      ProjectRow,
      PrefetchHooks Function({bool projectViewsRefs})
    >;
typedef $$ProjectViewsTableCreateCompanionBuilder =
    ProjectViewsCompanion Function({
      Value<int> id,
      required int projectId,
      required String title,
      required String kind,
      required double position,
      Value<String?> filterJson,
      required String bucketConfigurationMode,
      required int defaultBucketId,
      required int doneBucketId,
    });
typedef $$ProjectViewsTableUpdateCompanionBuilder =
    ProjectViewsCompanion Function({
      Value<int> id,
      Value<int> projectId,
      Value<String> title,
      Value<String> kind,
      Value<double> position,
      Value<String?> filterJson,
      Value<String> bucketConfigurationMode,
      Value<int> defaultBucketId,
      Value<int> doneBucketId,
    });

final class $$ProjectViewsTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectViewsTable, ProjectViewRow> {
  $$ProjectViewsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('project_views__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

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

class $$ProjectViewsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectViewsTable> {
  $$ProjectViewsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filterJson => $composableBuilder(
    column: $table.filterJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bucketConfigurationMode => $composableBuilder(
    column: $table.bucketConfigurationMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultBucketId => $composableBuilder(
    column: $table.defaultBucketId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get doneBucketId => $composableBuilder(
    column: $table.doneBucketId,
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

class $$ProjectViewsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectViewsTable> {
  $$ProjectViewsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filterJson => $composableBuilder(
    column: $table.filterJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bucketConfigurationMode => $composableBuilder(
    column: $table.bucketConfigurationMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultBucketId => $composableBuilder(
    column: $table.defaultBucketId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get doneBucketId => $composableBuilder(
    column: $table.doneBucketId,
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

class $$ProjectViewsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectViewsTable> {
  $$ProjectViewsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<double> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get filterJson => $composableBuilder(
    column: $table.filterJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bucketConfigurationMode => $composableBuilder(
    column: $table.bucketConfigurationMode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultBucketId => $composableBuilder(
    column: $table.defaultBucketId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get doneBucketId => $composableBuilder(
    column: $table.doneBucketId,
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
}

class $$ProjectViewsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectViewsTable,
          ProjectViewRow,
          $$ProjectViewsTableFilterComposer,
          $$ProjectViewsTableOrderingComposer,
          $$ProjectViewsTableAnnotationComposer,
          $$ProjectViewsTableCreateCompanionBuilder,
          $$ProjectViewsTableUpdateCompanionBuilder,
          (ProjectViewRow, $$ProjectViewsTableReferences),
          ProjectViewRow,
          PrefetchHooks Function({bool projectId})
        > {
  $$ProjectViewsTableTableManager(_$AppDatabase db, $ProjectViewsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectViewsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectViewsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectViewsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<double> position = const Value.absent(),
                Value<String?> filterJson = const Value.absent(),
                Value<String> bucketConfigurationMode = const Value.absent(),
                Value<int> defaultBucketId = const Value.absent(),
                Value<int> doneBucketId = const Value.absent(),
              }) => ProjectViewsCompanion(
                id: id,
                projectId: projectId,
                title: title,
                kind: kind,
                position: position,
                filterJson: filterJson,
                bucketConfigurationMode: bucketConfigurationMode,
                defaultBucketId: defaultBucketId,
                doneBucketId: doneBucketId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                required String title,
                required String kind,
                required double position,
                Value<String?> filterJson = const Value.absent(),
                required String bucketConfigurationMode,
                required int defaultBucketId,
                required int doneBucketId,
              }) => ProjectViewsCompanion.insert(
                id: id,
                projectId: projectId,
                title: title,
                kind: kind,
                position: position,
                filterJson: filterJson,
                bucketConfigurationMode: bucketConfigurationMode,
                defaultBucketId: defaultBucketId,
                doneBucketId: doneBucketId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProjectViewsTable, ProjectViewRow>(table),
                  $$ProjectViewsTableReferences(db, table, e),
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
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.projectId,
                        referencedTable: $$ProjectViewsTableReferences
                            ._projectIdTable(db),
                        referencedColumn: $$ProjectViewsTableReferences
                            ._projectIdTable(db)
                            .id,
                      ) as T;
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

typedef $$ProjectViewsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectViewsTable,
      ProjectViewRow,
      $$ProjectViewsTableFilterComposer,
      $$ProjectViewsTableOrderingComposer,
      $$ProjectViewsTableAnnotationComposer,
      $$ProjectViewsTableCreateCompanionBuilder,
      $$ProjectViewsTableUpdateCompanionBuilder,
      (ProjectViewRow, $$ProjectViewsTableReferences),
      ProjectViewRow,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$LabelsTableCreateCompanionBuilder = LabelsCompanion Function({
  Value<int> id,
  required String title,
  required String description,
  required String hexColor,
  Value<int?> createdById,
  Value<DateTime?> created,
  Value<DateTime?> updated,
});
typedef $$LabelsTableUpdateCompanionBuilder = LabelsCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String> description,
  Value<String> hexColor,
  Value<int?> createdById,
  Value<DateTime?> created,
  Value<DateTime?> updated,
});

final class $$LabelsTableReferences
    extends BaseReferences<_$AppDatabase, $LabelsTable, LabelRow> {
  $$LabelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TaskLabelsTable, List<TaskLabelRow>>
  _taskLabelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taskLabels,
    aliasName: 'labels__id__task_labels__label_id',
  );

  $$TaskLabelsTableProcessedTableManager get taskLabelsRefs {
    final manager = $$TaskLabelsTableTableManager(
      $_db,
      $_db.taskLabels,
    ).filter((f) => f.labelId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskLabelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LabelsTableFilterComposer
    extends Composer<_$AppDatabase, $LabelsTable> {
  $$LabelsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hexColor => $composableBuilder(
    column: $table.hexColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdById => $composableBuilder(
    column: $table.createdById,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get created =>
      $composableBuilder(
        column: $table.created,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get updated =>
      $composableBuilder(
        column: $table.updated,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  Expression<bool> taskLabelsRefs(
    Expression<bool> Function($$TaskLabelsTableFilterComposer f) f,
  ) {
    final $$TaskLabelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskLabels,
      getReferencedColumn: (t) => t.labelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskLabelsTableFilterComposer(
            $db: $db,
            $table: $db.taskLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LabelsTableOrderingComposer
    extends Composer<_$AppDatabase, $LabelsTable> {
  $$LabelsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hexColor => $composableBuilder(
    column: $table.hexColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdById => $composableBuilder(
    column: $table.createdById,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updated => $composableBuilder(
    column: $table.updated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LabelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LabelsTable> {
  $$LabelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hexColor =>
      $composableBuilder(column: $table.hexColor, builder: (column) => column);

  GeneratedColumn<int> get createdById => $composableBuilder(
    column: $table.createdById,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, int> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get updated =>
      $composableBuilder(column: $table.updated, builder: (column) => column);

  Expression<T> taskLabelsRefs<T extends Object>(
    Expression<T> Function($$TaskLabelsTableAnnotationComposer a) f,
  ) {
    final $$TaskLabelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskLabels,
      getReferencedColumn: (t) => t.labelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskLabelsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LabelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LabelsTable,
          LabelRow,
          $$LabelsTableFilterComposer,
          $$LabelsTableOrderingComposer,
          $$LabelsTableAnnotationComposer,
          $$LabelsTableCreateCompanionBuilder,
          $$LabelsTableUpdateCompanionBuilder,
          (LabelRow, $$LabelsTableReferences),
          LabelRow,
          PrefetchHooks Function({bool taskLabelsRefs})
        > {
  $$LabelsTableTableManager(_$AppDatabase db, $LabelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LabelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LabelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LabelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> hexColor = const Value.absent(),
                Value<int?> createdById = const Value.absent(),
                Value<DateTime?> created = const Value.absent(),
                Value<DateTime?> updated = const Value.absent(),
              }) => LabelsCompanion(
                id: id,
                title: title,
                description: description,
                hexColor: hexColor,
                createdById: createdById,
                created: created,
                updated: updated,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String description,
                required String hexColor,
                Value<int?> createdById = const Value.absent(),
                Value<DateTime?> created = const Value.absent(),
                Value<DateTime?> updated = const Value.absent(),
              }) => LabelsCompanion.insert(
                id: id,
                title: title,
                description: description,
                hexColor: hexColor,
                createdById: createdById,
                created: created,
                updated: updated,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LabelsTable, LabelRow>(table),
                  $$LabelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskLabelsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (taskLabelsRefs) db.taskLabels],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (taskLabelsRefs)
                    await $_getPrefetchedData<
                      LabelRow,
                      $LabelsTable,
                      TaskLabelRow
                    >(
                      currentTable: table,
                      referencedTable: $$LabelsTableReferences
                          ._taskLabelsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LabelsTableReferences(db, table, p0).taskLabelsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.labelId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LabelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LabelsTable,
      LabelRow,
      $$LabelsTableFilterComposer,
      $$LabelsTableOrderingComposer,
      $$LabelsTableAnnotationComposer,
      $$LabelsTableCreateCompanionBuilder,
      $$LabelsTableUpdateCompanionBuilder,
      (LabelRow, $$LabelsTableReferences),
      LabelRow,
      PrefetchHooks Function({bool taskLabelsRefs})
    >;
typedef $$UsersTableCreateCompanionBuilder = UsersCompanion Function({
  Value<int> id,
  required String username,
  required String name,
});
typedef $$UsersTableUpdateCompanionBuilder = UsersCompanion Function({
  Value<int> id,
  Value<String> username,
  Value<String> name,
});

final class $$UsersTableReferences
    extends BaseReferences<_$AppDatabase, $UsersTable, UserRow> {
  $$UsersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TaskAssigneesTable, List<TaskAssigneeRow>>
  _taskAssigneesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taskAssignees,
    aliasName: 'users__id__task_assignees__user_id',
  );

  $$TaskAssigneesTableProcessedTableManager get taskAssigneesRefs {
    final manager = $$TaskAssigneesTableTableManager(
      $_db,
      $_db.taskAssignees,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskAssigneesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
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

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> taskAssigneesRefs(
    Expression<bool> Function($$TaskAssigneesTableFilterComposer f) f,
  ) {
    final $$TaskAssigneesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskAssignees,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskAssigneesTableFilterComposer(
            $db: $db,
            $table: $db.taskAssignees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
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

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> taskAssigneesRefs<T extends Object>(
    Expression<T> Function($$TaskAssigneesTableAnnotationComposer a) f,
  ) {
    final $$TaskAssigneesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskAssignees,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskAssigneesTableAnnotationComposer(
            $db: $db,
            $table: $db.taskAssignees,
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
          _$AppDatabase,
          $UsersTable,
          UserRow,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (UserRow, $$UsersTableReferences),
          UserRow,
          PrefetchHooks Function({bool taskAssigneesRefs})
        > {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
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
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> username = const Value.absent(),
            Value<String> name = const Value.absent(),
          }) => UsersCompanion(id: id, username: username, name: name),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String username,
            required String name,
          }) => UsersCompanion.insert(id: id, username: username, name: name),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UsersTable, UserRow>(table),
                  $$UsersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskAssigneesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (taskAssigneesRefs) db.taskAssignees,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (taskAssigneesRefs)
                    await $_getPrefetchedData<
                      UserRow,
                      $UsersTable,
                      TaskAssigneeRow
                    >(
                      currentTable: table,
                      referencedTable: $$UsersTableReferences
                          ._taskAssigneesRefsTable(db),
                      managerFromTypedResult: (p0) => $$UsersTableReferences(
                        db,
                        table,
                        p0,
                      ).taskAssigneesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.userId == item.id),
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
      _$AppDatabase,
      $UsersTable,
      UserRow,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (UserRow, $$UsersTableReferences),
      UserRow,
      PrefetchHooks Function({bool taskAssigneesRefs})
    >;
typedef $$TasksTableCreateCompanionBuilder = TasksCompanion Function({
  Value<int> id,
  required int projectId,
  required String title,
  required String description,
  required bool done,
  Value<DateTime?> doneAt,
  Value<DateTime?> dueDate,
  Value<DateTime?> startDate,
  Value<DateTime?> endDate,
  required int priority,
  required double percentDone,
  required String hexColor,
  required String identifier,
  required int taskIndex,
  required bool isFavorite,
  required double position,
  required int repeatAfter,
  required int repeatMode,
  required int bucketId,
  Value<int?> createdById,
  Value<DateTime?> created,
  Value<DateTime?> updated,
  Value<String?> syncRunId,
  Value<String?> pendingChanges,
  Value<bool> pendingDelete,
});
typedef $$TasksTableUpdateCompanionBuilder = TasksCompanion Function({
  Value<int> id,
  Value<int> projectId,
  Value<String> title,
  Value<String> description,
  Value<bool> done,
  Value<DateTime?> doneAt,
  Value<DateTime?> dueDate,
  Value<DateTime?> startDate,
  Value<DateTime?> endDate,
  Value<int> priority,
  Value<double> percentDone,
  Value<String> hexColor,
  Value<String> identifier,
  Value<int> taskIndex,
  Value<bool> isFavorite,
  Value<double> position,
  Value<int> repeatAfter,
  Value<int> repeatMode,
  Value<int> bucketId,
  Value<int?> createdById,
  Value<DateTime?> created,
  Value<DateTime?> updated,
  Value<String?> syncRunId,
  Value<String?> pendingChanges,
  Value<bool> pendingDelete,
});

final class $$TasksTableReferences
    extends BaseReferences<_$AppDatabase, $TasksTable, TaskRow> {
  $$TasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TaskLabelsTable, List<TaskLabelRow>>
  _taskLabelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taskLabels,
    aliasName: 'tasks__id__task_labels__task_id',
  );

  $$TaskLabelsTableProcessedTableManager get taskLabelsRefs {
    final manager = $$TaskLabelsTableTableManager(
      $_db,
      $_db.taskLabels,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskLabelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TaskAssigneesTable, List<TaskAssigneeRow>>
  _taskAssigneesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taskAssignees,
    aliasName: 'tasks__id__task_assignees__task_id',
  );

  $$TaskAssigneesTableProcessedTableManager get taskAssigneesRefs {
    final manager = $$TaskAssigneesTableTableManager(
      $_db,
      $_db.taskAssignees,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskAssigneesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TaskRemindersTable, List<TaskReminderRow>>
  _taskRemindersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taskReminders,
    aliasName: 'tasks__id__task_reminders__task_id',
  );

  $$TaskRemindersTableProcessedTableManager get taskRemindersRefs {
    final manager = $$TaskRemindersTableTableManager(
      $_db,
      $_db.taskReminders,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskRemindersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TaskRelationsTable, List<TaskRelationRow>>
  _taskRelationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taskRelations,
    aliasName: 'tasks__id__task_relations__task_id',
  );

  $$TaskRelationsTableProcessedTableManager get taskRelationsRefs {
    final manager = $$TaskRelationsTableTableManager(
      $_db,
      $_db.taskRelations,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskRelationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
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

  ColumnFilters<int> get projectId => $composableBuilder(
    column: $table.projectId,
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

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get doneAt =>
      $composableBuilder(
        column: $table.doneAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get dueDate =>
      $composableBuilder(
        column: $table.dueDate,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get startDate =>
      $composableBuilder(
        column: $table.startDate,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get endDate =>
      $composableBuilder(
        column: $table.endDate,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get percentDone => $composableBuilder(
    column: $table.percentDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hexColor => $composableBuilder(
    column: $table.hexColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get identifier => $composableBuilder(
    column: $table.identifier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taskIndex => $composableBuilder(
    column: $table.taskIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repeatAfter => $composableBuilder(
    column: $table.repeatAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repeatMode => $composableBuilder(
    column: $table.repeatMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bucketId => $composableBuilder(
    column: $table.bucketId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdById => $composableBuilder(
    column: $table.createdById,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get created =>
      $composableBuilder(
        column: $table.created,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get updated =>
      $composableBuilder(
        column: $table.updated,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get syncRunId => $composableBuilder(
    column: $table.syncRunId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pendingChanges => $composableBuilder(
    column: $table.pendingChanges,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pendingDelete => $composableBuilder(
    column: $table.pendingDelete,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> taskLabelsRefs(
    Expression<bool> Function($$TaskLabelsTableFilterComposer f) f,
  ) {
    final $$TaskLabelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskLabels,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskLabelsTableFilterComposer(
            $db: $db,
            $table: $db.taskLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> taskAssigneesRefs(
    Expression<bool> Function($$TaskAssigneesTableFilterComposer f) f,
  ) {
    final $$TaskAssigneesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskAssignees,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskAssigneesTableFilterComposer(
            $db: $db,
            $table: $db.taskAssignees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> taskRemindersRefs(
    Expression<bool> Function($$TaskRemindersTableFilterComposer f) f,
  ) {
    final $$TaskRemindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskReminders,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRemindersTableFilterComposer(
            $db: $db,
            $table: $db.taskReminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> taskRelationsRefs(
    Expression<bool> Function($$TaskRelationsTableFilterComposer f) f,
  ) {
    final $$TaskRelationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskRelations,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRelationsTableFilterComposer(
            $db: $db,
            $table: $db.taskRelations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
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

  ColumnOrderings<int> get projectId => $composableBuilder(
    column: $table.projectId,
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

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get doneAt => $composableBuilder(
    column: $table.doneAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get percentDone => $composableBuilder(
    column: $table.percentDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hexColor => $composableBuilder(
    column: $table.hexColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get identifier => $composableBuilder(
    column: $table.identifier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taskIndex => $composableBuilder(
    column: $table.taskIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repeatAfter => $composableBuilder(
    column: $table.repeatAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repeatMode => $composableBuilder(
    column: $table.repeatMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bucketId => $composableBuilder(
    column: $table.bucketId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdById => $composableBuilder(
    column: $table.createdById,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updated => $composableBuilder(
    column: $table.updated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncRunId => $composableBuilder(
    column: $table.syncRunId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingChanges => $composableBuilder(
    column: $table.pendingChanges,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pendingDelete => $composableBuilder(
    column: $table.pendingDelete,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get doneAt =>
      $composableBuilder(column: $table.doneAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<double> get percentDone => $composableBuilder(
    column: $table.percentDone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hexColor =>
      $composableBuilder(column: $table.hexColor, builder: (column) => column);

  GeneratedColumn<String> get identifier => $composableBuilder(
    column: $table.identifier,
    builder: (column) => column,
  );

  GeneratedColumn<int> get taskIndex =>
      $composableBuilder(column: $table.taskIndex, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<double> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get repeatAfter => $composableBuilder(
    column: $table.repeatAfter,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repeatMode => $composableBuilder(
    column: $table.repeatMode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bucketId =>
      $composableBuilder(column: $table.bucketId, builder: (column) => column);

  GeneratedColumn<int> get createdById => $composableBuilder(
    column: $table.createdById,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, int> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get updated =>
      $composableBuilder(column: $table.updated, builder: (column) => column);

  GeneratedColumn<String> get syncRunId =>
      $composableBuilder(column: $table.syncRunId, builder: (column) => column);

  GeneratedColumn<String> get pendingChanges => $composableBuilder(
    column: $table.pendingChanges,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pendingDelete => $composableBuilder(
    column: $table.pendingDelete,
    builder: (column) => column,
  );

  Expression<T> taskLabelsRefs<T extends Object>(
    Expression<T> Function($$TaskLabelsTableAnnotationComposer a) f,
  ) {
    final $$TaskLabelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskLabels,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskLabelsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> taskAssigneesRefs<T extends Object>(
    Expression<T> Function($$TaskAssigneesTableAnnotationComposer a) f,
  ) {
    final $$TaskAssigneesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskAssignees,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskAssigneesTableAnnotationComposer(
            $db: $db,
            $table: $db.taskAssignees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> taskRemindersRefs<T extends Object>(
    Expression<T> Function($$TaskRemindersTableAnnotationComposer a) f,
  ) {
    final $$TaskRemindersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskReminders,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRemindersTableAnnotationComposer(
            $db: $db,
            $table: $db.taskReminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> taskRelationsRefs<T extends Object>(
    Expression<T> Function($$TaskRelationsTableAnnotationComposer a) f,
  ) {
    final $$TaskRelationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskRelations,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRelationsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskRelations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          TaskRow,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (TaskRow, $$TasksTableReferences),
          TaskRow,
          PrefetchHooks Function({
            bool taskLabelsRefs,
            bool taskAssigneesRefs,
            bool taskRemindersRefs,
            bool taskRelationsRefs,
          })
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<DateTime?> doneAt = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<double> percentDone = const Value.absent(),
                Value<String> hexColor = const Value.absent(),
                Value<String> identifier = const Value.absent(),
                Value<int> taskIndex = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<double> position = const Value.absent(),
                Value<int> repeatAfter = const Value.absent(),
                Value<int> repeatMode = const Value.absent(),
                Value<int> bucketId = const Value.absent(),
                Value<int?> createdById = const Value.absent(),
                Value<DateTime?> created = const Value.absent(),
                Value<DateTime?> updated = const Value.absent(),
                Value<String?> syncRunId = const Value.absent(),
                Value<String?> pendingChanges = const Value.absent(),
                Value<bool> pendingDelete = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                projectId: projectId,
                title: title,
                description: description,
                done: done,
                doneAt: doneAt,
                dueDate: dueDate,
                startDate: startDate,
                endDate: endDate,
                priority: priority,
                percentDone: percentDone,
                hexColor: hexColor,
                identifier: identifier,
                taskIndex: taskIndex,
                isFavorite: isFavorite,
                position: position,
                repeatAfter: repeatAfter,
                repeatMode: repeatMode,
                bucketId: bucketId,
                createdById: createdById,
                created: created,
                updated: updated,
                syncRunId: syncRunId,
                pendingChanges: pendingChanges,
                pendingDelete: pendingDelete,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                required String title,
                required String description,
                required bool done,
                Value<DateTime?> doneAt = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                required int priority,
                required double percentDone,
                required String hexColor,
                required String identifier,
                required int taskIndex,
                required bool isFavorite,
                required double position,
                required int repeatAfter,
                required int repeatMode,
                required int bucketId,
                Value<int?> createdById = const Value.absent(),
                Value<DateTime?> created = const Value.absent(),
                Value<DateTime?> updated = const Value.absent(),
                Value<String?> syncRunId = const Value.absent(),
                Value<String?> pendingChanges = const Value.absent(),
                Value<bool> pendingDelete = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                projectId: projectId,
                title: title,
                description: description,
                done: done,
                doneAt: doneAt,
                dueDate: dueDate,
                startDate: startDate,
                endDate: endDate,
                priority: priority,
                percentDone: percentDone,
                hexColor: hexColor,
                identifier: identifier,
                taskIndex: taskIndex,
                isFavorite: isFavorite,
                position: position,
                repeatAfter: repeatAfter,
                repeatMode: repeatMode,
                bucketId: bucketId,
                createdById: createdById,
                created: created,
                updated: updated,
                syncRunId: syncRunId,
                pendingChanges: pendingChanges,
                pendingDelete: pendingDelete,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TasksTable, TaskRow>(table),
                  $$TasksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                taskLabelsRefs = false,
                taskAssigneesRefs = false,
                taskRemindersRefs = false,
                taskRelationsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (taskLabelsRefs) db.taskLabels,
                    if (taskAssigneesRefs) db.taskAssignees,
                    if (taskRemindersRefs) db.taskReminders,
                    if (taskRelationsRefs) db.taskRelations,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (taskLabelsRefs)
                        await $_getPrefetchedData<
                          TaskRow,
                          $TasksTable,
                          TaskLabelRow
                        >(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._taskLabelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).taskLabelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (taskAssigneesRefs)
                        await $_getPrefetchedData<
                          TaskRow,
                          $TasksTable,
                          TaskAssigneeRow
                        >(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._taskAssigneesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).taskAssigneesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (taskRemindersRefs)
                        await $_getPrefetchedData<
                          TaskRow,
                          $TasksTable,
                          TaskReminderRow
                        >(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._taskRemindersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).taskRemindersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (taskRelationsRefs)
                        await $_getPrefetchedData<
                          TaskRow,
                          $TasksTable,
                          TaskRelationRow
                        >(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._taskRelationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).taskRelationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
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

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      TaskRow,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (TaskRow, $$TasksTableReferences),
      TaskRow,
      PrefetchHooks Function({
        bool taskLabelsRefs,
        bool taskAssigneesRefs,
        bool taskRemindersRefs,
        bool taskRelationsRefs,
      })
    >;
typedef $$TaskLabelsTableCreateCompanionBuilder = TaskLabelsCompanion Function({
  required int taskId,
  required int labelId,
  Value<int> rowid,
});
typedef $$TaskLabelsTableUpdateCompanionBuilder = TaskLabelsCompanion Function({
  Value<int> taskId,
  Value<int> labelId,
  Value<int> rowid,
});

final class $$TaskLabelsTableReferences
    extends BaseReferences<_$AppDatabase, $TaskLabelsTable, TaskLabelRow> {
  $$TaskLabelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TasksTable _taskIdTable(_$AppDatabase db) =>
      db.tasks.createAlias('task_labels__task_id__tasks__id');

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<int>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LabelsTable _labelIdTable(_$AppDatabase db) =>
      db.labels.createAlias('task_labels__label_id__labels__id');

  $$LabelsTableProcessedTableManager get labelId {
    final $_column = $_itemColumn<int>('label_id')!;

    final manager = $$LabelsTableTableManager(
      $_db,
      $_db.labels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_labelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TaskLabelsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskLabelsTable> {
  $$TaskLabelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LabelsTableFilterComposer get labelId {
    final $$LabelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.labelId,
      referencedTable: $db.labels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LabelsTableFilterComposer(
            $db: $db,
            $table: $db.labels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskLabelsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskLabelsTable> {
  $$TaskLabelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LabelsTableOrderingComposer get labelId {
    final $$LabelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.labelId,
      referencedTable: $db.labels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LabelsTableOrderingComposer(
            $db: $db,
            $table: $db.labels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskLabelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskLabelsTable> {
  $$TaskLabelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LabelsTableAnnotationComposer get labelId {
    final $$LabelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.labelId,
      referencedTable: $db.labels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LabelsTableAnnotationComposer(
            $db: $db,
            $table: $db.labels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskLabelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskLabelsTable,
          TaskLabelRow,
          $$TaskLabelsTableFilterComposer,
          $$TaskLabelsTableOrderingComposer,
          $$TaskLabelsTableAnnotationComposer,
          $$TaskLabelsTableCreateCompanionBuilder,
          $$TaskLabelsTableUpdateCompanionBuilder,
          (TaskLabelRow, $$TaskLabelsTableReferences),
          TaskLabelRow,
          PrefetchHooks Function({bool taskId, bool labelId})
        > {
  $$TaskLabelsTableTableManager(_$AppDatabase db, $TaskLabelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskLabelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskLabelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskLabelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> taskId = const Value.absent(),
                Value<int> labelId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskLabelsCompanion(
                taskId: taskId,
                labelId: labelId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int taskId,
                required int labelId,
                Value<int> rowid = const Value.absent(),
              }) => TaskLabelsCompanion.insert(
                taskId: taskId,
                labelId: labelId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TaskLabelsTable, TaskLabelRow>(table),
                  $$TaskLabelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false, labelId = false}) {
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
                    if (taskId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.taskId,
                        referencedTable: $$TaskLabelsTableReferences
                            ._taskIdTable(db),
                        referencedColumn: $$TaskLabelsTableReferences
                            ._taskIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (labelId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.labelId,
                        referencedTable: $$TaskLabelsTableReferences
                            ._labelIdTable(db),
                        referencedColumn: $$TaskLabelsTableReferences
                            ._labelIdTable(db)
                            .id,
                      ) as T;
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

typedef $$TaskLabelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskLabelsTable,
      TaskLabelRow,
      $$TaskLabelsTableFilterComposer,
      $$TaskLabelsTableOrderingComposer,
      $$TaskLabelsTableAnnotationComposer,
      $$TaskLabelsTableCreateCompanionBuilder,
      $$TaskLabelsTableUpdateCompanionBuilder,
      (TaskLabelRow, $$TaskLabelsTableReferences),
      TaskLabelRow,
      PrefetchHooks Function({bool taskId, bool labelId})
    >;
typedef $$TaskAssigneesTableCreateCompanionBuilder =
    TaskAssigneesCompanion Function({
      required int taskId,
      required int userId,
      Value<int> rowid,
    });
typedef $$TaskAssigneesTableUpdateCompanionBuilder =
    TaskAssigneesCompanion Function({
      Value<int> taskId,
      Value<int> userId,
      Value<int> rowid,
    });

final class $$TaskAssigneesTableReferences
    extends
        BaseReferences<_$AppDatabase, $TaskAssigneesTable, TaskAssigneeRow> {
  $$TaskAssigneesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TasksTable _taskIdTable(_$AppDatabase db) =>
      db.tasks.createAlias('task_assignees__task_id__tasks__id');

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<int>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UsersTable _userIdTable(_$AppDatabase db) =>
      db.users.createAlias('task_assignees__user_id__users__id');

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<int>('user_id')!;

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

class $$TaskAssigneesTableFilterComposer
    extends Composer<_$AppDatabase, $TaskAssigneesTable> {
  $$TaskAssigneesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
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

class $$TaskAssigneesTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskAssigneesTable> {
  $$TaskAssigneesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
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

class $$TaskAssigneesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskAssigneesTable> {
  $$TaskAssigneesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
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

class $$TaskAssigneesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskAssigneesTable,
          TaskAssigneeRow,
          $$TaskAssigneesTableFilterComposer,
          $$TaskAssigneesTableOrderingComposer,
          $$TaskAssigneesTableAnnotationComposer,
          $$TaskAssigneesTableCreateCompanionBuilder,
          $$TaskAssigneesTableUpdateCompanionBuilder,
          (TaskAssigneeRow, $$TaskAssigneesTableReferences),
          TaskAssigneeRow,
          PrefetchHooks Function({bool taskId, bool userId})
        > {
  $$TaskAssigneesTableTableManager(_$AppDatabase db, $TaskAssigneesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskAssigneesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskAssigneesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskAssigneesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> taskId = const Value.absent(),
                Value<int> userId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskAssigneesCompanion(
                taskId: taskId,
                userId: userId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int taskId,
                required int userId,
                Value<int> rowid = const Value.absent(),
              }) => TaskAssigneesCompanion.insert(
                taskId: taskId,
                userId: userId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TaskAssigneesTable, TaskAssigneeRow>(table),
                  $$TaskAssigneesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false, userId = false}) {
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
                    if (taskId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.taskId,
                        referencedTable: $$TaskAssigneesTableReferences
                            ._taskIdTable(db),
                        referencedColumn: $$TaskAssigneesTableReferences
                            ._taskIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (userId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.userId,
                        referencedTable: $$TaskAssigneesTableReferences
                            ._userIdTable(db),
                        referencedColumn: $$TaskAssigneesTableReferences
                            ._userIdTable(db)
                            .id,
                      ) as T;
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

typedef $$TaskAssigneesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskAssigneesTable,
      TaskAssigneeRow,
      $$TaskAssigneesTableFilterComposer,
      $$TaskAssigneesTableOrderingComposer,
      $$TaskAssigneesTableAnnotationComposer,
      $$TaskAssigneesTableCreateCompanionBuilder,
      $$TaskAssigneesTableUpdateCompanionBuilder,
      (TaskAssigneeRow, $$TaskAssigneesTableReferences),
      TaskAssigneeRow,
      PrefetchHooks Function({bool taskId, bool userId})
    >;
typedef $$TaskRemindersTableCreateCompanionBuilder =
    TaskRemindersCompanion Function({
      required int taskId,
      required int ordinal,
      Value<DateTime?> reminder,
      required int relativePeriod,
      Value<String?> relativeTo,
      Value<int> rowid,
    });
typedef $$TaskRemindersTableUpdateCompanionBuilder =
    TaskRemindersCompanion Function({
      Value<int> taskId,
      Value<int> ordinal,
      Value<DateTime?> reminder,
      Value<int> relativePeriod,
      Value<String?> relativeTo,
      Value<int> rowid,
    });

final class $$TaskRemindersTableReferences
    extends
        BaseReferences<_$AppDatabase, $TaskRemindersTable, TaskReminderRow> {
  $$TaskRemindersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TasksTable _taskIdTable(_$AppDatabase db) =>
      db.tasks.createAlias('task_reminders__task_id__tasks__id');

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<int>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TaskRemindersTableFilterComposer
    extends Composer<_$AppDatabase, $TaskRemindersTable> {
  $$TaskRemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get reminder =>
      $composableBuilder(
        column: $table.reminder,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get relativePeriod => $composableBuilder(
    column: $table.relativePeriod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativeTo => $composableBuilder(
    column: $table.relativeTo,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskRemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskRemindersTable> {
  $$TaskRemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminder => $composableBuilder(
    column: $table.reminder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get relativePeriod => $composableBuilder(
    column: $table.relativePeriod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativeTo => $composableBuilder(
    column: $table.relativeTo,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskRemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskRemindersTable> {
  $$TaskRemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get reminder =>
      $composableBuilder(column: $table.reminder, builder: (column) => column);

  GeneratedColumn<int> get relativePeriod => $composableBuilder(
    column: $table.relativePeriod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relativeTo => $composableBuilder(
    column: $table.relativeTo,
    builder: (column) => column,
  );

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskRemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskRemindersTable,
          TaskReminderRow,
          $$TaskRemindersTableFilterComposer,
          $$TaskRemindersTableOrderingComposer,
          $$TaskRemindersTableAnnotationComposer,
          $$TaskRemindersTableCreateCompanionBuilder,
          $$TaskRemindersTableUpdateCompanionBuilder,
          (TaskReminderRow, $$TaskRemindersTableReferences),
          TaskReminderRow,
          PrefetchHooks Function({bool taskId})
        > {
  $$TaskRemindersTableTableManager(_$AppDatabase db, $TaskRemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskRemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskRemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskRemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> taskId = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<DateTime?> reminder = const Value.absent(),
                Value<int> relativePeriod = const Value.absent(),
                Value<String?> relativeTo = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskRemindersCompanion(
                taskId: taskId,
                ordinal: ordinal,
                reminder: reminder,
                relativePeriod: relativePeriod,
                relativeTo: relativeTo,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int taskId,
                required int ordinal,
                Value<DateTime?> reminder = const Value.absent(),
                required int relativePeriod,
                Value<String?> relativeTo = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskRemindersCompanion.insert(
                taskId: taskId,
                ordinal: ordinal,
                reminder: reminder,
                relativePeriod: relativePeriod,
                relativeTo: relativeTo,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TaskRemindersTable, TaskReminderRow>(table),
                  $$TaskRemindersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
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
                    if (taskId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.taskId,
                        referencedTable: $$TaskRemindersTableReferences
                            ._taskIdTable(db),
                        referencedColumn: $$TaskRemindersTableReferences
                            ._taskIdTable(db)
                            .id,
                      ) as T;
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

typedef $$TaskRemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskRemindersTable,
      TaskReminderRow,
      $$TaskRemindersTableFilterComposer,
      $$TaskRemindersTableOrderingComposer,
      $$TaskRemindersTableAnnotationComposer,
      $$TaskRemindersTableCreateCompanionBuilder,
      $$TaskRemindersTableUpdateCompanionBuilder,
      (TaskReminderRow, $$TaskRemindersTableReferences),
      TaskReminderRow,
      PrefetchHooks Function({bool taskId})
    >;
typedef $$TaskRelationsTableCreateCompanionBuilder =
    TaskRelationsCompanion Function({
      required int taskId,
      required int otherTaskId,
      required String kind,
      Value<int> rowid,
    });
typedef $$TaskRelationsTableUpdateCompanionBuilder =
    TaskRelationsCompanion Function({
      Value<int> taskId,
      Value<int> otherTaskId,
      Value<String> kind,
      Value<int> rowid,
    });

final class $$TaskRelationsTableReferences
    extends
        BaseReferences<_$AppDatabase, $TaskRelationsTable, TaskRelationRow> {
  $$TaskRelationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TasksTable _taskIdTable(_$AppDatabase db) =>
      db.tasks.createAlias('task_relations__task_id__tasks__id');

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<int>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TaskRelationsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskRelationsTable> {
  $$TaskRelationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get otherTaskId => $composableBuilder(
    column: $table.otherTaskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskRelationsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskRelationsTable> {
  $$TaskRelationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get otherTaskId => $composableBuilder(
    column: $table.otherTaskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskRelationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskRelationsTable> {
  $$TaskRelationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get otherTaskId => $composableBuilder(
    column: $table.otherTaskId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskRelationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskRelationsTable,
          TaskRelationRow,
          $$TaskRelationsTableFilterComposer,
          $$TaskRelationsTableOrderingComposer,
          $$TaskRelationsTableAnnotationComposer,
          $$TaskRelationsTableCreateCompanionBuilder,
          $$TaskRelationsTableUpdateCompanionBuilder,
          (TaskRelationRow, $$TaskRelationsTableReferences),
          TaskRelationRow,
          PrefetchHooks Function({bool taskId})
        > {
  $$TaskRelationsTableTableManager(_$AppDatabase db, $TaskRelationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskRelationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskRelationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskRelationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> taskId = const Value.absent(),
                Value<int> otherTaskId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskRelationsCompanion(
                taskId: taskId,
                otherTaskId: otherTaskId,
                kind: kind,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int taskId,
                required int otherTaskId,
                required String kind,
                Value<int> rowid = const Value.absent(),
              }) => TaskRelationsCompanion.insert(
                taskId: taskId,
                otherTaskId: otherTaskId,
                kind: kind,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TaskRelationsTable, TaskRelationRow>(table),
                  $$TaskRelationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
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
                    if (taskId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.taskId,
                        referencedTable: $$TaskRelationsTableReferences
                            ._taskIdTable(db),
                        referencedColumn: $$TaskRelationsTableReferences
                            ._taskIdTable(db)
                            .id,
                      ) as T;
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

typedef $$TaskRelationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskRelationsTable,
      TaskRelationRow,
      $$TaskRelationsTableFilterComposer,
      $$TaskRelationsTableOrderingComposer,
      $$TaskRelationsTableAnnotationComposer,
      $$TaskRelationsTableCreateCompanionBuilder,
      $$TaskRelationsTableUpdateCompanionBuilder,
      (TaskRelationRow, $$TaskRelationsTableReferences),
      TaskRelationRow,
      PrefetchHooks Function({bool taskId})
    >;
typedef $$SyncStateTableCreateCompanionBuilder = SyncStateCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SyncStateTableUpdateCompanionBuilder = SyncStateCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateRow,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
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
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncStateCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SyncStateCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStateTable, SyncStateRow>(table),
                  BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateRow,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateRow,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>,
      ),
      SyncStateRow,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  required String id,
  required int sequence,
  required String kind,
  required int taskId,
  required String payload,
  required DateTime createdAt,
  required int attempts,
  Value<DateTime?> nextAttemptAt,
  Value<DateTime?> lastAttemptAt,
  required String state,
  Value<String?> lastError,
  Value<DateTime?> sentAt,
  Value<int> rowid,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<String> id,
  Value<int> sequence,
  Value<String> kind,
  Value<int> taskId,
  Value<String> payload,
  Value<DateTime> createdAt,
  Value<int> attempts,
  Value<DateTime?> nextAttemptAt,
  Value<DateTime?> lastAttemptAt,
  Value<String> state,
  Value<String?> lastError,
  Value<DateTime?> sentAt,
  Value<int> rowid,
});

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
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

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get nextAttemptAt =>
      $composableBuilder(
        column: $table.nextAttemptAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get lastAttemptAt =>
      $composableBuilder(
        column: $table.lastAttemptAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get sentAt =>
      $composableBuilder(
        column: $table.sentAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
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

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get nextAttemptAt =>
      $composableBuilder(
        column: $table.nextAttemptAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime?, int> get lastAttemptAt =>
      $composableBuilder(
        column: $table.lastAttemptAt,
        builder: (column) => column,
      );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxRow,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> taskId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> sentAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                sequence: sequence,
                kind: kind,
                taskId: taskId,
                payload: payload,
                createdAt: createdAt,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                lastAttemptAt: lastAttemptAt,
                state: state,
                lastError: lastError,
                sentAt: sentAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int sequence,
                required String kind,
                required int taskId,
                required String payload,
                required DateTime createdAt,
                required int attempts,
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                required String state,
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> sentAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion.insert(
                id: id,
                sequence: sequence,
                kind: kind,
                taskId: taskId,
                payload: payload,
                createdAt: createdAt,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                lastAttemptAt: lastAttemptAt,
                state: state,
                lastError: lastError,
                sentAt: sentAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxRow>(table),
                  BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxRow,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$TaskIdRemapsTableCreateCompanionBuilder =
    TaskIdRemapsCompanion Function({
      Value<int> localId,
      required int serverId,
      required DateTime at,
    });
typedef $$TaskIdRemapsTableUpdateCompanionBuilder =
    TaskIdRemapsCompanion Function({
      Value<int> localId,
      Value<int> serverId,
      Value<DateTime> at,
    });

class $$TaskIdRemapsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskIdRemapsTable> {
  $$TaskIdRemapsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get at =>
      $composableBuilder(
        column: $table.at,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$TaskIdRemapsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskIdRemapsTable> {
  $$TaskIdRemapsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaskIdRemapsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskIdRemapsTable> {
  $$TaskIdRemapsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);
}

class $$TaskIdRemapsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskIdRemapsTable,
          TaskIdRemapRow,
          $$TaskIdRemapsTableFilterComposer,
          $$TaskIdRemapsTableOrderingComposer,
          $$TaskIdRemapsTableAnnotationComposer,
          $$TaskIdRemapsTableCreateCompanionBuilder,
          $$TaskIdRemapsTableUpdateCompanionBuilder,
          (
            TaskIdRemapRow,
            BaseReferences<_$AppDatabase, $TaskIdRemapsTable, TaskIdRemapRow>,
          ),
          TaskIdRemapRow,
          PrefetchHooks Function()
        > {
  $$TaskIdRemapsTableTableManager(_$AppDatabase db, $TaskIdRemapsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskIdRemapsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskIdRemapsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskIdRemapsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> localId = const Value.absent(),
                Value<int> serverId = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
              }) => TaskIdRemapsCompanion(
                localId: localId,
                serverId: serverId,
                at: at,
              ),
          createCompanionCallback:
              ({
                Value<int> localId = const Value.absent(),
                required int serverId,
                required DateTime at,
              }) => TaskIdRemapsCompanion.insert(
                localId: localId,
                serverId: serverId,
                at: at,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TaskIdRemapsTable, TaskIdRemapRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $TaskIdRemapsTable,
                    TaskIdRemapRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TaskIdRemapsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskIdRemapsTable,
      TaskIdRemapRow,
      $$TaskIdRemapsTableFilterComposer,
      $$TaskIdRemapsTableOrderingComposer,
      $$TaskIdRemapsTableAnnotationComposer,
      $$TaskIdRemapsTableCreateCompanionBuilder,
      $$TaskIdRemapsTableUpdateCompanionBuilder,
      (
        TaskIdRemapRow,
        BaseReferences<_$AppDatabase, $TaskIdRemapsTable, TaskIdRemapRow>,
      ),
      TaskIdRemapRow,
      PrefetchHooks Function()
    >;
typedef $$ScheduledNotificationsTableCreateCompanionBuilder =
    ScheduledNotificationsCompanion Function({
      required String key,
      required int osId,
      required int taskId,
      required String kind,
      required DateTime fireAt,
      required String title,
      required String body,
      Value<DateTime?> snoozedUntil,
      Value<DateTime?> snoozeOriginalFireAt,
      required bool exact,
      Value<int> rowid,
    });
typedef $$ScheduledNotificationsTableUpdateCompanionBuilder =
    ScheduledNotificationsCompanion Function({
      Value<String> key,
      Value<int> osId,
      Value<int> taskId,
      Value<String> kind,
      Value<DateTime> fireAt,
      Value<String> title,
      Value<String> body,
      Value<DateTime?> snoozedUntil,
      Value<DateTime?> snoozeOriginalFireAt,
      Value<bool> exact,
      Value<int> rowid,
    });

class $$ScheduledNotificationsTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduledNotificationsTable> {
  $$ScheduledNotificationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get osId => $composableBuilder(
    column: $table.osId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get fireAt =>
      $composableBuilder(
        column: $table.fireAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get snoozedUntil =>
      $composableBuilder(
        column: $table.snoozedUntil,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int>
  get snoozeOriginalFireAt => $composableBuilder(
    column: $table.snoozeOriginalFireAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get exact => $composableBuilder(
    column: $table.exact,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScheduledNotificationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduledNotificationsTable> {
  $$ScheduledNotificationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get osId => $composableBuilder(
    column: $table.osId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fireAt => $composableBuilder(
    column: $table.fireAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozeOriginalFireAt => $composableBuilder(
    column: $table.snoozeOriginalFireAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get exact => $composableBuilder(
    column: $table.exact,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScheduledNotificationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduledNotificationsTable> {
  $$ScheduledNotificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get osId =>
      $composableBuilder(column: $table.osId, builder: (column) => column);

  GeneratedColumn<int> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get fireAt =>
      $composableBuilder(column: $table.fireAt, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get snoozedUntil =>
      $composableBuilder(
        column: $table.snoozedUntil,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime?, int> get snoozeOriginalFireAt =>
      $composableBuilder(
        column: $table.snoozeOriginalFireAt,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get exact =>
      $composableBuilder(column: $table.exact, builder: (column) => column);
}

class $$ScheduledNotificationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduledNotificationsTable,
          ScheduledNotificationRow,
          $$ScheduledNotificationsTableFilterComposer,
          $$ScheduledNotificationsTableOrderingComposer,
          $$ScheduledNotificationsTableAnnotationComposer,
          $$ScheduledNotificationsTableCreateCompanionBuilder,
          $$ScheduledNotificationsTableUpdateCompanionBuilder,
          (
            ScheduledNotificationRow,
            BaseReferences<
              _$AppDatabase,
              $ScheduledNotificationsTable,
              ScheduledNotificationRow
            >,
          ),
          ScheduledNotificationRow,
          PrefetchHooks Function()
        > {
  $$ScheduledNotificationsTableTableManager(
    _$AppDatabase db,
    $ScheduledNotificationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduledNotificationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ScheduledNotificationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ScheduledNotificationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<int> osId = const Value.absent(),
                Value<int> taskId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<DateTime> fireAt = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<DateTime?> snoozeOriginalFireAt = const Value.absent(),
                Value<bool> exact = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduledNotificationsCompanion(
                key: key,
                osId: osId,
                taskId: taskId,
                kind: kind,
                fireAt: fireAt,
                title: title,
                body: body,
                snoozedUntil: snoozedUntil,
                snoozeOriginalFireAt: snoozeOriginalFireAt,
                exact: exact,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required int osId,
                required int taskId,
                required String kind,
                required DateTime fireAt,
                required String title,
                required String body,
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<DateTime?> snoozeOriginalFireAt = const Value.absent(),
                required bool exact,
                Value<int> rowid = const Value.absent(),
              }) => ScheduledNotificationsCompanion.insert(
                key: key,
                osId: osId,
                taskId: taskId,
                kind: kind,
                fireAt: fireAt,
                title: title,
                body: body,
                snoozedUntil: snoozedUntil,
                snoozeOriginalFireAt: snoozeOriginalFireAt,
                exact: exact,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ScheduledNotificationsTable,
                    ScheduledNotificationRow
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ScheduledNotificationsTable,
                    ScheduledNotificationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScheduledNotificationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduledNotificationsTable,
      ScheduledNotificationRow,
      $$ScheduledNotificationsTableFilterComposer,
      $$ScheduledNotificationsTableOrderingComposer,
      $$ScheduledNotificationsTableAnnotationComposer,
      $$ScheduledNotificationsTableCreateCompanionBuilder,
      $$ScheduledNotificationsTableUpdateCompanionBuilder,
      (
        ScheduledNotificationRow,
        BaseReferences<
          _$AppDatabase,
          $ScheduledNotificationsTable,
          ScheduledNotificationRow
        >,
      ),
      ScheduledNotificationRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$ProjectViewsTableTableManager get projectViews =>
      $$ProjectViewsTableTableManager(_db, _db.projectViews);
  $$LabelsTableTableManager get labels =>
      $$LabelsTableTableManager(_db, _db.labels);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$TaskLabelsTableTableManager get taskLabels =>
      $$TaskLabelsTableTableManager(_db, _db.taskLabels);
  $$TaskAssigneesTableTableManager get taskAssignees =>
      $$TaskAssigneesTableTableManager(_db, _db.taskAssignees);
  $$TaskRemindersTableTableManager get taskReminders =>
      $$TaskRemindersTableTableManager(_db, _db.taskReminders);
  $$TaskRelationsTableTableManager get taskRelations =>
      $$TaskRelationsTableTableManager(_db, _db.taskRelations);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$TaskIdRemapsTableTableManager get taskIdRemaps =>
      $$TaskIdRemapsTableTableManager(_db, _db.taskIdRemaps);
  $$ScheduledNotificationsTableTableManager get scheduledNotifications =>
      $$ScheduledNotificationsTableTableManager(
        _db,
        _db.scheduledNotifications,
      );
}
