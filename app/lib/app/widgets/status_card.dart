import 'package:material_ui/material_ui.dart';

class StatusCard extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    required this.background,
    required this.foreground,
    this.footnote,
    this.liveRegion = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? footnote;
  final Color background;
  final Color foreground;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bodyStyle = textTheme.bodyMedium?.copyWith(color: foreground);
    // Inside the Card, whose semantics container merges the live-region flag
    // and all texts into one node, so the whole card is announced.
    return Card.filled(
      color: background,
      child: Semantics(
        liveRegion: liveRegion,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(color: foreground),
                    ),
                    const SizedBox(height: 4),
                    Text(body, style: bodyStyle),
                    if (footnote case final footnote?) ...[
                      const SizedBox(height: 8),
                      Text(footnote, style: bodyStyle),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
