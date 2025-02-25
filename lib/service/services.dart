import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vikunja_app/api/response.dart';
import 'package:vikunja_app/models/label.dart';
import 'package:vikunja_app/models/labelTask.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/user.dart';
import 'package:vikunja_app/models/bucket.dart';

import '../models/project.dart';
import '../models/server.dart';
import '../models/view.dart';

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

enum TaskServiceOptionFilterBy { done, due_date, reminders }

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
  String? value;
  List<String>? valueList;
  dynamic defValue;

  TaskServiceOption(this.name, dynamic input_values) {
    if (input_values is List<String>) {
      valueList = input_values;
    } else if (input_values is String) {
      value = input_values;
    }
  }

  String handleValue(dynamic input) {
    if (input is String) return input;
    return input.toString().split('.').last.replaceAll('enum_', '');
  }

  dynamic getValue() {
    if (valueList != null)
      return valueList!.map((elem) => handleValue(elem)).toList();
    else
      return handleValue(value);
  }
}

final List<TaskServiceOption> defaultOptions = [
  TaskServiceOption<TaskServiceOptionSortBy>("sort_by",
      [TaskServiceOptionSortBy.due_date, TaskServiceOptionSortBy.id]),
  TaskServiceOption<TaskServiceOptionOrderBy>(
      "order_by", TaskServiceOptionOrderBy.asc),
  TaskServiceOption<TaskServiceOptionFilterBy>("filter_by",
      [TaskServiceOptionFilterBy.done, TaskServiceOptionFilterBy.due_date]),
  TaskServiceOption<TaskServiceOptionFilterValue>("filter_value",
      [TaskServiceOptionFilterValue.enum_false, '1970-01-01T00:00:00.000Z']),
  TaskServiceOption<TaskServiceOptionFilterComparator>("filter_comparator", [
    TaskServiceOptionFilterComparator.equals,
    TaskServiceOptionFilterComparator.greater
  ]),
  TaskServiceOption<TaskServiceOptionFilterConcat>(
      "filter_concat", TaskServiceOptionFilterConcat.and),
];

class TaskServiceOptions {
  List<TaskServiceOption> options = [];

  TaskServiceOptions(
      {List<TaskServiceOption>? newOptions, bool clearOther = false}) {
    if (!clearOther) options = new List<TaskServiceOption>.from(defaultOptions);
    if (newOptions != null) {
      for (TaskServiceOption custom_option in newOptions) {
        int index =
            options.indexWhere((element) => element.name == custom_option.name);
        if (index > -1) {
          options.removeAt(index);
        } else {
          index = options.length;
        }
        options.insert(index, custom_option);
      }
    }
  }

  Map<String, List<String>> getOptions() {
    Map<String, List<String>> queryparams = {};
    for (TaskServiceOption option in options) {
      dynamic value = option.getValue();
      if (value is List) {
        queryparams[option.name + "[]"] = value as List<String>;
        //for (dynamic valueEntry in value) {
        //  result += '&' + option.name + '[]=' + valueEntry;
        //}
      } else {
        queryparams[option.name] = [value as String];
        //result += '&' + option.name + '[]=' + value;
      }
    }

    //if (result.startsWith('&')) result = result.substring(1);
    //result = "?" + result;
    return queryparams;
  }
}

abstract class ProjectService {
  Future<List<Project>?> getAll();

  Future<Project?> get(int projectId);
  Future<Project?> create(Project p);
  Future<Project?> update(Project p);
  Future delete(int projectId);

  Future<String?> getDisplayDoneTasks(int listId);
  void setDisplayDoneTasks(int listId, String value);
  //Future<String?> getDefaultList();
  //void setDefaultList(int? listId);
}

abstract class ProjectViewService {
  Future<ProjectView?> get(int projectId, int viewId);
  Future<ProjectView?> create(ProjectView view);
  Future<ProjectView?> update(ProjectView view);
  Future delete(int projectId, int viewId);
}

abstract class TaskService {
  Future<Task?> get(int taskId);

  Future<Task?> update(Task task);

  Future delete(int taskId);

  Future<Task?> add(int listId, Task task);

  Future<List<Task>?> getAll();

  Future<Response?> getAllByProject(int projectId,
      [Map<String, List<String>> queryParameters]);

  @deprecated
  Future<List<Task>?> getByOptions(TaskServiceOptions options);
  Future<List<Task>?> getByFilterString(String filterString,
      [Map<String, List<String>> queryParameters]);

  int get maxPages;
}

abstract class BucketService {
  // Not implemented in the Vikunja API
  // Future<Bucket> get(int listId, int bucketId);
  Future<Bucket?> update(Bucket bucket, int projectId, int viewId);

  Future delete(int listId, int viewId, int bucketId);

  Future<Bucket?> add(int listId, int viewId, Bucket bucket);

  Future<Response?> getAllByList(int listId, int viewId,
      [Map<String, List<String>> queryParameters]);

  int get maxPages;
}

abstract class UserService {
  Future<UserTokenPair> login(String username, String password,
      {bool rememberMe = false, String totp});

