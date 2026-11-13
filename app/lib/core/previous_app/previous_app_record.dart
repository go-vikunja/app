import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

final _log = Logger('PreviousApp');

/// The previous app's light or dark choice and its server, until the shell
/// of a user account on that server saves it to that account.
const previousAppThemeKey = 'previous_app.theme';

/// What the import kept of the previous Vikunja app, which this app
/// replaced as an update on Android: never a secret.
@immutable
final class PreviousAppRecord {
  const new({
    this.server,
    this.recentServers = const [],
    this.placedWidgets = 0,
  });

  static const storageKey = 'previous_app.import';
  static const _version = 1;

  final Uri? server;

  /// Newest first, without [server], at most five.
  final List<Uri> recentServers;

  /// The previous app's widgets on the home screen.
  final int placedWidgets;

  /// Null when there is none or it cannot be read. Never throws.
  static Future<PreviousAppRecord?> read(PreferencesStore preferences) async {
    try {
      final stored = await preferences.getString(storageKey);
      return stored == null ? null : _decode(stored);
    } on Object catch (error) {
      _log.warning(
        'Could not read the previous app record: ${error.runtimeType}',
      );
      return null;
    }
  }

  Future<void> write(PreferencesStore preferences) => preferences.setString(
    storageKey,
    jsonEncode({
      'v': _version,
      'server': server?.toString(),
      'recentServers': [for (final uri in recentServers) '$uri'],
      'placedWidgets': placedWidgets,
    }),
  );

  static Future<void> remove(PreferencesStore preferences) =>
      preferences.remove(storageKey);

  static PreviousAppRecord? _decode(String stored) {
    final Object? json;
    try {
      json = jsonDecode(stored);
    } on FormatException {
      return null;
    }
    if (json
        case {
          'v': _version,
          'server': final String? server,
          'recentServers': final List<Object?> recent,
          'placedWidgets': final int placedWidgets,
        }
        when placedWidgets >= 0) {
      final serverUri = server == null ? null : _serverUri(server);
      if (server != null && serverUri == null) return null;
      final recentUris = <Uri>[];
      for (final entry in recent) {
        final uri = entry is String ? _serverUri(entry) : null;
        if (uri == null) return null;
        recentUris.add(uri);
      }
      return PreviousAppRecord(
        server: serverUri,
        recentServers: List.unmodifiable(recentUris),
        placedWidgets: placedWidgets,
      );
    }
    return null;
  }

  static Uri? _serverUri(String value) => switch (Uri.tryParse(value)) {
    final uri?
        when (uri.isScheme('https') || uri.isScheme('http')) &&
            uri.host.isNotEmpty =>
      uri,
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is PreviousAppRecord &&
      other.server == server &&
      listEquals(other.recentServers, recentServers) &&
      other.placedWidgets == placedWidgets;

  @override
  int get hashCode =>
      Object.hash(server, Object.hashAll(recentServers), placedWidgets);

  @override
  String toString() =>
      'PreviousAppRecord($server, recent: $recentServers, '
      'widgets: $placedWidgets)';
}
