import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

String widgetKindTitle(AppLocalizations l10n, WidgetKind kind) =>
    switch (kind) {
      TodayKind() => l10n.widgetKindToday,
      UpcomingKind() => l10n.widgetKindUpcoming,
      OverdueKind() => l10n.widgetKindOverdue,
      FavoritesKind() => l10n.widgetKindFavorites,
      ProjectTasksKind() => l10n.widgetKindProject,
      LabelTasksKind() => l10n.widgetKindLabel,
      SavedFilterKind() => l10n.widgetKindSavedFilter,
      QuickAddKind() => l10n.widgetKindQuickAdd,
    };

IconData widgetKindIcon(WidgetKind kind) => switch (kind) {
  TodayKind() => Icons.today_outlined,
  UpcomingKind() => Icons.event_outlined,
  OverdueKind() => Icons.history_outlined,
  FavoritesKind() => Icons.star_outline,
  ProjectTasksKind() => Icons.folder_outlined,
  LabelTasksKind() => Icons.label_outline,
  SavedFilterKind() => Icons.filter_alt_outlined,
  QuickAddKind() => Icons.add_task_outlined,
};
