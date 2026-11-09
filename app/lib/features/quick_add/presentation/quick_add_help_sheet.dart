import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_spans.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_text_controller.dart';

Future<void> showQuickAddHelp(
  BuildContext context, {
  required QuickAddMagicMode mode,
  required QuickAddPrefixes prefixes,
  required DateTime now,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.75,
    maxChildSize: 0.95,
    builder: (context, scrollController) => QuickAddHelpSheet(
      mode: mode,
      prefixes: prefixes,
      now: now,
      scrollController: scrollController,
    ),
  ),
);

const _monthAbbreviations = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

// The grammar is English only, like on the web, so these stay untranslated.
// The calendar dates are the 27th of next month, so that a copied example
// is never overdue.
List<String> _dateExamples(DateTime now) {
  final date = DateTime(now.year, now.month + 1, 27);
  final month = _monthAbbreviations[date.month - 1];
  final mm = '${date.month}'.padLeft(2, '0');
  return [
    'today',
    'tonight',
    'tomorrow',
    'next monday',
    'this weekend',
    'later this week',
    'later next week',
    'next week',
    'next month',
    'end of month',
    'fri',
    'friday',
    '17th',
    '$month 27',
    '27 $month',
    '27/$mm',
    '${date.year}-$mm-27',
    'in 3 days',
    'in two weeks',
    'in 30 minutes',
  ];
}

const _timeExamples = ['at 15:00', 'at 3pm', '@ 9am'];
const _repeatExamples = [
  'every day',
  'every 2 weeks',
  'each month',
  'daily',
  'weekly',
  'monthly',
  'yearly',
];

/// The Quick Add Magic syntax with examples in the prefixes of [mode].
class QuickAddHelpSheet extends StatelessWidget {
  const new({
    required this.mode,
    required this.prefixes,
    required this.now,
    this.scrollController,
    super.key,
  });

  final QuickAddMagicMode mode;
  final QuickAddPrefixes prefixes;
  final DateTime now;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final example =
        '${l10n.quickAddHelpExampleTask} '
        '${prefixes.label}${l10n.quickAddHelpExampleLabel} '
        '${prefixes.project}${l10n.quickAddHelpExampleProject} '
        '${prefixes.priority}3 tomorrow at 9:00 every week';
    final modeName = switch (mode) {
      QuickAddMagicMode.todoist => 'Todoist',
      _ => 'Vikunja',
    };

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Semantics(
          header: true,
          headingLevel: 1,
          child: Text(
            l10n.quickAddHelpTitle,
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 8),
        Text(l10n.quickAddHelpIntro),
        _Section(
          title: l10n.quickAddHelpExampleTitle,
          children: [_Code(example)],
        ),
        _Section(
          kind: MagicSpanKind.label,
          icon: Icons.label_outline,
          title: l10n.quickAddHelpLabelsTitle,
          children: [
            Text(l10n.quickAddHelpLabelsBody(prefixes.label)),
            _Examples([
              '${prefixes.label}${l10n.quickAddHelpExampleLabel}',
              '${prefixes.label}"${l10n.quickAddHelpExampleLabel} 2"',
            ]),
          ],
        ),
        _Section(
          kind: MagicSpanKind.project,
          icon: Icons.folder_outlined,
          title: l10n.quickAddHelpProjectTitle,
          children: [
            Text(l10n.quickAddHelpProjectBody(prefixes.project)),
            _Examples([
              '${prefixes.project}${l10n.quickAddHelpExampleProject}',
            ]),
          ],
        ),
        _Section(
          kind: MagicSpanKind.priority,
          icon: Icons.flag_outlined,
          title: l10n.quickAddHelpPriorityTitle,
          children: [
            Text(l10n.quickAddHelpPriorityBody(prefixes.priority)),
            _Examples([
              for (var level = 1; level <= 5; level++)
                '${prefixes.priority}$level',
            ]),
          ],
        ),
        _Section(
          kind: MagicSpanKind.assignee,
          icon: Icons.person_add_alt,
          title: l10n.quickAddHelpPeopleTitle,
          children: [
            Text(l10n.quickAddHelpPeopleBody(prefixes.assignee)),
            _Examples(['${prefixes.assignee}alex']),
          ],
        ),
        _Section(
          kind: MagicSpanKind.date,
          icon: Icons.event,
          title: l10n.quickAddHelpDatesTitle,
          children: [
            Text(l10n.quickAddHelpDatesBody),
            _Examples(_dateExamples(now)),
            Text(l10n.quickAddHelpTimesBody),
            const _Examples(_timeExamples),
          ],
        ),
        _Section(
          kind: MagicSpanKind.repeat,
          icon: Icons.repeat,
          title: l10n.quickAddHelpRepeatsTitle,
          children: [
            const _Examples(_repeatExamples),
            Text(l10n.quickAddHelpRepeatsBody),
          ],
        ),
        _Section(
          icon: Icons.info_outline,
          title: l10n.quickAddHelpMoreTitle,
          children: [
            Text(l10n.quickAddHelpEnglish),
            Text(l10n.quickAddHelpQuotes),
            Text(l10n.quickAddHelpLines),
            Text(l10n.quickAddHelpMode(modeName)),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const new({
    required this.title,
    required this.children,
    this.kind,
    this.icon,
  });

  final String title;
  final List<Widget> children;
  final MagicSpanKind? kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = this.kind;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon case final icon?) ...[
                Icon(
                  icon,
                  size: 20,
                  color: kind == null
                      ? theme.colorScheme.onSurfaceVariant
                      : MagicColors.accentOf(context, kind),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Semantics(
                  header: true,
                  headingLevel: 2,
                  child: Text(title, style: theme.textTheme.titleSmall),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final child in children)
            Padding(padding: const EdgeInsets.only(top: 4), child: child),
        ],
      ),
    );
  }
}

class _Examples extends StatelessWidget {
  const new(this.examples);

  final List<String> examples;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [for (final example in examples) _Code(example)],
  );
}

class _Code extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.merge(AppTheme.monospace),
        ),
      ),
    );
  }
}
