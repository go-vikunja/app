import 'package:vikunja_app/core/network/service.dart';
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/data/models/label_dto.dart';
import 'package:vikunja_app/data/models/task_label_dto.dart';

class TaskLabelDataSource extends RemoteDataSource {
  TaskLabelDataSource(Client client) : super(client);

  Future<LabelDto?> create(LabelTaskDto lt) async {
    return client.put('/tasks/${lt.task!.id}/labels', body: lt.toJSON()).then((
      response,
    ) {
      if (response == null) return null;
      return LabelDto.fromJson(response.body);
    });
  }

  Future<LabelDto?> delete(LabelTaskDto lt) async {
    return client.delete('/tasks/${lt.task!.id}/labels/${lt.label.id}').then((
      response,
    ) {
      if (response == null) return null;
      return LabelDto.fromJson(response.body);
    });
  }

  Future<List<LabelDto>?> getAll(LabelTaskDto lt, {String? query}) async {
    String? params = query == null
        ? null
        : '?s=' + Uri.encodeQueryComponent(query);

    return client.get('/tasks/${lt.task!.id}/labels$params').then((label) {
      if (label == null) return null;
      return convertList(label, (result) => LabelDto.fromJson(result));
    });
  }
}
