import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_dialog_action.dart';
import 'package:vikunja_mobile/core/platform/secure_display.dart';
import 'package:vikunja_mobile/core/platform/sensitive_clipboard.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';

final _log = Logger('OneTimeSecret');

/// A token's value right after the server made it, the only time it can
/// be seen: copied to a clipboard that keeps it out of previews, kept out
/// of screenshots and the Recents thumbnail while it shows, and asked
/// about once when the user leaves without copying it. The value lives
/// only in this widget and the one that received it.
class OneTimeSecretView extends ConsumerStatefulWidget {
  const new({
    required this.secret,
    required this.title,
    required this.usage,
    super.key,
  });

  final String secret;
  final String title;

  /// How to use it, e.g. as the password of a CalDAV app.
  final String usage;

  @override
  ConsumerState<OneTimeSecretView> createState() => _OneTimeSecretViewState();
}

class _OneTimeSecretViewState extends ConsumerState<OneTimeSecretView> {
  late final SecureHold _secureHold;
  bool _copied = false;
  bool _askedBeforeLeaving = false;
  TextSelection _selection = const TextSelection.collapsed(offset: -1);

  @override
  void initState() {
    super.initState();
    _secureHold = ref.read(secureDisplayProvider).hold();
  }

  @override
  void dispose() {
    _secureHold.release();
    super.dispose();
  }

  Future<void> _copy(String text) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(sensitiveClipboardProvider).copy(text);
    } on Object catch (error) {
      _log.info('Copying a new token failed: ${error.runtimeType}');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.copyToClipboardFailed)));
      return;
    }
    if (!mounted) return;
    if (text == widget.secret) setState(() => _copied = true);
    unawaited(HapticFeedback.selectionClick());
    announce(context, l10n.copiedToClipboard);
  }

  // The selection's own Copy, Share and keyboard shortcut would use the
  // plain clipboard, which Android previews and keyboards remember.
  void _copySelection() {
    if (!_selection.isValid || _selection.isCollapsed) return;
    unawaited(_copy(_selection.textInside(widget.secret)));
  }

  Widget _selectionMenu(BuildContext context, EditableTextState editable) =>
      AdaptiveTextSelectionToolbar.buttonItems(
        anchors: editable.contextMenuAnchors,
        buttonItems: [
          for (final item in editable.contextMenuButtonItems)
            if (item.type == ContextMenuButtonType.copy)
              item.copyWith(
                onPressed: () {
                  editable.hideToolbar();
                  _copySelection();
                },
              )
            else if (item.type == ContextMenuButtonType.selectAll)
              item,
        ],
      );

  Future<void> _confirmLeave() async {
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    setState(() => _askedBeforeLeaving = true);
    final leave = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        scrollable: true,
        title: Text(l10n.oneTimeSecretLeaveTitle),
        content: Text(l10n.oneTimeSecretLeaveBody),
        actions: [
          AdaptiveDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.oneTimeSecretStay),
          ),
          AdaptiveDialogAction(
            onPressed: () => Navigator.of(context).pop(true),
            isDestructive: true,
            child: Text(l10n.oneTimeSecretLeave),
          ),
        ],
      ),
    );
    if ((leave ?? false) && mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PopScope(
      canPop: _copied || _askedBeforeLeaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Semantics(
            header: true,
            child: Text(widget.title, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Semantics(
                label: l10n.oneTimeSecretLabel,
                child: Actions(
                  actions: {
                    CopySelectionTextIntent:
                        CallbackAction<CopySelectionTextIntent>(
                          onInvoke: (_) => _copySelection(),
                        ),
                  },
                  child: SelectableText(
                    widget.secret,
                    style: theme.textTheme.titleMedium?.merge(
                      AppTheme.monospace,
                    ),
                    onSelectionChanged: (selection, _) =>
                        _selection = selection,
                    contextMenuBuilder: _selectionMenu,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: () => unawaited(_copy(widget.secret)),
              icon: Icon(_copied ? Icons.check : Icons.copy),
              label: Text(
                _copied ? l10n.copiedToClipboard : l10n.oneTimeSecretCopy,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(Icons.visibility_off_outlined, color: colors.error),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.oneTimeSecretOnce,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.usage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l10n.oneTimeSecretDone),
            ),
          ),
        ],
      ),
    );
  }
}

/// [OneTimeSecretView] as a page of its own, for a token made without a
/// form.
class OneTimeSecretPage extends StatelessWidget {
  const new({
    required this.pageTitle,
    required this.secret,
    required this.title,
    required this.usage,
    super.key,
  });

  final String pageTitle;
  final String secret;
  final String title;
  final String usage;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(pageTitle)),
    body: SafeArea(
      top: false,
      child: OneTimeSecretView(secret: secret, title: title, usage: usage),
    ),
  );
}
