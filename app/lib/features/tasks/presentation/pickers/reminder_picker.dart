import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/application/date_shortcuts.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/application/reminder_editing.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/date_time_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

/// The web's reminder editor: presets relative to the first date the task
/// has, a custom relative period, or an absolute date and time. [editing]
/// pre-fills the form; [existing] marks the presets already in the list.
/// Null when dismissed.
Future<TaskReminder?> pickReminder(
  BuildContext context, {
  required ReminderDates dates,
  required DateTime now,
  TaskReminder? editing,
  List<TaskReminder> existing = const [],
}) => showPickerSheet<TaskReminder>(
  context,
  builder: (context, scrollController) => ReminderPicker(
    dates: dates,
    now: now,
    editing: editing,
    existing: existing,
    scrollController: scrollController,
  ),
);

String reminderUnitLabel(AppLocalizations l10n, ReminderUnit unit) =>
    switch (unit) {
      ReminderUnit.minutes => l10n.reminderUnitMinutes,
      ReminderUnit.hours => l10n.reminderUnitHours,
      ReminderUnit.days => l10n.reminderUnitDays,
      ReminderUnit.weeks => l10n.reminderUnitWeeks,
    };

String reminderReferenceLabel(
  AppLocalizations l10n,
  ReminderRelativeTo relativeTo,
) => switch (relativeTo) {
  ReminderRelativeTo.dueDate => l10n.reminderRelativeToDueDate,
  ReminderRelativeTo.startDate => l10n.reminderRelativeToStartDate,
  ReminderRelativeTo.endDate => l10n.reminderRelativeToEndDate,
};

class ReminderPicker extends ConsumerStatefulWidget {
  const new({
    required this.dates,
    required this.now,
    this.editing,
    this.existing = const [],
    this.scrollController,
    super.key,
  });

  final ReminderDates dates;
  final DateTime now;
  final TaskReminder? editing;
  final List<TaskReminder> existing;
  final ScrollController? scrollController;

  @override
  ConsumerState<ReminderPicker> createState() => _ReminderPickerState();
}

class _ReminderPickerState extends ConsumerState<ReminderPicker> {
  static const _checkmarkBox = BoxConstraints.tightFor(width: 20, height: 20);

  late final ReminderRelativeTo? _defaultReference = defaultReminderReference(
    widget.dates,
  );
  late bool _custom = widget.editing?.isRelative ?? false;
  late ReminderRelativeTo _relativeTo =
      widget.editing?.relativeTo ??
      _defaultReference ??
      ReminderRelativeTo.dueDate;
  late ReminderPeriodParts _parts = switch (widget.editing) {
    TaskReminder(isRelative: true, :final relativePeriod) =>
      ReminderPeriodParts.fromPeriod(relativePeriod),
    _ => const ReminderPeriodParts(
      amount: 1,
      unit: ReminderUnit.days,
      direction: ReminderDirection.before,
    ),
  };
  late final _amount = TextEditingController(text: '${_parts.amount}');
  bool _amountValid = true;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  TaskReminder get _customReminder =>
      TaskReminder(relativePeriod: _parts.period, relativeTo: _relativeTo);

  String _format(TaskReminder reminder, MomentFormatter formatter) =>
      formatReminder(
        context.l10n,
        reminder,
        formatAbsolute: formatter.absolute,
      );

  Future<void> _pickAbsolute() async {
    final now = widget.now;
    final current = switch (widget.editing) {
      TaskReminder(isRelative: false, reminder: final moment?) => moment,
      _ => dayWithTime(
        DateTime(now.year, now.month, now.day + 1),
        current: null,
        now: now,
      ),
    };
    final picked = await pickDateTime(
      context,
      current: current,
      now: now,
      display: ref.read(displaySettingsProvider),
    );
    if (picked == null || !mounted) return;
    Navigator.of(context).pop(TaskReminder(reminder: picked.toUtc()));
  }

