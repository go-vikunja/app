import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';

/// A pull-to-refresh friendly scroll view with one centred child, for the
/// loading, empty and error states of a list screen.
class CenteredScrollView extends StatelessWidget {
  const new({required this.child, this.header, super.key});

  final Widget child;

  /// Shown above the centred content, e.g. a failure notice.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (header case final header?) NoticeSliver(notice: header),
        SliverFillRemaining(
          hasScrollBody: false,
          child: SafeArea(top: false, child: Center(child: child)),
        ),
      ],
    );
  }
}
