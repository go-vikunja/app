import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/api/service.dart';
import 'package:vikunja_app/models/label.dart';
import 'package:vikunja_app/models/labelTask.dart';
import 'package:vikunja_app/service/services.dart';

class LabelTaskAPIService extends APIService implements LabelTaskService {
  LabelTaskAPIService(Client client) : super(client);

  @override
  Future<Label> create(LabelTask lt) async {
    return client.put('/tasks/${lt.task.id}/labels', body: lt.toJSON())
        .then((result) => Label.fromJson(result.body));
  }

  @override
  Future<Label> delete(LabelTask lt) async {
    return client.delete('/tasks/${lt.task.id}/labels/${lt.label.id}')
      .then((result) => Label.fromJson(result.body));
  }

  @override
  Future<List<Label>> getAll(LabelTask lt, {String query}) async {
    String params =
        query == '' ? null : '?s=' + Uri.encodeQueryComponent(query);

    return client.get('/tasks/${lt.task.id}/labels$params').then(
        (label) => convertList(label, (result) => Label.fromJson(result)));
  }
}