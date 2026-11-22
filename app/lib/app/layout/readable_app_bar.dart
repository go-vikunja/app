import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/layout/window_layout.dart';

/// An app bar across the whole width, as every app bar is, whose back
/// button, title and actions keep to the band of [maxWidth] that the
/// screen's content takes below it ([ReadableWidth]); [bottom] keeps the
/// whole width. Without a cap it is the plain [AppBar].
class ReadableAppBar extends StatelessWidget implements PreferredSizeWidget {
  const new({
    required this.maxWidth,
    this.title,
    this.actions,
    this.bottom,
    this.automaticallyImplyLeading = true,
    super.key,
  });

  final double maxWidth;
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  /// As [AppBar.automaticallyImplyLeading]; no screen with one has a drawer.
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final caps = WindowLayout.of(context).capsWidths;
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = ReadableWidth.insetFor(
          available: constraints.maxWidth,
          max: maxWidth,
          caps: caps,
        );
        if (inset == 0) {
          return AppBar(
            automaticallyImplyLeading: automaticallyImplyLeading,
            title: title,
            actions: actions,
            bottom: bottom,
          );
        }
        final leading = automaticallyImplyLeading
            ? _impliedLeading(context)
            : null;
        return AppBar(
          leadingWidth: inset + (leading == null ? 0 : kToolbarHeight),
          leading: Padding(
            padding: EdgeInsetsDirectional.only(start: inset),
            // As the app bar places its own.
            child: leading == null ? null : Center(child: leading),
          ),
          title: title,
          actions: actions,
          actionsPadding: EdgeInsetsDirectional.only(end: inset),
          bottom: bottom,
        );
      },
    );
  }

  /// The button [AppBar] would imply.
  static Widget? _impliedLeading(BuildContext context) {
    final route = ModalRoute.of(context);
    if (!(route?.impliesAppBarDismissal ?? false)) return null;
    return route is PageRoute && route.fullscreenDialog
        ? const CloseButton()
        : const BackButton();
  }
}
