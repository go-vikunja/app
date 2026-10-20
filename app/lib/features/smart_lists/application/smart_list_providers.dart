import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';

part 'smart_list_providers.g.dart';

/// By title; stays loading while no account is signed in.
@riverpod
Stream<List<SavedFilterRef>> savedFilters(Ref ref) =>
    ref.watch(projectRepositoryProvider)?.watchSavedFilters() ??
    const Stream.empty();

/// The Favorites list; stays loading while no account is signed in.
@riverpod
Stream<List<Task>> favoriteTasks(Ref ref) =>
    ref.watch(taskRepositoryProvider)?.watchFavoriteTasks() ??
    const Stream.empty();

/// Stays loading while no account is signed in.
@riverpod
Stream<SavedFilterTasks> savedFilterTasks(Ref ref, int pseudoProjectId) =>
    ref.watch(taskRepositoryProvider)?.watchSavedFilterTasks(pseudoProjectId) ??
    const Stream.empty();

/// A label's open tasks; stays loading while no account is signed in.
@riverpod
Stream<List<Task>> labelTasks(Ref ref, int labelId) =>
    ref.watch(taskRepositoryProvider)?.watchLabelTasks(labelId) ??
    const Stream.empty();
