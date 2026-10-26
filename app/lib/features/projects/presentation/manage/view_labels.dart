import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

String viewKindLabel(AppLocalizations l10n, ProjectViewKind kind) =>
    switch (kind) {
      ProjectViewKind.list => l10n.projectViewList,
      ProjectViewKind.gantt => l10n.projectViewGantt,
      ProjectViewKind.table => l10n.projectViewTable,
      ProjectViewKind.kanban => l10n.projectViewKanban,
    };

IconData viewKindIcon(ProjectViewKind kind) => switch (kind) {
  ProjectViewKind.list => Icons.view_list_outlined,
  ProjectViewKind.gantt => Icons.view_timeline_outlined,
  ProjectViewKind.table => Icons.table_chart_outlined,
  ProjectViewKind.kanban => Icons.view_kanban_outlined,
};

String bucketModeLabel(AppLocalizations l10n, BucketConfigurationMode mode) =>
    mode == BucketConfigurationMode.filter
    ? l10n.projectViewColumnsFilter
    : l10n.projectViewColumnsManual;
