import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

class SettingsManager {
  final FlutterSecureStorage _storage;

  Map<String, String> defaults = {
    "ignore-certificates": "0",
    "get-version-notifications": "1",
    "workmanager-duration": "0",
    "recent-servers": "[\"https://try.vikunja.io\"]",
    "theme_mode": "system",
    "landing-page-due-date-tasks": "1",
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

  Future<bool> getSentryModalShown() {
    return _storage
        .read(key: "sentry-modal-shown")
        .then((value) => value == "1");
  }

  Future<void> setSentryModalShown(bool value) {
    return _storage.write(key: "sentry-modal-shown", value: value ? "1" : "0");
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
}

enum FlutterThemeMode {
  system,
  light,
  dark,
}
