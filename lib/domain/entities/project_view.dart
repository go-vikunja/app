import 'package:flutter/material.dart';
import 'package:vikunja_app/domain/entities/bucket_configuration.dart';
import 'package:vikunja_app/domain/entities/filter.dart';
import 'package:vikunja_app/domain/entities/view_kind.dart';

class ProjectView {
  final int id;
  final String title;
  final int projectId;
  final ViewKind viewKind;
  final Filter? filter;
  final int position;
  final String bucketConfigurationMode;
  final List<BucketConfiguration>? bucketConfiguration;
  int defaultBucketId;
  int doneBucketId;
  final DateTime created;
  final DateTime updated;

  Icon get icon {
    switch (viewKind) {
      case ViewKind.list:
        return Icon(Icons.view_list);
      case ViewKind.kanban:
        return Icon(Icons.view_kanban);
      case ViewKind.gantt:
        return Icon(Icons.view_timeline);
      case ViewKind.table:
        return Icon(Icons.table_chart);
    }
  }

  ProjectView(
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
      this.viewKind);
}
