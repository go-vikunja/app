import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/home/presentation/account_header.dart';

/// A person's initials in a circle; decoration only, the name is next to it.
class InitialsAvatar extends StatelessWidget {
  const new({required this.user, this.radius = 14, super.key});

  final User user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: colors.secondaryContainer,
        child: Text(
          initialsOf(user.displayName),
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSecondaryContainer,
          ),
          // The circle does not grow with the text.
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }
}
