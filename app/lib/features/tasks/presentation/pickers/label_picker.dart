import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/label_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/label_search.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

/// Lets the user tick labels, and create one online unless a link-share
/// guest, whom the server refuses that; Done returns the ticked labels, in
/// the order they were ticked after the [selected] ones. Null when
/// dismissed, which keeps the previous selection.
Future<List<Label>?> pickLabels(
  BuildContext context, {
  required List<Label> selected,
}) => showPickerSheet<List<Label>>(
  context,
  heightFactor: 0.9,
  builder: (context, scrollController) =>
      LabelPicker(selected: selected, scrollController: scrollController),
);

class LabelPicker extends ConsumerStatefulWidget {
  const new({required this.selected, this.scrollController, super.key});

  final List<Label> selected;
  final ScrollController? scrollController;

  @override
  ConsumerState<LabelPicker> createState() => _LabelPickerState();
}

class _LabelPickerState extends ConsumerState<LabelPicker> {
  final _query = TextEditingController();
  final _random = Random();
  late final List<Label> _selected = [...widget.selected];
  bool _creating = false;
  String? _createError;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _isSelected(Label label) => _selected.any((s) => s.id == label.id);

  void _toggle(Label label) => setState(() {
    if (_isSelected(label)) {
      _selected.removeWhere((s) => s.id == label.id);
    } else {
      _selected.add(label);
    }
  });

  Future<void> _create(String title) async {
    final l10n = context.l10n;
    final repository = ref.read(labelRepositoryProvider);
    if (repository == null ||
        _creating ||
        title.runes.length > maxLabelTitleLength) {
      return;
    }
    setState(() {
      _creating = true;
      _createError = null;
    });
    String? error;
    Label? created;
    try {
      created = await repository.create(
        NewLabel(title: title, hexColor: randomLabelColor(_random)),
      );
    } on NetworkFailure catch (failure) {
      // A timeout may come after the server stored the label; the
      // repository looks for it before the next create of this title.
      error = failure.problem == NetworkProblem.timeout
          ? l10n.labelPickerCreateUnconfirmed
          : l10n.labelPickerCreateOffline;
    } on VikunjaFailure catch (failure) {
      error = failure.message.trim().isEmpty
          ? l10n.labelPickerCreateFailed
          : l10n.labelPickerCreateRejected(failure.message.trim());
    } on Object {
      error = l10n.labelPickerCreateFailed;
    }
    if (!mounted) return;
    setState(() {
      _creating = false;
      _createError = error;
      if (created != null && !_isSelected(created)) _selected.add(created);
    });
  }

  /// The stored labels and, so that it still shows, a label of the task
  /// this device has no row for.
  List<Label> _known(List<Label>? stored) => [
    ...?stored,
    for (final label in _selected)
      if (!(stored ?? const []).any((s) => s.id == label.id)) label,
  ];

  /// The keyboard action creates the offered label or ticks the only
  /// match; with nothing to do it closes the keyboard.
  void _submit() {
    final known = _known(ref.read(allLabelsProvider).value);
    final query = _query.text;
    final createTitle = ref.read(activeAccountIsGuestProvider)
        ? null
        : labelTitleToCreate(known, query);
    final shown = filterLabels(known, query);
    if (createTitle != null) {
      unawaited(_create(createTitle));
    } else if (query.trim().isNotEmpty && shown.length == 1) {
      _toggle(shown.single);
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final stored = ref.watch(allLabelsProvider);
    final known = _known(stored.value);
    final query = _query.text;
    final shown = filterLabels(known, query);
    final guest = ref.watch(activeAccountIsGuestProvider);
    final createTitle = guest ? null : labelTitleToCreate(known, query);
    final tooLong =
        createTitle != null && createTitle.runes.length > maxLabelTitleLength;

    // Everything under the header scrolls: with the keyboard up, in
    // landscape or at a large text size, little room is left.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerHeader(
          title: l10n.labelPickerTitle,
          actionLabel: l10n.pickerDone,
          onAction: () => Navigator.of(context).pop(_selected),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.labelPickerSearch,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() => _createError = null),
                  onEditingComplete: _submit,
                ),
              ),
              if (guest)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    l10n.guestLabelPickerNote,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
              if (createTitle != null)
                _CreateRow(
                  title: createTitle,
                  creating: _creating,
                  tooLong: tooLong,
                  onCreate: () => unawaited(_create(createTitle)),
                ),
              if (_createError case final error?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(error, style: TextStyle(color: colors.error)),
                  ),
                ),
              for (final label in shown)
                CheckboxListTile.adaptive(
                  value: _isSelected(label),
                  onChanged: (_) => _toggle(label),
                  secondary: _ColorDot(hexColor: label.hexColor),
                  title: Text(label.title),
                ),
              if (stored.hasValue && known.isEmpty && createTitle == null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.labelPickerEmpty,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CreateRow extends StatelessWidget {
  const new({
    required this.title,
    required this.creating,
    required this.tooLong,
    required this.onCreate,
  });

  final String title;
  final bool creating;
  final bool tooLong;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: creating
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : const Icon(Icons.add),
      title: Text(
        l10n.labelPickerCreate(title),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: switch ((creating, tooLong)) {
        (true, _) => Text(l10n.labelPickerCreating),
        (false, true) => Text(
          l10n.labelPickerTitleTooLong(maxLabelTitleLength),
          style: TextStyle(color: colors.error),
        ),
        _ => null,
      },
      enabled: !creating && !tooLong,
      onTap: onCreate,
    );
  }
}

class _ColorDot extends StatelessWidget {
  const new({required this.hexColor});

  final String hexColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = parseHexColor(hexColor);
    return ExcludeSemantics(
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: color == null ? Border.all(color: colors.outline) : null,
        ),
      ),
    );
  }
}
