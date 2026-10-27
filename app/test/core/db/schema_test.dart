import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

import 'generated/schema.dart';

// The dump under drift_schemas/ must match the code. After a schema change:
//   dart run drift_dev schema dump lib/core/db/app_database.dart \
//     drift_schemas/drift_schema_v<N>.json
//   dart run drift_dev schema generate drift_schemas/ test/core/db/generated/
// and a migration test from v<N-1> to v<N> below.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('the schema dump matches the generated code', () async {
    final connection = await verifier.startAt(11);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 11);
  });

  test('a fresh database validates against the code', () async {
    final schema = await verifier.schemaAt(11);
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    await db.validateDatabaseSchema();
  });
}
