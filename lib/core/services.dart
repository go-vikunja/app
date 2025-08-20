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
  updated,
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
  enum_in,
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
  TaskServiceOption<TaskServiceOptionSortBy>("sort_by", [
    TaskServiceOptionSortBy.due_date,
    TaskServiceOptionSortBy.id,
  ]),
  TaskServiceOption<TaskServiceOptionOrderBy>(
    "order_by",
    TaskServiceOptionOrderBy.asc,
  ),
  TaskServiceOption<TaskServiceOptionFilterBy>("filter_by", [
    TaskServiceOptionFilterBy.done,
    TaskServiceOptionFilterBy.due_date,
  ]),
  TaskServiceOption<TaskServiceOptionFilterValue>("filter_value", [
    TaskServiceOptionFilterValue.enum_false,
    '1970-01-01T00:00:00.000Z',
  ]),
  TaskServiceOption<TaskServiceOptionFilterComparator>("filter_comparator", [
    TaskServiceOptionFilterComparator.equals,
    TaskServiceOptionFilterComparator.greater,
  ]),
  TaskServiceOption<TaskServiceOptionFilterConcat>(
    "filter_concat",
    TaskServiceOptionFilterConcat.and,
  ),
];

class TaskServiceOptions {
  List<TaskServiceOption> options = [];

  TaskServiceOptions({
    List<TaskServiceOption>? newOptions,
    bool clearOther = false,
  }) {
    if (!clearOther) options = new List<TaskServiceOption>.from(defaultOptions);
    if (newOptions != null) {
      for (TaskServiceOption custom_option in newOptions) {
        int index = options.indexWhere(
          (element) => element.name == custom_option.name,
        );
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
