import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/service.dart';
import 'package:vikunja_app/data/models/label.dart';
import 'package:vikunja_app/core/services.dart';

class LabelDataSource extends RemoteDataSource implements LabelService {
  LabelDataSource(Client client) : super(client);

  @override
  Future<Label?> create(Label label) {
    return client.put('/labels', body: label.toJSON()).then((response) {
      if (response == null) return null;
      return Label.fromJson(response.body);
    });
  }

  @override
  Future<Label?> delete(Label label) {
    return client.delete('/labels/${label.id}').then((response) {
      if (response == null) return null;
      return Label.fromJson(response.body);
    });
  }

  @override
  Future<Label?> get(int labelID) {
    return client.get('/labels/$labelID').then((response) {
      if (response == null) return null;
      return Label.fromJson(response.body);
    });
  }

  @override
  Future<List<Label>?> getAll({String? query}) {
    String params =
        query == null ? '' : '?s=' + Uri.encodeQueryComponent(query);
    return client.get('/labels$params').then((response) {
      if (response == null) return null;
      return convertList(response.body, (result) => Label.fromJson(result));
    });
  }

  @override
  Future<Label?> update(Label label) {
    return client.post('/labels/${label.id}', body: label).then((response) {
      if (response == null) return null;
      return Label.fromJson(response.body);
    });
  }
}
