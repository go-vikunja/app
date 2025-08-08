import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/service.dart';
import 'package:vikunja_app/data/models/label.dart';
import 'package:vikunja_app/data/models/labelTaskBulk.dart';
import 'package:vikunja_app/data/models/task.dart';
import 'package:vikunja_app/core/services.dart';

class TaskLabelBulkDataSource extends RemoteDataSource
    implements LabelTaskBulkService {
  TaskLabelBulkDataSource(Client client) : super(client);

  @override
  Future<List<Label>?> update(Task task, List<Label>? labels) {
    if (labels == null) labels = [];
    return client
        .post('/tasks/${task.id}/labels/bulk',
            body: LabelTaskBulk(labels: labels).toJSON())
        .then((response) {
      if (response == null) return null;
      return convertList(
          response.body['labels'], (result) => Label.fromJson(result));
    });
  }
}
