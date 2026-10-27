import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/common/presentation/settings_section.dart';

/// The Account tab's way to the home-screen widgets, which belong to this
/// device and may show any account.
class WidgetsSection extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsSection(
      title: l10n.widgetsHeading,
      trailing: const OnThisDeviceMark(),
      children: [
        ListTile(
          leading: const Icon(Icons.widgets_outlined),
          title: Text(l10n.widgetsEntryTitle),
          subtitle: Text(l10n.widgetsEntrySubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => unawaited(GoRouter.of(context).push(AppRoutes.widgets)),
        ),
      ],
    );
  }
}
