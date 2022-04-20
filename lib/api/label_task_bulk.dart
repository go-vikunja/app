import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/api/service.dart';
import 'package:vikunja_app/models/label.dart';
import 'package:vikunja_app/models/labelTaskBulk.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/service/services.dart';

class LabelTaskBulkAPIService extends APIService
    implements LabelTaskBulkService {
  LabelTaskBulkAPIService(Client client) : super(client);

  @override
  Future<List<Label>> update(Task task, List<Label> labels) {
    return client
        .post('/tasks/${task.id}/labels/bulk',
            body: LabelTaskBulk(labels: labels).toJSON())
        .then((response) => convertList(
            response.body['labels'], (result) => Label.fromJson(result)));
  }
}
