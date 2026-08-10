// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ReportDraftsTable extends ReportDrafts
    with TableInfo<$ReportDraftsTable, ReportDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReportDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _severityMeta =
      const VerificationMeta('severity');
  @override
  late final GeneratedColumn<String> severity = GeneratedColumn<String>(
      'severity', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _altitudeMetersMeta =
      const VerificationMeta('altitudeMeters');
  @override
  late final GeneratedColumn<double> altitudeMeters = GeneratedColumn<double>(
      'altitude_meters', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _accuracyMetersMeta =
      const VerificationMeta('accuracyMeters');
  @override
  late final GeneratedColumn<double> accuracyMeters = GeneratedColumn<double>(
      'accuracy_meters', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _bearingDegreesMeta =
      const VerificationMeta('bearingDegrees');
  @override
  late final GeneratedColumn<double> bearingDegrees = GeneratedColumn<double>(
      'bearing_degrees', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _speedMpsMeta =
      const VerificationMeta('speedMps');
  @override
  late final GeneratedColumn<double> speedMps = GeneratedColumn<double>(
      'speed_mps', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _capturedAtUtcMeta =
      const VerificationMeta('capturedAtUtc');
  @override
  late final GeneratedColumn<DateTime> capturedAtUtc =
      GeneratedColumn<DateTime>('captured_at_utc', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _thumbnailPathMeta =
      const VerificationMeta('thumbnailPath');
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
      'thumbnail_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contractorIdMeta =
      const VerificationMeta('contractorId');
  @override
  late final GeneratedColumn<String> contractorId = GeneratedColumn<String>(
      'contractor_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _infrastructureIdMeta =
      const VerificationMeta('infrastructureId');
  @override
  late final GeneratedColumn<String> infrastructureId = GeneratedColumn<String>(
      'infrastructure_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _qualityGateMeta =
      const VerificationMeta('qualityGate');
  @override
  late final GeneratedColumn<String> qualityGate = GeneratedColumn<String>(
      'quality_gate', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isGuestMeta =
      const VerificationMeta('isGuest');
  @override
  late final GeneratedColumn<bool> isGuest = GeneratedColumn<bool>(
      'is_guest', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_guest" IN (0, 1))'));
  static const VerificationMeta _syncStateMeta =
      const VerificationMeta('syncState');
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
      'sync_state', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtUtcMeta =
      const VerificationMeta('createdAtUtc');
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
      'created_at_utc', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _syncedAtUtcMeta =
      const VerificationMeta('syncedAtUtc');
  @override
  late final GeneratedColumn<DateTime> syncedAtUtc = GeneratedColumn<DateTime>(
      'synced_at_utc', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sensorDataMeta =
      const VerificationMeta('sensorData');
  @override
  late final GeneratedColumn<String> sensorData = GeneratedColumn<String>(
      'sensor_data', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        category,
        severity,
        description,
        latitude,
        longitude,
        altitudeMeters,
        accuracyMeters,
        bearingDegrees,
        speedMps,
        capturedAtUtc,
        imagePath,
        thumbnailPath,
        contractorId,
        infrastructureId,
        qualityGate,
        isGuest,
        syncState,
        createdAtUtc,
        syncedAtUtc,
        retryCount,
        lastError,
        sensorData
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'report_drafts';
  @override
  VerificationContext validateIntegrity(Insertable<ReportDraft> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('severity')) {
      context.handle(_severityMeta,
          severity.isAcceptableOrUnknown(data['severity']!, _severityMeta));
    } else if (isInserting) {
      context.missing(_severityMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('altitude_meters')) {
      context.handle(
          _altitudeMetersMeta,
          altitudeMeters.isAcceptableOrUnknown(
              data['altitude_meters']!, _altitudeMetersMeta));
    } else if (isInserting) {
      context.missing(_altitudeMetersMeta);
    }
    if (data.containsKey('accuracy_meters')) {
      context.handle(
          _accuracyMetersMeta,
          accuracyMeters.isAcceptableOrUnknown(
              data['accuracy_meters']!, _accuracyMetersMeta));
    } else if (isInserting) {
      context.missing(_accuracyMetersMeta);
    }
    if (data.containsKey('bearing_degrees')) {
      context.handle(
          _bearingDegreesMeta,
          bearingDegrees.isAcceptableOrUnknown(
              data['bearing_degrees']!, _bearingDegreesMeta));
    } else if (isInserting) {
      context.missing(_bearingDegreesMeta);
    }
    if (data.containsKey('speed_mps')) {
      context.handle(_speedMpsMeta,
          speedMps.isAcceptableOrUnknown(data['speed_mps']!, _speedMpsMeta));
    } else if (isInserting) {
      context.missing(_speedMpsMeta);
    }
    if (data.containsKey('captured_at_utc')) {
      context.handle(
          _capturedAtUtcMeta,
          capturedAtUtc.isAcceptableOrUnknown(
              data['captured_at_utc']!, _capturedAtUtcMeta));
    } else if (isInserting) {
      context.missing(_capturedAtUtcMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
          _thumbnailPathMeta,
          thumbnailPath.isAcceptableOrUnknown(
              data['thumbnail_path']!, _thumbnailPathMeta));
    }
    if (data.containsKey('contractor_id')) {
      context.handle(
          _contractorIdMeta,
          contractorId.isAcceptableOrUnknown(
              data['contractor_id']!, _contractorIdMeta));
    }
    if (data.containsKey('infrastructure_id')) {
      context.handle(
          _infrastructureIdMeta,
          infrastructureId.isAcceptableOrUnknown(
              data['infrastructure_id']!, _infrastructureIdMeta));
    }
    if (data.containsKey('quality_gate')) {
      context.handle(
          _qualityGateMeta,
          qualityGate.isAcceptableOrUnknown(
              data['quality_gate']!, _qualityGateMeta));
    } else if (isInserting) {
      context.missing(_qualityGateMeta);
    }
    if (data.containsKey('is_guest')) {
      context.handle(_isGuestMeta,
          isGuest.isAcceptableOrUnknown(data['is_guest']!, _isGuestMeta));
    } else if (isInserting) {
      context.missing(_isGuestMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(_syncStateMeta,
          syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta));
    } else if (isInserting) {
      context.missing(_syncStateMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
          _createdAtUtcMeta,
          createdAtUtc.isAcceptableOrUnknown(
              data['created_at_utc']!, _createdAtUtcMeta));
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('synced_at_utc')) {
      context.handle(
          _syncedAtUtcMeta,
          syncedAtUtc.isAcceptableOrUnknown(
              data['synced_at_utc']!, _syncedAtUtcMeta));
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('sensor_data')) {
      context.handle(
          _sensorDataMeta,
          sensorData.isAcceptableOrUnknown(
              data['sensor_data']!, _sensorDataMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReportDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReportDraft(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      severity: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}severity'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude'])!,
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude'])!,
      altitudeMeters: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}altitude_meters'])!,
      accuracyMeters: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}accuracy_meters'])!,
      bearingDegrees: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}bearing_degrees'])!,
      speedMps: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}speed_mps'])!,
      capturedAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}captured_at_utc'])!,
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path'])!,
      thumbnailPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_path']),
      contractorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contractor_id']),
      infrastructureId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}infrastructure_id']),
      qualityGate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}quality_gate'])!,
      isGuest: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_guest'])!,
      syncState: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_state'])!,
      createdAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}created_at_utc'])!,
      syncedAtUtc: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at_utc']),
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      sensorData: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sensor_data']),
    );
  }

  @override
  $ReportDraftsTable createAlias(String alias) {
    return $ReportDraftsTable(attachedDatabase, alias);
  }
}

class ReportDraft extends DataClass implements Insertable<ReportDraft> {
  final String id;
  final String userId;
  final String category;
  final String severity;
  final String description;
  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final double accuracyMeters;
  final double bearingDegrees;
  final double speedMps;
  final DateTime capturedAtUtc;
  final String imagePath;
  final String? thumbnailPath;
  final String? contractorId;
  final String? infrastructureId;
  final String qualityGate;
  final bool isGuest;
  final String syncState;
  final DateTime createdAtUtc;
  final DateTime? syncedAtUtc;
  final int retryCount;
  final String? lastError;
  final String? sensorData;
  const ReportDraft(
      {required this.id,
      required this.userId,
      required this.category,
      required this.severity,
      required this.description,
      required this.latitude,
      required this.longitude,
      required this.altitudeMeters,
      required this.accuracyMeters,
      required this.bearingDegrees,
      required this.speedMps,
      required this.capturedAtUtc,
      required this.imagePath,
      this.thumbnailPath,
      this.contractorId,
      this.infrastructureId,
      required this.qualityGate,
      required this.isGuest,
      required this.syncState,
      required this.createdAtUtc,
      this.syncedAtUtc,
      required this.retryCount,
      this.lastError,
      this.sensorData});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['category'] = Variable<String>(category);
    map['severity'] = Variable<String>(severity);
    map['description'] = Variable<String>(description);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['altitude_meters'] = Variable<double>(altitudeMeters);
    map['accuracy_meters'] = Variable<double>(accuracyMeters);
    map['bearing_degrees'] = Variable<double>(bearingDegrees);
    map['speed_mps'] = Variable<double>(speedMps);
    map['captured_at_utc'] = Variable<DateTime>(capturedAtUtc);
    map['image_path'] = Variable<String>(imagePath);
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    if (!nullToAbsent || contractorId != null) {
      map['contractor_id'] = Variable<String>(contractorId);
    }
    if (!nullToAbsent || infrastructureId != null) {
      map['infrastructure_id'] = Variable<String>(infrastructureId);
    }
    map['quality_gate'] = Variable<String>(qualityGate);
    map['is_guest'] = Variable<bool>(isGuest);
    map['sync_state'] = Variable<String>(syncState);
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    if (!nullToAbsent || syncedAtUtc != null) {
      map['synced_at_utc'] = Variable<DateTime>(syncedAtUtc);
    }
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || sensorData != null) {
      map['sensor_data'] = Variable<String>(sensorData);
    }
    return map;
  }

  ReportDraftsCompanion toCompanion(bool nullToAbsent) {
    return ReportDraftsCompanion(
      id: Value(id),
      userId: Value(userId),
      category: Value(category),
      severity: Value(severity),
      description: Value(description),
      latitude: Value(latitude),
      longitude: Value(longitude),
      altitudeMeters: Value(altitudeMeters),
      accuracyMeters: Value(accuracyMeters),
      bearingDegrees: Value(bearingDegrees),
      speedMps: Value(speedMps),
      capturedAtUtc: Value(capturedAtUtc),
      imagePath: Value(imagePath),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      contractorId: contractorId == null && nullToAbsent
          ? const Value.absent()
          : Value(contractorId),
      infrastructureId: infrastructureId == null && nullToAbsent
          ? const Value.absent()
          : Value(infrastructureId),
      qualityGate: Value(qualityGate),
      isGuest: Value(isGuest),
      syncState: Value(syncState),
      createdAtUtc: Value(createdAtUtc),
      syncedAtUtc: syncedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAtUtc),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      sensorData: sensorData == null && nullToAbsent
          ? const Value.absent()
          : Value(sensorData),
    );
  }

  factory ReportDraft.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReportDraft(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      category: serializer.fromJson<String>(json['category']),
      severity: serializer.fromJson<String>(json['severity']),
      description: serializer.fromJson<String>(json['description']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      altitudeMeters: serializer.fromJson<double>(json['altitudeMeters']),
      accuracyMeters: serializer.fromJson<double>(json['accuracyMeters']),
      bearingDegrees: serializer.fromJson<double>(json['bearingDegrees']),
      speedMps: serializer.fromJson<double>(json['speedMps']),
      capturedAtUtc: serializer.fromJson<DateTime>(json['capturedAtUtc']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      contractorId: serializer.fromJson<String?>(json['contractorId']),
      infrastructureId: serializer.fromJson<String?>(json['infrastructureId']),
      qualityGate: serializer.fromJson<String>(json['qualityGate']),
      isGuest: serializer.fromJson<bool>(json['isGuest']),
      syncState: serializer.fromJson<String>(json['syncState']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      syncedAtUtc: serializer.fromJson<DateTime?>(json['syncedAtUtc']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      sensorData: serializer.fromJson<String?>(json['sensorData']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'category': serializer.toJson<String>(category),
      'severity': serializer.toJson<String>(severity),
      'description': serializer.toJson<String>(description),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'altitudeMeters': serializer.toJson<double>(altitudeMeters),
      'accuracyMeters': serializer.toJson<double>(accuracyMeters),
      'bearingDegrees': serializer.toJson<double>(bearingDegrees),
      'speedMps': serializer.toJson<double>(speedMps),
      'capturedAtUtc': serializer.toJson<DateTime>(capturedAtUtc),
      'imagePath': serializer.toJson<String>(imagePath),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'contractorId': serializer.toJson<String?>(contractorId),
      'infrastructureId': serializer.toJson<String?>(infrastructureId),
      'qualityGate': serializer.toJson<String>(qualityGate),
      'isGuest': serializer.toJson<bool>(isGuest),
      'syncState': serializer.toJson<String>(syncState),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'syncedAtUtc': serializer.toJson<DateTime?>(syncedAtUtc),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
      'sensorData': serializer.toJson<String?>(sensorData),
    };
  }

  ReportDraft copyWith(
          {String? id,
          String? userId,
          String? category,
          String? severity,
          String? description,
          double? latitude,
          double? longitude,
          double? altitudeMeters,
          double? accuracyMeters,
          double? bearingDegrees,
          double? speedMps,
          DateTime? capturedAtUtc,
          String? imagePath,
          Value<String?> thumbnailPath = const Value.absent(),
          Value<String?> contractorId = const Value.absent(),
          Value<String?> infrastructureId = const Value.absent(),
          String? qualityGate,
          bool? isGuest,
          String? syncState,
          DateTime? createdAtUtc,
          Value<DateTime?> syncedAtUtc = const Value.absent(),
          int? retryCount,
          Value<String?> lastError = const Value.absent(),
          Value<String?> sensorData = const Value.absent()}) =>
      ReportDraft(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        category: category ?? this.category,
        severity: severity ?? this.severity,
        description: description ?? this.description,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        altitudeMeters: altitudeMeters ?? this.altitudeMeters,
        accuracyMeters: accuracyMeters ?? this.accuracyMeters,
        bearingDegrees: bearingDegrees ?? this.bearingDegrees,
        speedMps: speedMps ?? this.speedMps,
        capturedAtUtc: capturedAtUtc ?? this.capturedAtUtc,
        imagePath: imagePath ?? this.imagePath,
        thumbnailPath:
            thumbnailPath.present ? thumbnailPath.value : this.thumbnailPath,
        contractorId:
            contractorId.present ? contractorId.value : this.contractorId,
        infrastructureId: infrastructureId.present
            ? infrastructureId.value
            : this.infrastructureId,
        qualityGate: qualityGate ?? this.qualityGate,
        isGuest: isGuest ?? this.isGuest,
        syncState: syncState ?? this.syncState,
        createdAtUtc: createdAtUtc ?? this.createdAtUtc,
        syncedAtUtc: syncedAtUtc.present ? syncedAtUtc.value : this.syncedAtUtc,
        retryCount: retryCount ?? this.retryCount,
        lastError: lastError.present ? lastError.value : this.lastError,
        sensorData: sensorData.present ? sensorData.value : this.sensorData,
      );
  ReportDraft copyWithCompanion(ReportDraftsCompanion data) {
    return ReportDraft(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      category: data.category.present ? data.category.value : this.category,
      severity: data.severity.present ? data.severity.value : this.severity,
      description:
          data.description.present ? data.description.value : this.description,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      altitudeMeters: data.altitudeMeters.present
          ? data.altitudeMeters.value
          : this.altitudeMeters,
      accuracyMeters: data.accuracyMeters.present
          ? data.accuracyMeters.value
          : this.accuracyMeters,
      bearingDegrees: data.bearingDegrees.present
          ? data.bearingDegrees.value
          : this.bearingDegrees,
      speedMps: data.speedMps.present ? data.speedMps.value : this.speedMps,
      capturedAtUtc: data.capturedAtUtc.present
          ? data.capturedAtUtc.value
          : this.capturedAtUtc,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      contractorId: data.contractorId.present
          ? data.contractorId.value
          : this.contractorId,
      infrastructureId: data.infrastructureId.present
          ? data.infrastructureId.value
          : this.infrastructureId,
      qualityGate:
          data.qualityGate.present ? data.qualityGate.value : this.qualityGate,
      isGuest: data.isGuest.present ? data.isGuest.value : this.isGuest,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      syncedAtUtc:
          data.syncedAtUtc.present ? data.syncedAtUtc.value : this.syncedAtUtc,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      sensorData:
          data.sensorData.present ? data.sensorData.value : this.sensorData,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReportDraft(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('category: $category, ')
          ..write('severity: $severity, ')
          ..write('description: $description, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('altitudeMeters: $altitudeMeters, ')
          ..write('accuracyMeters: $accuracyMeters, ')
          ..write('bearingDegrees: $bearingDegrees, ')
          ..write('speedMps: $speedMps, ')
          ..write('capturedAtUtc: $capturedAtUtc, ')
          ..write('imagePath: $imagePath, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('contractorId: $contractorId, ')
          ..write('infrastructureId: $infrastructureId, ')
          ..write('qualityGate: $qualityGate, ')
          ..write('isGuest: $isGuest, ')
          ..write('syncState: $syncState, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('syncedAtUtc: $syncedAtUtc, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('sensorData: $sensorData')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        userId,
        category,
        severity,
        description,
        latitude,
        longitude,
        altitudeMeters,
        accuracyMeters,
        bearingDegrees,
        speedMps,
        capturedAtUtc,
        imagePath,
        thumbnailPath,
        contractorId,
        infrastructureId,
        qualityGate,
        isGuest,
        syncState,
        createdAtUtc,
        syncedAtUtc,
        retryCount,
        lastError,
        sensorData
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReportDraft &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.category == this.category &&
          other.severity == this.severity &&
          other.description == this.description &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.altitudeMeters == this.altitudeMeters &&
          other.accuracyMeters == this.accuracyMeters &&
          other.bearingDegrees == this.bearingDegrees &&
          other.speedMps == this.speedMps &&
          other.capturedAtUtc == this.capturedAtUtc &&
          other.imagePath == this.imagePath &&
          other.thumbnailPath == this.thumbnailPath &&
          other.contractorId == this.contractorId &&
          other.infrastructureId == this.infrastructureId &&
          other.qualityGate == this.qualityGate &&
          other.isGuest == this.isGuest &&
          other.syncState == this.syncState &&
          other.createdAtUtc == this.createdAtUtc &&
          other.syncedAtUtc == this.syncedAtUtc &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError &&
          other.sensorData == this.sensorData);
}

class ReportDraftsCompanion extends UpdateCompanion<ReportDraft> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> category;
  final Value<String> severity;
  final Value<String> description;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double> altitudeMeters;
  final Value<double> accuracyMeters;
  final Value<double> bearingDegrees;
  final Value<double> speedMps;
  final Value<DateTime> capturedAtUtc;
  final Value<String> imagePath;
  final Value<String?> thumbnailPath;
  final Value<String?> contractorId;
  final Value<String?> infrastructureId;
  final Value<String> qualityGate;
  final Value<bool> isGuest;
  final Value<String> syncState;
  final Value<DateTime> createdAtUtc;
  final Value<DateTime?> syncedAtUtc;
  final Value<int> retryCount;
  final Value<String?> lastError;
  final Value<String?> sensorData;
  final Value<int> rowid;
  const ReportDraftsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.category = const Value.absent(),
    this.severity = const Value.absent(),
    this.description = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.altitudeMeters = const Value.absent(),
    this.accuracyMeters = const Value.absent(),
    this.bearingDegrees = const Value.absent(),
    this.speedMps = const Value.absent(),
    this.capturedAtUtc = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.contractorId = const Value.absent(),
    this.infrastructureId = const Value.absent(),
    this.qualityGate = const Value.absent(),
    this.isGuest = const Value.absent(),
    this.syncState = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.syncedAtUtc = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.sensorData = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReportDraftsCompanion.insert({
    required String id,
    required String userId,
    required String category,
    required String severity,
    required String description,
    required double latitude,
    required double longitude,
    required double altitudeMeters,
    required double accuracyMeters,
    required double bearingDegrees,
    required double speedMps,
    required DateTime capturedAtUtc,
    required String imagePath,
    this.thumbnailPath = const Value.absent(),
    this.contractorId = const Value.absent(),
    this.infrastructureId = const Value.absent(),
    required String qualityGate,
    required bool isGuest,
    required String syncState,
    required DateTime createdAtUtc,
    this.syncedAtUtc = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.sensorData = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        category = Value(category),
        severity = Value(severity),
        description = Value(description),
        latitude = Value(latitude),
        longitude = Value(longitude),
        altitudeMeters = Value(altitudeMeters),
        accuracyMeters = Value(accuracyMeters),
        bearingDegrees = Value(bearingDegrees),
        speedMps = Value(speedMps),
        capturedAtUtc = Value(capturedAtUtc),
        imagePath = Value(imagePath),
        qualityGate = Value(qualityGate),
        isGuest = Value(isGuest),
        syncState = Value(syncState),
        createdAtUtc = Value(createdAtUtc);
  static Insertable<ReportDraft> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? category,
    Expression<String>? severity,
    Expression<String>? description,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? altitudeMeters,
    Expression<double>? accuracyMeters,
    Expression<double>? bearingDegrees,
    Expression<double>? speedMps,
    Expression<DateTime>? capturedAtUtc,
    Expression<String>? imagePath,
    Expression<String>? thumbnailPath,
    Expression<String>? contractorId,
    Expression<String>? infrastructureId,
    Expression<String>? qualityGate,
    Expression<bool>? isGuest,
    Expression<String>? syncState,
    Expression<DateTime>? createdAtUtc,
    Expression<DateTime>? syncedAtUtc,
    Expression<int>? retryCount,
    Expression<String>? lastError,
    Expression<String>? sensorData,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (category != null) 'category': category,
      if (severity != null) 'severity': severity,
      if (description != null) 'description': description,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (altitudeMeters != null) 'altitude_meters': altitudeMeters,
      if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
      if (bearingDegrees != null) 'bearing_degrees': bearingDegrees,
      if (speedMps != null) 'speed_mps': speedMps,
      if (capturedAtUtc != null) 'captured_at_utc': capturedAtUtc,
      if (imagePath != null) 'image_path': imagePath,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (contractorId != null) 'contractor_id': contractorId,
      if (infrastructureId != null) 'infrastructure_id': infrastructureId,
      if (qualityGate != null) 'quality_gate': qualityGate,
      if (isGuest != null) 'is_guest': isGuest,
      if (syncState != null) 'sync_state': syncState,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (syncedAtUtc != null) 'synced_at_utc': syncedAtUtc,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      if (sensorData != null) 'sensor_data': sensorData,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReportDraftsCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? category,
      Value<String>? severity,
      Value<String>? description,
      Value<double>? latitude,
      Value<double>? longitude,
      Value<double>? altitudeMeters,
      Value<double>? accuracyMeters,
      Value<double>? bearingDegrees,
      Value<double>? speedMps,
      Value<DateTime>? capturedAtUtc,
      Value<String>? imagePath,
      Value<String?>? thumbnailPath,
      Value<String?>? contractorId,
      Value<String?>? infrastructureId,
      Value<String>? qualityGate,
      Value<bool>? isGuest,
      Value<String>? syncState,
      Value<DateTime>? createdAtUtc,
      Value<DateTime?>? syncedAtUtc,
      Value<int>? retryCount,
      Value<String?>? lastError,
      Value<String?>? sensorData,
      Value<int>? rowid}) {
    return ReportDraftsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitudeMeters: altitudeMeters ?? this.altitudeMeters,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      bearingDegrees: bearingDegrees ?? this.bearingDegrees,
      speedMps: speedMps ?? this.speedMps,
      capturedAtUtc: capturedAtUtc ?? this.capturedAtUtc,
      imagePath: imagePath ?? this.imagePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      contractorId: contractorId ?? this.contractorId,
      infrastructureId: infrastructureId ?? this.infrastructureId,
      qualityGate: qualityGate ?? this.qualityGate,
      isGuest: isGuest ?? this.isGuest,
      syncState: syncState ?? this.syncState,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      syncedAtUtc: syncedAtUtc ?? this.syncedAtUtc,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      sensorData: sensorData ?? this.sensorData,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (severity.present) {
      map['severity'] = Variable<String>(severity.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (altitudeMeters.present) {
      map['altitude_meters'] = Variable<double>(altitudeMeters.value);
    }
    if (accuracyMeters.present) {
      map['accuracy_meters'] = Variable<double>(accuracyMeters.value);
    }
    if (bearingDegrees.present) {
      map['bearing_degrees'] = Variable<double>(bearingDegrees.value);
    }
    if (speedMps.present) {
      map['speed_mps'] = Variable<double>(speedMps.value);
    }
    if (capturedAtUtc.present) {
      map['captured_at_utc'] = Variable<DateTime>(capturedAtUtc.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (contractorId.present) {
      map['contractor_id'] = Variable<String>(contractorId.value);
    }
    if (infrastructureId.present) {
      map['infrastructure_id'] = Variable<String>(infrastructureId.value);
    }
    if (qualityGate.present) {
      map['quality_gate'] = Variable<String>(qualityGate.value);
    }
    if (isGuest.present) {
      map['is_guest'] = Variable<bool>(isGuest.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (syncedAtUtc.present) {
      map['synced_at_utc'] = Variable<DateTime>(syncedAtUtc.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (sensorData.present) {
      map['sensor_data'] = Variable<String>(sensorData.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReportDraftsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('category: $category, ')
          ..write('severity: $severity, ')
          ..write('description: $description, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('altitudeMeters: $altitudeMeters, ')
          ..write('accuracyMeters: $accuracyMeters, ')
          ..write('bearingDegrees: $bearingDegrees, ')
          ..write('speedMps: $speedMps, ')
          ..write('capturedAtUtc: $capturedAtUtc, ')
          ..write('imagePath: $imagePath, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('contractorId: $contractorId, ')
          ..write('infrastructureId: $infrastructureId, ')
          ..write('qualityGate: $qualityGate, ')
          ..write('isGuest: $isGuest, ')
          ..write('syncState: $syncState, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('syncedAtUtc: $syncedAtUtc, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('sensorData: $sensorData, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ReportDraftsTable reportDrafts = $ReportDraftsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [reportDrafts];
}

typedef $$ReportDraftsTableCreateCompanionBuilder = ReportDraftsCompanion
    Function({
  required String id,
  required String userId,
  required String category,
  required String severity,
  required String description,
  required double latitude,
  required double longitude,
  required double altitudeMeters,
  required double accuracyMeters,
  required double bearingDegrees,
  required double speedMps,
  required DateTime capturedAtUtc,
  required String imagePath,
  Value<String?> thumbnailPath,
  Value<String?> contractorId,
  Value<String?> infrastructureId,
  required String qualityGate,
  required bool isGuest,
  required String syncState,
  required DateTime createdAtUtc,
  Value<DateTime?> syncedAtUtc,
  Value<int> retryCount,
  Value<String?> lastError,
  Value<String?> sensorData,
  Value<int> rowid,
});
typedef $$ReportDraftsTableUpdateCompanionBuilder = ReportDraftsCompanion
    Function({
  Value<String> id,
  Value<String> userId,
  Value<String> category,
  Value<String> severity,
  Value<String> description,
  Value<double> latitude,
  Value<double> longitude,
  Value<double> altitudeMeters,
  Value<double> accuracyMeters,
  Value<double> bearingDegrees,
  Value<double> speedMps,
  Value<DateTime> capturedAtUtc,
  Value<String> imagePath,
  Value<String?> thumbnailPath,
  Value<String?> contractorId,
  Value<String?> infrastructureId,
  Value<String> qualityGate,
  Value<bool> isGuest,
  Value<String> syncState,
  Value<DateTime> createdAtUtc,
  Value<DateTime?> syncedAtUtc,
  Value<int> retryCount,
  Value<String?> lastError,
  Value<String?> sensorData,
  Value<int> rowid,
});

class $$ReportDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $ReportDraftsTable> {
  $$ReportDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get severity => $composableBuilder(
      column: $table.severity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get altitudeMeters => $composableBuilder(
      column: $table.altitudeMeters,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get accuracyMeters => $composableBuilder(
      column: $table.accuracyMeters,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get bearingDegrees => $composableBuilder(
      column: $table.bearingDegrees,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get speedMps => $composableBuilder(
      column: $table.speedMps, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get capturedAtUtc => $composableBuilder(
      column: $table.capturedAtUtc, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contractorId => $composableBuilder(
      column: $table.contractorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get infrastructureId => $composableBuilder(
      column: $table.infrastructureId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get qualityGate => $composableBuilder(
      column: $table.qualityGate, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isGuest => $composableBuilder(
      column: $table.isGuest, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncState => $composableBuilder(
      column: $table.syncState, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAtUtc => $composableBuilder(
      column: $table.createdAtUtc, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAtUtc => $composableBuilder(
      column: $table.syncedAtUtc, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sensorData => $composableBuilder(
      column: $table.sensorData, builder: (column) => ColumnFilters(column));
}

class $$ReportDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReportDraftsTable> {
  $$ReportDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get severity => $composableBuilder(
      column: $table.severity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get altitudeMeters => $composableBuilder(
      column: $table.altitudeMeters,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get accuracyMeters => $composableBuilder(
      column: $table.accuracyMeters,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get bearingDegrees => $composableBuilder(
      column: $table.bearingDegrees,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get speedMps => $composableBuilder(
      column: $table.speedMps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get capturedAtUtc => $composableBuilder(
      column: $table.capturedAtUtc,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contractorId => $composableBuilder(
      column: $table.contractorId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get infrastructureId => $composableBuilder(
      column: $table.infrastructureId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get qualityGate => $composableBuilder(
      column: $table.qualityGate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isGuest => $composableBuilder(
      column: $table.isGuest, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncState => $composableBuilder(
      column: $table.syncState, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAtUtc => $composableBuilder(
      column: $table.createdAtUtc,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAtUtc => $composableBuilder(
      column: $table.syncedAtUtc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sensorData => $composableBuilder(
      column: $table.sensorData, builder: (column) => ColumnOrderings(column));
}

class $$ReportDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReportDraftsTable> {
  $$ReportDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get altitudeMeters => $composableBuilder(
      column: $table.altitudeMeters, builder: (column) => column);

  GeneratedColumn<double> get accuracyMeters => $composableBuilder(
      column: $table.accuracyMeters, builder: (column) => column);

  GeneratedColumn<double> get bearingDegrees => $composableBuilder(
      column: $table.bearingDegrees, builder: (column) => column);

  GeneratedColumn<double> get speedMps =>
      $composableBuilder(column: $table.speedMps, builder: (column) => column);

  GeneratedColumn<DateTime> get capturedAtUtc => $composableBuilder(
      column: $table.capturedAtUtc, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath, builder: (column) => column);

  GeneratedColumn<String> get contractorId => $composableBuilder(
      column: $table.contractorId, builder: (column) => column);

  GeneratedColumn<String> get infrastructureId => $composableBuilder(
      column: $table.infrastructureId, builder: (column) => column);

  GeneratedColumn<String> get qualityGate => $composableBuilder(
      column: $table.qualityGate, builder: (column) => column);

  GeneratedColumn<bool> get isGuest =>
      $composableBuilder(column: $table.isGuest, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
      column: $table.createdAtUtc, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAtUtc => $composableBuilder(
      column: $table.syncedAtUtc, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get sensorData => $composableBuilder(
      column: $table.sensorData, builder: (column) => column);
}

class $$ReportDraftsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReportDraftsTable,
    ReportDraft,
    $$ReportDraftsTableFilterComposer,
    $$ReportDraftsTableOrderingComposer,
    $$ReportDraftsTableAnnotationComposer,
    $$ReportDraftsTableCreateCompanionBuilder,
    $$ReportDraftsTableUpdateCompanionBuilder,
    (
      ReportDraft,
      BaseReferences<_$AppDatabase, $ReportDraftsTable, ReportDraft>
    ),
    ReportDraft,
    PrefetchHooks Function()> {
  $$ReportDraftsTableTableManager(_$AppDatabase db, $ReportDraftsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReportDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReportDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReportDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> severity = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<double> latitude = const Value.absent(),
            Value<double> longitude = const Value.absent(),
            Value<double> altitudeMeters = const Value.absent(),
            Value<double> accuracyMeters = const Value.absent(),
            Value<double> bearingDegrees = const Value.absent(),
            Value<double> speedMps = const Value.absent(),
            Value<DateTime> capturedAtUtc = const Value.absent(),
            Value<String> imagePath = const Value.absent(),
            Value<String?> thumbnailPath = const Value.absent(),
            Value<String?> contractorId = const Value.absent(),
            Value<String?> infrastructureId = const Value.absent(),
            Value<String> qualityGate = const Value.absent(),
            Value<bool> isGuest = const Value.absent(),
            Value<String> syncState = const Value.absent(),
            Value<DateTime> createdAtUtc = const Value.absent(),
            Value<DateTime?> syncedAtUtc = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<String?> sensorData = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReportDraftsCompanion(
            id: id,
            userId: userId,
            category: category,
            severity: severity,
            description: description,
            latitude: latitude,
            longitude: longitude,
            altitudeMeters: altitudeMeters,
            accuracyMeters: accuracyMeters,
            bearingDegrees: bearingDegrees,
            speedMps: speedMps,
            capturedAtUtc: capturedAtUtc,
            imagePath: imagePath,
            thumbnailPath: thumbnailPath,
            contractorId: contractorId,
            infrastructureId: infrastructureId,
            qualityGate: qualityGate,
            isGuest: isGuest,
            syncState: syncState,
            createdAtUtc: createdAtUtc,
            syncedAtUtc: syncedAtUtc,
            retryCount: retryCount,
            lastError: lastError,
            sensorData: sensorData,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required String category,
            required String severity,
            required String description,
            required double latitude,
            required double longitude,
            required double altitudeMeters,
            required double accuracyMeters,
            required double bearingDegrees,
            required double speedMps,
            required DateTime capturedAtUtc,
            required String imagePath,
            Value<String?> thumbnailPath = const Value.absent(),
            Value<String?> contractorId = const Value.absent(),
            Value<String?> infrastructureId = const Value.absent(),
            required String qualityGate,
            required bool isGuest,
            required String syncState,
            required DateTime createdAtUtc,
            Value<DateTime?> syncedAtUtc = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<String?> sensorData = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReportDraftsCompanion.insert(
            id: id,
            userId: userId,
            category: category,
            severity: severity,
            description: description,
            latitude: latitude,
            longitude: longitude,
            altitudeMeters: altitudeMeters,
            accuracyMeters: accuracyMeters,
            bearingDegrees: bearingDegrees,
            speedMps: speedMps,
            capturedAtUtc: capturedAtUtc,
            imagePath: imagePath,
            thumbnailPath: thumbnailPath,
            contractorId: contractorId,
            infrastructureId: infrastructureId,
            qualityGate: qualityGate,
            isGuest: isGuest,
            syncState: syncState,
            createdAtUtc: createdAtUtc,
            syncedAtUtc: syncedAtUtc,
            retryCount: retryCount,
            lastError: lastError,
            sensorData: sensorData,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ReportDraftsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReportDraftsTable,
    ReportDraft,
    $$ReportDraftsTableFilterComposer,
    $$ReportDraftsTableOrderingComposer,
    $$ReportDraftsTableAnnotationComposer,
    $$ReportDraftsTableCreateCompanionBuilder,
    $$ReportDraftsTableUpdateCompanionBuilder,
    (
      ReportDraft,
      BaseReferences<_$AppDatabase, $ReportDraftsTable, ReportDraft>
    ),
    ReportDraft,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ReportDraftsTableTableManager get reportDrafts =>
      $$ReportDraftsTableTableManager(_db, _db.reportDrafts);
}
