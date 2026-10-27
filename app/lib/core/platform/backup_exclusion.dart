import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rurana_widgets/rurana_widgets.dart';
import 'package:vikunja_mobile/core/db/account_database_files.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';

final _log = Logger('BackupExclusion');

/// Keeps folders out of iCloud and computer backups on iOS, creating them
/// when missing. Android needs nothing at run time: its data extraction
/// rules leave everything out.
abstract interface class BackupExclusion {
  Future<void> exclude(List<String> paths);
}

final class PlatformBackupExclusion implements BackupExclusion {
  new({this._channel = deviceChannel, bool? ios})
    : _ios = ios ?? Platform.isIOS;

  final MethodChannel _channel;
  final bool _ios;

  @override
  Future<void> exclude(List<String> paths) async {
    if (!_ios || paths.isEmpty) return;
    await _channel.invokeMethod<void>('excludeFromBackup', {'paths': paths});
  }
}

/// The accounts' databases and queued uploads, and the widgets' files in
/// the App Group (snapshots, catalogs, Done taps), stay out of backups
/// (D66). A restore or a move to another device clears the flag, so every
/// UI start sets it again. Best effort: a failure is logged by its type.
Future<void> excludeAppDataFromBackup({
  BackupExclusion? exclusion,
  Future<Directory> Function()? supportDirectory,
  Future<Directory?> Function()? widgetsDirectory,
}) async {
  try {
    final support =
        await (supportDirectory ?? getApplicationSupportDirectory)();
    final widgets =
        await (widgetsDirectory ?? RuranaWidgets().widgetsDirectory)();
    await (exclusion ?? PlatformBackupExclusion()).exclude([
      p.join(support.path, PathProviderAccountDatabaseFiles.accountsFolder),
      ?widgets?.path,
    ]);
  } on Object catch (error) {
    _log.warning(
      'Could not keep the app data out of backups: ${error.runtimeType}',
    );
  }
}
