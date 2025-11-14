import 'package:vikunja_app/data/models/bucket_configuration_dto.dart';
import 'package:vikunja_app/data/models/dto.dart';
import 'package:vikunja_app/data/models/filter_dto.dart';
import 'package:vikunja_app/domain/entities/project_view.dart';
import 'package:vikunja_app/domain/entities/view_kind.dart';

class ProjectViewDto extends Dto<ProjectView> {
  final int id;
  final String title;
  final int projectId;
  final String viewKind;
  final FilterDto? filter;
  final int position;
  final String bucketConfigurationMode;
  final List<BucketConfigurationDto>? bucketConfiguration;
  final int defaultBucketId;
  final int doneBucketId;
  final DateTime created;
  final DateTime updated;

  ProjectViewDto(
    this.created,
    this.defaultBucketId,
    this.doneBucketId,
    this.id,
    this.position,
    this.projectId,
    this.title,
    this.updated,
    this.filter,
    this.bucketConfiguration,
    this.bucketConfigurationMode,
    this.viewKind,
  );

  ProjectViewDto.fromJson(Map<String, dynamic> json)
    : created = DateTime.parse(json['created']),
      defaultBucketId = json['default_bucket_id'],
      doneBucketId = json['done_bucket_id'],
      id = json['id'],
      filter = json['filter'] != null && json['filter'] is Map<String, dynamic>
          ? FilterDto.fromJson(json['filter'])
          : null,
      position = json['position'],
      projectId = json['project_id'],
      title = json['title'],
      viewKind = json['view_kind'],
      bucketConfigurationMode = json['bucket_configuration_mode'],
      bucketConfiguration = json['bucket_configuration'] != null
          ? (json['bucket_configuration'] as List<dynamic>)
                .map((task) => BucketConfigurationDto.fromJson(task))
                .toList()
          : null,
      updated = DateTime.parse(json['updated']);

  Map<String, Object> toJSON() => {
    "created": created.toUtc().toIso8601String(),
    "default_bucket_id": defaultBucketId,
    "done_bucket_id": doneBucketId,
    "id": id,
    "position": position,
    "project_id": projectId,
    "title": title,
    "filter": filter?.toJSON() ?? "null",
    "bucket_configuration_mode": bucketConfigurationMode,
    "bucket_configuration":
        bucketConfiguration?.map((e) => e.toJSON()).toList() ?? "null",
    "updated": updated.toUtc().toIso8601String(),
    "view_kind": viewKind,
  };

  @override
  ProjectView toDomain() => ProjectView(
    created,
    defaultBucketId,
    doneBucketId,
    id,
    position,
    projectId,
    title,
    updated,
    filter?.toDomain(),
    bucketConfiguration?.map((e) => e.toDomain()).toList(),
    bucketConfigurationMode,
    ViewKind.fromString(viewKind),
  );

  static ProjectViewDto fromDomain(ProjectView p) => ProjectViewDto(
    p.created,
    p.defaultBucketId,
    p.doneBucketId,
    p.id,
    p.position,
    p.projectId,
    p.title,
    p.updated,
    p.filter != null ? FilterDto.fromDomain(p.filter!) : null,
    p.bucketConfiguration
        ?.map((e) => BucketConfigurationDto.fromDomain(e))
        .toList(),
    p.bucketConfigurationMode,
    p.viewKind.toString().split(".")[1].toLowerCase(),
  );
}
