import 'dart:async';

import 'package:vikunja_app/models/list.dart';
import 'package:vikunja_app/models/namespace.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/user.dart';
import 'package:vikunja_app/service/services.dart';

// Data for mocked services
var _users = {1: User(1, 'test@testuser.org', 'test1', '')};

var _namespaces = {
  1: Namespace(
    id: 1,
    name: 'Test 1',
    created: DateTime.now(),
    updated: DateTime.now(),
    description: 'A namespace for testing purposes',
    owner: _users[1],
  )
};

var _nsLists = {
  1: [1]
};

var _lists = {
  1: TaskList(
      id: 1,
      title: 'List 1',
      tasks: _tasks.values.toList(),
      owner: _users[1],
      description: 'A nice list',
      created: DateTime.now(),
      updated: DateTime.now())
};

var _tasks = {
  1: Task(
    id: 1,
    text: 'Task 1',
    owner: _users[1],
    updated: DateTime.now(),
    created: DateTime.now(),
    description: 'A descriptive task',
    done: false,
  )
};

// Mocked services

class MockedNamespaceService implements NamespaceService {
  @override
  Future<Namespace> create(Namespace ns) {
    _namespaces[ns.id] = ns;
    return Future.value(ns);
  }

  @override
  Future delete(int namespaceId) {
    _namespaces.remove(namespaceId);
    return Future.value();
  }

  @override
  Future<Namespace> get(int namespaceId) {
    return Future.value(_namespaces[namespaceId]);
  }

  @override
  Future<List<Namespace>> getAll() {
    return Future.value(_namespaces.values.toList());
  }

  @override
  Future<Namespace> update(Namespace ns) {
    if (!_namespaces.containsKey(ns.id))
      throw Exception('Namespace ${ns.id} does not exsists');
    return create(ns);
  }
}

class MockedListService implements ListService {
  @override
  Future<TaskList> create(namespaceId, TaskList tl) {
    _nsLists[namespaceId].add(tl.id);
    return Future.value(_lists[tl.id] = tl);
  }

  @override
  Future delete(int listId) {
    _lists.remove(listId);
    return Future.value();
  }

  @override
  Future<TaskList> get(int listId) {
    return Future.value(_lists[listId]);
  }

  @override
  Future<List<TaskList>> getAll() {
    return Future.value(_lists.values.toList());
  }

  @override
  Future<List<TaskList>> getByNamespace(int namespaceId) {
    return Future.value(
        _nsLists[namespaceId].map((listId) => _lists[listId]).toList());
  }

  @override
  Future<TaskList> update(TaskList tl) {
    if (!_lists.containsKey(tl))
      throw Exception('TaskList ${tl.id} does not exists');
    return Future.value(_lists[tl.id] = tl);
  }
}

class MockedTaskService implements TaskService {
  @override
  Future delete(int taskId) {
    _lists.forEach(
        (_, list) => list.tasks.removeWhere((task) => task.id == taskId));
    _tasks.remove(taskId);
    return Future.value();
  }

  @override
  Future<Task> update(Task task) {
    _lists.forEach((_, list) {
      if (list.tasks.where((t) => t.id == task.id).length > 0) {
        list.tasks.removeWhere((t) => t.id == task.id);
        list.tasks.add(task);
      }
    });
    return Future.value(_tasks[task.id] = task);
  }

  @override
  Future<Task> add(int listId, Task task) {
    var id = _tasks.keys.last + 1;
    _tasks[id] = task;
    _lists[listId].tasks.add(task);
    return Future.value(task);
  }
}

class MockedUserService implements UserService {
  @override
  Future<UserTokenPair> login(String username, password) {
    return Future.value(UserTokenPair(_users[1], 'abcdefg'));
  }

  @override
  Future<UserTokenPair> register(String username, email, password) {
    return Future.value(UserTokenPair(_users[1], 'abcdefg'));
  }

  @override
  Future<User> getCurrentUser() {
    return Future.value(_users[1]);
  }
}
