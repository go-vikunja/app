import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

class ServerAddressField extends StatelessWidget {
  const new({
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
    required this.onChanged,
    this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final VoidCallback onSubmitted;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) => TextFormField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.go,
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        autofillHints: const [AutofillHints.url],
        autovalidateMode: AutovalidateMode.onUserInteractionIfError,
        // Keeps the Continue button above the keyboard, not just the field.
        scrollPadding: const EdgeInsets.only(bottom: 160),
        validator: (text) => text == null || text.trim().isEmpty
            ? l10n.connectAddressEmpty
            : null,
        onChanged: onChanged,
        onFieldSubmitted: (_) => onSubmitted(),
        decoration: InputDecoration(
          labelText: l10n.connectAddressLabel,
          hintText: l10n.connectAddressHint,
          helperText: l10n.connectAddressHelper,
          helperMaxLines: 4,
          errorMaxLines: 4,
          prefixIcon: const Icon(Icons.dns_outlined),
          suffixIcon: value.text.isEmpty || !enabled
              ? null
              : IconButton(
                  tooltip: l10n.connectClearAddress,
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}
