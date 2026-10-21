import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_view_labels.dart';
import 'package:vikunja_mobile/features/sync/presentation/sync_progress_bar.dart';

/// Below a project's title: its progress and the views as tabs, each only
/// when there is something to show, above the sync indicator.
class ProjectAppBarBottom extends StatelessWidget
    implements PreferredSizeWidget {
  /// [textScaler] sizes the progress line, whose text grows with it.
  const new({
    required this.progress,
    required this.textScaler,
    this.tabs,
    super.key,
  });

  /// Null or without tasks: no progress line, as in a window too short
  /// to spare it ([showsProgressIn]).
  final ProjectProgress? progress;
  final TextScaler textScaler;
  final Widget? tabs;

  static const _tabsHeight = 48.0;

  /// A phone in landscape keeps its few lines for the tasks.
  static bool showsProgressIn(BuildContext context) =>
      MediaQuery.sizeOf(context).height >= 480;

  bool get _showsProgress => (progress?.total ?? 0) > 0;

  @override
  Size get preferredSize => Size.fromHeight(
    (_showsProgress ? ProjectProgressLine.heightFor(textScaler) : 0) +
        (tabs == null ? 0 : _tabsHeight) +
        SyncProgressBar.height,
  );

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (progress != null && _showsProgress)
          SizedBox(
            height: ProjectProgressLine.heightFor(textScaler),
            child: ProjectProgressLine(progress: progress),
          ),
        if (tabs case final tabs?) SizedBox(height: _tabsHeight, child: tabs),
        const SyncProgressBar(),
      ],
    );
  }
}

/// "3 of 5 done" beside a bar: the project's own tasks, not its
/// subprojects'.
class ProjectProgressLine extends StatelessWidget {
  const new({required this.progress, super.key});

  final ProjectProgress progress;

  static const _textSize = 12.0;
  static const double _lineHeight = 16 / 12;
  static const _bottomPadding = 12.0;

  static double heightFor(TextScaler textScaler) =>
      (textScaler.scale(_textSize) * _lineHeight).ceilToDouble() +
      _bottomPadding;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (:done, :total) = progress;
    return Semantics(
      container: true,
      label: l10n.projectProgressSemantics(done, total),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, _bottomPadding),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.max(constraints.maxWidth * 0.6, 0),
                  ),
                  child: Text(
                    l10n.projectProgressDone(done, total),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: _textSize,
                      height: _lineHeight,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The project's views as tabs of equal width, scrolling instead when a
/// title would not fit its share.
class ProjectViewTabs extends StatefulWidget {
  const new({
    required this.views,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<ProjectView> views;
  final int selectedId;
  final ValueChanged<int> onSelected;

  @override
  State<ProjectViewTabs> createState() => _ProjectViewTabsState();
}

class _ProjectViewTabsState extends State<ProjectViewTabs>
    with TickerProviderStateMixin {
  late TabController _controller = _newController();

  int get _selectedIndex => math.max(
    widget.views.indexWhere((view) => view.id == widget.selectedId),
    0,
  );

  TabController _newController() => TabController(
    length: widget.views.length,
    initialIndex: _selectedIndex,
    vsync: this,
  );

  @override
  void didUpdateWidget(ProjectViewTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.views.length != widget.views.length) {
      final previous = _controller;
      _controller = _newController();
      // The tab bar lets go of it in this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    } else if (_controller.index != _selectedIndex &&
        !_controller.indexIsChanging) {
      _controller.index = _selectedIndex;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final titles = [for (final view in widget.views) viewTitle(l10n, view)];
    final labelStyle =
        theme.tabBarTheme.labelStyle ?? theme.textTheme.titleSmall;
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double widthOf(String title) {
      final painter = TextPainter(
        text: TextSpan(text: title, style: labelStyle),
        textScaler: textScaler,
        textDirection: direction,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final widest = titles.map(widthOf).fold<double>(0, math.max);
    return Semantics(
      container: true,
      label: l10n.projectViewSwitch,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scrolls =
              widest + kTabLabelPadding.horizontal >
              constraints.maxWidth / titles.length;
          return TabBar(
            controller: _controller,
            isScrollable: scrolls,
            tabAlignment: scrolls ? TabAlignment.start : TabAlignment.fill,
            onTap: (index) => widget.onSelected(widget.views[index].id),
            tabs: [for (final title in titles) Tab(text: title)],
          );
        },
      ),
    );
  }
}

/// Above a list view's rows: whether its done tasks show, where the view
/// leaves that to the user, and its sort; in one row that scrolls sideways
/// when the chips do not fit.
class ProjectListControls extends StatelessWidget {
  const new({
    required this.sort,
    required this.onSort,
    this.showDone = false,
    this.onShowDoneChanged,
    super.key,
  });

  final TaskListSort sort;
  final VoidCallback onSort;
  final bool showDone;

  /// Null hides the chip, for a view whose filter decides.
  final VoidCallback? onShowDoneChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sorted = sortLabel(l10n, sort);
    final onShowDoneChanged = this.onShowDoneChanged;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Scrolled, the chips run to the screen's edges.
      clipBehavior: Clip.none,
      child: Row(
        spacing: 8,
        children: [
          if (onShowDoneChanged != null)
            FilterChip(
              label: Text(l10n.projectShowDoneChip),
              selected: showDone,
              onSelected: (_) => onShowDoneChanged(),
            ),
          ActionChip(
            avatar: const Icon(Icons.sort),
            label: Text(sorted),
            tooltip: l10n.projectSortCurrent(sorted),
            onPressed: onSort,
          ),
        ],
      ),
    );
  }
}
