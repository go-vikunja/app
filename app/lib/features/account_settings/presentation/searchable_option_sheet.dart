import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/filters/search_index.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

@immutable
final class SearchableOption<T> {
  const new({
    required this.value,
    required this.label,
    this.detail,
    this.searchTerms = const [],
    this.selected = false,
  });

  final T value;
  final String label;

  /// A second line, e.g. a time zone's offset; searched too.
  final String? detail;

  /// Searched besides [label] and [detail], e.g. a time zone's own name
  /// with its underscores.
  final List<String> searchTerms;
  final bool selected;

  /// Ignores case and accents, and a typed `-` finds the `−` offsets are
  /// written with.
  bool matches(String query) {
    final needle = _searchable(query.trim());
    return needle.isEmpty ||
        [
          label,
          ?detail,
          ...searchTerms,
        ].any((text) => _searchable(text).contains(needle));
  }
}

String _searchable(String text) => foldForSearch(text).replaceAll('−', '-');

/// One of a long list of [options] with a search field over it; the
/// [suggested] ones first under [suggestedHeading] while nothing is
/// searched. Null when dismissed.
Future<T?> showSearchableOptionSheet<T extends Object>(
  BuildContext context, {
  required String title,
  required String searchLabel,
  required List<SearchableOption<T>> options,
  List<SearchableOption<T>> suggested = const [],
  String? suggestedHeading,
  String? allHeading,
}) => showPickerSheet<T>(
  context,
  heightFactor: 0.9,
  builder: (context, scrollController) => _SearchableOptionList<T>(
    title: title,
    searchLabel: searchLabel,
    options: options,
    suggested: suggested,
    suggestedHeading: suggestedHeading,
    allHeading: allHeading,
    scrollController: scrollController,
  ),
);

class _SearchableOptionList<T extends Object> extends StatefulWidget {
  const new({
    required this.title,
    required this.searchLabel,
    required this.options,
    required this.suggested,
    required this.suggestedHeading,
    required this.allHeading,
    required this.scrollController,
  });

  final String title;
  final String searchLabel;
  final List<SearchableOption<T>> options;
  final List<SearchableOption<T>> suggested;
  final String? suggestedHeading;
  final String? allHeading;
  final ScrollController? scrollController;

  @override
  State<_SearchableOptionList<T>> createState() =>
      _SearchableOptionListState<T>();
}

class _SearchableOptionListState<T extends Object>
    extends State<_SearchableOptionList<T>> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final query = _query.text;
    final searching = query.trim().isNotEmpty;
    final suggested = searching ? <SearchableOption<T>>[] : widget.suggested;
    final shown = [
      for (final option in widget.options)
        if (option.matches(query)) option,
    ];
    final rows = <Widget Function()>[
      () => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: widget.searchLabel,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
          onEditingComplete: () => FocusScope.of(context).unfocus(),
        ),
      ),
      if (suggested.isNotEmpty) ...[
        if (widget.suggestedHeading case final heading?)
          () => ListSectionHeader(title: heading),
        for (final option in suggested) () => _row(option),
        if (widget.allHeading case final heading?)
          () => ListSectionHeader(title: heading),
      ],
      for (final option in shown) () => _row(option),
      if (shown.isEmpty)
        () => Padding(
          padding: const EdgeInsets.all(16),
          child: Semantics(
            liveRegion: true,
            child: Text(
              l10n.accountSettingsNothingFound,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerHeader(title: widget.title),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: rows.length,
            itemBuilder: (context, index) => rows[index](),
          ),
        ),
      ],
    );
  }

  Widget _row(SearchableOption<T> option) {
    final detail = option.detail;
    return ListTile(
      title: Text(option.label),
      subtitle: detail == null ? null : Text(detail),
      selected: option.selected,
      trailing: option.selected ? const Icon(Icons.check) : null,
      onTap: () => Navigator.of(context).pop(option.value),
    );
  }
}
