import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_tile.dart';

/// Which of [accounts] a link opens in; null when the user closes the
/// sheet. With one account it asks whether to switch to it. [title] and
/// [body] say what the account is for when it is not a link. A Cupertino
/// sheet on iOS, a modal bottom sheet elsewhere.
Future<String?> pickAccount(
  BuildContext context,
  List<RegisteredAccount> accounts, {
  String? title,
  String? body,
}) {
  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS || TargetPlatform.macOS:
      return showCupertinoSheet<String>(
        context: context,
        showDragHandle: true,
        scrollableBuilder: (context, scrollController) => Material(
          color: Theme.of(context).colorScheme.surface,
          child: AccountPickerSheet(
            accounts: accounts,
            title: title,
            body: body,
            scrollController: scrollController,
          ),
        ),
      );
    case _:
      return showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) =>
            AccountPickerSheet(accounts: accounts, title: title, body: body),
      );
  }
}

class AccountPickerSheet extends StatelessWidget {
  const new({
    required this.accounts,
    this.title,
    this.body,
    this.scrollController,
    super.key,
  });

  final List<RegisteredAccount> accounts;
  final String? title;
  final String? body;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final single = accounts.length == 1;
    return SafeArea(
      top: false,
      child: ListView(
        controller: scrollController,
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Semantics(
              header: true,
              headingLevel: 1,
              child: Text(
                title ??
                    (single
                        ? l10n.deepLinkSwitchAccountTitle
                        : l10n.deepLinkPickAccountTitle),
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              body ??
                  (single
                      ? l10n.deepLinkSwitchAccountBody
                      : l10n.deepLinkPickAccountBody),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final entry in accounts)
            AccountTile(
              entry: entry,
              onTap: () => Navigator.of(context).pop(entry.id),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            ),
        ],
      ),
    );
  }
}
