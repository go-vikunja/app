import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';

/// A pull-to-refresh friendly scroll view with one centred child, for the
/// loading, empty and error states of a list screen.
class CenteredScrollView extends StatelessWidget {
  const new({required this.child, this.header, this.maxWidth, super.key});

  final Widget child;

  /// Shown above the centred content, e.g. a failure notice.
  final Widget? header;

  /// The screen's readable width (`ReadableWidth.list` or `.form`), which
  /// the header and the child share; null uses the whole width.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final slivers = [
      if (header case final header?) NoticeSliver(notice: header),
      SliverFillRemaining(
        hasScrollBody: false,
        child: SafeArea(top: false, child: Center(child: child)),
      ),
    ];
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: switch (maxWidth) {
        final maxWidth? => [
          SliverReadableWidth.group(maxWidth: maxWidth, slivers: slivers),
        ],
        null => slivers,
      },
    );
  }
}
