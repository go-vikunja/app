import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/projects/application/project_access.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  group('ProjectAccess', () {
    const read = ProjectAccess(Permission.read);
    const write = ProjectAccess(Permission.write);
    const admin = ProjectAccess(Permission.admin);

    test("follows the server's rules per permission", () {
      bool Function(ProjectAccess) rule(String name) => switch (name) {
        'canWrite' => (a) => a.canWrite,
        'canEdit' => (a) => a.canEdit,
        'canArchive' => (a) => a.canArchive,
        'canCreateChild' => (a) => a.canCreateChild,
        'canAddTasks' => (a) => a.canAddTasks,
        'canChangeTasks' => (a) => a.canChangeTasks,
        'canReorderOrBoard' => (a) => a.canReorderOrBoard,
        'canComment' => (a) => a.canComment,
        'canReact' => (a) => a.canReact,
        'isAdmin' => (a) => a.isAdmin,
        'canChangeParent' => (a) => a.canChangeParent,
        'canDelete' => (a) => a.canDelete,
        'canManageViews' => (a) => a.canManageViews,
        'canChooseDoneAndDefaultColumn' => (
          a,
        ) => a.canChooseDoneAndDefaultColumn,
        'canManageShares' => (a) => a.canManageShares,
        'canDuplicate' => (a) => a.canDuplicate,
        _ => throw ArgumentError(name),
      };
      const writeRules = [
        'canWrite',
        'canEdit',
        'canArchive',
        'canCreateChild',
        'canAddTasks',
        'canChangeTasks',
        'canReorderOrBoard',
        'canComment',
        'canReact',
      ];
      const adminRules = [
        'isAdmin',
        'canChangeParent',
        'canDelete',
        'canManageViews',
        'canChooseDoneAndDefaultColumn',
        'canManageShares',
      ];
      for (final name in writeRules) {
        expect(rule(name)(read), isFalse, reason: '$name for read');
        expect(rule(name)(write), isTrue, reason: '$name for write');
        expect(rule(name)(admin), isTrue, reason: '$name for admin');
      }
      for (final name in adminRules) {
        expect(rule(name)(read), isFalse, reason: '$name for read');
        expect(rule(name)(write), isFalse, reason: '$name for write');
        expect(rule(name)(admin), isTrue, reason: '$name for admin');
      }
      for (final access in [read, write, admin]) {
        expect(access.canDuplicate, isTrue);
      }
      for (final name in [...writeRules, ...adminRules]) {
        expect(
          rule(name)(ProjectAccess.unknown),
          isTrue,
          reason: '$name for an unknown permission, as before it was stored',
        );
      }
    });

    test('only a known read permission is read only', () {
      expect(read.isReadOnly, isTrue);
      expect(write.isReadOnly, isFalse);
      expect(ProjectAccess.unknown.isReadOnly, isFalse);
      expect(ProjectAccess.unknown.isKnown, isFalse);
      expect(
        ProjectAccess.of(
          const Project(id: 1, title: 'P', maxPermission: Permission.write),
        ),
        write,
      );
    });
  });

  test('the provider follows the stored project through every sync', () async {
    final now = DateTime.utc(2026, 10, 26, 12);
    final auth = AuthFakes();
    final sync = SyncFakes(now: now);
    final container = ProviderContainer(
      overrides: [...auth.overrides, ...sync.overrides],
    );
    addTearDown(container.dispose);
    await auth.seedAccount(fullServer270(), tokens: issueTokens(issuedAt: now));
    await container.read(accountsProvider.future);
    sync.projects.all = [
      sampleProject(
        id: 1,
        title: 'Shared',
      ).copyWith(maxPermission: Permission.read),
    ];
    final seen = <ProjectAccess>[];
    container.listen(
      projectAccessProvider(1),
      (_, next) => seen.add(next),
      fireImmediately: true,
    );
    final other = container.listen(projectAccessProvider(2), (_, _) {});
    await pumpEventQueue();

    sync.projects.all = [
      sampleProject(
        id: 1,
        title: 'Shared',
      ).copyWith(maxPermission: Permission.write),
    ];
    await pumpEventQueue();
    sync.projects.all = [];
    await pumpEventQueue();

    expect(seen, [
      ProjectAccess.unknown,
      const ProjectAccess(Permission.read),
      const ProjectAccess(Permission.write),
      ProjectAccess.unknown,
    ]);
    expect(other.read(), ProjectAccess.unknown);
  });
}
