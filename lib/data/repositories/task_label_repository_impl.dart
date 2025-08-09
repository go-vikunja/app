import 'package:vikunja_app/data/data_sources/task_label_data_source.dart';
import 'package:vikunja_app/data/models/task_label_dto.dart';
import 'package:vikunja_app/domain/entities/label.dart';
import 'package:vikunja_app/domain/entities/task_label.dart';
import 'package:vikunja_app/domain/repositories/task_label_repository.dart';

class TaskLabelRepositoryImpl extends TaskLabelRepository {
  final TaskLabelDataSource _dataSource;

  TaskLabelRepositoryImpl(this._dataSource);

  @override
  Future<Label?> create(LabelTask lt) async {
    return (await _dataSource.create(LabelTaskDto.fromDomain(lt)))?.toDomain();
  }

  @override
  Future<Label?> delete(LabelTask lt) async {
    return (await _dataSource.delete(LabelTaskDto.fromDomain(lt)))?.toDomain();
  }

  @override
  Future<List<Label>?> getAll(LabelTask lt, {String? query}) async {
    return (await _dataSource.getAll(LabelTaskDto.fromDomain(lt), query: query))
        ?.map((e) => e.toDomain())
        .toList();
  }
}
