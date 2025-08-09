import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/service.dart';
import 'package:vikunja_app/data/models/task_label_bulk_dto.dart';
import 'package:vikunja_app/data/models/label_dto.dart';
import 'package:vikunja_app/data/models/task_dto.dart';

class TaskLabelBulkDataSource extends RemoteDataSource {
  TaskLabelBulkDataSource(Client client) : super(client);

  Future<List<LabelDto>?> update(TaskDto task, List<LabelDto>? labels) {
    if (labels == null) labels = [];
    return client
        .post('/tasks/${task.id}/labels/bulk',
            body: LabelTaskBulkDto(labels: labels).toJSON())
        .then((response) {
      if (response == null) return null;
      return convertList(
          response.body['labels'], (result) => LabelDto.fromJson(result));
    });
  }
}
