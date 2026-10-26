import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/project_sharing_repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/form_parts.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/form_parts.dart';
import 'package:vikunja_mobile/features/sharing/presentation/share_texts.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

final _log = Logger('LinkShareForm');

/// Asks for a new link's permission, name and password and creates it
/// online. The password lives only in the form's field and the request.
Future<void> createLinkShare(
  BuildContext context, {
  required int projectId,
  required ValueChanged<LinkShare> onCreated,
}) => showPickerSheet<void>(
  context,
  builder: (context, scrollController) => LinkShareFormSheet(
    projectId: projectId,
    onCreated: onCreated,
    scrollController: scrollController,
  ),
);

/// Create waits for the server, closes and calls [onCreated] with the new
/// link, also when the sheet was dragged shut meanwhile; a refusal stays
/// in the sheet.
class LinkShareFormSheet extends ConsumerStatefulWidget {
  const new({
    required this.projectId,
    required this.onCreated,
    this.scrollController,
    super.key,
  });

  final int projectId;
  final ValueChanged<LinkShare> onCreated;
  final ScrollController? scrollController;

  @override
  ConsumerState<LinkShareFormSheet> createState() => _LinkShareFormSheetState();
}

class _LinkShareFormSheetState extends ConsumerState<LinkShareFormSheet> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  Permission _permission = Permission.read;
  var _passwordShown = false;
  var _creating = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickPermission() async {
    final l10n = context.l10n;
    final picked = await showOptionSheet<Permission>(
      context,
      title: l10n.linkShareFormPermission,
      options: [
        for (final permission in Permission.values)
          SheetOption(
            value: permission,
            label: permissionLabel(l10n, permission),
            selected: permission == _permission,
          ),
      ],
    );
    if (picked != null && mounted) setState(() => _permission = picked);
  }

  Future<void> _create() async {
    final repository = ref.read(projectSharingRepositoryProvider);
    if (repository == null || _creating) return;
    final l10n = context.l10n;
    final name = _name.text.trim();
    final password = _password.text;
    final onCreated = widget.onCreated;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final created = await repository.createLinkShare(
        widget.projectId,
        NewLinkShare(
          permission: _permission,
          name: name.isEmpty ? null : name,
          password: password.isEmpty ? null : password,
        ),
      );
      if (mounted) Navigator.of(context).pop();
      onCreated(created);
    } on Object catch (error) {
      _log.warning('Creating a link share failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      final text = shareFailureText(l10n, error, ShareChange.createLink);
      if (!mounted) {
        showFailureAfterClose(messenger, text);
        return;
      }
      setState(() {
        _creating = false;
        _error = text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_creating,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PickerHeader(
              title: l10n.linkShareFormTitle,
              actionLabel: l10n.linkShareFormSubmit,
              onAction: _creating ? null : () => unawaited(_create()),
            ),
            SizedBox(
              height: 4,
              child: _creating ? const LinearProgressIndicator() : null,
            ),
            ListTile(
              enabled: !_creating,
              leading: Icon(
                Icons.admin_panel_settings_outlined,
                color: colors.onSurfaceVariant,
              ),
              title: Text(l10n.linkShareFormPermission),
              subtitle: Text(permissionLabel(l10n, _permission)),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () => unawaited(_pickPermission()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _name,
                enabled: !_creating,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.linkShareFormName,
                  helperText: l10n.linkShareFormNameHelper,
                  helperMaxLines: 3,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                controller: _password,
                enabled: !_creating,
                obscureText: !_passwordShown,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.newPassword],
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.linkShareFormPassword,
                  helperText: l10n.linkShareFormPasswordHelper,
                  helperMaxLines: 3,
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _passwordShown = !_passwordShown),
                    tooltip: _passwordShown
                        ? l10n.linkShareFormHidePassword
                        : l10n.linkShareFormShowPassword,
                    icon: Icon(
                      _passwordShown
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                onSubmitted: (_) => unawaited(_create()),
              ),
            ),
            if (_error case final error?) FormErrorText(error),
          ],
        ),
      ),
    );
  }
}
