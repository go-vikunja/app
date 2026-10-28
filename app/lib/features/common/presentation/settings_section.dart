import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/common/presentation/section_semantics.dart';

/// A group of a settings list: a divider above it (but not above the
/// first, [dividerAbove] false), the header in the primary colour and
/// its tiles, `ListTile`s with a 24 dp outlined leading icon.
class SettingsSection extends StatelessWidget {
  const new({
    required this.title,
    required this.children,
    this.trailing,
    this.dividerAbove = true,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final bool dividerAbove;

  @override
  Widget build(BuildContext context) => SectionSemantics(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dividerAbove) const Divider(height: 1),
        ListSectionHeader(
          title: title,
          trailing: trailing,
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
        ),
        ...children,
        const SizedBox(height: 8),
      ],
    ),
  );
}
