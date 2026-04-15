import 'package:drift/drift.dart';

/// Stores a single persisted authentication record (id = 1) enforced by a CHECK constraint.
class Auth extends Table {
  IntColumn get id => integer().check(id.equals(1))();
  TextColumn get steamId => text()();

  @override
  Set<Column>? get primaryKey => {id};
}
