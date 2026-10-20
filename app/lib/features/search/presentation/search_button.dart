import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';

/// Opens the search over the shell.
class SearchButton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: () => unawaited(GoRouter.of(context).push(AppRoutes.search)),
    tooltip: context.l10n.search,
    icon: const Icon(Icons.search),
  );
}
