import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/widgets/status_card.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/failure_message.dart';

class ConnectionErrorCard extends StatelessWidget {
  const new({required this.message, this.action, super.key});

  final FailureMessage message;

  /// What can fix it, such as the server's connection settings.
  final Widget? action;

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
      action: action,
    );
  }
}
