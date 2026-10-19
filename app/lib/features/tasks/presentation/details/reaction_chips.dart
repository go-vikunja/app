import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/application/account_context_providers.dart';

/// Who reacted with [reaction], the way the web's tooltip says it: one
/// name, up to ten names, or the first ten and how many more.
String reactionLabel(AppLocalizations l10n, String reaction, List<User> users) {
  final names = [for (final user in users) user.displayName];
  return switch (names.length) {
    0 => reaction,
    1 => l10n.reactionByOne(names.single, reaction),
    <= 10 => l10n.reactionBySeveral(
      names.sublist(0, names.length - 1).join(', '),
      names.last,
      reaction,
    ),
    _ => l10n.reactionByMany(
      names.take(10).join(', '),
      names.length - 10,
      reaction,
    ),
  };
}

/// The reactions to a task or comment, "👍 2" each, highlighted where the
/// signed-in user reacted; read-only until reacting arrives.
class ReactionChips extends ConsumerWidget {
  const new({required this.reactions, super.key});

  final Reactions reactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final me = ref.watch(activeUserIdProvider);
    final entries = reactions.entries.where((entry) => entry.value.isNotEmpty);
    if (entries.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final MapEntry(key: reaction, value: users) in entries)
          _ReactionChip(
            text: '$reaction ${users.length}',
            label: reactionLabel(l10n, reaction, users),
            mine: users.any((user) => user.id == me),
            colors: colors,
            style: theme.textTheme.labelLarge,
          ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const new({
    required this.text,
    required this.label,
    required this.mine,
    required this.colors,
    required this.style,
  });

  final String text;
  final String label;
  final bool mine;
  final ColorScheme colors;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    selected: mine,
    label: label,
    excludeSemantics: true,
    child: Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: mine ? colors.primaryContainer : colors.surfaceContainerHigh,
          border: Border.all(
            color: mine ? colors.primary : colors.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: style?.copyWith(
            color: mine ? colors.onPrimaryContainer : colors.onSurface,
          ),
        ),
      ),
    ),
  );
}
