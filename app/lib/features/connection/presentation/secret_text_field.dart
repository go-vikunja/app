import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/core/platform/secure_display.dart';

/// A field for a header value or a certificate file's password: masked,
/// no suggestions or autofill, paste but no copy or cut, and out of
/// screenshots and the Recents thumbnail while revealed.
class SecretTextField extends ConsumerStatefulWidget {
  const new({
    required this.controller,
    required this.label,
    required this.revealTooltip,
    required this.hideTooltip,
    this.errorText,
    this.helperText,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.focusNode,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String revealTooltip;
  final String hideTooltip;
  final String? errorText;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool enabled;

  @override
  ConsumerState<SecretTextField> createState() => _SecretTextFieldState();
}

class _SecretTextFieldState extends ConsumerState<SecretTextField> {
  SecureHold? _hold;

  bool get _revealed => _hold != null;

  @override
  void dispose() {
    _hold?.release();
    super.dispose();
  }

  void _toggle() => setState(() {
    if (_hold case final hold?) {
      hold.release();
      _hold = null;
    } else {
      _hold = ref.read(secureDisplayProvider).hold();
    }
  });

  Widget _menu(BuildContext context, EditableTextState editable) =>
      AdaptiveTextSelectionToolbar.buttonItems(
        anchors: editable.contextMenuAnchors,
        buttonItems: [
          // Copy, cut, share, look up and web search would all hand the
          // revealed secret to another app.
          for (final item in editable.contextMenuButtonItems)
            if (item.type == ContextMenuButtonType.paste ||
                item.type == ContextMenuButtonType.selectAll ||
                item.type == ContextMenuButtonType.delete)
              item,
        ],
      );

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    focusNode: widget.focusNode,
    enabled: widget.enabled,
    obscureText: !_revealed,
    autocorrect: false,
    enableSuggestions: false,
    // The default is an empty list, which still turns autofill on.
    autofillHints: null,
    enableIMEPersonalizedLearning: false,
    smartDashesType: SmartDashesType.disabled,
    smartQuotesType: SmartQuotesType.disabled,
    keyboardType: TextInputType.visiblePassword,
    textInputAction: widget.textInputAction,
    onChanged: widget.onChanged,
    onSubmitted: widget.onSubmitted,
    contextMenuBuilder: _menu,
    decoration: InputDecoration(
      labelText: widget.label,
      errorText: widget.errorText,
      errorMaxLines: 4,
      helperText: widget.helperText,
      helperMaxLines: 4,
      suffixIcon: IconButton(
        tooltip: _revealed ? widget.hideTooltip : widget.revealTooltip,
        onPressed: widget.enabled ? _toggle : null,
        icon: Icon(
          _revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
    ),
  );
}
