import 'package:flutter/material.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/global.dart';

class ListProvider with ChangeNotifier {
  bool _isLoading = false;
  int _maxPages = 0;

  // TODO: Streams
  List<Task> _tasks = [];

  bool get isLoading => _isLoading;

  int get maxPages => _maxPages;

  set tasks(List<Task> tasks) {
    _tasks = tasks;
    notifyListeners();
  }

  List<Task> get tasks => _tasks;

  void loadTasks({BuildContext context, int listId, int page = 1}) {
    _tasks = [];
    _isLoading = true;
    notifyListeners();

    VikunjaGlobal.of(context).taskService.getAll(listId, {
      "sort_by": ["done", "id"],
      "order_by": ["asc", "desc"],
      "page": [page.toString()]
    }).then((response) {
      if (response.headers["x-pagination-total-pages"] != null) {
        _maxPages = int.parse(response.headers["x-pagination-total-pages"]);
      }
      _tasks.addAll(response.body);
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addTaskByTitle({BuildContext context, String title, int listId}) {
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
    _isLoading = true;
    notifyListeners();

    return globalState.taskService.add(listId, newTask).then((task) {
      _tasks.insert(0, task);
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> updateTask({BuildContext context, int id, bool done}) {
    var globalState = VikunjaGlobal.of(context);
    globalState.taskService.update(Task(
      id: id,
      done: done,
    )).then((task) {
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
}
