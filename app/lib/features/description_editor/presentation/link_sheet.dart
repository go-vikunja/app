import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

/// What the link sheet asks the editor to do.
@immutable
sealed class LinkEdit {
  const new();
}

final class SetLink extends LinkEdit {
  const new(this.href);

  final String href;
}

final class RemoveLink extends LinkEdit {
  const new();
}

/// The address for the link at the cursor, [href] when it has one; null
/// when dismissed. An emptied address removes the link, as on the web.
Future<LinkEdit?> showLinkSheet(
  BuildContext context, {
  required bool hasLink,
  String href = '',
}) => showPickerSheet<LinkEdit>(
  context,
  builder: (context, scrollController) => LinkSheet(
    href: href,
    hasLink: hasLink,
    scrollController: scrollController,
  ),
);

class LinkSheet extends StatefulWidget {
  const new({
    required this.href,
    required this.hasLink,
    this.scrollController,
    super.key,
  });

  final String href;
  final bool hasLink;
  final ScrollController? scrollController;

  @override
  State<LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<LinkSheet> {
  late final _address = TextEditingController(text: widget.href);

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _apply() {
    final href = _address.text.trim();
    Navigator.of(context)
        .pop(href.isEmpty ? const RemoveLink() : SetLink(href));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canApply = _address.text.trim().isNotEmpty || widget.hasLink;
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickerHeader(
            title: widget.hasLink
                ? l10n.editorLinkEditTitle
                : l10n.editorLinkAddTitle,
            actionLabel: l10n.editorLinkApply,
            onAction: canApply ? _apply : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _address,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.editorLinkAddress,
                hintText: 'https://',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (canApply) _apply();
              },
            ),
          ),
          if (widget.hasLink)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(const RemoveLink()),
                  icon: const Icon(Icons.link_off),
                  label: Text(l10n.editorLinkRemove),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
