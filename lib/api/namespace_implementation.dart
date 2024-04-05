import 'dart:async';
import 'dart:developer';
import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/api/service.dart';
import 'package:vikunja_app/models/namespace.dart';
import 'package:vikunja_app/service/services.dart';

class NamespaceAPIService extends APIService implements NamespaceService {
  NamespaceAPIService(Client client) : super(client);

  @override
  Future<Namespace?> create(Namespace ns) {
    return client.put('/namespaces', body: ns.toJSON()).then((response) {
      if (response == null) return null;
      return Namespace.fromJson(response.body);
    });
  }

  @override
  Future delete(int namespaceId) {
    return client.delete('/namespaces/$namespaceId');
  }

  @override
  Future<Namespace?> get(int namespaceId) {
    return client.get('/namespaces/$namespaceId').then((response) {
      if (response == null) return null;
      return Namespace.fromJson(response.body);
    });
  }

  @override
  Future<List<Namespace>?> getAll() {
    return client.get('/namespaces').then((response) {
      if (response == null) return null;
      return convertList(response.body, (result) => Namespace.fromJson(result));
    });
  }

  @override
  Future<Namespace?> update(Namespace ns) {
    return client
        .post('/namespaces/${ns.id}', body: ns.toJSON())
        .then((response) {
      if (response == null) return null;
      return Namespace.fromJson(response.body);
    });
  }
}
