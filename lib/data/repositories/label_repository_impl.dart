import 'package:vikunja_app/data/data_sources/label_datasource.dart';
import 'package:vikunja_app/data/models/label_dto.dart';
import 'package:vikunja_app/domain/entities/label.dart';
import 'package:vikunja_app/domain/repositories/label_repository.dart';

class LabelRepositoryImpl extends LabelRepository {
  LabelDataSource _dataSource;

  LabelRepositoryImpl(this._dataSource);

  @override
  Future<Label?> create(Label label) async {
    return (await _dataSource.create(LabelDto.fromDomain(label)))?.toDomain();
  }

  @override
  Future<Label?> delete(Label label) async {
    return (await _dataSource.delete(LabelDto.fromDomain(label)))?.toDomain();
  }

  @override
  Future<Label?> get(int labelID) async {
    return (await _dataSource.get(labelID))?.toDomain();
  }

  @override
  Future<List<Label>?> getAll({String? query}) async {
    return (await _dataSource.getAll(query: query))
        ?.map((e) => e.toDomain())
        .toList();
  }

  @override
  Future<Label?> update(Label label) async {
    return (await _dataSource.update(LabelDto.fromDomain(label)))?.toDomain();
  }
}
