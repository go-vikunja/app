import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/onboarding/application/browser_sign_in_method.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/widgets/section_heading.dart';

class SignInMethodsSection extends StatelessWidget {
  const new({required this.method, super.key});

  final BrowserSignInMethod method;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final providers = method.openIdProviderNames;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(l10n.signInMethodsHeading),
        Card.outlined(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.open_in_browser),
            title: Text(l10n.signInBrowserTitle),
            subtitle: Text(
              providers.isEmpty
                  ? l10n.signInBrowserSubtitle
                  : l10n.signInBrowserProvidersSubtitle(providers.join(', ')),
            ),
          ),
        ),
      ],
    );
  }
}
