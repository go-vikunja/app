import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

Project _project(int id, {int parentProjectId = 0}) =>
    Project(id: id, title: 'p', parentProjectId: parentProjectId);

void main() {
  test('a project without parent is top level', () {
    expect(_project(3).isTopLevel, isTrue);
    expect(_project(3, parentProjectId: 1).isTopLevel, isFalse);
  });

  group('pseudo projects', () {
    test('negative ids are pseudo projects', () {
      expect(_project(-1).isPseudo, isTrue);
      expect(_project(-2).isPseudo, isTrue);
      expect(_project(0).isPseudo, isFalse);
      expect(_project(5).isPseudo, isFalse);
    });

    test('-1 is the Favorites project', () {
      expect(Project.favoritesId, -1);
      expect(_project(-1).isFavoritesPseudo, isTrue);
      expect(_project(-2).isFavoritesPseudo, isFalse);
      expect(_project(1).isFavoritesPseudo, isFalse);
    });

    test('saved filter n is project -n - 1', () {
      expect(_project(-2).savedFilterId, 1);
      expect(_project(-10).savedFilterId, 9);
      expect(_project(-1).savedFilterId, isNull);
      expect(_project(4).savedFilterId, isNull);
    });
  });

  group('views', () {
    test('kinds and bucket modes come from wire names', () {
      expect(ProjectViewKind.fromWire('kanban'), ProjectViewKind.kanban);
      expect(ProjectViewKind.fromWire('timeline'), isNull);
      expect(
        BucketConfigurationMode.fromWire('manual'),
        BucketConfigurationMode.manual,
      );
      expect(
        BucketConfigurationMode.fromWire('x'),
        BucketConfigurationMode.none,
      );
    });

    test('views are identified by id and project', () {
      const a = ProjectView(
        id: 1,
        projectId: 2,
        title: 'List',
        kind: ProjectViewKind.list,
      );
      const b = ProjectView(
        id: 1,
        projectId: 2,
        title: 'Other',
        kind: ProjectViewKind.table,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          const ProjectView(
            id: 1,
            projectId: 3,
            title: 'List',
            kind: ProjectViewKind.list,
          ),
        ),
      );
    });
  });

  test('equality ignores owner and views', () {
    const owner = User(id: 1, username: 'u');
    const view = ProjectView(
      id: 1,
      projectId: 1,
      title: 'List',
      kind: ProjectViewKind.list,
    );

    expect(
      const Project(id: 1, title: 'p', owner: owner, views: [view]),
      const Project(id: 1, title: 'p'),
    );
    expect(
      const Project(id: 1, title: 'p'),
      isNot(const Project(id: 1, title: 'q')),
    );
  });

  group('max permission', () {
    const shared = Project(
      id: 7,
      title: 'Shared',
      maxPermission: Permission.read,
    );

    test('a changed permission makes another project', () {
      expect(shared.copyWith(maxPermission: Permission.write), isNot(shared));
      expect(
        shared.copyWith(maxPermission: Permission.write).hashCode,
        isNot(shared.hashCode),
      );
      expect(shared.copyWith(), shared);
    });

    test('copyWith clears it with null and keeps it when left out', () {
      expect(shared.copyWith(maxPermission: null).maxPermission, isNull);
      expect(shared.copyWith(title: 'Renamed').maxPermission, Permission.read);
      expect(shared.copyWith(title: 'Renamed').title, 'Renamed');
    });

    test('copyWith keeps and replaces every other field', () {
      final full = Project(
        id: 3,
        title: 'Full',
        description: '<p>d</p>',
        identifier: 'FU',
        hexColor: '1973ff',
        parentProjectId: 2,
        isArchived: true,
        isFavorite: true,
        position: 4.5,
        owner: const User(id: 1, username: 'owner'),
        views: const [
          ProjectView(
            id: 9,
            projectId: 3,
            title: 'List',
            kind: ProjectViewKind.list,
          ),
        ],
        created: DateTime.utc(2026),
        updated: DateTime.utc(2026, 2),
        maxPermission: Permission.admin,
      );

      final copy = full.copyWith();

      expect(copy, full);
      expect(copy.owner, full.owner);
      expect(copy.views, full.views);
      expect(copy.created, full.created);
      expect(full.copyWith(owner: null).owner, isNull);
      expect(full.copyWith(updated: null).updated, isNull);
      expect(full.copyWith(parentProjectId: 0).isTopLevel, isTrue);
    });
  });

  group('subscription', () {
    const own = Subscription(entity: SubscriptionEntity.project, entityId: 5);
    const viaParent = Subscription(
      entity: SubscriptionEntity.project,
      entityId: 4,
    );
    const followed = Project(id: 5, title: 'Followed', subscription: own);

    test('copyWith keeps it when left out, replaces and clears it', () {
      expect(followed.copyWith(title: 'Renamed').subscription, own);
      expect(
        followed.copyWith(subscription: viaParent).subscription,
        viaParent,
      );
      expect(followed.copyWith(subscription: null).subscription, isNull);
      expect(
        const Project(id: 5, title: 'p').copyWith(subscription: own),
        const Project(id: 5, title: 'p', subscription: own),
      );
    });

    test('a different subscription makes another project', () {
      const unfollowed = Project(id: 5, title: 'Followed');

      expect(followed, isNot(unfollowed));
      expect(followed.hashCode, isNot(unfollowed.hashCode));
      expect(followed, isNot(followed.copyWith(subscription: viaParent)));
      expect(
        followed.hashCode,
        isNot(followed.copyWith(subscription: viaParent).hashCode),
      );
      expect(followed.copyWith(), followed);
      expect(followed.copyWith().hashCode, followed.hashCode);
    });
  });
}
