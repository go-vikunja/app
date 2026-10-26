import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/initials_avatar.dart';

/// What sets a team apart for the user: Admin when the user administers
/// it, Public while the server has public teams on, and who manages an
/// external team.
List<Widget> teamBadges(
  AppLocalizations l10n,
  Team team, {
  required bool admin,
  required bool publicTeams,
}) {
  final provider = team.isExternal ? externalTeamProvider(team.name) : null;
  return [
    if (admin)
      TeamBadge(icon: Icons.shield_outlined, label: l10n.teamAdminBadge),
    if (publicTeams && team.isPublic)
      TeamBadge(icon: Icons.public, label: l10n.teamPublicBadge),
    if (team.isExternal)
      TeamBadge(
        icon: Icons.sync_lock_outlined,
        label: provider == null
            ? l10n.teamManagedExternally
            : l10n.teamManagedBy(provider),
      ),
  ];
}

/// A team's initials in a circle, without the provider an external team's
/// name ends in. Share rows know only the name, so any such suffix goes:
/// its bracket would make an initial.
class TeamAvatar extends StatelessWidget {
  const new({required this.name, this.radius = 20, super.key});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final name = this.name.trim();
    final shown = externalTeamProvider(name) == null
        ? name
        : name.substring(0, name.lastIndexOf('(')).trim();
    return InitialsAvatar(name: shown, radius: radius, primary: true);
  }
}

class TeamBadge extends StatelessWidget {
  const new({required this.label, this.icon, super.key});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final icon = this.icon;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.secondaryContainer,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              ExcludeSemantics(
                child: Icon(icon, size: 14, color: colors.onSecondaryContainer),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
