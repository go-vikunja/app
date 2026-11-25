import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_sheet.dart';
import 'package:vikunja_mobile/app/widgets/sheet_title.dart';
import 'package:vikunja_mobile/core/text/server_address_display.dart';

enum SharedLinkChoice { open, newTask }

enum SharedLinkKind { project, invite }

/// What to do with a project's link another app shared: open the project
/// as a guest or, with [offerNewTask], make a task of the text as before.
/// Null when the user closes the sheet.
Future<SharedLinkChoice?> askToOpenSharedLink(
  BuildContext context, {
  required ParsedLinkShareUrl link,
  required bool offerNewTask,
}) => _ask(
  context,
  kind: SharedLinkKind.project,
  base: link.base,
  offerNewTask: offerNewTask,
);

/// What to do with an admin's invite another app shared: open it for its
/// check on its server or, with [offerNewTask], make a task of the text.
/// Null when the user closes the sheet.
Future<SharedLinkChoice?> askToOpenSharedInvite(
  BuildContext context, {
  required ParsedInviteLink invite,
  required bool offerNewTask,
}) => _ask(
  context,
  kind: SharedLinkKind.invite,
  base: invite.base,
  offerNewTask: offerNewTask,
);

Future<SharedLinkChoice?> _ask(
  BuildContext context, {
  required SharedLinkKind kind,
  required Uri base,
  required bool offerNewTask,
}) {
  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS || TargetPlatform.macOS:
      return showReadableCupertinoSheet<SharedLinkChoice>(
        context: context,
        showDragHandle: true,
        scrollableBuilder: (context, scrollController) => Material(
          color: Theme.of(context).colorScheme.surface,
          child: OpenSharedLinkSheet(
            kind: kind,
            base: base,
            offerNewTask: offerNewTask,
            scrollController: scrollController,
          ),
        ),
      );
    case _:
      return showModalBottomSheet<SharedLinkChoice>(
        context: context,
        barrierLabel: sheetBarrierLabel(context),
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => OpenSharedLinkSheet(
          kind: kind,
          base: base,
          offerNewTask: offerNewTask,
        ),
      );
  }
}

class OpenSharedLinkSheet extends StatelessWidget {
  const new({
    required this.kind,
    required this.base,
    required this.offerNewTask,
    this.scrollController,
    super.key,
  });

  final SharedLinkKind kind;

  /// The web frontend the link is under; only its host is shown.
  final Uri base;
  final bool offerNewTask;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final host = displayHost(base);
    final (title, body, openLabel, openIcon) = switch (kind) {
      SharedLinkKind.project => (
        l10n.guestShareTitle,
        l10n.guestShareBody(host),
        l10n.guestShareOpen,
        Icons.link,
      ),
      SharedLinkKind.invite => (
        l10n.inviteShareTitle,
        l10n.inviteShareBody(host),
        l10n.inviteShareOpen,
        Icons.mail_outline,
      ),
    };
    void choose(SharedLinkChoice choice) => Navigator.of(context).pop(choice);
    return SafeArea(
      top: false,
      child: ListView(
        controller: scrollController,
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        children: [
          SheetTitle(title),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => choose(SharedLinkChoice.open),
            icon: Icon(openIcon),
            label: Text(openLabel),
          ),
          if (offerNewTask) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => choose(SharedLinkChoice.newTask),
              child: Text(l10n.guestShareNewTask, textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }
}
