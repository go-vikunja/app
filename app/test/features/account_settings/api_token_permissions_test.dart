import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/account_settings/application/api_token_expiry.dart';
import 'package:vikunja_mobile/features/account_settings/application/api_token_permissions.dart';
import 'package:vikunja_mobile/features/account_settings/application/integration_addresses.dart';

import '../../helpers/server_connections.dart';

void main() {
  final offered = ApiPermissionGroups(const {
    'caldav': ['access'],
    'labels': ['create', 'delete', 'read_all', 'read_one', 'update'],
    'other': ['routes', 'user'],
    'projects': [
      'create',
      'read_all',
      'read_one',
      'update',
      'views_buckets_tasks',
    ],
    'projects_views': ['create', 'read_all', 'read_one'],
    'tasks': ['create', 'delete', 'read_all', 'read_one', 'update'],
    'tasks_comments': ['create', 'read_all'],
    'teams': ['create', 'read_all', 'read_one'],
  });

  group('presets, as the web defines them', () {
    test('read only picks read_one and read_all wherever offered', () {
      expect(presetSelection(ApiTokenPreset.readOnly, offered), {
        'labels': {'read_all', 'read_one'},
        'projects': {'read_all', 'read_one'},
        'projects_views': {'read_all', 'read_one'},
        'tasks': {'read_all', 'read_one'},
        'tasks_comments': {'read_all'},
        'teams': {'read_all', 'read_one'},
      });
    });

    test('task management: the task groups whole, reads around them and '
        'moving tasks between buckets, before 2.7.1 by its old name', () {
      expect(presetSelection(ApiTokenPreset.tasks, offered), {
        'tasks': {'create', 'delete', 'read_all', 'read_one', 'update'},
        'tasks_comments': {'create', 'read_all'},
        'labels': {'create', 'read_all', 'read_one'},
        'projects': {'read_all', 'read_one', 'views_buckets_tasks'},
        'projects_views': {'read_all', 'read_one'},
      });
    });

    test('task management on 2.7.1 moves tasks by the new name and leaves '
        'out reading them by bucket, which took the old one', () {
      final renamed = ApiPermissionGroups(const {
        'projects': [
          'read_all',
          'read_one',
          'views_buckets_tasks',
          'views_buckets_tasks_update',
        ],
        'projects_views_tasks': ['read_all'],
      });

      expect(presetSelection(ApiTokenPreset.tasks, renamed), {
        'projects': {'read_all', 'read_one', 'views_buckets_tasks_update'},
        'projects_views_tasks': {'read_all'},
      });
    });

    test('project management: the project groups whole, reads of tasks and '
        'teams; groups the server lacks are left out', () {
      expect(presetSelection(ApiTokenPreset.projects, offered), {
        'projects': {
          'create',
          'read_all',
          'read_one',
          'update',
          'views_buckets_tasks',
        },
        'projects_views': {'create', 'read_all', 'read_one'},
        'tasks': {'read_all', 'read_one'},
        'teams': {'read_all', 'read_one'},
      });
    });

    test('full access picks everything', () {
      final picked = presetSelection(ApiTokenPreset.fullAccess, offered);
      expect(selectedPermissions(offered, picked), offered.groups);
    });
  });

  group('on 2.8.0, as on the web, with the bin', () {
    // The two groups as 2.8.0's /routes offers them, alike on v1 and v2.
    final offered280 = ApiPermissionGroups(const {
      'projects': [
        'background',
        'background_delete',
        'backgrounds_upload',
        'count',
        'create',
        'delete',
        'deleted',
        'deleted_count',
        'deleted_delete',
        'duplicate',
        'permanent',
        'projectusers',
        'read_all',
        'read_one',
        'restore',
        'tasks_by_index',
        'update',
        'users_search',
        'views_buckets',
        'views_buckets_create',
        'views_buckets_delete',
        'views_buckets_tasks',
        'views_buckets_tasks_update',
        'views_buckets_update',
      ],
      'tasks': [
        'attachments_preview',
        'create',
        'create_bulk',
        'delete',
        'deleted',
        'deleted_count',
        'deleted_delete',
        'duplicate',
        'permanent',
        'position',
        'read',
        'read_all',
        'read_one',
        'restore',
        'update',
        'update_bulk',
      ],
    });
    Set<String> all(String group) => offered280.groups[group]!.toSet();

    test('task management picks every task permission, the bin, deleting '
        'forever and emptying included, and of projects only reads and '
        'moving tasks between buckets', () {
      expect(presetSelection(ApiTokenPreset.tasks, offered280), {
        'tasks': all('tasks'),
        'projects': {'read_all', 'read_one', 'views_buckets_tasks_update'},
      });
    });

    test('project management picks every project permission, the count and '
        'the bin included, and of tasks only reads', () {
      expect(presetSelection(ApiTokenPreset.projects, offered280), {
        'projects': all('projects'),
        'tasks': {'read_all', 'read_one'},
      });
    });

    test('read only picks no bin permission', () {
      expect(presetSelection(ApiTokenPreset.readOnly, offered280), {
        'projects': {'read_all', 'read_one'},
        'tasks': {'read_all', 'read_one'},
      });
    });

    test('full access picks everything', () {
      final picked = presetSelection(ApiTokenPreset.fullAccess, offered280);
      expect(selectedPermissions(offered280, picked), offered280.groups);
    });
  });

  test('the selection is sent in the order the server offers it', () {
    final sent = selectedPermissions(offered, {
      'tasks': {'update', 'create'},
      'caldav': {'access'},
      'labels': {},
    });

    expect(sent.keys, ['caldav', 'tasks']);
    expect(sent['tasks'], ['create', 'update']);
  });

  test('names read like the web shows them', () {
    expect(humanizePermission('read_all'), 'Read all');
    expect(humanizePermission('tasks_attachments'), 'Tasks attachments');
    expect(humanizePermission('ws'), 'Ws');
    expect(humanizePermission(''), '');
  });

  group('expiry', () {
    final now = DateTime(2026, 10, 21, 22, 30);

    test('a preset counts whole days of 24 hours from now, as on the web', () {
      expect(
        presetExpiry(30, DateTime.utc(2026, 10, 21, 22, 30)),
        DateTime.utc(2026, 11, 20, 22, 30),
      );
      expect(presetExpiry(90, now).difference(now), const Duration(days: 90));
    });

    test('a picked day is valid through its end', () {
      expect(
        endOfDay(DateTime(2026, 10, 21)),
        DateTime(2026, 10, 21, 23, 59, 59),
      );
      expect(isCustomExpiryValid(DateTime(2026, 10, 21), now), isTrue);
      expect(isCustomExpiryValid(DateTime(2026, 10, 20), now), isFalse);
    });
  });

  test('the CalDAV address is under the server, with the username', () {
    expect(
      caldavPrincipalUri(fullServer270(), 'alice').toString(),
      'https://tasks.example.org/vikunja/dav/principals/alice/',
    );
    expect(
      caldavPrincipalUri(oauthServer230(), 'a b').toString(),
      'https://vikunja.example.com/dav/principals/a%20b/',
    );
  });

  test('the API documentation is on v1', () {
    expect(
      apiDocsUri(fullServer270()).toString(),
      'https://tasks.example.org/vikunja/api/v1/docs',
    );
  });
}
