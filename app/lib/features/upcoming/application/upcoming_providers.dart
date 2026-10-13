import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'upcoming_providers.g.dart';

/// Stays loading while no account is signed in.
@riverpod
Stream<List<Task>> activeOpenTasks(Ref ref) =>
    ref.watch(taskRepositoryProvider)?.watchActiveOpenTasks() ??
    const Stream.empty();

@riverpod
Stream<UpcomingPreferences> upcomingPreferences(Ref ref) =>
    ref.watch(listPreferencesProvider)?.watchUpcoming() ??
    Stream.value(const UpcomingPreferences());
