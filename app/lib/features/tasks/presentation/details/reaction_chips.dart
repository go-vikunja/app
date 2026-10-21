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
/// signed-in user reacted; a long press shows who did. With [onToggle] a
/// tap adds or removes the user's own reaction (ignored while one of that
/// value is [pending]) and [onAdd] offers an "Add reaction" chip; without,
/// the chips are shown disabled, as for a user who may only read.
/// [offline] shows both disabled, saying why.
class ReactionChips extends ConsumerWidget {
  const new({
    required this.reactions,
    this.onToggle,
    this.onAdd,
    this.offline = false,
    this.pending = const {},
    super.key,
  });

  final Reactions reactions;
  final ValueChanged<String>? onToggle;
  final VoidCallback? onAdd;
  final bool offline;
  final Set<String> pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final me = ref.watch(activeUserIdProvider);
    final entries = reactions.entries.where((entry) => entry.value.isNotEmpty);
    final onToggle = offline ? null : this.onToggle;
    final onAdd = this.onAdd;
    final offlineHint = offline && this.onToggle != null
        ? l10n.commentFailedNeedsConnection
        : null;
    if (entries.isEmpty && onAdd == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final MapEntry(key: reaction, value: users) in entries)
          _ReactionChip(
            key: ValueKey(('reaction', reaction)),
            text: '$reaction ${users.length}',
            label: reactionLabel(l10n, reaction, users),
            mine: users.any((user) => user.id == me),
            enabled: onToggle != null,
            offlineHint: offlineHint,
            onTap: onToggle == null || pending.contains(reaction)
                ? null
                : () => onToggle(reaction),
          ),
        if (onAdd != null)
          _AddReactionChip(onTap: offline ? null : onAdd, hint: offlineHint),
      ],
    );
  }
}

/// A 32 dp pill in a 48 dp tall tap target, like a Material chip.
class _ChipFrame extends StatelessWidget {
  const new({
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = StadiumBorder(
      side: BorderSide(
        color: selected ? colors.primary : colors.outlineVariant,
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Center(
        widthFactor: 1,
        child: Opacity(
          opacity: enabled ? 1 : 0.6,
          child: Material(
            color: selected
                ? colors.primaryContainer
                : colors.surfaceContainerHigh,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Center(widthFactor: 1, heightFactor: 1, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const new({
    required this.text,
    required this.label,
    required this.mine,
    required this.enabled,
    required this.offlineHint,
    required this.onTap,
    super.key,
  });

  final String text;
  final String label;
  final bool mine;
  final bool enabled;
  final String? offlineHint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      selected: mine,
      label: label,
      hint: offlineHint,
      onTapHint: enabled
          ? (mine ? l10n.reactionRemoveMine : l10n.reactionAddMine)
          : null,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: _ChipFrame(
          selected: mine,
          enabled: enabled,
          onTap: onTap,
          // Any text up to 20 characters can be a reaction.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: mine ? colors.onPrimaryContainer : colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddReactionChip extends StatelessWidget {
  const new({required this.onTap, required this.hint});

  final VoidCallback? onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      label: l10n.reactionAdd,
      hint: hint,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: l10n.reactionAdd,
        child: _ChipFrame(
          selected: false,
          enabled: onTap != null,
          onTap: onTap,
          child: Icon(
            Icons.add_reaction_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
