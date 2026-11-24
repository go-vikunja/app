import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/files/file_actions.dart';
import 'package:vikunja_mobile/core/files/platform_file_actions.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';

part 'file_actions_providers.g.dart';

@Riverpod(keepAlive: true)
FileActions fileActions(Ref ref) =>
    PlatformFileActions(excursions: ref.watch(appExcursionsProvider));

/// On Android share_plus shares a copy of each file from `<cache>/share_plus`
/// and empties that folder only when the next share starts; a sign-out
/// deletes it (`accountDataWiper`). Never when a share returns: the app it
/// went to may still be reading it (decision log: Security and privacy).
/// iOS shares the file itself.
@Riverpod(keepAlive: true)
Future<Directory> Function() shareCopiesFolder(Ref ref) =>
    () async => Directory(
      p.join((await getApplicationCacheDirectory()).path, 'share_plus'),
    );
