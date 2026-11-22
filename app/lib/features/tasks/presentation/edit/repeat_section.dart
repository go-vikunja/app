import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/application/repeat_editor.dart';

String repeatUnitLabel(AppLocalizations l10n, RepeatUnit unit) =>
    switch (unit) {
      RepeatUnit.hours => l10n.repeatUnitHours,
      RepeatUnit.days => l10n.repeatUnitDays,
      RepeatUnit.weeks => l10n.repeatUnitWeeks,
    };

String repeatPresetLabel(AppLocalizations l10n, RepeatPreset preset) =>
    switch (preset) {
      RepeatPreset.daily => l10n.repeatPresetDaily,
      RepeatPreset.weekly => l10n.repeatPresetWeekly,
      RepeatPreset.thirtyDays => l10n.repeatPresetThirtyDays,
    };

/// What the mode chips offer: an interval stands for both of the web's
/// interval modes, whose difference is the switch under the interval.
enum _Choice { never, interval, monthly }

/// The web's repeat editor: Never, an interval or the same day every
/// month. An interval has its amount and unit, the three presets and
/// whether it counts from when the task is done.
class RepeatSection extends StatefulWidget {
  const new({
    required this.value,
    required this.onChanged,
    this.amountKey,
    super.key,
  });

  final RepeatSetting value;

  /// The amount field's key, e.g. to bring its error into view.
  final Key? amountKey;

  /// Gets an updater over the latest setting, so edits in one frame add up.
  final void Function(RepeatSetting Function(RepeatSetting setting) change)
  onChanged;

  @override
  State<RepeatSection> createState() => _RepeatSectionState();
}

class _RepeatSectionState extends State<RepeatSection> {
  late final _amount = TextEditingController(text: '${widget.value.amount}');

  @override
  void didUpdateWidget(RepeatSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A preset or an outside change rewrites the field; typing does not.
    final shown = int.tryParse(_amount.text) ?? 0;
    if (widget.value.amount != shown) {
      _amount.text = '${widget.value.amount}';
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  static _Choice _choiceOf(RepeatSetting setting) => switch (setting.mode) {
    RepeatEditorMode.none => _Choice.never,
    RepeatEditorMode.every ||
    RepeatEditorMode.fromCompletion => _Choice.interval,
    RepeatEditorMode.monthly => _Choice.monthly,
  };

  static RepeatSetting _choose(RepeatSetting setting, _Choice choice) =>
      switch (choice) {
        _Choice.never => setting.copyWith(mode: RepeatEditorMode.none),
        _Choice.interval when setting.usesAmount => setting,
        _Choice.interval => setting.copyWith(mode: RepeatEditorMode.every),
        _Choice.monthly => setting.copyWith(mode: RepeatEditorMode.monthly),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = widget.value;
    final chosen = _choiceOf(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final choice in _Choice.values)
              ChoiceChip(
                label: Text(switch (choice) {
                  _Choice.never => l10n.repeatModeNone,
                  _Choice.interval => l10n.repeatModeEvery,
                  _Choice.monthly => l10n.repeatModeMonthly,
                }),
                selected: choice == chosen,
                onSelected: (_) =>
                    widget.onChanged((setting) => _choose(setting, choice)),
              ),
          ],
        ),
        if (value.usesAmount) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 112,
                child: TextField(
                  key: widget.amountKey,
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.repeatAmountLabel,
                    errorText: value.tooLong
                        ? l10n.repeatAmountTooLarge(
                            RepeatSetting.maxAmount(value.unit),
                          )
                        : value.isValid
                        ? null
                        : l10n.repeatAmountInvalid,
                    errorMaxLines: 5,
                  ),
                  onChanged: (text) => widget.onChanged(
                    (setting) =>
                        setting.copyWith(amount: int.tryParse(text) ?? 0),
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final unit in RepeatUnit.values)
                    ChoiceChip(
                      label: Text(repeatUnitLabel(l10n, unit)),
                      selected: unit == value.unit,
                      onSelected: (_) => widget.onChanged(
                        (setting) => setting.copyWith(unit: unit),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in RepeatPreset.values)
                ActionChip(
                  label: Text(repeatPresetLabel(l10n, preset)),
                  onPressed: () => widget.onChanged(
                    (setting) => setting
                        .withPreset(preset)
                        .copyWith(
                          mode: setting.mode == RepeatEditorMode.fromCompletion
                              ? RepeatEditorMode.fromCompletion
                              : RepeatEditorMode.every,
                        ),
                  ),
                ),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.repeatModeFromCompletion),
            value: value.mode == RepeatEditorMode.fromCompletion,
            onChanged: (fromCompletion) => widget.onChanged(
              (setting) => setting.copyWith(
                mode: fromCompletion
                    ? RepeatEditorMode.fromCompletion
                    : RepeatEditorMode.every,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
