import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

/// "Create a column" after the last column, as wide as a column so that a
/// phone's board still settles from column to column.
class NewColumnTile extends StatelessWidget {
  const new({
    required this.width,
    required this.onPressed,
    this.creating = false,
    super.key,
  });

  final double width;

  /// Null disables it, e.g. while another column change is on its way.
  final VoidCallback? onPressed;
  final bool creating;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: creating ? null : onPressed,
            icon: creating
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      semanticsLabel: l10n.boardColumnSaving,
                    ),
                  )
                : const Icon(Icons.add),
            label: Text(l10n.boardCreateColumn),
            style: TextButton.styleFrom(
              backgroundColor: colors.surfaceContainerLow,
              disabledBackgroundColor: colors.surfaceContainerLow,
              alignment: AlignmentDirectional.centerStart,
              minimumSize: const Size.fromHeight(56),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
