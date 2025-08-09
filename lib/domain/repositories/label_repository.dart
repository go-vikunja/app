import 'package:vikunja_app/domain/entities/label.dart';

abstract class LabelRepository {
  Future<Label?> create(Label label);

  Future<Label?> delete(Label label);

  Future<Label?> get(int labelID);

  Future<List<Label>?> getAll({String? query});

  Future<Label?> update(Label label);
}
