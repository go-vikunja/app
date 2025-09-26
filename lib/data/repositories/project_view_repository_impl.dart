import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/utils/mapping_extensions.dart';
import 'package:vikunja_app/data/data_sources/project_view_data_source.dart';
import 'package:vikunja_app/data/models/project_view_dto.dart';
import 'package:vikunja_app/domain/entities/project_view.dart';
import 'package:vikunja_app/domain/repositories/project_view_repository.dart';

class ProjectViewRepositoryImpl extends ProjectViewRepository {
  final ProjectViewDataSource _dataSource;

  ProjectViewRepositoryImpl(this._dataSource);

  @override
  Future<Response<ProjectView>> update(ProjectView view) async {
    return (await _dataSource.update(
      ProjectViewDto.fromDomain(view),
    )).toDomain();
  }
}
