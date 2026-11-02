import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/links/widget_link.dart';

void main() {
  const scheme = oauthCallbackScheme;
  const account = '30ce2008a48567a5b9af7e9cc4ed0345';

  WidgetLink? parse(String link) => WidgetLink.parse(Uri.parse(link));

  group('parse', () {
    test('reads every kind of link', () {
      expect(
        parse('$scheme://widget/task/7?account=$account'),
        const WidgetTaskLink(accountId: account, taskId: 7),
      );
      expect(
        parse('$scheme://widget/task/-3?account=$account'),
        const WidgetTaskLink(accountId: account, taskId: -3),
      );
      expect(
        parse('$scheme://widget/new-task?account=$account&project=4'),
        const WidgetNewTaskLink(accountId: account, projectId: 4),
      );
      expect(parse('$scheme://widget/new-task'), const WidgetNewTaskLink());
      expect(
        parse('$scheme://widget/list?account=$account&kind=upcoming&days=3'),
        const WidgetListLink(
          accountId: account,
          kind: WidgetListKind.upcoming,
          days: 3,
        ),
      );
      expect(
        parse('$scheme://widget/list?account=$account&kind=savedFilter&id=2'),
        const WidgetListLink(
          accountId: account,
          kind: WidgetListKind.savedFilter,
          id: 2,
        ),
      );
      expect(
        parse('$scheme://widget/account?account=$account'),
        const WidgetAccountLink(accountId: account),
      );
      expect(parse('$scheme://widget/open'), const WidgetOpenLink());
      expect(
        parse('$scheme://widget/open?account=$account'),
        const WidgetOpenLink(accountId: account),
      );
      expect(
        parse('$scheme://widget/configure?appWidgetId=12'),
        const WidgetConfigureLink(appWidgetId: 12),
      );
    });

    test('reads the link key, and none from an empty one', () {
      expect(
        parse('$scheme://widget/task/7?account=$account&k=key-1'),
        const WidgetTaskLink(accountId: account, taskId: 7, linkKey: 'key-1'),
      );
      expect(
        parse('$scheme://widget/list?account=$account&kind=today&k=key-1'),
        const WidgetListLink(
          accountId: account,
          kind: WidgetListKind.today,
          linkKey: 'key-1',
        ),
      );
      expect(
        parse('$scheme://widget/configure?appWidgetId=12&k=key-1')?.linkKey,
        'key-1',
      );
      expect(parse('$scheme://widget/open?k=')?.linkKey, isNull);
      expect(
        parse('$scheme://widget/task/7?account=$account'),
        isNot(
          const WidgetTaskLink(accountId: account, taskId: 7, linkKey: 'key-1'),
        ),
      );
    });

    test('keeps the days of a list within a year', () {
      int? days(String value) => switch (parse(
        '$scheme://widget/list?account=$account&kind=upcoming&days=$value',
      )) {
        WidgetListLink(:final days) => days,
        _ => null,
      };

      expect(days('14'), 14);
      expect(days('0'), 1);
      expect(days('-5'), 1);
      expect(days('99999999'), WidgetLink.maxDays);
    });

    test('ignores the case of the scheme and the host', () {
      expect(
        parse(
          'VIKUNJA-dev.coderoftime.rurana://Widget/task/7?account=$account',
        ),
        const WidgetTaskLink(accountId: account, taskId: 7),
      );
    });

    test('is null for anything malformed or foreign', () {
      for (final link in [
        '$scheme://task/7?account=$account',
        'https://example.com/widget/task/7?account=$account',
        '$scheme://widget/task/7',
        '$scheme://widget/task/seven?account=$account',
        '$scheme://widget/task?account=$account',
        '$scheme://widget/done/7?account=$account',
        '$scheme://widget/list?account=$account',
        '$scheme://widget/list?account=$account&kind=weekly',
        '$scheme://widget/list?account=$account&kind=project',
        '$scheme://widget/list?kind=today',
        '$scheme://widget/account',
        '$scheme://widget/configure',
        '$scheme://widget/configure?appWidgetId=x',
        '$scheme://widget/',
        '$scheme://widget/settings?account=$account',
      ]) {
        expect(parse(link), isNull, reason: link);
      }
    });
  });

  test('every link reads back as itself', () {
    for (final link in const <WidgetLink>[
      WidgetTaskLink(accountId: account, taskId: -2),
      WidgetNewTaskLink(accountId: account, projectId: 3),
      WidgetNewTaskLink(accountId: account),
      WidgetNewTaskLink(),
      WidgetListLink(accountId: account, kind: WidgetListKind.today),
      WidgetListLink(
        accountId: account,
        kind: WidgetListKind.upcoming,
        days: 14,
      ),
      WidgetListLink(accountId: account, kind: WidgetListKind.label, id: 5),
      WidgetAccountLink(accountId: account),
      WidgetOpenLink(accountId: account),
      WidgetOpenLink(),
      WidgetConfigureLink(appWidgetId: 31),
      WidgetTaskLink(accountId: account, taskId: 7, linkKey: 'key-1'),
      WidgetNewTaskLink(linkKey: 'key-1'),
      WidgetListLink(
        accountId: account,
        kind: WidgetListKind.project,
        id: 3,
        linkKey: 'key-1',
      ),
      WidgetAccountLink(accountId: account, linkKey: 'key-1'),
      WidgetOpenLink(accountId: account, linkKey: 'key-1'),
      WidgetConfigureLink(appWidgetId: 31, linkKey: 'key-1'),
    ]) {
      final uri = link.toUri();
      expect(uri.scheme, scheme);
      expect(uri.host, WidgetLink.host);
      expect(uri.queryParameters, isNot(contains('homeWidget')));
      expect(WidgetLink.parse(Uri.parse('$uri')), link, reason: '$uri');
    }
  });

  test('a task link has the documented shape', () {
    expect(
      '${const WidgetTaskLink(accountId: account, taskId: 7).toUri()}',
      '$scheme://widget/task/7?account=$account',
    );
    const projectList = WidgetListLink(
      accountId: account,
      kind: WidgetListKind.project,
      id: 12,
    );
    expect(
      '${projectList.toUri()}',
      '$scheme://widget/list?account=$account&kind=project&id=12',
    );
    expect(
      '${projectList.withLinkKey('key-1').toUri()}',
      '$scheme://widget/list?account=$account&kind=project&id=12&k=key-1',
    );
  });
}
