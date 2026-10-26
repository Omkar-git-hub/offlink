import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/conversations_table.dart';
import 'tables/messages_table.dart';

part 'offlink_database.g.dart';

/// Central Drift database for local Offlink persistence.
@DriftDatabase(tables: [ConversationsTable, MessagesTable])
class OfflinkDatabase extends _$OfflinkDatabase {
  OfflinkDatabase([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  OfflinkDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Schema upgrade hooks for future migrations
      },
      beforeOpen: (details) async {
        // Enable foreign key support in SQLite
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'offlink.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
