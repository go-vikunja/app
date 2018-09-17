import 'dart:async';

import 'package:fluttering_vikunja/api/client.dart';
import 'package:fluttering_vikunja/api/service.dart';
import 'package:fluttering_vikunja/models/namespace.dart';
import 'package:fluttering_vikunja/service/services.dart';

class NamespaceAPIService extends APIService implements NamespaceService {
  NamespaceAPIService(Client client) : super(client);

  @override
  Future<Namespace> create(Namespace ns) {
    return client
        .put('/namespaces', body: ns.toJSON())
        .then((map) => Namespace.fromJson(map));
  }

  @override
  Future delete(int namespaceId) {
    return client.delete('/namespaces/$namespaceId');
  }

  @override
  Future<Namespace> get(int namespaceId) {
    return client
        .get('/namespaces/$namespaceId')
        .then((map) => Namespace.fromJson(map));
  }

  @override
  Future<List<Namespace>> getAll() {
    return client.get('/namespaces').then(
        (list) => convertList(list, (result) => Namespace.fromJson(result)));
  }

  @override
  Future<Namespace> update(Namespace ns) {
    return client
        .post('/namespaces/${ns.id}', body: ns.toJSON())
        .then((map) => Namespace.fromJson(map));
  }
}
