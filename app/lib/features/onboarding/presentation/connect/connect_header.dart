import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

class ConnectHeader extends StatelessWidget {
  const new({super.key});

  static const logoAsset = 'assets/branding/logo_mark.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        Image.asset(
          logoAsset,
          width: 72,
          height: 72,
          excludeFromSemantics: true,
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            context.l10n.appTitle,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.connectTagline,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
