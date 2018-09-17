import 'dart:async';

import 'package:fluttering_vikunja/models/namespace.dart';
import 'package:fluttering_vikunja/models/task.dart';
import 'package:fluttering_vikunja/models/user.dart';

abstract class NamespaceService {
  Future<List<Namespace>> getAll();
  Future<Namespace> get(int namespaceId);
  Future<Namespace> create(Namespace ns);
  Future<Namespace> update(Namespace ns);
  Future delete(int namespaceId);
}

abstract class ListService {
  Future<List<TaskList>> getAll();
  Future<TaskList> get(int listId);
  Future<List<TaskList>> getByNamespace(int namespaceId);
  Future<TaskList> create(TaskList tl);
  Future<TaskList> update(TaskList tl);
  Future delete(int listId);
}

abstract class TaskService {
  Future<Task> update(Task task);
  Future delete(int taskId);
}

abstract class UserService {
  Future<UserTokenPair> login(String username, password);
  Future<User> getCurrentUser();
}
