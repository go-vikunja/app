import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/bucket.dart';
import 'package:vikunja_app/global.dart';

class ListProvider with ChangeNotifier {
  bool _isLoading = false;
  bool _taskDragging = false;
  int _maxPages = 0;

  // TODO: Streams
  List<Task> _tasks = [];
  List<Bucket> _buckets = [];

  bool get isLoading => _isLoading;

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

  Future<void> loadTasks({BuildContext context, int listId, int page = 1, bool displayDoneTasks = true}) {
    _tasks = [];
    _isLoading = true;
    notifyListeners();

    Map<String, List<String>> queryParams = {
      "sort_by": ["done", "id"],
      "order_by": ["asc", "desc"],
      "page": [page.toString()]
    };

    if(!displayDoneTasks) {
      queryParams.addAll({
        "filter_by": ["done"],
        "filter_value": ["false"]
      });
    }
    return VikunjaGlobal.of(context).taskService.getAllByList(listId, queryParams).then((response) {
      if (response.headers["x-pagination-total-pages"] != null) {
        _maxPages = int.parse(response.headers["x-pagination-total-pages"]);
      }
      _tasks.addAll(response.body);

      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> loadBuckets({BuildContext context, int listId, int page = 1}) {
    _buckets = [];
    _isLoading = true;
    notifyListeners();

    Map<String, List<String>> queryParams = {
      "page": [page.toString()]
    };

    return VikunjaGlobal.of(context).bucketService.getAllByList(listId, queryParams).then((response) {
      if (response.headers["x-pagination-total-pages"] != null) {
        _maxPages = int.parse(response.headers["x-pagination-total-pages"]);
      }
      _buckets.addAll(response.body);

      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addTaskByTitle(
      {BuildContext context, String title, int listId}) {
    var globalState = VikunjaGlobal.of(context);
    var newTask = Task(
      id: null,
      title: title,
      createdBy: globalState.currentUser,
      done: false,
    );
    _isLoading = true;
    notifyListeners();

    return globalState.taskService.add(listId, newTask).then((task) {
      _tasks.insert(0, task);
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addTask({BuildContext context, Task newTask, int listId}) {
    var globalState = VikunjaGlobal.of(context);
    if (newTask.bucketId == null) _isLoading = true;
    notifyListeners();

    return globalState.taskService.add(listId, newTask).then((task) {
      if (newTask.bucketId == null) {
        _tasks.insert(0, task);
      } else {
        final bucket = _buckets[_buckets.indexWhere((b) => task.bucketId == b.id)];
        if (bucket.tasks != null) {
          bucket.tasks.add(task);
        } else {
          bucket.tasks = <Task>[task];
        }
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<Task> updateTask({BuildContext context, Task task}) {
    return VikunjaGlobal.of(context).taskService.update(task).then((task) {
      // FIXME: This is ugly. We should use a redux to not have to do these kind of things.
      //  This is enough for now (it works™) but we should definitly fix it later.
      _tasks.asMap().forEach((i, t) {
        if (task.id == t.id) {
          _tasks[i] = task;
        }
      });
      _buckets.asMap().forEach((i, b) => b.tasks.asMap().forEach((v, t) {
        if (task.id == t.id){
          _buckets[i].tasks[v] = task;
        }
      }));
      notifyListeners();
      return task;
    });
  }

  Future<void> addBucket({BuildContext context, Bucket newBucket, int listId}) {
    notifyListeners();
    return VikunjaGlobal.of(context).bucketService.add(listId, newBucket)
        .then((bucket) {
          _buckets.add(bucket);
          notifyListeners();
        });
  }

  Future<void> updateBucket({BuildContext context, Bucket bucket}) {
    return VikunjaGlobal.of(context).bucketService.update(bucket)
        .then((rBucket) {
          _buckets[_buckets.indexWhere((b) => rBucket.id == b.id)] = rBucket;
          _buckets.sort((a, b) => a.position.compareTo(b.position));
          notifyListeners();
        });
  }
  
  Future<void> deleteBucket({BuildContext context, int listId, int bucketId}) {
    return VikunjaGlobal.of(context).bucketService.delete(listId, bucketId)
        .then((_) {
          _buckets.removeWhere((bucket) => bucket.id == bucketId);
          notifyListeners();
        });
  }

  Future<void> moveTaskToBucket({BuildContext context, Task task, int newBucketId, int index}) async {
    final sameBucket = task.bucketId == newBucketId;
    final newBucketIndex = _buckets.indexWhere((b) => b.id == newBucketId);
    if (sameBucket && index > _buckets[newBucketIndex].tasks.indexWhere((t) => t.id == task.id)) index--;

    _buckets[_buckets.indexWhere((b) => b.id == task.bucketId)].tasks.remove(task);
    if (index >= _buckets[newBucketIndex].tasks.length)
      _buckets[newBucketIndex].tasks.add(task);
    else
      _buckets[newBucketIndex].tasks.insert(index, task);

    double kanbanPosition;
    if (_buckets[newBucketIndex].tasks.length == 1) // only task
      kanbanPosition = 0.0;
    else if (index == 0) // first task
      kanbanPosition = _buckets[newBucketIndex].tasks[1].kanbanPosition / 2.0;
    else if (index == _buckets[newBucketIndex].tasks.length - 1) // last task
      kanbanPosition = _buckets[newBucketIndex].tasks[index - 1].kanbanPosition + pow(2.0, 16.0);
    else // in the middle
      kanbanPosition = (_buckets[newBucketIndex].tasks[index - 1].kanbanPosition
          + _buckets[newBucketIndex].tasks[index + 1].kanbanPosition) / 2.0;

    task = await VikunjaGlobal.of(context).taskService.update(task.copyWith(
      bucketId: newBucketId ?? task.bucketId,
      kanbanPosition: kanbanPosition,
    ));
    _buckets[newBucketIndex].tasks[index] = task;

    // make sure first 2 tasks don't have 0 kanbanPosition
    Task secondTask;
    if (index == 0 && _buckets[newBucketIndex].tasks.length > 1
        && _buckets[newBucketIndex].tasks[1].kanbanPosition == 0) {
      if (_buckets[newBucketIndex].tasks.length == 2) // last task
        kanbanPosition = _buckets[newBucketIndex].tasks[0].kanbanPosition + pow(2.0, 16.0);
      else // in the middle
        kanbanPosition = (_buckets[newBucketIndex].tasks[0].kanbanPosition
            + _buckets[newBucketIndex].tasks[2].kanbanPosition) / 2.0;

      secondTask = await VikunjaGlobal.of(context).taskService.update(
          _buckets[newBucketIndex].tasks[1].copyWith(
            kanbanPosition: kanbanPosition,
          ));
      _buckets[newBucketIndex].tasks[1] = secondTask;
    }

    if (_tasks.isNotEmpty) {
      _tasks[_tasks.indexWhere((t) => t.id == task.id)] = task;
      if (secondTask != null) _tasks[_tasks.indexWhere((t) => t.id == secondTask.id)] = secondTask;
    }

    _buckets[newBucketIndex].tasks[_buckets[newBucketIndex].tasks.indexWhere((t) => t.id == task.id)] = task;
    _buckets[newBucketIndex].tasks.sort((a, b) => a.kanbanPosition.compareTo(b.kanbanPosition));

    notifyListeners();
  }
}
