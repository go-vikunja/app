import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences_providers.dart';

part 'new_task_keep_open_provider.g.dart';

/// Whether the new-task sheet stays open after adding; off while nobody is
/// signed in.
@riverpod
Stream<bool> newTaskKeepOpen(Ref ref) =>
    ref.watch(listPreferencesProvider)?.watchNewTaskKeepOpen() ??
    Stream.value(false);
