import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';

/// Up to [max] avatars, overlapping, then "+N" for the rest. Only
/// decoration: the names belong in the enclosing semantics label.
class AvatarStack extends StatelessWidget {
  const new({required this.users, this.max = 3, this.radius = 12, super.key});

  final List<User> users;
  final int max;
  final double radius;

  static double widthOf(int userCount, {int max = 3, double radius = 12}) {
    final circles = userCount > max ? max + 1 : userCount;
    return circles == 0 ? 0 : radius * 2 + (circles - 1) * radius * 1.5;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // The ring takes the colour of what lies below: a card's or the
    // screen's.
    final ring = switch (Material.maybeOf(context)?.color) {
      final Color color when color.a > 0 => color,
      _ => colors.surface,
    };
    final shown = users.take(max).toList();
    final more = users.length - shown.length;
    final diameter = radius * 2;
    final step = radius * 1.5;
    final circles = [
      for (final user in shown) UserAvatar(user: user, radius: radius),
      if (more > 0)
        CircleAvatar(
          radius: radius,
          backgroundColor: colors.surfaceContainerHighest,
          child: Text(
            context.l10n.taskMoreAssignees(more),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textScaler: TextScaler.noScaling,
          ),
        ),
    ];
    return ExcludeSemantics(
      child: SizedBox(
        width: widthOf(users.length, max: max, radius: radius),
        height: diameter,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < circles.length; i++)
              PositionedDirectional(
                start: i * step,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ring, width: 2),
                  ),
                  child: circles[i],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
