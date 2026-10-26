import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

/// Asks for a shared project's link, typed or pasted: the text once it
/// holds a link share or a registration invite, null when closed.
Future<String?> askForSharedLink(BuildContext context) =>
    showPickerSheet<String>(
      context,
      builder: (context, scrollController) =>
          SharedLinkSheet(scrollController: scrollController),
    );

class SharedLinkSheet extends StatefulWidget {
  const new({this.scrollController, super.key});

  final ScrollController? scrollController;

  @override
  State<SharedLinkSheet> createState() => _SharedLinkSheetState();
}

class _SharedLinkSheetState extends State<SharedLinkSheet> {
  final _link = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  static bool _isOpenable(String text) =>
      parseLinkShareUrl(text) != null || parseInviteLink(text) != null;

  void _open() {
    final text = _link.text.trim();
    if (!_isOpenable(text)) {
      unawaited(HapticFeedback.heavyImpact());
      setState(() => _error = context.l10n.guestLinkInvalid);
      return;
    }
    Navigator.of(context).pop(text);
  }

  Future<void> _paste() async {
    final l10n = context.l10n;
    String? text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    } on PlatformException {
      text = null;
    }
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      setState(() => _error = l10n.guestLinkClipboardEmpty);
      return;
    }
    _link.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() => _error = _isOpenable(text!) ? null : l10n.guestLinkInvalid);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      child: ValueListenableBuilder(
        valueListenable: _link,
        builder: (context, value, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PickerHeader(
              title: l10n.guestOpenSharedLink,
              actionLabel: l10n.guestLinkOpen,
              onAction: value.text.trim().isEmpty ? null : _open,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                l10n.guestLinkExplanation,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                controller: _link,
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                autocorrect: false,
                enableSuggestions: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                minLines: 1,
                maxLines: 3,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _open(),
                decoration: InputDecoration(
                  labelText: l10n.guestLinkLabel,
                  hintText: l10n.guestLinkHint,
                  errorText: _error,
                  errorMaxLines: 4,
                  prefixIcon: const Icon(Icons.link),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => unawaited(_paste()),
                  icon: const Icon(Icons.content_paste),
                  label: Text(l10n.guestLinkPaste),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
