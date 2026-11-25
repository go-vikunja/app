import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/text/server_address_display.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/common/presentation/form_parts.dart';
import 'package:vikunja_mobile/features/onboarding/application/connect_server_state.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

typedef SharePasswordSubmit = Future<SharePasswordOutcome> Function(
  String password, {
  required bool remember,
});

/// Asks for a shared project's password and hands each try to [submit]; a
/// wrong one keeps the sheet open with a note, anything else closes it.
/// Null when the user closed it. The password goes in the request [submit]
/// makes, to [serverRoot], whose host the sheet names. Remember starts
/// unchecked, so the password is kept on the device only when the
/// user checks it (decision log: Accounts and sign-in).
Future<SharePasswordOutcome?> askForSharePassword(
  BuildContext context, {
  required Uri serverRoot,
  required SharePasswordSubmit submit,
}) => showPickerSheet<SharePasswordOutcome>(
  context,
  builder: (context, scrollController) => SharePasswordSheet(
    serverRoot: serverRoot,
    submit: submit,
    scrollController: scrollController,
  ),
);

class SharePasswordSheet extends StatefulWidget {
  const new({
    required this.serverRoot,
    required this.submit,
    this.scrollController,
    super.key,
  });

  final Uri serverRoot;
  final SharePasswordSubmit submit;
  final ScrollController? scrollController;

  @override
  State<SharePasswordSheet> createState() => _SharePasswordSheetState();
}

class _SharePasswordSheetState extends State<SharePasswordSheet> {
  final _password = TextEditingController();
  final _focus = FocusNode();
  var _shown = false;
  var _remember = false;
  var _submitting = false;
  var _wrong = false;

  @override
  void dispose() {
    _password.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onEdited(String _) {
    if (_wrong) setState(() => _wrong = false);
  }

  Future<void> _submit() async {
    final password = _password.text;
    if (_submitting || password.isEmpty) return;
    final l10n = context.l10n;
    final announcer = Announcer.of(context);
    // The note stays while the same password is tried again, so that the
    // field does not say it once more; editing the field removes it.
    final noteShown = _wrong;
    final route = ModalRoute.of(context);
    setState(() => _submitting = true);
    final outcome = await widget.submit(password, remember: _remember);
    if (!mounted || !sheetIsOpen(route)) return;
    if (outcome != SharePasswordOutcome.wrong) {
      closeSheet(route, outcome);
      return;
    }
    unawaited(HapticFeedback.heavyImpact());
    // Where the platform cannot announce, a note that appears speaks itself
    // as the field's live region; one that stays does not.
    announcer.say(l10n.guestPasswordWrong, onlyIfPlatformAnnounces: !noteShown);
    _password.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _password.text.length,
    );
    setState(() {
      _submitting = false;
      _wrong = true;
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final noteStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return PopScope(
      canPop: !_submitting,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.only(bottom: 16),
        child: ValueListenableBuilder(
          valueListenable: _password,
          builder: (context, value, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PickerHeader(
                title: l10n.guestPasswordTitle,
                actionLabel: l10n.guestLinkOpen,
                onAction: _submitting || value.text.isEmpty
                    ? null
                    : () => unawaited(_submit()),
              ),
              SizedBox(
                height: 4,
                child: _submitting ? const LinearProgressIndicator() : null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [
                    Text(l10n.guestPasswordBody, style: noteStyle),
                    Text(
                      l10n.guestPasswordSentTo(displayHost(widget.serverRoot)),
                      style: noteStyle,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  controller: _password,
                  focusNode: _focus,
                  autofocus: true,
                  // Read-only rather than disabled, which would drop the
                  // focus that a wrong password is typed again into.
                  readOnly: _submitting,
                  obscureText: !_shown,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: null,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  onChanged: _onEdited,
                  onSubmitted: (_) => unawaited(_submit()),
                  decoration: InputDecoration(
                    labelText: l10n.guestPasswordLabel,
                    errorText: _wrong ? l10n.guestPasswordWrong : null,
                    errorMaxLines: 3,
                    helperText: _remember
                        ? l10n.guestPasswordRemembered
                        : l10n.guestPasswordNotStored,
                    helperMaxLines: 4,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _shown = !_shown),
                      tooltip: _shown
                          ? l10n.linkShareFormHidePassword
                          : l10n.linkShareFormShowPassword,
                      icon: Icon(
                        _shown
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
              ),
              CheckboxListTile.adaptive(
                value: _remember,
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _remember = value ?? false),
                title: Text(l10n.guestPasswordRemember),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
