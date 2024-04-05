import 'package:flutter/material.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/bucket.dart';
import 'package:vikunja_app/utils/calculate_item_position.dart';
import 'package:vikunja_app/global.dart';

import '../components/pagestatus.dart';

class ProjectProvider with ChangeNotifier {
  bool _taskDragging = false;
  int _maxPages = 0;

  // TODO: Streams
  List<Task> _tasks = [];
  List<Bucket> _buckets = [];

  bool get taskDragging => _taskDragging;

  set taskDragging(bool value) {
    _taskDragging = value;
    notifyListeners();
  }

  int get maxPages => _maxPages;

  set tasks(List<Task> tasks) {
    _tasks = tasks;
    notifyListeners();
  }

  List<Task> get tasks => _tasks;

  set buckets(List<Bucket> buckets) {
    _buckets = buckets;
    notifyListeners();
  }

  List<Bucket> get buckets => _buckets;

  PageStatus _pageStatus = PageStatus.built;

  PageStatus get pageStatus => _pageStatus;

  set pageStatus(PageStatus ps) {
    _pageStatus = ps;
    print("new PageStatus: ${ps.toString()}");
    notifyListeners();
  }

  Future<void> loadTasks(
      {required BuildContext context,
      required int listId,
      int page = 1,
      bool displayDoneTasks = true}) {
    _tasks = [];
    notifyListeners();

    Map<String, List<String>> queryParams = {
      "sort_by": ["done", "id"],
      "order_by": ["asc", "desc"],
      "page": [page.toString()]
    };

    if (!displayDoneTasks) {
      queryParams.addAll({
        "filter_by": ["done"],
        "filter_value": ["false"],
        "sort_by": ["done"],
      });
    }
    return VikunjaGlobal.of(context)
        .taskService
        .getAllByProject(listId, queryParams)
        .then((response) {
      if (response == null) {
        pageStatus = PageStatus.error;
        return;
      }
      if (response.headers["x-pagination-total-pages"] != null) {
        _maxPages = int.parse(response.headers["x-pagination-total-pages"]!);
      }
      _tasks.addAll(response.body);
      pageStatus = PageStatus.success;
    });
  }

  Future<void> loadBuckets(
      {required BuildContext context, required int listId, int page = 1}) {
    _buckets = [];
    pageStatus = PageStatus.loading;
    notifyListeners();

    Map<String, List<String>> queryParams = {
      "page": [page.toString()]
    };

    return VikunjaGlobal.of(context)
        .bucketService
        .getAllByList(listId, queryParams)
        .then((response) {
      if (response == null) {
        pageStatus = PageStatus.error;
        return;
      }
      if (response.headers["x-pagination-total-pages"] != null) {
        _maxPages = int.parse(response.headers["x-pagination-total-pages"]!);
      }
      _buckets.addAll(response.body);

      pageStatus = PageStatus.success;
    });
  }

  Future<void> addTaskByTitle(
      {required BuildContext context,
      required String title,
      required int projectId}) async {
    final globalState = VikunjaGlobal.of(context);
    if (globalState.currentUser == null) {
      return;
    }

    final newTask = Task(
      title: title,
      createdBy: globalState.currentUser!,
      done: false,
      projectId: projectId,
    );
    pageStatus = PageStatus.loading;

    return globalState.taskService.add(projectId, newTask).then((task) {
      if (task != null) _tasks.insert(0, task);
      pageStatus = PageStatus.success;
    });
  }

  Future<void> addTask(
      {required BuildContext context,
      required Task newTask,
      required int listId}) {
    var globalState = VikunjaGlobal.of(context);
    if (newTask.bucketId == null) pageStatus = PageStatus.loading;
    notifyListeners();

    return globalState.taskService.add(listId, newTask).then((task) {
      if (task == null) {
        pageStatus = PageStatus.error;
        return;
      }
      if (_tasks.isNotEmpty) _tasks.insert(0, task);
      if (_buckets.isNotEmpty) {
        final bucket =
            _buckets[_buckets.indexWhere((b) => task.bucketId == b.id)];
        bucket.tasks.add(task);
      }
      pageStatus = PageStatus.success;
    });
  }

