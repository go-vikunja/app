import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/status_card.dart';
import 'package:vikunja_mobile/features/onboarding/application/previous_app.dart';

/// "This is the new Vikunja app", on the start that found the previous app.
class PreviousAppNoteCard extends StatelessWidget {
  const new({required this.note, required this.signedIn, super.key});

  final PreviousAppNote note;

  /// The previous app's session was kept.
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return StatusCard(
      icon: Icons.info_outline,
      title: l10n.previousAppNoteTitle,
      body: signedIn
          ? l10n.previousAppNoteSignedIn
          : note.serverFilledIn
          ? l10n.previousAppNoteSignInAgain
          : l10n.previousAppNoteSignIn,
      // Before a sign-in, a tap on such a widget only opens Connect.
      footnote: note.placedWidgets == 0
          ? null
          : signedIn
          ? l10n.previousAppNoteWidgets
          : l10n.previousAppNoteWidgetsAfterSignIn,
      background: colors.secondaryContainer,
      foreground: colors.onSecondaryContainer,
      liveRegion: true,
    );
  }
}
