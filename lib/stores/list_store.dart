import 'package:flutter/material.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/bucket.dart';
import 'package:vikunja_app/global.dart';

class ListProvider with ChangeNotifier {
  bool _isLoading = false;
  int _maxPages = 0;

  // TODO: Streams
  List<Task> _tasks = [];
  List<Bucket> _buckets = [];

  bool get isLoading => _isLoading;

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

  void loadTasks({BuildContext context, int listId, int page = 1, bool displayDoneTasks = true}) {
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
    VikunjaGlobal.of(context).taskService.getAllByList(listId, queryParams).then((response) {
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

  void updateTask({BuildContext context, int id, bool done}) {
    var globalState = VikunjaGlobal.of(context);
    globalState.taskService
        .update(Task(
      id: id,
      done: done,
    ))
        .then((task) {
      // FIXME: This is ugly. We should use a redux to not have to do these kind of things.
      //  This is enough for now (it works™) but we should definitly fix it later.
      _tasks.asMap().forEach((i, t) {
        if (task.id == t.id) {
          _tasks[i] = task;
        }
      });
      notifyListeners();
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
}
