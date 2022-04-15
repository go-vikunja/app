import 'dart:async';
import 'dart:developer';
import 'package:vikunja_app/models/list.dart';
import 'package:vikunja_app/models/namespace.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/user.dart';

enum TaskServiceOptionSortBy {id, title, description, done, done_at, due_date, created_by_id, list_id, repeat_after, priority, start_date, end_date, hex_color, percent_done, uid, created, updated}
enum TaskServiceOptionOrderBy {asc,desc}
enum TaskServiceOptionFilterBy {done, due_date}
enum TaskServiceOptionFilterValue {enum_true,enum_false}
enum TaskServiceOptionFilterComparator {equals, greater, greater_equals, less, less_equals, like, enum_in}
enum TaskServiceOptionFilterConcat {and, or}


class TaskServiceOption<T> {
  String name;
  dynamic value;
  dynamic defValue;
  TaskServiceOption(
      this.name,
      this.value
      );
  String handleValue(dynamic input) {
    if(input is String)
      return input;
    return input.toString().split('.').last.replaceAll('enum_', '');
  }
  dynamic getValue() {
    if(value is List)
      return value.map((elem) => handleValue(elem)).toList();
    else
      return handleValue(value);
  }
}

class TaskServiceOptions {
  List<TaskServiceOption> options = [
    TaskServiceOption<TaskServiceOptionSortBy>("sort_by",[TaskServiceOptionSortBy.due_date, TaskServiceOptionSortBy.id]),
    TaskServiceOption<TaskServiceOptionOrderBy>("order_by", TaskServiceOptionOrderBy.asc),
    TaskServiceOption<TaskServiceOptionFilterBy>("filter_by", [TaskServiceOptionFilterBy.done, TaskServiceOptionFilterBy.due_date]),
    TaskServiceOption<TaskServiceOptionFilterValue>("filter_value", [TaskServiceOptionFilterValue.enum_false, '0001-01-02T00:00:00.000Z']),
    TaskServiceOption<TaskServiceOptionFilterComparator>("filter_comparator", [TaskServiceOptionFilterComparator.equals,TaskServiceOptionFilterComparator.greater]),
    TaskServiceOption<TaskServiceOptionFilterConcat>("filter_concat", TaskServiceOptionFilterConcat.and),
  ];
  void setOption(TaskServiceOption option, dynamic value) {
    options.firstWhere((element) => element.name == option.name).value = value;
  }

  String getOptions() {
    String result = '';
    for(TaskServiceOption option in options) {
      dynamic value = option.getValue();
      if (value is List) {
        for (dynamic value_entry in value) {
          result += '&' + option.name + '[]=' + value_entry;
        }
      } else {
        result += '&' + option.name + '=' + value;
      }
    }

    if(result.startsWith('&'))
      result.substring(1);
    log(result);
    return result;
  }
}

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
  Future<List<Task>> getByOptions(TaskServiceOptions options);
  }

abstract class UserService {
  Future<UserTokenPair> login(String username, password);
  Future<UserTokenPair> register(String username, email, password);
  Future<User> getCurrentUser();
}
