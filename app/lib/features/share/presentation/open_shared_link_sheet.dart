import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';

enum SharedLinkChoice { openAsGuest, newTask }

/// What to do with a project's link another app shared: open the project
/// as a guest or, with [offerNewTask], make a task of the text as before.
/// Null when the user closes the sheet.
Future<SharedLinkChoice?> askToOpenSharedLink(
  BuildContext context, {
  required ParsedLinkShareUrl link,
  required bool offerNewTask,
}) {
  final sheet = OpenSharedLinkSheet(link: link, offerNewTask: offerNewTask);
  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS || TargetPlatform.macOS:
      return showCupertinoSheet<SharedLinkChoice>(
        context: context,
        showDragHandle: true,
        scrollableBuilder: (context, scrollController) => Material(
          color: Theme.of(context).colorScheme.surface,
          child: OpenSharedLinkSheet(
            link: link,
            offerNewTask: offerNewTask,
            scrollController: scrollController,
          ),
        ),
      );
    case _:
      return showModalBottomSheet<SharedLinkChoice>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => sheet,
      );
  }
}

class OpenSharedLinkSheet extends StatelessWidget {
  const new({
    required this.link,
    required this.offerNewTask,
    this.scrollController,
    super.key,
  });

  final ParsedLinkShareUrl link;
  final bool offerNewTask;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    void choose(SharedLinkChoice choice) => Navigator.of(context).pop(choice);
    return SafeArea(
      top: false,
      child: ListView(
        controller: scrollController,
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        children: [
          Semantics(
            header: true,
            headingLevel: 1,
            child: Text(
              l10n.guestShareTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.guestShareBody(displayHost(link.base)),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => choose(SharedLinkChoice.openAsGuest),
            icon: const Icon(Icons.link),
            label: Text(l10n.guestShareOpen),
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
