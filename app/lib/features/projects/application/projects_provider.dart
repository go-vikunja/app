import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';

part 'projects_provider.g.dart';

/// Stays loading while no account is signed in.
@riverpod
Stream<List<Project>> projects(Ref ref) =>
    ref.watch(projectRepositoryProvider)?.watchAll() ?? const Stream.empty();

/// Leaves out a change of the project's views alone (`Project ==` ignores
/// them); read the views from [projectsProvider].
@riverpod
Project? projectById(Ref ref, int id) => ref.watch(
  projectsProvider.select((projects) {
    for (final project in projects.value ?? const <Project>[]) {
      if (project.id == id) return project;
    }
    return null;
  }),
);

/// Stays loading while no account is signed in. [includeDone] as in
/// `TaskRepository.watchProjectList`.
@riverpod
Stream<ProjectListSource> projectListSource(
  Ref ref,
  int projectId, {
  required int viewId,
  required bool includeDone,
}) =>
    ref
        .watch(taskRepositoryProvider)
        ?.watchProjectList(
          projectId,
          viewId: viewId,
          includeDone: includeDone,
        ) ??
    const Stream.empty();

/// Stays loading while no account is signed in.
@riverpod
Stream<BoardSource> boardSource(Ref ref, int projectId, int viewId) =>
    ref.watch(taskRepositoryProvider)?.watchBoard(projectId, viewId) ??
    const Stream.empty();

/// Stays loading while no account is signed in.
@riverpod
Stream<ProjectProgress> projectProgress(Ref ref, int projectId) =>
    ref.watch(taskRepositoryProvider)?.watchProjectProgress(projectId) ??
    const Stream.empty();

/// Stays loading while no account is signed in.
@riverpod
Stream<Map<int, int>> openTaskCounts(Ref ref) =>
    ref.watch(taskRepositoryProvider)?.watchOpenTaskCounts() ??
    const Stream.empty();

/// [listKey] from `listKeyFor`; the defaults while nobody is signed in.
@riverpod
Stream<ViewPreferences> viewPreferences(Ref ref, String listKey) =>
    ref.watch(listPreferencesProvider)?.watchView(listKey) ??
    Stream.value(const ViewPreferences());

/// What the Projects tab shows of the tree; the defaults while nobody is
/// signed in.
@riverpod
Stream<ProjectTreePreferences> projectTreePreferences(Ref ref) =>
    ref.watch(listPreferencesProvider)?.watchProjectTree() ??
    Stream.value(const ProjectTreePreferences());
