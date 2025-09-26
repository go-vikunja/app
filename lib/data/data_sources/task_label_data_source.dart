import 'package:vikunja_app/core/network/remote_data_source.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/models/label_dto.dart';
import 'package:vikunja_app/data/models/task_label_dto.dart';

class TaskLabelDataSource extends RemoteDataSource {
  TaskLabelDataSource(super.client);

  Future<Response<LabelDto>> delete(LabelTaskDto lt) async {
    return client.delete(
      url: '/tasks/${lt.task!.id}/labels/${lt.label.id}',
      mapper: (body) {
        return LabelDto.fromJson(body);
      },
    );
  }
}
