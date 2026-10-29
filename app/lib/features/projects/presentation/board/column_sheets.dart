import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

/// A column's title, trimmed and never empty; null when dismissed.
Future<String?> showColumnTitleSheet(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String initial = '',
}) => showPickerSheet<String>(
  context,
  builder: (context, scrollController) => ColumnTitleSheet(
    title: title,
    actionLabel: actionLabel,
    initial: initial,
    scrollController: scrollController,
  ),
);

/// The task limit of a column holding [count] tasks: 0 for none, null when
/// dismissed.
Future<int?> showColumnLimitSheet(
  BuildContext context, {
  required int current,
  required int count,
}) => showPickerSheet<int>(
  context,
  builder: (context, scrollController) => ColumnLimitSheet(
    current: current,
    count: count,
    scrollController: scrollController,
  ),
);

class ColumnTitleSheet extends StatefulWidget {
  const new({
    required this.title,
    required this.actionLabel,
    this.initial = '',
    this.scrollController,
    super.key,
  });

  final String title;
  final String actionLabel;
  final String initial;
  final ScrollController? scrollController;

  @override
  State<ColumnTitleSheet> createState() => _ColumnTitleSheetState();
}

class _ColumnTitleSheetState extends State<ColumnTitleSheet> {
  late final _title = TextEditingController(text: widget.initial);
  var _edited = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String get _trimmed => _title.text.trim();

  void _submit() {
    final title = _trimmed;
    if (title.isEmpty) {
      setState(() => _edited = true);
      return;
    }
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final empty = _trimmed.isEmpty;
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickerHeader(
            title: widget.title,
            actionLabel: widget.actionLabel,
            onAction: empty ? null : _submit,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.boardColumnTitleLabel,
                hintText: l10n.boardColumnTitleHint,
                errorText: _edited && empty ? l10n.boardColumnTitleEmpty : null,
                errorMaxLines: 3,
              ),
              onChanged: (_) => setState(() => _edited = true),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ],
      ),
    );
  }
}

class ColumnLimitSheet extends StatefulWidget {
  const new({
    required this.current,
    required this.count,
    this.scrollController,
    super.key,
  });

  final int current;
  final int count;
  final ScrollController? scrollController;

  @override
  State<ColumnLimitSheet> createState() => _ColumnLimitSheetState();
}

class _ColumnLimitSheetState extends State<ColumnLimitSheet> {
  late final _limit = TextEditingController(
    text: widget.current > 0 ? '${widget.current}' : '',
  );

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  int get _value => int.tryParse(_limit.text) ?? 0;

  void _submit() => Navigator.of(context).pop(_value);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final value = _value;
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickerHeader(
            title: l10n.boardColumnLimitTitle,
            actionLabel: l10n.boardColumnSave,
            onAction: _submit,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _limit,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              decoration: InputDecoration(
                labelText: l10n.boardColumnLimitLabel,
                hintText: l10n.boardColumnLimitNotSet,
                helperText: l10n.boardColumnLimitHelp(widget.count),
                helperMaxLines: 10,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
          ),
          if (value > 0 && value < widget.count)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.boardColumnLimitBelowCount,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
