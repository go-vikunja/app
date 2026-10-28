import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

/// Our own short choice; the web offers a full emoji picker instead.
@visibleForTesting
const quickReactions = ['👍', '👎', '😄', '🎉', '😕', '❤️', '🚀', '👀'];

/// A reaction to add: one of [quickReactions] or what the user types in
/// the field below them (the system keyboard has every emoji), up to the
/// server's 20 code points; null when dismissed.
Future<String?> pickReaction(BuildContext context) => showPickerSheet<String>(
  context,
  builder: (context, scrollController) =>
      _ReactionPicker(scrollController: scrollController),
);

class _ReactionPicker extends StatefulWidget {
  const new({required this.scrollController});

  final ScrollController? scrollController;

  @override
  State<_ReactionPicker> createState() => _ReactionPickerState();
}

class _ReactionPickerState extends State<_ReactionPicker> {
  final _other = TextEditingController();
  bool _tooLong = false;

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  /// Spaces around it would make a reaction of their own on the server.
  String get _typed => _other.text.trim();

  void _addTyped() {
    final value = _typed;
    if (value.isEmpty) return;
    if (value.runes.length > maxReactionLength) {
      setState(() => _tooLong = true);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      controller: widget.scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Semantics(
          header: true,
          headingLevel: 1,
          child: Text(l10n.reactionAdd, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final reaction in quickReactions)
              SizedBox.square(
                dimension: 56,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(reaction),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    reaction,
                    style: const TextStyle(fontSize: 28),
                    textScaler: TextScaler.noScaling,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: _other,
          builder: (context, _) => TextField(
            controller: _other,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_tooLong) setState(() => _tooLong = false);
            },
            onSubmitted: (_) => _addTyped(),
            decoration: InputDecoration(
              labelText: l10n.reactionOther,
              hintText: l10n.reactionOtherHint,
              errorText: _tooLong ? l10n.reactionTooLong : null,
              suffixIcon: IconButton(
                onPressed: _typed.isEmpty ? null : _addTyped,
                tooltip: l10n.reactionOtherAdd,
                icon: const Icon(Icons.add),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
