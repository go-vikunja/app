import 'package:vikunja_app/data/data_sources/task_label_bulk_data_source.dart';
import 'package:vikunja_app/data/models/label_dto.dart';
import 'package:vikunja_app/data/models/task_dto.dart';
import 'package:vikunja_app/domain/entities/label.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/repositories/task_label_bulk_repository.dart';

class TaskLabelBulkRepositoryImpl extends TaskLabelBulkRepository {
  final TaskLabelBulkDataSource _dataSource;

  TaskLabelBulkRepositoryImpl(this._dataSource);

  @override
  Future<List<Label>?> update(Task task, List<Label>? labels) async {
    var labelsDto = labels?.map((e) => LabelDto.fromDomain(e)).toList();
    return (await _dataSource.update(
      TaskDto.fromDomain(task),
      labelsDto,
    ))?.map((e) => e.toDomain()).toList();
  }
}
