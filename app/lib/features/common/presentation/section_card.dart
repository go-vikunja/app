import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';

const _margin = EdgeInsets.symmetric(horizontal: 16);
const _headerPadding = EdgeInsetsDirectional.fromSTEB(20, 16, 20, 4);

/// The row's own key keeps its place among the card's rows; a global key
/// must stay with the row alone.
Key? _slotKey(Widget row) => row.key is LocalKey ? row.key : null;

/// A group of rows under an optional [ListSectionHeader]: a rounded card
/// with dividers between the rows. For a long or lazily built list,
/// [SliverSectionCard].
class SectionCard extends StatelessWidget {
  const new({
    required this.children,
    this.title,
    this.count,
    this.trailing,
    this.titleColor,
    this.margin = _margin,
    super.key,
  });

  final List<Widget> children;
  final String? title;
  final int? count;
  final Widget? trailing;
  final Color? titleColor;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          ListSectionHeader(
            title: title,
            count: count,
            trailing: trailing,
            color: titleColor,
            padding: _headerPadding,
          ),
        Padding(
          padding: margin,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++)
                SectionCardItem(
                  key: _slotKey(children[i]),
                  first: i == 0,
                  last: i == children.length - 1,
                  child: children[i],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// [SectionCard] for a [CustomScrollView]: the header and a lazily built
/// list of rows.
class SliverSectionCard extends StatelessWidget {
  const new({
    required this.itemCount,
    required this.itemBuilder,
    this.title,
    this.count,
    this.trailing,
    this.titleColor,
    this.margin = _margin,
    super.key,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final String? title;
  final int? count;
  final Widget? trailing;
  final Color? titleColor;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return SliverMainAxisGroup(
      slivers: [
        if (title != null)
          SliverToBoxAdapter(
            child: ListSectionHeader(
              title: title,
              count: count,
              trailing: trailing,
              color: titleColor,
              padding: _headerPadding,
            ),
          ),
        SliverPadding(
          padding: margin,
          sliver: SliverList.builder(
            itemCount: itemCount,
            itemBuilder: (context, index) {
              final item = itemBuilder(context, index);
              if (item == null) return null;
              return SectionCardItem(
                key: _slotKey(item),
                first: index == 0,
                last: index == itemCount - 1,
                child: item,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One row of a section card: its slice of the card's background, the
/// rounded corners at the card's ends and the divider below all but the
/// last. Its own [Material], so that the row's ink shows on the card.
class SectionCardItem extends StatelessWidget {
  const new({
    required this.child,
    required this.first,
    required this.last,
    super.key,
  });

  final Widget child;
  final bool first;
  final bool last;

  static const radius = Radius.circular(12);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: first ? radius : Radius.zero,
          bottom: last ? radius : Radius.zero,
        ),
      ),
      // Also around the last row: a row that becomes or stops being the
      // last keeps its place in the tree and so its state.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          child,
          if (!last)
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: colors.outlineVariant.withValues(alpha: 0.7),
            ),
        ],
      ),
    );
  }
}
