import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/onboarding/application/connect_server_state.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

/// Asks for a shared project's password and hands each try to [submit]; a
/// wrong one keeps the sheet open with a note, anything else closes it.
/// Null when the user closed it. The password lives only in the field and
/// the one request [submit] makes.
Future<SharePasswordOutcome?> askForSharePassword(
  BuildContext context, {
  required Future<SharePasswordOutcome> Function(String password) submit,
}) => showPickerSheet<SharePasswordOutcome>(
  context,
  builder: (context, scrollController) =>
      SharePasswordSheet(submit: submit, scrollController: scrollController),
);

class SharePasswordSheet extends StatefulWidget {
  const new({required this.submit, this.scrollController, super.key});

  final Future<SharePasswordOutcome> Function(String password) submit;
  final ScrollController? scrollController;

  @override
  State<SharePasswordSheet> createState() => _SharePasswordSheetState();
}

class _SharePasswordSheetState extends State<SharePasswordSheet> {
  final _password = TextEditingController();
  final _focus = FocusNode();
  var _shown = false;
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
    setState(() {
      _submitting = true;
      _wrong = false;
    });
    final outcome = await widget.submit(password);
    if (!mounted) return;
    if (outcome != SharePasswordOutcome.wrong) {
      Navigator.of(context).pop(outcome);
      return;
    }
    unawaited(HapticFeedback.heavyImpact());
    announce(context, l10n.guestPasswordWrong);
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
                child: Text(
                  l10n.guestPasswordBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
                    helperText: l10n.guestPasswordNotStored,
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
            ],
          ),
        ),
      ),
    );
  }
}