  void _onAmountChanged(String text) {
    final amount = int.tryParse(text);
    setState(() {
      _amountValid = amount != null && amount >= 0;
      if (amount != null && _amountValid) {
        _parts = _parts.copyWith(amount: amount);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = widget.editing == null
        ? l10n.taskEditAddReminder
        : l10n.taskEditEditReminder;
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      child: _custom
          ? _buildCustom(context, title)
          : _buildMenu(context, title),
    );
  }

  Widget _buildMenu(BuildContext context, String title) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final formatter = MomentFormatter.watch(context, ref);
    final reference = _defaultReference;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerHeader(title: title),
        if (reference != null)
          for (final preset in reminderPresets(reference))
            _PresetRow(
              label: _format(preset, formatter),
              instant: switch (reminderInstant(preset, widget.dates)) {
                final instant? => (
                  text: formatter.absolute(instant),
                  spoken: formatter.semanticsLabel(instant),
                ),
                null => null,
              },
              alreadySet:
                  widget.existing.any((r) => sameReminder(r, preset)) &&
                  !(widget.editing != null &&
                      sameReminder(widget.editing!, preset)),
              onTap: () => Navigator.of(context).pop(preset),
            )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              l10n.reminderPickerNoDateHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.tune),
          title: Text(l10n.reminderPickerCustom),
          onTap: () => setState(() => _custom = true),
        ),
        ListTile(
          leading: const Icon(Icons.event),
          title: Text(l10n.reminderPickerDateTime),
          onTap: () => unawaited(_pickAbsolute()),
        ),
      ],
    );
  }

  Widget _buildCustom(BuildContext context, String title) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerHeader(
          title: l10n.reminderPickerCustomTitle,
          leading: IconButton(
            onPressed: () => setState(() => _custom = false),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const BackButtonIcon(),
          ),
          actionLabel: l10n.pickerDone,
          onAction: _amountValid
              ? () => Navigator.of(context).pop(_customReminder)
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.reminderAmountLabel,
                    errorText: _amountValid ? null : l10n.reminderAmountInvalid,
                    errorMaxLines: 5,
                  ),
                  onChanged: _onAmountChanged,
                ),
              ),
              const SizedBox(height: 16),
              _Caption(l10n.reminderUnitCaption),
              _Choices(
                children: [
                  for (final unit in ReminderUnit.values)
                    ChoiceChip(
                      label: Text(reminderUnitLabel(l10n, unit)),
                      selected: _parts.unit == unit,
                      onSelected: (_) =>
                          setState(() => _parts = _parts.copyWith(unit: unit)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _Caption(l10n.reminderDirectionCaption),
              _Choices(
                children: [
                  for (final direction in ReminderDirection.values)
                    ChoiceChip(
                      label: Text(switch (direction) {
                        ReminderDirection.before =>
                          l10n.reminderDirectionBefore,
                        ReminderDirection.after => l10n.reminderDirectionAfter,
                      }),
                      selected: _parts.direction == direction,
                      onSelected: (_) => setState(
                        () => _parts = _parts.copyWith(direction: direction),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _Caption(l10n.reminderRelativeToLabel),
              _Choices(
                children: [
                  for (final relativeTo in ReminderRelativeTo.values)
                    ChoiceChip(
                      // The chip's own one-line style fades "(not set)" out
                      // at large text. A wrapped label needs a checkmark box
                      // of a fixed size: by default it is a square as tall
                      // as the label.
                      avatarBoxConstraints: _checkmarkBox,
                      label: Text(
                        referenceDate(relativeTo, widget.dates) == null
                            ? l10n.reminderRelativeToUnset(
                                reminderReferenceLabel(l10n, relativeTo),
                              )
                            : reminderReferenceLabel(l10n, relativeTo),
                        softWrap: true,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: _relativeTo == relativeTo,
                      onSelected: (_) =>
                          setState(() => _relativeTo = relativeTo),
                    ),
                ],
              ),
              if (_amountValid) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _format(
                      _customReminder,
                      MomentFormatter.watch(context, ref),
                    ),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Caption extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Choices extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);
}

/// A preset the list already has is marked and inert; removing it is the
/// list's job.
class _PresetRow extends StatelessWidget {
  const new({
    required this.label,
    required this.instant,
    required this.alreadySet,
    required this.onTap,
  });

  final String label;

  /// When it fires with the task's dates, and how screen readers say it.
  final ({String text, String? spoken})? instant;
  final bool alreadySet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.alarm, color: colors.onSurfaceVariant),
      title: Text(label),
      subtitle: switch (instant) {
        (:final text, :final spoken) => Text(text, semanticsLabel: spoken),
        null => null,
      },
      trailing: alreadySet
          ? Icon(
              Icons.check,
              semanticLabel: context.l10n.reminderPickerAlreadySet,
            )
          : null,
      selected: alreadySet,
      onTap: alreadySet ? null : onTap,
    );
  }
}
