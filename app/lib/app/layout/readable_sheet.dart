import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/layout/window_layout.dart';

/// The app's iOS sheet: `showCupertinoSheet` with its content in a
/// [ReadableSheetWidth] that closes it on a tap beside the card.
Future<T?> showReadableCupertinoSheet<T>({
  required BuildContext context,
  required ScrollableWidgetBuilder scrollableBuilder,
  bool showDragHandle = false,
  RouteSettings? settings,
}) => showCupertinoSheet<T>(
  context: context,
  settings: settings,
  showDragHandle: showDragHandle,
  scrollableBuilder: (context, scrollController) => ReadableSheetWidth(
    closesOnTapBeside: true,
    child: scrollableBuilder(context, scrollController),
  ),
);

/// The content of an iOS sheet or bottom popup: at most
/// [ReadableWidth.sheet] wide and centred on large windows, a card with the
/// sheet's top corners over the page beside it. It takes the height it is
/// given, so the sheet's drag and scroll behave as at full width.
///
/// With [closesOnTapBeside], a tap beside the card closes the route as a
/// tap on a dismissible barrier would, by `Navigator.maybePop`, so a
/// `PopScope` in the content still decides. `showCupertinoSheet`'s own
/// barrier never closes the sheet; a bottom popup leaves this off, as the
/// taps beside its card reach its own barrier.
class ReadableSheetWidth extends StatelessWidget {
  const new({required this.child, this.closesOnTapBeside = false, super.key});

  final Widget child;
  final bool closesOnTapBeside;

  /// Below this beside the card, the sheet spans the window as on a phone:
  /// slivers of the page at the sides would read as a misplaced sheet.
  static const minMargin = 48.0;

  static const _cardCorners = BorderRadius.vertical(top: Radius.circular(12));

  @override
  Widget build(BuildContext context) {
    final caps = WindowLayout.of(context).capsWidths;
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = ReadableWidth.insetFor(
          available: constraints.maxWidth,
          max: ReadableWidth.sheet,
          caps: caps,
        );
        final card = inset >= minMargin;
        // Like the barrier of a Cupertino popup, no stop for a screen
        // reader.
        final beside = ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.maybePop(context),
          ),
        );
        // A Stack in every case, so a resize across the card's threshold
        // keeps the content's state.
        return Stack(
          fit: StackFit.passthrough,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: card ? inset : 0),
              child: ClipRSuperellipse(
                borderRadius: card ? _cardCorners : BorderRadius.zero,
                clipBehavior: card ? Clip.antiAlias : Clip.none,
                child: child,
              ),
            ),
            if (card && closesOnTapBeside) ...[
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: inset,
                child: beside,
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: inset,
                child: beside,
              ),
            ],
          ],
        );
      },
    );
  }
}
