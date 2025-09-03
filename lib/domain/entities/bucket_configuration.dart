import 'package:vikunja_app/domain/entities/filter.dart';

class BucketConfiguration {
  final String title;
  final Filter filter;

  BucketConfiguration(this.title, this.filter);
}
