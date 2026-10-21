import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  final expires = DateTime.utc(2026, 11, 20);

  group('ApiToken', () {
    ApiToken token({Map<String, List<String>>? permissions}) => ApiToken(
      id: 3,
      title: 'Home Assistant',
      permissions:
          permissions ??
          {
            'tasks': ['read_all', 'update'],
            'projects': ['read_all'],
          },
      expiresAt: expires,
      created: DateTime.utc(2026, 10, 21),
    );

    test('keeps the permission order and cannot be changed', () {
      final permissions = {
        'tasks': ['read_all', 'update'],
        'projects': ['read_all'],
      };
      final subject = token(permissions: permissions);
      permissions['tasks']!.add('delete');
      permissions['labels'] = ['read_all'];

      expect(subject.permissions.keys, ['tasks', 'projects']);
      expect(subject.permissions['tasks'], ['read_all', 'update']);
      expect(subject.permissionCount, 3);
      expect(() => subject.permissions['x'] = [], throwsUnsupportedError);
      expect(
        () => subject.permissions['tasks']!.add('x'),
        throwsUnsupportedError,
      );
    });

    test('is expired from its expiry on', () {
      expect(token().isExpiredAt(expires), isTrue);
      expect(
        token().isExpiredAt(expires.subtract(const Duration(seconds: 1))),
        isFalse,
      );
    });

    test('equal by every field, the permission order included', () {
      expect(token(), token());
      expect(token().hashCode, token().hashCode);
      expect(
        token(
          permissions: {
            'projects': ['read_all'],
            'tasks': ['read_all', 'update'],
          },
        ),
        isNot(token()),
      );
      expect(
        token(
          permissions: {
            'tasks': ['update', 'read_all'],
            'projects': ['read_all'],
          },
        ),
        isNot(token()),
      );
    });

    test('toString leaves out the title', () {
      expect(token().toString(), 'ApiToken(3)');
    });
  });

  test('NewApiToken toString leaves out the title', () {
    final token = NewApiToken(
      title: 'Private title',
      permissions: const {
        'tasks': ['read_all'],
      },
      expiresAt: expires,
    );

    expect(token.toString(), isNot(contains('Private')));
    expect(
      token,
      NewApiToken(
        title: 'Private title',
        permissions: const {
          'tasks': ['read_all'],
        },
        expiresAt: expires,
      ),
    );
  });

  test('a created token never prints its value', () {
    final created = CreatedApiToken(
      token: ApiToken(
        id: 4,
        title: 'x',
        permissions: const {},
        expiresAt: expires,
      ),
      secret: 'tk_${'0' * 40}',
    );
    final caldav = CreatedCaldavToken(
      token: const CaldavToken(id: 5),
      secret: 'C' * 64,
    );

    expect('$created', isNot(contains('tk_')));
    expect('$caldav', isNot(contains('CCCC')));
    expect('$created $caldav', contains('[redacted]'));
  });

  group('ApiPermissionGroups', () {
    final groups = ApiPermissionGroups(const {
      'caldav': ['access'],
      'other': ['user', 'routes'],
      'tasks': ['read_all', 'update'],
    });

    test("keeps the server's order with other last", () {
      expect(groups.groupNames, ['caldav', 'tasks', 'other']);
      expect(groups.groups.keys, ['caldav', 'other', 'tasks']);
      expect(groups.permissionCount, 5);
      expect(groups.isEmpty, isFalse);
      expect(ApiPermissionGroups(const {'tasks': []}).isEmpty, isTrue);
    });

    test('offers only what the server listed', () {
      expect(groups.offers('tasks', 'update'), isTrue);
      expect(groups.offers('tasks', 'delete'), isFalse);
      expect(groups.offers('labels', 'read_all'), isFalse);
    });
  });
}
