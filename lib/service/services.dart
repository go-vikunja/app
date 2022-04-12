import 'dart:async';

import 'package:vikunja_app/models/list.dart';
import 'package:vikunja_app/models/namespace.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/user.dart';

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
  Future<TaskList> create(int namespaceId, TaskList tl);
  Future<TaskList> update(TaskList tl);
  Future delete(int listId);
  Future<String> getDisplayDoneTasks(int listId);
  void setDisplayDoneTasks(int listId, String value);
  Future<String> getDefaultList();
  void setDefaultList(int listId);
}

abstract class TaskService {
  Future<List<Task>> get(int taskId);
  Future<Task> update(Task task);
  Future delete(int taskId);
  Future<Task> add(int listId, Task task);
}

abstract class UserService {
  Future<UserTokenPair> login(String username, password);
  Future<UserTokenPair> register(String username, email, password);
  Future<User> getCurrentUser();
}
