import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/label.dart';

abstract class LabelRepository {
  Future<Response<Label>> create(Label label);

  Future<Response<List<Label>>> getAll({String? query});
}
