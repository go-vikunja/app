// Records the answers of step 28 into test/fixtures/sharing, with three
// throwaway users (owner, member, guest):
//   dart run tool/capture_sharing_fixtures.dart [http://localhost:34527] [2.7.0]
// Labels: the owner's label updated (v2 merge-patch, the same unchanged, v1
// read and full replace), refused for the member, a title too long, deleted
// twice, and a label titled "2026" listed with every label. The global user
// search. Teams: created, read by admin and member, listed (whole, paged and
// searched), members added (again, unknown), the admin flag toggled (also
// for a non-member), updated (and refused), a member removed, the last one
// refused, an external team (2.7.0 still takes an `external_id` from a
// client) refusing removal, deleted. A project shared with the member and
// the guest, with two teams and by links (one with a password), changed,
// listed (also as a non-member of the teams, who sees them nameless) and
// removed, with the refusals; the project lists with `expand=permissions`
// and the single reads as the member. The request bodies are kept as
// `sent`. Writes are paced by half a second. The users are renamed, emails
// replaced; link share hashes become 40 `x`, passwords and tokens never
// appear: no file may hold a secret.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

typedef _User = ({
  String username,
  String email,
  String password,
  String jwt,
  int id,
});

const _mergePatch = 'application/merge-patch+json';
final String _fakeHash = 'x' * 40;
final _hashPattern = RegExp('"hash":"([A-Za-z0-9]{40})"');
const _keptHeaders = [
  'content-type',
  'x-pagination-total-pages',
  'x-pagination-result-count',
  'x-max-permission',
];

