import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/service.dart';
import 'package:vikunja_app/data/models/label_dto.dart';

class LabelDataSource extends RemoteDataSource {
  LabelDataSource(Client client) : super(client);

  Future<LabelDto?> create(LabelDto label) {
    return client.put('/labels', body: label.toJSON()).then((response) {
      if (response == null) return null;
      return LabelDto.fromJson(response.body);
    });
  }

  Future<LabelDto?> delete(LabelDto label) {
    return client.delete('/labels/${label.id}').then((response) {
      if (response == null) return null;
      return LabelDto.fromJson(response.body);
    });
  }

  Future<LabelDto?> get(int labelID) {
    return client.get('/labels/$labelID').then((response) {
      if (response == null) return null;
      return LabelDto.fromJson(response.body);
    });
  }

  Future<List<LabelDto>?> getAll({String? query}) {
    String params = query == null
        ? ''
        : '?s=' + Uri.encodeQueryComponent(query);
    return client.get('/labels$params').then((response) {
      if (response == null) return null;
      return convertList(response.body, (result) => LabelDto.fromJson(result));
    });
  }

  Future<LabelDto?> update(LabelDto label) {
    return client.post('/labels/${label.id}', body: label).then((response) {
      if (response == null) return null;
      return LabelDto.fromJson(response.body);
    });
  }
}
