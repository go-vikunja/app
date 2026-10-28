import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/rich_html.dart';

enum DescriptionChoice { mine, web }

/// The queued description [mine] and the server's [web] one above the
/// other, and which of them stays; null when dismissed. Without [web] the
/// server no longer has the task, and only dropping the change is offered.
Future<DescriptionChoice?> showDescriptionConflictSheet(
  BuildContext context, {
  required String mine,
  required String? web,
}) => showPickerSheet<DescriptionChoice>(
  context,
  builder: (context, scrollController) => DescriptionConflictSheet(
    mine: mine,
    web: web,
    scrollController: scrollController,
  ),
);

class DescriptionConflictSheet extends StatelessWidget {
  const new({
    required this.mine,
    required this.web,
    this.scrollController,
    super.key,
  });

  final String mine;
  final String? web;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final web = this.web;
    void choose(DescriptionChoice choice) => Navigator.of(context).pop(choice);
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            headingLevel: 1,
            child: Text(
              l10n.syncProblemCompareTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 16),
          _Version(label: l10n.syncProblemYourVersion, html: mine),
          const SizedBox(height: 16),
          if (web != null)
            _Version(label: l10n.syncProblemWebVersion, html: web)
          else
            Text(l10n.syncProblemWebTaskGone),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => choose(DescriptionChoice.web),
                child: Text(
                  web == null
                      ? l10n.syncProblemDiscard
                      : l10n.syncProblemUseWebs,
                ),
              ),
              if (web != null)
                FilledButton(
                  onPressed: () => choose(DescriptionChoice.mine),
                  child: Text(l10n.syncProblemKeepMine),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Version extends StatelessWidget {
  const new({required this.label, required this.html});

  final String label;
  final String html;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          headingLevel: 2,
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(color: colors.primary),
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            // Only to compare: links open nothing here.
            child: RichHtml(
              html: html,
              onLink: (_) {},
              onTaskLink: (_) {},
              empty: Text(
                context.l10n.syncProblemNoDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
