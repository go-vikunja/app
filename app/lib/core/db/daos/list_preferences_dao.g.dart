// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_preferences_dao.dart';

// ignore_for_file: type=lint
mixin _$ListPreferencesDaoMixin on DatabaseAccessor<AppDatabase> {
  $ListPreferenceEntriesTable get listPreferenceEntries =>
      attachedDatabase.listPreferenceEntries;
  ListPreferencesDaoManager get managers => ListPreferencesDaoManager(this);
}

class ListPreferencesDaoManager {
  final _$ListPreferencesDaoMixin _db;
  ListPreferencesDaoManager(this._db);
  $$ListPreferenceEntriesTableTableManager get listPreferenceEntries =>
      $$ListPreferenceEntriesTableTableManager(
        _db.attachedDatabase,
        _db.listPreferenceEntries,
      );
}
