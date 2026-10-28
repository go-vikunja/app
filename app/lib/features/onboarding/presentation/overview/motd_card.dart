import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/section_semantics.dart';

class MotdCard extends StatelessWidget {
  const new({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card.filled(
      color: colors.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SectionSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.campaign_outlined, color: colors.tertiary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      header: true,
                      headingLevel: 2,
                      child: Text(
                        context.l10n.motdHeading,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(message, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
