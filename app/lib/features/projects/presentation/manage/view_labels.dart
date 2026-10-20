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

/// Whether the app shows views of [kind]; the others are kept for the web.
bool isShownInApp(ProjectViewKind kind) =>
    kind == ProjectViewKind.list || kind == ProjectViewKind.kanban;

/// The kind, and for one the app does not show yet, that it does not.
String viewKindOptionLabel(AppLocalizations l10n, ProjectViewKind kind) =>
    isShownInApp(kind)
    ? viewKindLabel(l10n, kind)
    : l10n.projectViewKindWebOnly(viewKindLabel(l10n, kind));

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
