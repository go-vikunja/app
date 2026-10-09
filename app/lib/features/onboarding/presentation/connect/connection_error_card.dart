import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/failure_message.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/widgets/status_card.dart';

class ConnectionErrorCard extends StatelessWidget {
  const new({required this.message, super.key});

  final FailureMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return StatusCard(
      icon: Icons.error_outline,
      title: message.title,
      body: message.explanation,
      footnote: message.suggestion,
      background: colors.errorContainer,
      foreground: colors.onErrorContainer,
      liveRegion: true,
    );
  }
}
