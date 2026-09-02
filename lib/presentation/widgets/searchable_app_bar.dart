import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class SearchableAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final String searchHint;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final List<Widget>? actions;
  final bool showProgress;

  const SearchableAppBar({
    super.key,
    required this.title,
    required this.searchHint,
    required this.searchQuery,
    required this.onSearchChanged,
    this.actions,
    this.showProgress = false,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (showProgress ? 4.0 : 0));

  @override
  State<SearchableAppBar> createState() => _SearchableAppBarState();
}

class _SearchableAppBarState extends State<SearchableAppBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounce;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
    _focusNode = FocusNode();
    _searching = widget.searchQuery.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant SearchableAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _controller.text.trim()) {
      _controller.text = widget.searchQuery;
    }
    if (widget.searchQuery.isNotEmpty && !_searching) {
      _searching = true;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _closeSearch() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _searching = false);
    if (widget.searchQuery.isNotEmpty) {
      widget.onSearchChanged('');
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      widget.onSearchChanged(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppBar(
      title: _searching
          ? TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() {});
                _onQueryChanged(value);
              },
              onSubmitted: (value) {
                _debounce?.cancel();
                widget.onSearchChanged(value.trim());
              },
            )
          : Text(widget.title),
      actions: [
        if (_searching && _controller.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: l10n.clearSearch,
            onPressed: () {
              _controller.clear();
              _debounce?.cancel();
              widget.onSearchChanged('');
              setState(() {});
            },
          ),
        IconButton(
          icon: Icon(_searching ? Icons.close : Icons.search),
          tooltip: _searching ? l10n.closeSearch : l10n.search,
          onPressed: _searching ? _closeSearch : _openSearch,
        ),
        if (!_searching) ...?widget.actions,
      ],
      bottom: widget.showProgress
          ? const PreferredSize(
              preferredSize: Size.fromHeight(4),
              child: LinearProgressIndicator(minHeight: 2),
            )
          : null,
    );
  }
}
