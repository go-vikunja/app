import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserManager {
  final FlutterSecureStorage _storage;

  UserManager(this._storage);

  Future<List<int>?> loadLocalUserIds() async {
    return await _storage.readAll().then((userMap) {
      userMap.keys
          .where((id) => _isNumeric(id))
          .map((idString) => int.tryParse(idString));
      return null;
    });
  }

  bool _isNumeric(String str) {
    return double.tryParse(str) != null;
  }
}
