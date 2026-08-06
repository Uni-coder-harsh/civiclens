import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DataClassName('ReportDraft')
class ReportDrafts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get category => text()();
  TextColumn get severity => text()();
  TextColumn get description => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get altitudeMeters => real()();
  RealColumn get accuracyMeters => real()();
  RealColumn get bearingDegrees => real()();
  RealColumn get speedMps => real()();
  DateTimeColumn get capturedAtUtc => dateTime()();
  TextColumn get imagePath => text()();
  TextColumn get thumbnailPath => text().nullable()();
  TextColumn get contractorId => text().nullable()();
  TextColumn get infrastructureId => text().nullable()();
  TextColumn get qualityGate => text()();
  BoolColumn get isGuest => boolean()();
  TextColumn get syncState => text()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get syncedAtUtc => dateTime().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ReportDrafts])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  Future<int> insertOrUpdateDraft(ReportDraftsCompanion draft) {
    return into(reportDrafts).insertOnConflictUpdate(draft);
  }

  Future<List<ReportDraft>> getPendingOrFailedDrafts() {
    return (select(reportDrafts)
          ..where((t) => t.syncState.isIn(['pending', 'failed']))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAtUtc)]))
        .get();
  }

  Future<int> updateDraftSyncState(
    String id,
    String syncState, {
    DateTime? syncedAtUtc,
    int? retryCount,
    String? lastError,
  }) {
    return (update(reportDrafts)..where((t) => t.id.equals(id))).write(
      ReportDraftsCompanion(
        syncState: Value(syncState),
        syncedAtUtc: Value(syncedAtUtc),
        retryCount:
            retryCount != null ? Value(retryCount) : const Value.absent(),
        lastError: Value(lastError),
      ),
    );
  }

  Future<int> deleteDraft(String id) {
    return (delete(reportDrafts)..where((t) => t.id.equals(id))).go();
  }

  Future<int> clearSyncedDrafts() {
    return (delete(reportDrafts)..where((t) => t.syncState.equals('synced')))
        .go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'civiclens.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
