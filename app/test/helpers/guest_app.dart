import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';

import 'auth_fakes.dart';
import 'guest_entry_fakes.dart';
import 'guest_fakes.dart';
import 'pump_app.dart';
import 'sample_data.dart';
import 'server_connections.dart';
import 'sync_fakes.dart';

/// The shared project's id, `seedGuest`'s default.
const guestProjectId = 1378;

/// The shared project "Garden" as the guest's sync stored it, with the
/// share's [permission].
Project guestProject({Permission? permission = Permission.read}) =>
    sampleProject(
      id: guestProjectId,
      title: 'Garden',
    ).copyWith(maxPermission: permission);

/// Starts the app with a link-share guest ("Helper" on "Garden") as the
/// only, active account, its project in [data] unless that already has
/// projects.
Future<RegisteredAccount> pumpGuestApp(
  WidgetTester tester, {
  required AuthFakes auth,
  required SyncFakes data,
  Permission? permission = Permission.read,
  bool needsReauth = false,
  List<Override> overrides = const [],
}) async {
  if (data.projects.all.isEmpty) {
    data.projects.all = [guestProject(permission: permission)];
  }
  final entry = await auth.seedGuest(
    fullServer270(),
    token: issueLinkShareToken(
      issuedAt: DateTime.now().toUtc(),
      permission: permission ?? Permission.read,
    ),
    needsReauth: needsReauth,
  );
  await pumpVikunjaApp(
    tester,
    auth: auth,
    sync: data,
    overrides: [...guestEntryOverrides(), ...overrides],
  );
  return entry;
}
