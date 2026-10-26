import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/vikunja_app.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/team_sharing_fakes.dart';

/// The signed-in user of [OrganiseHarness]: `issueTokens`' default.
const alice = User(id: 7, username: 'alice', name: 'Alice Example');
const kim = User(id: 9, username: 'kim', name: 'Kim Lee');
const ben = User(id: 11, username: 'ben', name: 'Ben Ortiz');

Label ownLabel(int id, String title, {String hexColor = '', String? html}) =>
    Label(
      id: id,
      title: title,
      hexColor: hexColor,
      description: html ?? '',
      createdBy: alice,
    );

Label othersLabel(int id, String title, {User by = kim}) =>
    Label(id: id, title: title, createdBy: by);

Team sampleTeam({
  required int id,
  required String name,
  List<TeamMember> members = const [TeamMember(user: alice, admin: true)],
  String description = '',
  bool isPublic = false,
  bool isExternal = false,
}) => Team(
  id: id,
  name: name,
  description: description,
  isPublic: isPublic,
  isExternal: isExternal,
  members: members,
);

/// The labels, people and teams of the signed-in [alice], and the app
/// pumped on one of the pages over the shell.
final class OrganiseHarness {
  new() {
    teams
      ..me = alice
      ..people = [alice, kim, ben];
    data.shared.users.everyone = [alice, kim, ben];
  }

  final DateTime now = DateTime.now();
  final auth = AuthFakes();
  late final SyncFakes data = SyncFakes(now: now);

  FakeTeamRepository get teams => data.teams;
  FakeUserRepository get users => data.users;

  /// The active account's labels; set before [pump].
  FakeLabelRepository labels = FakeLabelRepository();

  /// Signed in on [connection] (a 2.7.0 server with public teams by
  /// default), then [location] pushed over the shell, unless null.
  Future<void> pump(
    WidgetTester tester, {
    String? location,
    ServerConnection? connection,
    Size size = phoneSize,
    List<Override> overrides = const [],
  }) async {
    usePhoneSurface(tester, logicalSize: size);
    await auth.seedAccount(
      connection ?? fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appOverrides(auth: auth, sync: data),
          clockProvider.overrideWithValue(() => now),
          labelRepositoryProvider.overrideWithValue(labels),
          ...overrides,
        ],
        child: const VikunjaApp(),
      ),
    );
    await tester.pumpAndSettle();
    if (location != null) await push(tester, location);
  }

  Future<void> push(WidgetTester tester, String location) async {
    unawaited(containerOf(tester).read(appRouterProvider).push(location));
    await tester.pumpAndSettle();
  }

  /// The last sync could not reach the server.
  void goOffline() => data.engine.emit(
    SyncFailed(
      failure: const NetworkFailure(NetworkProblem.unreachable),
      lastSyncedAt: now,
    ),
  );
}

/// The location the root router shows.
String currentLocation(WidgetTester tester) =>
    containerOf(tester).read(appRouterProvider).state.matchedLocation;