  Future<Task?> updateTask(
      {required BuildContext context, required Task task}) {
    return VikunjaGlobal.of(context).taskService.update(task).then((task) {
      // FIXME: This is ugly. We should use a redux to not have to do these kind of things.
      //  This is enough for now (it works™) but we should definitely fix it later.
      if (task == null) return null;
      _tasks.asMap().forEach((i, t) {
        if (task.id == t.id) {
          _tasks[i] = task;
        }
      });
      _buckets.asMap().forEach((i, b) => b.tasks.asMap().forEach((v, t) {
            if (task.id == t.id) {
              _buckets[i].tasks[v] = task;
            }
          }));
      notifyListeners();
      return task;
    });
  }

  Future<void> addBucket(
      {required BuildContext context,
      required Bucket newBucket,
      required int listId}) {
    notifyListeners();
    return VikunjaGlobal.of(context)
        .bucketService
        .add(listId, newBucket)
        .then((bucket) {
      if (bucket == null) return null;
      _buckets.add(bucket);
      notifyListeners();
    });
  }

  Future<void> updateBucket(
      {required BuildContext context, required Bucket bucket}) {
    return VikunjaGlobal.of(context)
        .bucketService
        .update(bucket)
        .then((rBucket) {
      if (rBucket == null) return null;
      _buckets[_buckets.indexWhere((b) => rBucket.id == b.id)] = rBucket;
      _buckets.sort((a, b) => a.position!.compareTo(b.position!));
      notifyListeners();
    });
  }

  Future<void> deleteBucket(
      {required BuildContext context,
      required int listId,
      required int bucketId}) {
    return VikunjaGlobal.of(context)
        .bucketService
        .delete(listId, bucketId)
        .then((_) {
      _buckets.removeWhere((bucket) => bucket.id == bucketId);
      notifyListeners();
    });
  }

  Future<void> moveTaskToBucket(
      {required BuildContext context,
      required Task? task,
      int? newBucketId,
      required int index}) async {
    if (task == null) throw Exception("Task to be moved may not be null");
    final sameBucket = task.bucketId == newBucketId;
    final newBucketIndex = _buckets.indexWhere((b) => b.id == newBucketId);
    if (sameBucket &&
        index >
            _buckets[newBucketIndex].tasks.indexWhere((t) => t.id == task?.id))
      index--;

    _buckets[_buckets.indexWhere((b) => b.id == task?.bucketId)]
        .tasks
        .remove(task);
    if (index >= _buckets[newBucketIndex].tasks.length)
      _buckets[newBucketIndex].tasks.add(task);
    else
      _buckets[newBucketIndex].tasks.insert(index, task);

    task = await VikunjaGlobal.of(context).taskService.update(task.copyWith(
          bucketId: newBucketId,
          kanbanPosition: calculateItemPosition(
            positionBefore: index != 0
                ? _buckets[newBucketIndex].tasks[index - 1].kanbanPosition
                : null,
            positionAfter: index < _buckets[newBucketIndex].tasks.length - 1
                ? _buckets[newBucketIndex].tasks[index + 1].kanbanPosition
                : null,
          ),
        ));
    if (task == null) return;
    _buckets[newBucketIndex].tasks[index] = task;

    // make sure the first 2 tasks don't have 0 kanbanPosition
    Task? secondTask;
    if (index == 0 &&
        _buckets[newBucketIndex].tasks.length > 1 &&
        _buckets[newBucketIndex].tasks[1].kanbanPosition == 0) {
      secondTask = await VikunjaGlobal.of(context)
          .taskService
          .update(_buckets[newBucketIndex].tasks[1].copyWith(
                kanbanPosition: calculateItemPosition(
                  positionBefore: task.kanbanPosition,
                  positionAfter: 1 < _buckets[newBucketIndex].tasks.length - 1
                      ? _buckets[newBucketIndex].tasks[2].kanbanPosition
                      : null,
                ),
              ));
      if (secondTask != null) _buckets[newBucketIndex].tasks[1] = secondTask;
    }

    if (_tasks.isNotEmpty) {
      _tasks[_tasks.indexWhere((t) => t.id == task?.id)] = task;
      if (secondTask != null)
        _tasks[_tasks.indexWhere((t) => t.id == secondTask!.id)] = secondTask;
    }

    _buckets[newBucketIndex].tasks[_buckets[newBucketIndex]
        .tasks
        .indexWhere((t) => t.id == task?.id)] = task;
    _buckets[newBucketIndex]
        .tasks
        .sort((a, b) => a.kanbanPosition!.compareTo(b.kanbanPosition!));

    notifyListeners();
  }
}
