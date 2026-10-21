import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';

/// One day of Upcoming's timeline: a date column (the day's number, filled
/// for today, its weekday and a line down to the next day) beside the
/// day's [title] and its task [rows] in a card; without rows "Nothing
/// planned".
class TimelineDay extends StatelessWidget {
  const new({
    required this.day,
    required this.title,
    required this.today,
    required this.rows,
    super.key,
  });

  /// Local midnight.
  final DateTime day;
  final String title;
  final bool today;
  final List<Widget> rows;

  static const _dateColumnWidth = 40.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListSectionHeader(
          title: title,
          count: rows.isEmpty ? null : rows.length,
          padding: const EdgeInsetsDirectional.fromSTEB(4, 2, 4, 4),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: Text(
              l10n.upcomingNothingPlanned,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        for (var i = 0; i < rows.length; i++)
          SectionCardItem(
            key: rows[i].key is LocalKey ? rows[i].key : null,
            first: i == 0,
            last: i == rows.length - 1,
            child: rows[i],
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          if (rows.isNotEmpty)
            PositionedDirectional(
              start: _dateColumnWidth / 2 - 0.5,
              top: 0,
              bottom: 0,
              child: ExcludeSemantics(
                child: SizedBox(
                  width: 1,
                  child: ColoredBox(color: colors.outlineVariant),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DateColumn(day: day, today: today),
                const SizedBox(width: 12),
                Expanded(child: content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The header says the date; this is its picture, and covers the line
/// behind it.
class _DateColumn extends StatelessWidget {
  const new({required this.day, required this.today});

  final DateTime day;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n.localeName;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ExcludeSemantics(
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: ColoredBox(
          color: colors.surface,
          child: SizedBox(
            width: TimelineDay._dateColumnWidth,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                spacing: 2,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: today ? colors.primary : null,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 36,
                      child: Center(
                        child: Text(
                          intl.DateFormat.d(locale).format(day),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: today ? colors.onPrimary : colors.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    intl.DateFormat.E(locale).format(day),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
