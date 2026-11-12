import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_sheet.dart';

final class SheetOption<T> {
  const new({
    required this.value,
    required this.label,
    this.selected = false,
    this.destructive = false,
    this.subtitle,
    this.subtitleSemanticsLabel,
  });

  final T value;
  final String label;
  final bool selected;

  /// In the error colour, such as Remove below a list of permissions.
  final bool destructive;

  /// A second line under [label], such as the date a shortcut stands for.
  final String? subtitle;

  /// How screen readers hear [subtitle]; null reads it as written.
  final String? subtitleSemanticsLabel;
}

/// One choice out of [options] in a sheet over the page, the current one
/// checked; null when dismissed. A Cupertino sheet on iOS, a draggable
/// bottom sheet elsewhere, like the project picker.
Future<T?> showOptionSheet<T extends Object>(
  BuildContext context, {
  required String title,
  required List<SheetOption<T>> options,
}) {
  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS || TargetPlatform.macOS:
      return showReadableCupertinoSheet<T>(
        context: context,
        showDragHandle: true,
        scrollableBuilder: (context, scrollController) => Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: _OptionList(
              title: title,
              options: options,
              scrollController: scrollController,
            ),
          ),
        ),
      );
    case _:
      return showModalBottomSheet<T>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, scrollController) => _OptionList(
            title: title,
            options: options,
            scrollController: scrollController,
          ),
        ),
      );
  }
}

class _OptionList<T extends Object> extends StatelessWidget {
  const new({
    required this.title,
    required this.options,
    required this.scrollController,
  });

  final String title;
  final List<SheetOption<T>> options;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      controller: scrollController,
      itemCount: options.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Semantics(
              header: true,
              headingLevel: 1,
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
          );
        }
        final option = options[index - 1];
        final subtitle = option.subtitle;
        return ListTile(
          title: Text(
            option.label,
            style: option.destructive
                ? TextStyle(color: theme.colorScheme.error)
                : null,
          ),
          subtitle: subtitle == null
              ? null
              : Text(subtitle, semanticsLabel: option.subtitleSemanticsLabel),
          selected: option.selected,
          trailing: option.selected ? const Icon(Icons.check) : null,
          onTap: () => Navigator.of(context).pop(option.value),
        );
      },
    );
  }
}
