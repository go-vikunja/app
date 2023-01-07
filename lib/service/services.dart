import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vikunja_app/api/response.dart';
import 'package:vikunja_app/models/label.dart';
import 'package:vikunja_app/models/labelTask.dart';
import 'package:vikunja_app/models/list.dart';
import 'package:vikunja_app/models/namespace.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/user.dart';
import 'package:vikunja_app/models/bucket.dart';

import '../models/server.dart';

enum TaskServiceOptionSortBy {
  id,
  title,
  description,
  done,
  done_at,
  due_date,
  created_by_id,
  list_id,
  repeat_after,
  priority,
  start_date,
  end_date,
  hex_color,
  percent_done,
  uid,
  created,
  updated
}

enum TaskServiceOptionOrderBy { asc, desc }

enum TaskServiceOptionFilterBy { done, due_date, reminder_dates }

enum TaskServiceOptionFilterValue { enum_true, enum_false, enum_null }

enum TaskServiceOptionFilterComparator {
  equals,
  greater,
  greater_equals,
  less,
  less_equals,
  like,
  enum_in
}

enum TaskServiceOptionFilterConcat { and, or }

class TaskServiceOption<T> {
  String name;
  dynamic value;
  dynamic defValue;

  TaskServiceOption(this.name, this.value);

  String handleValue(dynamic input) {
    if (input is String) return input;
    return input.toString().split('.').last.replaceAll('enum_', '');
  }

  dynamic getValue() {
    if (value is List)
      return value.map((elem) => handleValue(elem)).toList();
    else
      return handleValue(value);
  }
}

class TaskServiceOptions {
  List<TaskServiceOption>? options;

  TaskServiceOptions({this.options}) {
    if (this.options == null)
      options = [
        TaskServiceOption<TaskServiceOptionSortBy>("sort_by",
            [TaskServiceOptionSortBy.due_date, TaskServiceOptionSortBy.id]),
        TaskServiceOption<TaskServiceOptionOrderBy>(
            "order_by", TaskServiceOptionOrderBy.asc),
        TaskServiceOption<TaskServiceOptionFilterBy>("filter_by", [
          TaskServiceOptionFilterBy.done,
          TaskServiceOptionFilterBy.due_date
        ]),
        TaskServiceOption<TaskServiceOptionFilterValue>("filter_value", [
          TaskServiceOptionFilterValue.enum_false,
          '0001-01-02T00:00:00.000Z'
        ]),
        TaskServiceOption<TaskServiceOptionFilterComparator>(
            "filter_comparator", [
          TaskServiceOptionFilterComparator.equals,
          TaskServiceOptionFilterComparator.greater
        ]),
        TaskServiceOption<TaskServiceOptionFilterConcat>(
            "filter_concat", TaskServiceOptionFilterConcat.and),
      ];
  }

  void setOption(TaskServiceOption option, dynamic value) {
    options?.firstWhere((element) => element.name == option.name).value = value;
  }

  String getOptions() {
    String result = '';
    if (options == null) return '';
    for (TaskServiceOption option in options!) {
      dynamic value = option.getValue();
      if (value is List) {
        for (dynamic valueEntry in value) {
          result += '&' + option.name + '[]=' + valueEntry;
        }
      } else {
        result += '&' + option.name + '=' + value;
      }
    }

    if (result.startsWith('&')) result.substring(1);
    return result;
  }
}

abstract class NamespaceService {
  Future<List<Namespace>?> getAll();

  Future<Namespace?> get(int namespaceId);

  Future<Namespace?> create(Namespace ns);

  Future<Namespace?> update(Namespace ns);

  Future delete(int namespaceId);
}

abstract class ListService {
  Future<List<TaskList>?> getAll();

  Future<TaskList?> get(int listId);

  Future<List<TaskList>?> getByNamespace(int namespaceId);

  Future<TaskList?> create(int namespaceId, TaskList tl);

  Future<TaskList?> update(TaskList tl);

  Future delete(int listId);

  Future<String?> getDisplayDoneTasks(int listId);

  void setDisplayDoneTasks(int listId, String value);

  Future<String?> getDefaultList();

  void setDefaultList(int? listId);
}

abstract class TaskService {
  Future<Task?> get(int taskId);

  Future<Task?> update(Task task);

  Future delete(int taskId);

  Future<Task?> add(int listId, Task task);

  Future<List<Task>?> getAll();

  Future<Response?> getAllByList(int listId,
      [Map<String, List<String>> queryParameters]);

  Future<List<Task>?> getByOptions(TaskServiceOptions options);

  int get maxPages;
}

abstract class BucketService {
  // Not implemented in the Vikunja API
  // Future<Bucket> get(int listId, int bucketId);
  Future<Bucket?> update(Bucket bucket);

  Future delete(int listId, int bucketId);

  Future<Bucket?> add(int listId, Bucket bucket);

  Future<Response?> getAllByList(int listId,
      [Map<String, List<String>> queryParameters]);

  int get maxPages;
}

abstract class UserService {
  Future<UserTokenPair?> login(String username, String password,
      {bool rememberMe = false, String totp});

  Future<UserTokenPair?> register(String username, email, password);

  Future<User?> getCurrentUser();
}

abstract class LabelService {
  Future<List<Label>?> getAll({String query});

  Future<Label?> get(int labelID);

  Future<Label?> create(Label label);

  Future<Label?> delete(Label label);

  Future<Label?> update(Label label);
}

abstract class LabelTaskService {
  Future<List<Label>?> getAll(LabelTask lt, {String query});

  Future<Label?> create(LabelTask lt);

  Future<Label?> delete(LabelTask lt);
}

abstract class LabelTaskBulkService {
  Future<List<Label>?> update(Task task, List<Label> labels);
}

abstract class ServerService {
  Future<Server?> getInfo();
}

class SettingsManager {
  final FlutterSecureStorage _storage;

  Map<String, String> defaults = {
    "ignore-certificates": "0",
    "get-version-notifications": "1",
    "workmanager-duration": "0"
  };

  SettingsManager(this._storage) {
    defaults.forEach((key, value) {
      _storage.containsKey(key: key).then((is_created) {
        if (!is_created) _storage.write(key: key, value: value);
      });
    });
  }

  Future<String?> getIgnoreCertificates() {
    return _storage.read(key: "ignore-certificates");
  }
  void setIgnoreCertificates(bool value) {
    _storage.write(key: "ignore-certificates", value: value ? "1" : "0");
  }


  Future<String?> getVersionNotifications() {
    return _storage.read(key: "get-version-notifications");
  }
  void setVersionNotifications(bool value) {
    _storage.write(key: "get-version-notifications", value: value ? "1" : "0");
  }


  Future<Duration> getWorkmanagerDuration() {
    return _storage.read(key: "workmanager-duration").then((value) => Duration(minutes: int.parse(value ?? "0")));
  }
  void setWorkmanagerDuration(Duration duration) {
    _storage.write(key: "workmanager-duration", value: duration.inMinutes.toString());
  }



}
