import 'dart:async';

import 'package:vikunja_app/api/response.dart';
import 'package:vikunja_app/models/label.dart';
import 'package:vikunja_app/models/labelTask.dart';
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
}

abstract class TaskService {
  Future<Task> update(Task task);
  Future delete(int taskId);
  Future<Task> add(int listId, Task task);
  Future<Response> getAll(int listId,
      [Map<String, List<String>> queryParameters]);
  // TODO: Avoid having to add this to each abstract class
  int get maxPages;
}

abstract class UserService {
  Future<UserTokenPair> login(String username, password);
  Future<UserTokenPair> register(String username, email, password);
  Future<User> getCurrentUser();
}

abstract class LabelService {
  Future<List<Label>> getAll({String query});
  Future<Label> get(int labelID);
  Future<Label> create(Label label);
  Future<Label> delete(Label label);
  Future<Label> update(Label label);
}

abstract class LabelTaskService {
  Future<List<Label>> getAll(LabelTask lt, {String query});
  Future<Label> create(LabelTask lt);
  Future<Label> delete(LabelTask lt);
}

abstract class LabelTaskBulkService {
  Future<List<Label>> update(Task task, List<Label> labels);
}
