import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/projects_screen.dart';
import 'package:vikunja_mobile/features/smart_lists/application/smart_list_providers.dart';

/// Above the screens inside the shell's tabs: whether the project tree has
/// its column beside the Projects tab's pages. The same in every tab, so
/// the Projects tab, kept offstage, does not change with the tab shown.
class ProjectTreeColumnScope extends InheritedWidget {
  const new({required this.shown, required super.child, super.key});

  final bool shown;

  /// False outside the tabs.
  static bool shownOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ProjectTreeColumnScope>()
          ?.shown ??
      false;

  @override
  bool updateShouldNotify(ProjectTreeColumnScope oldWidget) =>
      shown != oldWidget.shown;
}

/// The project tree beside the Projects tab's pages on a wide window, with
/// the rows of [selectedId] marked; a region of its own for screen readers
/// and keyboards.
class ProjectTreeColumn extends StatelessWidget {
  const new({required this.selectedId, super.key});

  /// The narrowest phone width the app lays out for, so the tree looks as
  /// it does on a phone.
  static const width = 320.0;

  /// The project, saved filter or Favorites list open beside the column.
  final int? selectedId;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    child: FocusTraversalGroup(child: ProjectsScreen(selectedId: selectedId)),
  );
}

/// The Projects tab's first page: the project tree, or beside the tree's
/// column a note that no project is open. So there is one tree at a time.
/// Beside the tree's column it watches the data the tree waits for: while
/// another tab shows, that data then pauses with this page instead of
/// ending with the column, so the column's tree shows at once when the tab
/// comes back.
class ProjectsTab extends ConsumerWidget {
  const new({super.key});

  static final List<ProviderListenable<Object?>> _treeData = [
    projectsProvider,
    projectTreePreferencesProvider,
    savedFiltersProvider,
    favoriteTasksProvider,
    openTaskCountsProvider,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ProjectTreeColumnScope.shownOf(context)) return const ProjectsScreen();
    _treeData.forEach(ref.watch);
    return const NoProjectOpen();
  }
}

/// Beside the project tree's column while no project or list is open. No
/// app bar: the column's is beside it, so the note's title is the tab's
/// level-1 heading and names its route.
class NoProjectOpen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: CenteredScrollView(
        maxWidth: ReadableWidth.list,
        child: EmptyState(
          icon: Icons.folder_open,
          title: l10n.projectsNoneOpenTitle,
          body: l10n.projectsNoneOpenBody,
          isScreenTitle: true,
        ),
      ),
    );
  }
}
