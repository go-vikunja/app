import 'package:flutter/foundation.dart' show immutable;
import 'package:vikunja_mobile/core/auth/oauth_client.dart';

/// The lists a widget link can open.
enum WidgetListKind {
  today,
  overdue,
  upcoming,
  favorites,
  project,
  label,
  savedFilter,
}

/// A link of a home-screen widget, `<scheme>://widget/…`: what the widget's
/// rows, buttons and state texts open. Only the user's own accounts can be
/// reached. Any app or web page can send such a link, so only one that
/// carries the install's [linkKey] (`k`, see `widget_link_key.dart`)
/// switches to its account without asking.
@immutable
sealed class WidgetLink {
  const new({this.linkKey});

  static const host = 'widget';

  /// Upcoming lists name no more days than this.
  static const maxDays = 365;

  final String? linkKey;

  /// Null for anything that is not a well-formed widget link.
  static WidgetLink? parse(Uri uri) {
    if (uri.scheme.toLowerCase() != oauthCallbackScheme ||
        uri.host.toLowerCase() != host) {
      return null;
    }
    final query = uri.queryParameters;
    final account = query['account'];
    final hasAccount = account != null && account.isNotEmpty;
    final linkKey = switch (query['k']) {
      final key? when key.isNotEmpty => key,
      _ => null,
    };
    int? queryInt(String name) => int.tryParse(query[name] ?? '');
    return switch (uri.pathSegments.where((s) => s.isNotEmpty).toList()) {
      ['task', final id] when hasAccount => switch (int.tryParse(id)) {
        final taskId? => WidgetTaskLink(
          accountId: account,
          taskId: taskId,
          linkKey: linkKey,
        ),
        null => null,
      },
      ['new-task'] => WidgetNewTaskLink(
        accountId: hasAccount ? account : null,
        projectId: queryInt('project'),
        linkKey: linkKey,
      ),
      ['list'] when hasAccount => _list(
        account,
        query['kind'],
        queryInt('id'),
        queryInt('days')?.clamp(1, maxDays),
        linkKey,
      ),
      ['account'] when hasAccount => WidgetAccountLink(
        accountId: account,
        linkKey: linkKey,
      ),
      ['open'] => WidgetOpenLink(
        accountId: hasAccount ? account : null,
        linkKey: linkKey,
      ),
      ['configure'] => switch (queryInt('appWidgetId')) {
        final appWidgetId? => WidgetConfigureLink(
          appWidgetId: appWidgetId,
          linkKey: linkKey,
        ),
        null => null,
      },
      _ => null,
    };
  }

  static WidgetListLink? _list(
    String account,
    String? kind,
    int? id,
    int? days,
    String? linkKey,
  ) {
    final listKind = WidgetListKind.values.asNameMap()[kind];
    return switch (listKind) {
      null => null,
      WidgetListKind.project ||
      WidgetListKind.label ||
      WidgetListKind.savedFilter when id == null => null,
      _ => WidgetListLink(
        accountId: account,
        kind: listKind,
        id: id,
        days: days,
        linkKey: linkKey,
      ),
    };
  }

  Uri toUri();

  Uri _uri(List<String> path, [Map<String, String> query = const {}]) {
    final all = {...query, 'k': ?linkKey};
    return Uri(
      scheme: oauthCallbackScheme,
      host: host,
      pathSegments: path,
      queryParameters: all.isEmpty ? null : all,
    );
  }
}

final class WidgetTaskLink extends WidgetLink {
  const new({required this.accountId, required this.taskId, super.linkKey});

  final String accountId;
  final int taskId;

  @override
  Uri toUri() => _uri(['task', '$taskId'], {'account': accountId});

  @override
  bool operator ==(Object other) =>
      other is WidgetTaskLink &&
      other.accountId == accountId &&
      other.taskId == taskId &&
      other.linkKey == linkKey;

  @override
  int get hashCode => Object.hash(WidgetTaskLink, accountId, taskId, linkKey);
}

/// Without [accountId] (a Quick add widget not set up) in the active
/// account; [projectId] only applies with one.
final class WidgetNewTaskLink extends WidgetLink {
  const new({this.accountId, this.projectId, super.linkKey});

  final String? accountId;
  final int? projectId;

  @override
  Uri toUri() => _uri(
    ['new-task'],
    {
      'account': ?accountId,
      if (projectId case final projectId?) 'project': '$projectId',
    },
  );

  @override
  bool operator ==(Object other) =>
      other is WidgetNewTaskLink &&
      other.accountId == accountId &&
      other.projectId == projectId &&
      other.linkKey == linkKey;

  @override
  int get hashCode =>
      Object.hash(WidgetNewTaskLink, accountId, projectId, linkKey);
}

/// [id] is the project's or label's id, or the saved filter's own id (its
/// pseudo project id is accepted too).
final class WidgetListLink extends WidgetLink {
  const new({
    required this.accountId,
    required this.kind,
    this.id,
    this.days,
    super.linkKey,
  });

  final String accountId;
  final WidgetListKind kind;
  final int? id;
  final int? days;

  WidgetListLink withLinkKey(String? linkKey) => WidgetListLink(
    accountId: accountId,
    kind: kind,
    id: id,
    days: days,
    linkKey: linkKey,
  );

  @override
  Uri toUri() => _uri(
    ['list'],
    {
      'account': accountId,
      'kind': kind.name,
      if (id case final id?) 'id': '$id',
      if (days case final days?) 'days': '$days',
    },
  );

  @override
  bool operator ==(Object other) =>
      other is WidgetListLink &&
      other.accountId == accountId &&
      other.kind == kind &&
      other.id == id &&
      other.days == days &&
      other.linkKey == linkKey;

  @override
  int get hashCode =>
      Object.hash(WidgetListLink, accountId, kind, id, days, linkKey);
}

/// The account's Account tab, where an ended session is signed in again.
final class WidgetAccountLink extends WidgetLink {
  const new({required this.accountId, super.linkKey});

  final String accountId;

  @override
  Uri toUri() => _uri(['account'], {'account': accountId});

  @override
  bool operator ==(Object other) =>
      other is WidgetAccountLink &&
      other.accountId == accountId &&
      other.linkKey == linkKey;

  @override
  int get hashCode => Object.hash(WidgetAccountLink, accountId, linkKey);
}

/// Opens the app, in [accountId] when it is still signed in.
final class WidgetOpenLink extends WidgetLink {
  const new({this.accountId, super.linkKey});

  final String? accountId;

  @override
  Uri toUri() => _uri(['open'], {'account': ?accountId});

  @override
  bool operator ==(Object other) =>
      other is WidgetOpenLink &&
      other.accountId == accountId &&
      other.linkKey == linkKey;

  @override
  int get hashCode => Object.hash(WidgetOpenLink, accountId, linkKey);
}

/// Android's configuration of a placed widget, through a native hop.
final class WidgetConfigureLink extends WidgetLink {
  const new({required this.appWidgetId, super.linkKey});

  final int appWidgetId;

  @override
  Uri toUri() => _uri(['configure'], {'appWidgetId': '$appWidgetId'});

  @override
  bool operator ==(Object other) =>
      other is WidgetConfigureLink &&
      other.appWidgetId == appWidgetId &&
      other.linkKey == linkKey;

  @override
  int get hashCode => Object.hash(WidgetConfigureLink, appWidgetId, linkKey);
}
