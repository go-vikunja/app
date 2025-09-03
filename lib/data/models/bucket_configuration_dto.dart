import 'package:vikunja_app/data/models/filter_dto.dart';
import 'package:vikunja_app/domain/entities/bucket_configuration.dart';

class BucketConfigurationDto {
  final String title;
  final FilterDto filter;

  BucketConfigurationDto(this.title, this.filter);

  BucketConfigurationDto.fromJson(Map<String, dynamic> json)
      : title = json['title'],
        filter = FilterDto.fromJson(json['filter']);

  Map<String, dynamic> toJSON() => {
        'title': title,
        'filter': filter.toJSON(),
      };

  BucketConfiguration toDomain() => BucketConfiguration(
        title,
        filter.toDomain(),
      );

  static BucketConfigurationDto fromDomain(BucketConfiguration p) =>
      BucketConfigurationDto(
        p.title,
        FilterDto.fromDomain(p.filter),
      );
}
