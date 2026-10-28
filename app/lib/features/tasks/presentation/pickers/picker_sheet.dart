import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

/// A picker over the page: a Cupertino sheet on iOS, a modal bottom sheet
/// elsewhere, both above the keyboard. With [heightFactor] the content gets
/// that share of the room on Android and must fill it (a search field over
/// a list); without, it takes the height it needs and scrolls itself.
/// [builder] gets the Cupertino sheet's scroll controller, which the
/// content's main scrollable should use so that dragging it down closes
/// the sheet; null on Android.
Future<T?> showPickerSheet<T>(
  BuildContext context, {
  required Widget Function(
    BuildContext context,
    ScrollController? scrollController,
  )
  builder,
  double? heightFactor,
}) {
  Widget aboveKeyboard(BuildContext context, Widget child) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: child,
  );

  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS || TargetPlatform.macOS:
      return showCupertinoSheet<T>(
        context: context,
        showDragHandle: true,
        scrollableBuilder: (context, scrollController) => Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: aboveKeyboard(context, builder(context, scrollController)),
          ),
        ),
      );
    case _:
      return showModalBottomSheet<T>(
        context: context,
        // Over the tab bar, not inside the tab's own navigator.
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => aboveKeyboard(
          context,
          heightFactor == null
              ? builder(context, null)
              : FractionallySizedBox(
                  heightFactor: heightFactor,
                  child: builder(context, null),
                ),
        ),
      );
  }
}

/// The picker's title with its confirming action at the end, where the
/// keyboard cannot cover it; the action is disabled while [onAction] is
/// null. When both do not fit on one line, as at a large text size on a
/// narrow screen, the action moves under the title instead of squeezing it.
class PickerHeader extends StatelessWidget {
  const new({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.leading,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = actionLabel;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        leading == null ? 16 : 4,
        0,
        8,
        4,
      ),
      child: OverflowBar(
        alignment: MainAxisAlignment.spaceBetween,
        overflowAlignment: OverflowBarAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?leading,
              Flexible(
                child: Semantics(
                  header: true,
                  headingLevel: 1,
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ),
            ],
          ),
          if (label != null)
            switch (theme.platform) {
              TargetPlatform.iOS || TargetPlatform.macOS => CupertinoButton(
                onPressed: onAction,
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _ => TextButton(onPressed: onAction, child: Text(label)),
            },
        ],
      ),
    );
  }
}