Future<void> main(List<String> args) async {
  final root = args.elementAtOrNull(0) ?? 'http://localhost:34527';
  final serverVersion = args.elementAtOrNull(1) ?? '2.7.0';
  final dio = Dio(
    BaseOptions(
      baseUrl: root,
      headers: {'User-Agent': 'Rurana fixture capture'},
      responseType: ResponseType.plain,
    ),
  );
  final owner = await _register(dio, 'shrowner');
  final member = await _register(dio, 'shrmember');
  final guest = await _register(dio, 'shrguest');
  final linkPassword = 'link-${Random.secure().nextInt(1 << 32)}';
  final secrets = <String>{
    for (final user in [owner, member, guest]) ...[user.password, user.jwt],
    linkPassword,
  };
  final names = {
    for (final (user, fake) in [
      (owner, 'fixtureowner'),
      (member, 'fixturemember'),
      (guest, 'fixtureguest'),
    ]) ...{
      user.username: fake,
      user.username.toUpperCase(): fake.toUpperCase(),
    },
  };

  String scrub(String text) {
    var scrubbed = text;
    for (final MapEntry(key: real, value: fake) in names.entries) {
      scrubbed = scrubbed
          .replaceAll('$real@example.com', '$fake@example.invalid')
          .replaceAll(real, fake);
    }
    for (final match in _hashPattern.allMatches(scrubbed)) {
      if (match[1] != _fakeHash) secrets.add(match[1]!);
    }
    scrubbed = scrubbed.replaceAllMapped(
      _hashPattern,
      (_) => '"hash":"$_fakeHash"',
    );
    final leaks =
        scrubbed.contains('@example.com') ||
        scrubbed.contains('"token"') ||
        secrets.any(scrubbed.contains);
    if (leaks) throw StateError('a capture leaks a secret or an email');
    return scrubbed;
  }

  Future<Response<String>> capture(
    String name,
    String method,
    String path, {
    Map<String, Object?>? body,
    _User? as,
    String? contentType,
  }) async {
    final response = await _send(
      dio,
      (as ?? owner).jwt,
      method,
      path,
      body: body,
      contentType: contentType,
    );
    final file = File('test/fixtures/sharing/${name}_$serverVersion.json');
    await file.parent.create(recursive: true);
    final sent = body == null
        ? null
        : jsonEncode({
            for (final MapEntry(:key, :value) in body.entries)
              key: key == 'password' ? '<password>' : value,
          });
    final record = {
      'server': serverVersion,
      'request': scrub('$method $path'),
      if (sent != null) 'sent': jsonDecode(scrub(sent)),
      'status': response.statusCode,
      'headers': {
        for (final header in _keptHeaders)
          header: ?response.headers.value(header),
      },
      'body': scrub(response.data ?? ''),
    };
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(record)}\n',
    );
    stdout.writeln('wrote ${file.path} (${response.statusCode})');
    return response;
  }

  Future<Object?> raw(
    String method,
    String path, {
    Map<String, Object?>? body,
    _User? as,
  }) async {
    final response = await _send(
      dio,
      (as ?? owner).jwt,
      method,
      path,
      body: body,
    );
    if (response.statusCode! >= 300) {
      throw StateError('$method $path: ${response.statusCode}');
    }
    final data = response.data ?? '';
    return data.trim().isEmpty ? null : jsonDecode(data);
  }

  int idOf(Object? json) => (json! as Map<String, Object?>)['id']! as int;

  // Labels.
  final v2Label = idOf(
    await raw(
      'POST',
      '/api/v2/labels',
      body: {
        'title': 'Fixture label',
        'description': '<p>Old</p>',
        'hex_color': 'e8e8e8',
      },
    ),
  );
  final v1Label = idOf(
    await raw(
      'PUT',
      '/api/v1/labels',
      body: {
        'title': 'Odd colour',
        'description': '<p>Kept</p>',
        'hex_color': 'ABC',
      },
    ),
  );
  await raw('PUT', '/api/v1/labels', body: {'title': '2026'});
  await capture(
    'v2_label_update',
    'PATCH',
    '/api/v2/labels/$v2Label',
    body: {'title': 'Renamed label', 'hex_color': '1973ff'},
    contentType: _mergePatch,
  );
  await capture(
    'v2_label_update_unchanged',
    'PATCH',
    '/api/v2/labels/$v2Label',
    body: {'title': 'Renamed label'},
    contentType: _mergePatch,
  );
  await capture('v2_label_read', 'GET', '/api/v2/labels/$v2Label');
  await capture(
    'v2_label_update_not_creator',
    'PATCH',
    '/api/v2/labels/$v2Label',
    body: {'title': 'Hijacked'},
    contentType: _mergePatch,
    as: member,
  );
  await capture(
    'v2_label_update_too_long',
    'PATCH',
    '/api/v2/labels/$v2Label',
    body: {'title': 'x' * 251},
    contentType: _mergePatch,
  );
  final v1Read = await capture(
    'v1_label_read',
    'GET',
    '/api/v1/labels/$v1Label',
  );
  await capture(
    'v1_label_update',
    'POST',
    '/api/v1/labels/$v1Label',
    body: {
      ...jsonDecode(v1Read.data!) as Map<String, Object?>,
      'title': 'Still odd',
    },
  );
  await capture(
    'v1_label_read_not_visible',
    'GET',
    '/api/v1/labels/$v1Label',
    as: member,
  );
  await capture(
    'v1_label_update_not_creator',
    'POST',
    '/api/v1/labels/$v1Label',
    body: {'title': 'Hijacked'},
    as: member,
  );
  await capture(
    'v1_label_update_too_long',
    'POST',
    '/api/v1/labels/$v1Label',
    body: {'title': 'x' * 251, 'description': '', 'hex_color': ''},
  );
  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_labels_all',
      'GET',
      '/api/$version/labels?page=1&per_page=50',
    );
  }
  await capture(
    'v1_labels_search_digits',
    'GET',
    '/api/v1/labels?s=2026&page=1',
  );
  await capture('v2_label_delete', 'DELETE', '/api/v2/labels/$v2Label');
  await capture('v2_label_delete_gone', 'DELETE', '/api/v2/labels/$v2Label');
  await capture(
    'v2_label_update_gone',
    'PATCH',
    '/api/v2/labels/$v2Label',
    body: {'title': 'Gone'},
    contentType: _mergePatch,
  );
  await capture('v1_label_delete', 'DELETE', '/api/v1/labels/$v1Label');
  await capture('v1_label_delete_gone', 'DELETE', '/api/v1/labels/$v1Label');
  await capture('v1_label_read_gone', 'GET', '/api/v1/labels/$v1Label');
  await capture(
    'v1_label_update_gone',
    'POST',
    '/api/v1/labels/$v1Label',
    body: {'title': 'Gone'},
  );

  // The global user search.
  await capture(
    'v1_users_search',
    'GET',
    '/api/v1/users?s=${member.username.toUpperCase()}',
  );
  await capture('v2_users_search', 'GET', '/api/v2/users?q=${member.username}');
  await capture('v1_users_search_none', 'GET', '/api/v1/users?s=nobody-at-all');
  await capture('v2_users_search_none', 'GET', '/api/v2/users?q=nobody-at-all');

  // Teams.
  final v1Team = await capture(
    'v1_team_create',
    'PUT',
    '/api/v1/teams',
    body: {'name': 'Fixture team one', 'description': '<p>First</p>'},
  );
  final teamOne = idOf(jsonDecode(v1Team.data!));
  final v2Team = await capture(
    'v2_team_create',
    'POST',
    '/api/v2/teams',
    body: {'name': 'Fixture team two', 'is_public': false},
  );
  final teamTwo = idOf(jsonDecode(v2Team.data!));
  await capture(
    'v1_team_create_empty_name',
    'PUT',
    '/api/v1/teams',
    body: {'name': ''},
  );
  await capture(
    'v2_team_create_empty_name',
    'POST',
    '/api/v2/teams',
    body: {'name': ''},
  );
  for (final (version, method, team) in [
    ('v1', 'PUT', teamOne),
    ('v2', 'POST', teamTwo),
  ]) {
    await capture(
      '${version}_team_member_add',
      method,
      '/api/$version/teams/$team/members',
      body: {'username': member.username, 'admin': false},
    );
    await capture(
      '${version}_team_member_add_again',
      method,
      '/api/$version/teams/$team/members',
      body: {'username': member.username, 'admin': false},
    );
    await capture(
      '${version}_team_member_add_unknown',
      method,
      '/api/$version/teams/$team/members',
      body: {'username': 'nobody-at-all', 'admin': false},
    );
  }
  for (final version in ['v1', 'v2']) {
    final team = version == 'v1' ? teamOne : teamTwo;
    await capture('${version}_team_read', 'GET', '/api/$version/teams/$team');
    await capture(
      '${version}_team_read_member',
      'GET',
      '/api/$version/teams/$team',
      as: member,
    );
    await capture(
      '${version}_team_read_forbidden',
      'GET',
      '/api/$version/teams/$team',
      as: guest,
    );
    await capture(
      '${version}_teams',
      'GET',
      '/api/$version/teams?page=1&per_page=50',
    );
    for (final page in [1, 2]) {
      await capture(
        '${version}_teams_page_$page',
        'GET',
        '/api/$version/teams?page=$page&per_page=1',
      );
    }
    await capture(
      '${version}_teams_search',
      'GET',
      '/api/$version/teams?${version == 'v1' ? 's' : 'q'}=TWO'
          '&include_public=true&page=1&per_page=50',
    );
    await capture(
      '${version}_team_member_toggle',
      'POST',
      '/api/$version/teams/$team/members/${member.username}/admin',
    );
    await capture(
      '${version}_team_member_toggle_back',
      'POST',
      '/api/$version/teams/$team/members/${member.username}/admin',
    );
    await capture(
      '${version}_team_member_toggle_non_member',
      'POST',
      '/api/$version/teams/$team/members/${guest.username}/admin',
    );
  }
  await capture(
    'v2_team_update',
    'PATCH',
    '/api/v2/teams/$teamTwo',
    body: {'name': 'Fixture team renamed', 'description': '<p>Second</p>'},
    contentType: _mergePatch,
  );
  await capture(
    'v2_team_update_clear_description',
    'PATCH',
    '/api/v2/teams/$teamTwo',
    body: {'description': '<p></p>'},
    contentType: _mergePatch,
  );
  await capture(
    'v2_team_update_empty_description',
    'PATCH',
    '/api/v2/teams/$teamTwo',
    body: {'description': ''},
    contentType: _mergePatch,
  );
  await capture(
    'v2_team_update_forbidden',
    'PATCH',
    '/api/v2/teams/$teamTwo',
    body: {'name': 'Hijacked'},
    contentType: _mergePatch,
    as: member,
  );
  await capture(
    'v1_team_update',
    'POST',
    '/api/v1/teams/$teamOne',
    body: {
      'name': 'Fixture team one',
      'description': '<p>First, edited</p>',
      'is_public': false,
    },
  );
  await capture(
    'v1_team_update_forbidden',
    'POST',
    '/api/v1/teams/$teamOne',
    body: {'name': 'Hijacked', 'description': '', 'is_public': false},
    as: member,
  );

  // A project shared with the member, the guest, both teams and by links.
  final project = idOf(
    await raw('PUT', '/api/v1/projects', body: {'title': 'Fixture shared'}),
  );
  await raw(
    'PUT',
    '/api/v1/projects',
    body: {'title': 'Fixture child', 'parent_project_id': project},
  );
  await capture(
    'v1_project_user_add',
    'PUT',
    '/api/v1/projects/$project/users',
    body: {'username': member.username, 'permission': 0},
  );
  await capture(
    'v2_project_user_add',
    'POST',
    '/api/v2/projects/$project/users',
    body: {'username': guest.username, 'permission': 1},
  );
  for (final (version, method) in [('v1', 'PUT'), ('v2', 'POST')]) {
    await capture(
      '${version}_project_user_add_again',
      method,
      '/api/$version/projects/$project/users',
      body: {'username': member.username, 'permission': 0},
    );
    await capture(
      '${version}_project_user_add_owner',
      method,
      '/api/$version/projects/$project/users',
      body: {'username': owner.username, 'permission': 0},
    );
    await capture(
      '${version}_project_user_add_unknown',
      method,
      '/api/$version/projects/$project/users',
      body: {'username': 'nobody-at-all', 'permission': 0},
    );
    await capture(
      '${version}_project_user_add_bad_permission',
      method,
      '/api/$version/projects/$project/users',
      body: {'username': member.username, 'permission': 3},
    );
  }
  await capture(
    'v1_project_user_update',
    'POST',
    '/api/v1/projects/$project/users/${member.username}',
    body: {'permission': 1},
  );
  await capture(
    'v2_project_user_update',
    'PUT',
    '/api/v2/projects/$project/users/${guest.username}',
    body: {'permission': 0},
  );
  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_project_users',
      'GET',
      '/api/$version/projects/$project/users?page=1&per_page=50',
    );
    for (final page in [1, 2]) {
      await capture(
        '${version}_project_users_page_$page',
        'GET',
        '/api/$version/projects/$project/users?page=$page&per_page=1',
      );
    }
    await capture(
      '${version}_project_user_update_forbidden',
      version == 'v1' ? 'POST' : 'PUT',
      '/api/$version/projects/$project/users/${guest.username}',
      body: {'permission': 2},
      as: member,
    );
    await capture(
      '${version}_project_user_remove_unknown',
      'DELETE',
      '/api/$version/projects/$project/users/nobody-at-all',
    );
  }
  for (final (version, method, team, permission) in [
    ('v1', 'PUT', teamOne, 1),
    ('v2', 'POST', teamTwo, 0),
  ]) {
    await capture(
      '${version}_project_team_add',
      method,
      '/api/$version/projects/$project/teams',
      body: {'team_id': team, 'permission': permission},
    );
    await capture(
      '${version}_project_team_add_again',
      method,
      '/api/$version/projects/$project/teams',
      body: {'team_id': team, 'permission': permission},
    );
    await capture(
      '${version}_project_team_add_unknown',
      method,
      '/api/$version/projects/$project/teams',
      body: {'team_id': 99999999, 'permission': 0},
    );
  }
  await capture(
    'v1_project_team_update',
    'POST',
    '/api/v1/projects/$project/teams/$teamOne',
    body: {'permission': 0},
  );
  await capture(
    'v2_project_team_update',
    'PUT',
    '/api/v2/projects/$project/teams/$teamTwo',
    body: {'permission': 1},
  );
  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_project_teams',
      'GET',
      '/api/$version/projects/$project/teams?page=1&per_page=50',
    );
    await capture(
      '${version}_project_teams_hidden',
      'GET',
      '/api/$version/projects/$project/teams?page=1&per_page=50',
      as: guest,
    );
  }

  final v1Link = await capture(
    'v1_link_share_create',
    'PUT',
    '/api/v1/projects/$project/shares',
    body: {'permission': 0, 'name': 'Fixture read link'},
  );
  final v2Link = await capture(
    'v2_link_share_create',
    'POST',
    '/api/v2/projects/$project/shares',
    body: {
      'permission': 1,
      'name': 'Fixture team link',
      'password': linkPassword,
    },
  );
  await raw('PUT', '/api/v1/projects/$project/shares', body: {'permission': 2});
  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_link_shares',
      'GET',
      '/api/$version/projects/$project/shares?page=1&per_page=50',
    );
    for (final page in [1, 2]) {
      await capture(
        '${version}_link_shares_page_$page',
        'GET',
        '/api/$version/projects/$project/shares?page=$page&per_page=2',
      );
    }
    await capture(
      '${version}_link_shares_forbidden',
      'GET',
      '/api/$version/projects/$project/shares?page=1&per_page=50',
      as: member,
    );
  }
  await capture(
    'v2_link_share_create_bad_permission',
    'POST',
    '/api/v2/projects/$project/shares',
    body: {'permission': 3},
  );
  await capture(
    'v1_link_share_create_bad_permission',
    'PUT',
    '/api/v1/projects/$project/shares',
    body: {'permission': 3},
  );

  // The project as the member sees it, with the permissions.
  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_projects_expanded',
      'GET',
      '/api/$version/projects?is_archived=true&page=1&per_page=50'
          '&expand=permissions',
      as: member,
    );
    await capture(
      '${version}_projects_unexpanded',
      'GET',
      '/api/$version/projects?is_archived=true&page=1&per_page=50',
      as: member,
    );
    await capture(
      '${version}_project_read',
      'GET',
      '/api/$version/projects/$project',
      as: member,
    );
  }

  // Removals and their refusals.
  await capture(
    'v1_link_share_delete',
    'DELETE',
    '/api/v1/projects/$project/shares/${idOf(jsonDecode(v1Link.data!))}',
  );
  final v2LinkId = idOf(jsonDecode(v2Link.data!));
  await capture(
    'v2_link_share_delete',
    'DELETE',
    '/api/v2/projects/$project/shares/$v2LinkId',
  );
  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_link_share_delete_gone',
      'DELETE',
      '/api/$version/projects/$project/shares/$v2LinkId',
    );
  }
  await capture(
    'v1_project_team_remove',
    'DELETE',
    '/api/v1/projects/$project/teams/$teamOne',
  );
  await capture(
    'v2_project_team_remove',
    'DELETE',
    '/api/v2/projects/$project/teams/$teamTwo',
  );
  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_project_team_remove_none',
      'DELETE',
      '/api/$version/projects/$project/teams/$teamTwo',
    );
    await capture(
      '${version}_project_team_remove_unknown',
      'DELETE',
      '/api/$version/projects/$project/teams/99999999',
    );
  }
  await capture(
    'v1_project_user_remove',
    'DELETE',
    '/api/v1/projects/$project/users/${member.username}',
  );
  await capture(
    'v2_project_user_remove',
    'DELETE',
    '/api/v2/projects/$project/users/${guest.username}',
  );
  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_project_user_remove_none',
      'DELETE',
      '/api/$version/projects/$project/users/${guest.username}',
    );
  }

  // Members removed, the last one refused, an external team, deletes.
  await capture(
    'v1_team_member_remove',
    'DELETE',
    '/api/v1/teams/$teamOne/members/${member.username}',
  );
  await capture(
    'v2_team_member_remove',
    'DELETE',
    '/api/v2/teams/$teamTwo/members/${member.username}',
  );
  for (final version in ['v1', 'v2']) {
    final team = version == 'v1' ? teamOne : teamTwo;
    await capture(
      '${version}_team_member_remove_last',
      'DELETE',
      '/api/$version/teams/$team/members/${owner.username}',
    );
    await capture(
      '${version}_team_member_remove_unknown',
      'DELETE',
      '/api/$version/teams/$team/members/nobody-at-all',
    );
  }
  final external = idOf(
    await raw(
      'PUT',
      '/api/v1/teams',
      body: {
        'name': 'Fixture group (Keycloak)',
        'external_id': 'fixture-oidc-group',
      },
    ),
  );
  await raw(
    'PUT',
    '/api/v1/teams/$external/members',
    body: {'username': member.username},
  );
  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_team_external_read',
      'GET',
      '/api/$version/teams/$external',
    );
    await capture(
      '${version}_team_member_remove_external',
      'DELETE',
      '/api/$version/teams/$external/members/${member.username}',
    );
  }
  await raw('DELETE', '/api/v1/teams/$external');
  await capture(
    'v2_team_delete_forbidden',
    'DELETE',
    '/api/v2/teams/$teamTwo',
    as: member,
  );
  await capture('v1_team_delete', 'DELETE', '/api/v1/teams/$teamOne');
  await capture('v2_team_delete', 'DELETE', '/api/v2/teams/$teamTwo');
  await raw('DELETE', '/api/v1/projects/$project');

  dio.close();
}

