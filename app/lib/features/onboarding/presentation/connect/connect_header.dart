import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

class ConnectHeader extends StatelessWidget {
  const new({this.title, this.tagline, super.key});

  /// The app name and its tagline unless given.
  final String? title;
  final String? tagline;

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
            title ?? context.l10n.appTitle,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tagline ?? context.l10n.connectTagline,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
