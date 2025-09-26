import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/utils/mapping_extensions.dart';
import 'package:vikunja_app/data/data_sources/label_data_source.dart';
import 'package:vikunja_app/data/models/label_dto.dart';
import 'package:vikunja_app/domain/entities/label.dart';
import 'package:vikunja_app/domain/repositories/label_repository.dart';

class LabelRepositoryImpl extends LabelRepository {
  final LabelDataSource _dataSource;

  LabelRepositoryImpl(this._dataSource);

  @override
  Future<Response<Label>> create(Label label) async {
    return (await _dataSource.create(LabelDto.fromDomain(label))).toDomain();
  }

  @override
  Future<Response<List<Label>>> getAll({String? query}) async {
    return (await _dataSource.getAll(query: query)).toDomain();
  }
}
