import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';

part 'widget_launch_controller.g.dart';

@riverpod
WidgetLaunchController widgetLaunchController(Ref ref) =>
    WidgetLaunchController(ref.read(taskRepositoryProvider));

/// Resolves taps on home-screen widget task rows into hydrated tasks the app
/// can navigate to.
class WidgetLaunchController {
  final TaskRepository _taskRepository;

  WidgetLaunchController(this._taskRepository);

  /// Fetches the task identified by [taskId] coming from a widget row tap.
  /// Returns null when [taskId] is not a valid id or the fetch fails.
  Future<Task?> openTask(String? taskId) async {
    final id = int.tryParse(taskId ?? '');
    if (id == null || id <= 0) return null;

    final response = await _taskRepository.getTask(id);
    if (response.isSuccessful) {
      return response.toSuccess().body;
    }

    return null;
  }
}