Future<_User> _register(Dio dio, String prefix) async {
  final suffix = Random.secure().nextInt(1 << 32).toRadixString(16);
  final username = '$prefix$suffix';
  final email = '$username@example.com';
  final password = 'password-$suffix-${Random.secure().nextInt(1 << 32)}';
  final registered = await _unauthenticated(
    () => dio.post<String>(
      '/api/v1/register',
      data: {'username': username, 'email': email, 'password': password},
    ),
  );
  final login = await _unauthenticated(
    () => dio.post<String>(
      '/api/v1/login',
      data: {'username': username, 'password': password},
    ),
  );
  return (
    username: username,
    email: email,
    password: password,
    jwt: (jsonDecode(login.data!) as Map<String, Object?>)['token']! as String,
    id: (jsonDecode(registered.data!) as Map<String, Object?>)['id']! as int,
  );
}

/// Waits out the shared limit of the unauthenticated routes.
Future<Response<String>> _unauthenticated(
  Future<Response<String>> Function() call,
) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await call();
    } on DioException catch (error) {
      if (error.response?.statusCode != 429 || attempt == 8) rethrow;
      final retryAfter = int.tryParse(
        error.response?.headers.value('retry-after') ?? '',
      );
      await Future<void>.delayed(Duration(seconds: (retryAfter ?? 14) + 1));
    }
  }
}

Future<Response<String>> _send(
  Dio dio,
  String jwt,
  String method,
  String path, {
  Map<String, Object?>? body,
  String? contentType,
}) async {
  for (var attempt = 1; ; attempt++) {
    final response = await dio.request<String>(
      path,
      data: body,
      options: Options(
        method: method,
        contentType: contentType,
        headers: {'Authorization': 'Bearer $jwt'},
        validateStatus: (_) => true,
      ),
    );
    if (method != 'GET') {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    // The SQLite server answers a write that collides with its own event
    // handlers with a 500 and changes nothing.
    if (response.statusCode == 500 && attempt < 8) {
      await Future<void>.delayed(Duration(seconds: attempt));
      continue;
    }
    if (response.statusCode == 429 && attempt < 8) {
      final retryAfter = int.tryParse(
        response.headers.value('retry-after') ?? '',
      );
      await Future<void>.delayed(Duration(seconds: (retryAfter ?? 10) + 1));
      continue;
    }
    return response;
  }
}