  Future<UserTokenPair?> register(String username, email, password);

  Future<User?> getCurrentUser();
  Future<UserSettings?> setCurrentUserSettings(UserSettings userSettings);

  Future<String?> getToken();
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
    "workmanager-duration": "0",
    "recent-servers": "[\"https://try.vikunja.io\"]",
    "theme_mode": "system",
    "landing-page-due-date-tasks": "1",
    "landing-page-today-tasks": "1",
    "sentry-enabled": "0",
    "sentry-modal-shown": "0",
    "expanded-projects": "[]",
  };

  void applydefaults() {
    defaults.forEach((key, value) {
      _storage.containsKey(key: key).then((isCreated) async {
        if (!isCreated) {
          await _storage.write(key: key, value: value);
        }
      });
    });
  }

  SettingsManager(this._storage) {
    applydefaults();
  }

  Future<String?> getIgnoreCertificates() {
    return _storage.read(key: "ignore-certificates");
  }

  void setIgnoreCertificates(bool value) {
    _storage.write(key: "ignore-certificates", value: value ? "1" : "0");
  }

  Future<bool> getSentryEnabled() {
    return _storage.read(key: "sentry-enabled").then((value) => value == "1");
  }

  Future<void> setSentryEnabled(bool value) {
    return _storage.write(key: "sentry-enabled", value: value ? "1" : "0");
  }

  Future<bool> getSentryModalShown() {
    return _storage
        .read(key: "sentry-modal-shown")
        .then((value) => value == "1");
  }

  Future<void> setSentryModalShown(bool value) {
    return _storage.write(key: "sentry-modal-shown", value: value ? "1" : "0");
  }

  Future<bool> getLandingPageOnlyDueDateTasks() {
    return _storage
        .read(key: "landing-page-due-date-tasks")
        .then((value) => value == "1");
  }

  Future<Map<String, bool>> getLandingPageTasks() {
    // Map<String, bool> filters = {};
    // await filters['landing-page-due-date-tasks'] = _storage.read(key: "landing-page-due-date-tasks");
    // await filters['landing-page-today-tasks'] = _storage.read(key: "landing-page-today-tasks");
    return _storage.read(key: "landing-page-due-date-tasks").then((dueDate) {
      return _storage.read(key: "landing-page-today-tasks").then((today) {
        return {
          'landing-page-due-date-tasks': dueDate == "1",
          'landing-page-today-tasks': today == "1",
        };
      });
    });
  }

  Future<void> setLandingPageOnlyDueDateTasks(bool value) {
    return _storage.write(
        key: "landing-page-due-date-tasks", value: value ? "1" : "0");
  }

  Future<void> setLandingPageTodayTasks(bool value) {
    return _storage.write(
        key: "landing-page-today-tasks", value: value ? "1" : "0");
  }

  Future<String?> getVersionNotifications() {
    return _storage.read(key: "get-version-notifications");
  }

  void setVersionNotifications(bool value) {
    _storage.write(key: "get-version-notifications", value: value ? "1" : "0");
  }

  Future<Duration> getWorkmanagerDuration() {
    return _storage
        .read(key: "workmanager-duration")
        .then((value) => Duration(minutes: int.parse(value ?? "0")));
  }

  Future<void> setWorkmanagerDuration(Duration duration) {
    return _storage.write(
        key: "workmanager-duration", value: duration.inMinutes.toString());
  }

  Future<List<String>?> getPastServers() async {
    String jsonString = await _storage.read(key: "recent-servers") ?? "[]";
    List<dynamic> server = jsonDecode(jsonString);
    return server.map((e) => e as String).toList();
  }

  Future<void> setPastServers(List<String>? server) {
    return _storage.write(key: "recent-servers", value: jsonEncode(server));
  }

  Future<List<int>?> getExpandedProjects() async {
    String jsonString = await _storage.read(key: "expanded-projects") ?? "[]";
    List<dynamic> server = jsonDecode(jsonString);
    return server.map((e) => e as int).toList();
  }

  Future<void> setExpandedProjects(List<int>? expandedProjects) {
    return _storage.write(
        key: "expanded-projects", value: jsonEncode(expandedProjects));
  }

  Future<FlutterThemeMode> getThemeMode() async {
    String? theme_mode = await _storage.read(key: "theme_mode");
    if (theme_mode == null) setThemeMode(FlutterThemeMode.system);
    switch (theme_mode) {
      case "system":
        return FlutterThemeMode.system;
      case "light":
        return FlutterThemeMode.light;
      case "dark":
        return FlutterThemeMode.dark;
      case "materialYouLight":
        return FlutterThemeMode.materialYouLight;
      case "materialYouDark":
        return FlutterThemeMode.materialYouDark;
      default:
        return FlutterThemeMode.system;
    }
  }

  Future<void> setThemeMode(FlutterThemeMode newMode) async {
    await _storage.write(
        key: "theme_mode", value: newMode.toString().split('.').last);
  }
}

enum FlutterThemeMode {
  system,
  light,
  dark,
  materialYouLight,
  materialYouDark,
}
