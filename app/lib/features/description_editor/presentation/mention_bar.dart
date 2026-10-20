import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/description_editor/application/mention_suggestions.dart';

/// The people for the `@` being typed, above the keyboard; a tap mentions
/// one. Never taller than [maxHeight], scrolling what does not fit.
class MentionBar extends StatelessWidget {
  const new({
    required this.suggestions,
    required this.onPick,
    required this.maxHeight,
    super.key,
  });

  final MentionSuggestions suggestions;
  final ValueChanged<User> onPick;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final people = suggestions.people;
    final note = suggestions.fromDevice ? l10n.editorMentionsFromDevice : null;
    final status = people.isNotEmpty
        ? null
        : suggestions.searching
        ? l10n.editorMentionsSearching
        : l10n.editorMentionsNone;
    final noteStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Material(
      color: colors.surfaceContainerHigh,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: l10n.editorMentions,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 2,
                child: suggestions.searching
                    ? const LinearProgressIndicator()
                    : null,
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    if (note != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                        child: Text(note, style: noteStyle),
                      ),
                    if (status != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(status, style: noteStyle),
                        ),
                      ),
                    for (final user in people)
                      ListTile(
                        key: ValueKey(('mention', user.username)),
                        dense: true,
                        leading: UserAvatar(user: user, radius: 14),
                        title: Text(user.displayName),
                        subtitle: user.displayName == user.username
                            ? null
                            : Text('@${user.username}'),
                        onTap: () => onPick(user),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
