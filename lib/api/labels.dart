import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/api/service.dart';
import 'package:vikunja_app/models/label.dart';
import 'package:vikunja_app/service/services.dart';

class LabelAPIService extends APIService implements LabelService {
  LabelAPIService(Client client) : super(client);

  @override
  Future<Label> create(Label label) {
    return client
        .put('/labels', body: label.toJSON())
        .then((response) => Label.fromJson(response.body));
  }

  @override
  Future<Label> delete(Label label) {
    return client
        .delete('/labels/${label.id}')
        .then((response) => Label.fromJson(response.body));
  }

  @override
  Future<Label> get(int labelID) {
    return client
        .get('/labels/$labelID')
        .then((response) => Label.fromJson(response.body));
  }

  @override
  Future<List<Label>> getAll({String? query}) {
    String? params =
        query == null ? null : '?s=' + Uri.encodeQueryComponent(query);
    return client.get('/labels$params').then(
        (response) => convertList(response.body, (result) => Label.fromJson(result)));
  }

  @override
  Future<Label> update(Label label) {
    return client
        .post('/labels/${label.id}', body: label)
        .then((response) => Label.fromJson(response.body));
  }
}
