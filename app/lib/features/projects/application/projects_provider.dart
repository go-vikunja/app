import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/paged_list.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'projects_provider.g.dart';

/// Stays loading while no account is signed in.
@riverpod
Stream<List<Project>> projects(Ref ref) =>
    ref.watch(projectRepositoryProvider)?.watchAll() ?? const Stream.empty();

@riverpod
Project? projectById(Ref ref, int id) => ref.watch(
  projectsProvider.select((projects) {
    for (final project in projects.value ?? const <Project>[]) {
      if (project.id == id) return project;
    }
    return null;
  }),
);

@riverpod
Stream<PagedList<Task>> projectTasks(
  Ref ref,
  int projectId, {
  required bool showDone,
}) =>
    ref
        .watch(taskRepositoryProvider)
        ?.watchProjectTasks(projectId, showDone: showDone) ??
    const Stream.empty();
