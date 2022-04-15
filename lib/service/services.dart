import 'dart:async';

import 'package:vikunja_app/models/list.dart';
import 'package:vikunja_app/models/namespace.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/user.dart';

enum TaskServiceOptionSortBy {id, title, description, done, done_at, due_date, created_by_id, list_id, repeat_after, priority, start_date, end_date, hex_color, percent_done, uid, created, updated}
enum TaskServiceOptionOrderBy {asc,desc}
enum TaskServiceOptionFilterBy {done}
enum TaskServiceOptionFilterValue {enum_true,enum_false}


class TaskServiceOption<T> {
  String name;
  List<T> possibleValues;
  dynamic value;
  dynamic defValue;
  TaskServiceOption(
      this.name,
      this.possibleValues,
      this.value
      );
  String getValue() {
    return value.toString().split('.').last.replaceAll('enum_', '');
  }
}

class TaskServiceOptions {
  List<TaskServiceOption> options = [
    TaskServiceOption<TaskServiceOptionSortBy>("sort_by",TaskServiceOptionSortBy.values, TaskServiceOptionSortBy.due_date),
    TaskServiceOption<TaskServiceOptionOrderBy>("order_by",TaskServiceOptionOrderBy.values, TaskServiceOptionOrderBy.desc),
    TaskServiceOption<TaskServiceOptionFilterBy>("filter_by",TaskServiceOptionFilterBy.values, TaskServiceOptionFilterBy.done),
    TaskServiceOption<TaskServiceOptionFilterValue>("filter_value",TaskServiceOptionFilterValue.values, TaskServiceOptionFilterValue.enum_false),
  ];
  void setOption(TaskServiceOption option, dynamic value) {
    options.firstWhere((element) => element.name == option.name).value = value;
  }

  String getOptions() {
    String result = '';
    for(TaskServiceOption option in options) {
      dynamic value = option.getValue();
      if(result.isNotEmpty)
        result += '&';
      /*if(option.value is List) {
        for(dynamic value in option.value) {
          result += option.name+'[]='+value.g;
        }*/
      result += option.name+'=' + value;
    }
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
