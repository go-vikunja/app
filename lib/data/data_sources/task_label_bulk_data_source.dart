import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/network/remote_data_source.dart';
import 'package:vikunja_app/data/models/label_dto.dart';
import 'package:vikunja_app/data/models/task_dto.dart';
import 'package:vikunja_app/data/models/task_label_bulk_dto.dart';

class TaskLabelBulkDataSource extends RemoteDataSource {
  TaskLabelBulkDataSource(super.client);

  Future<Response<List<LabelDto>>> update(TaskDto task, List<LabelDto> labels) {
    return client.post(
      url: '/tasks/${task.id}/labels/bulk',
      body: LabelTaskBulkDto(labels: labels).toJSON(),
      mapper: (body) {
        return convertList(
          body['labels'],
          (result) => LabelDto.fromJson(result),
        );
      },
    );
  }
}
