import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/detail_header_layout.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/project_breadcrumb.dart';
import 'package:vikunja_mobile/features/tasks/presentation/favourite_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_controller.dart';

/// The detail's header: in the pane [onBack] to [backTitle]'s task, the
/// breadcrumb of [project] within [projects], then Edit unless [locked],
/// the bell and the star unless [guest], [menu] and Close.
class TaskDetailHeader extends StatelessWidget {
  const new({
    required this.task,
    required this.project,
    required this.projects,
    required this.onOpenProject,
    required this.locked,
    required this.onEdit,
    required this.guest,
    required this.follow,
    required this.onFollow,
    required this.onFavoriteChanged,
    required this.menu,
    required this.onClose,
    this.onBack,
    this.backTitle,
    super.key,
  });

  final Task task;
  final Project? project;
  final List<Project> projects;
  final ValueChanged<Project> onOpenProject;
  final bool locked;
  final VoidCallback? onEdit;
  final bool guest;
  final FollowController follow;
  final VoidCallback onFollow;
  final ValueChanged<bool>? onFavoriteChanged;
  final Widget? menu;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final String? backTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final back = onBack;
    final project = this.project;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: back == null ? 16 : 4, end: 4),
      child: DetailHeaderLayout(
        // Below the back arrow, in line with the title.
        breadcrumbIndent: back == null ? 0 : 12,
        back: back == null
            ? null
            : IconButton(
                onPressed: back,
                tooltip: l10n.taskDetailPaneBack(backTitle ?? ''),
                // The tooltip names the task; the icon's own "Back" would
                // be read before it.
                icon: const ExcludeSemantics(child: BackButtonIcon()),
              ),
        breadcrumb: project == null
            ? null
            : ProjectBreadcrumb(
                path: projectPath(project, projects),
                onOpen: onOpenProject,
              ),
        actions: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!locked)
              IconButton(
                onPressed: onEdit,
                tooltip: l10n.taskEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            if (!guest) ...[
              ValueListenableBuilder(
                valueListenable: follow,
                builder: (context, state, _) => FollowButton(
                  state: task.id < 0 ? const FollowUnknown() : state,
                  onPressed: onFollow,
                ),
              ),
              FavouriteButton(
                isFavorite: task.isFavorite,
                onChanged: onFavoriteChanged,
              ),
            ],
            ?menu,
            IconButton(
              onPressed: onClose,
              tooltip: l10n.taskDetailClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
