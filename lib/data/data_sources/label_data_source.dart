import 'package:vikunja_app/core/network/remote_data_source.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/models/label_dto.dart';

class LabelDataSource extends RemoteDataSource {
  LabelDataSource(super.client);

  Future<Response<LabelDto>> create(LabelDto label) {
    return client.put(
      url: '/labels',
      body: label.toJSON(),
      mapper: (body) {
        return LabelDto.fromJson(body);
      },
    );
  }

  Future<Response<List<LabelDto>>> getAll({String? query}) {
    String params = query == null
        ? ''
        : '?s=${Uri.encodeQueryComponent(query)}';
    return client.get(
      url: '/labels$params',
      mapper: (body) {
        return convertList(body, (result) => LabelDto.fromJson(result));
      },
    );
  }
}
