import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/widgets/status_card.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/connection/presentation/fingerprint_view.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/project_board.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_chart.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../helpers/editor_bridge_fakes.dart';

/// How a route's screen uses a large window (step 36b, D69).
enum ReadableClass {
  /// Lists, the overview and the project tree: centred, at most 840.
  list840,

  /// Settings, forms and detail pages: centred, at most 640.
  form640,

  /// The board, the timeline and the description editor: the whole width.
  uncapped,

  /// Onboarding and lock screens with their own, narrower cap.
  ownCap,
}

/// Every route scenario of the sweep, by its key. The tablet pass checks
/// the `list840` and `form640` screens' boxes against their band, which
/// ends at the task pane's divider when a task is open beside the list and
/// starts at the project tree's divider beside its column; the tree's own
/// band is its column.
const readableWidths = <String, ReadableClass>{
  '/home/overview': ReadableClass.list840,
  '/home/upcoming': ReadableClass.list840,
  '/home/projects': ReadableClass.list840,
  '/home/account': ReadableClass.form640,
  '/home/projects/:id [list]': ReadableClass.list840,
  '/home/projects/:id [kanban]': ReadableClass.uncapped,
  '/home/projects/:id [table]': ReadableClass.list840,
  '/home/projects/:id [gantt]': ReadableClass.uncapped,
  '/home/projects/:id [favourites]': ReadableClass.list840,
  '/home/projects/:id [saved filter]': ReadableClass.list840,
  '/home/overview [pane]': ReadableClass.list840,
  '/home/overview [pane guest]': ReadableClass.list840,
  '/home/overview [pane offline]': ReadableClass.list840,
  '/home/upcoming [pane]': ReadableClass.list840,
  '/home/projects/:id [pane list]': ReadableClass.list840,
  '/home/projects/:id [pane table]': ReadableClass.list840,
  '/home/projects/:id [pane kanban]': ReadableClass.uncapped,
  '/home/projects/:id [pane gantt]': ReadableClass.uncapped,
  '/home/projects/:id [pane favourites]': ReadableClass.list840,
  '/home/tasks/:id/edit': ReadableClass.form640,
  '/home/tasks/:id/description': ReadableClass.uncapped,
  '/home/tasks/:id/comments/:commentId/edit': ReadableClass.uncapped,
  '/home/project/:id/description': ReadableClass.uncapped,
  '/home/project/:id/edit': ReadableClass.form640,
  '/home/project/:id/views': ReadableClass.form640,
  '/home/project/:id/share': ReadableClass.form640,
  '/home/inbox': ReadableClass.list840,
  '/home/search': ReadableClass.list840,
  '/home/labels': ReadableClass.form640,
  '/home/labels/new': ReadableClass.form640,
  '/home/labels/:id': ReadableClass.list840,
  '/home/labels/:id/edit': ReadableClass.form640,
  '/home/labels/:id/description': ReadableClass.uncapped,
  '/home/teams': ReadableClass.form640,
  '/home/teams/:id': ReadableClass.form640,
  '/home/teams/:id/description': ReadableClass.uncapped,
  '/home/trash [tasks]': ReadableClass.list840,
  '/home/trash [projects]': ReadableClass.list840,
  '/home/filters/new': ReadableClass.form640,
  '/home/filters/:id/edit': ReadableClass.form640,
  '/home/widgets': ReadableClass.form640,
  '/home/widgets/configure': ReadableClass.form640,
  '/home/account-settings': ReadableClass.form640,
  '/home/account-settings/avatar': ReadableClass.form640,
  '/home/account-settings/sessions': ReadableClass.form640,
  '/home/account-settings/api-tokens': ReadableClass.form640,
  '/home/account-settings/api-tokens/new': ReadableClass.form640,
  '/home/account-settings/caldav': ReadableClass.form640,
  '/home/account-settings/data-export': ReadableClass.form640,
  '/home/privacy': ReadableClass.form640,
  '/about': ReadableClass.form640,
  '/': ReadableClass.ownCap,
  '/server': ReadableClass.form640,
  '/connection [https]': ReadableClass.form640,
  '/connection [http]': ReadableClass.form640,
  '/connection [headers]': ReadableClass.form640,
  '/connection [certificate]': ReadableClass.form640,
  '/connection [clientCertificate]': ReadableClass.form640,
  '/sync': ReadableClass.ownCap,
  '/notifications-setup': ReadableClass.ownCap,
  '/home/accounts/add': ReadableClass.ownCap,
  '/home/accounts/add/server': ReadableClass.form640,
};

/// The boxes of a capped screen that must lie in its band.
final Finder readableContentBoxes = find.byWidgetPredicate(
  (widget) =>
      widget is SectionCard ||
      widget is TaskRow ||
      widget is ListTile ||
      widget is TextField,
);

/// Screens with none of [readableContentBoxes], with the boxes checked
/// instead and the reason.
final Map<String, (Finder, String)> readableBoxOverrides = {
  '/home/account-settings/data-export': (
    find.byType(StatusCard),
    'the export state is a status card; the page has no rows or fields',
  ),
  '/connection [certificate]': (
    find.byWidgetPredicate(
      (widget) =>
          widget is FingerprintView ||
          widget is StatusCard ||
          widget is ListNote,
    ),
    'the certificate review is fingerprints, notes and status cards',
  ),
};

/// The cap of each `ownCap` screen, which the tablet pass checks its
/// content against.
const readableOwnCaps = <String, double>{
  '/': 480,
  '/home/accounts/add': 480,
  '/sync': 420,
  '/notifications-setup': 420,
};

/// The boxes of an `ownCap` screen that stay within its cap.
final Finder ownCapContentBoxes = find.byWidgetPredicate(
  (widget) =>
      widget is Text || widget is TextField || widget is ButtonStyleButton,
);

/// What takes the whole width on the `uncapped` screens: the timeline, the
/// board and the description editor's view.
final Finder uncappedContentBoxes = find.byWidgetPredicate(
  (widget) =>
      widget is TimelineChart ||
      widget is ProjectBoard ||
      widget.key == FakeEditorBridge.viewKey,
);
