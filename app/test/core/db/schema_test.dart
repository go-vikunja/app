import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

import 'generated/schema.dart';

// The dump under drift_schemas/ must match the code. After a schema change:
//   dart run drift_dev schema dump lib/core/db/app_database.dart \
//     drift_schemas/drift_schema_v<N>.json
//   dart run drift_dev schema generate drift_schemas/ test/core/db/generated/
// and a migration test from v<N-1> to v<N> in migration_test.dart.
void main() {
  late SchemaVerifier verifier;
  final latest = GeneratedHelper.versions.last;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test("the latest schema dump is the code's version and matches its "
      'generated code', () async {
    final connection = await verifier.startAt(latest);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    expect(db.schemaVersion, latest);
    await verifier.migrateAndValidate(db, latest);
  });

  test('a fresh database validates against the code', () async {
    final schema = await verifier.schemaAt(latest);
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    await db.validateDatabaseSchema();
  });
}
