import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/files/file_actions.dart';
import 'package:vikunja_mobile/core/files/platform_file_actions.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';

part 'file_actions_providers.g.dart';

@Riverpod(keepAlive: true)
FileActions fileActions(Ref ref) =>
    PlatformFileActions(excursions: ref.watch(appExcursionsProvider));
