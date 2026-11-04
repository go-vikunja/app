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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 4.0);

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
    if (_focusNode.hasFocus) {
      return;
    }
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

  void _clearQuery() {
    _controller.clear();
    _debounce?.cancel();
    widget.onSearchChanged('');
    setState(() {});
    _focusNode.requestFocus();
  }

  void _closeSearch() {
    _debounce?.cancel();
    _controller.clear();
    _focusNode.unfocus();
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

  void _onTapOutside(PointerDownEvent _) {
    if (!_searching) {
      return;
    }

    _focusNode.unfocus();
    if (_controller.text.trim().isEmpty) {
      _closeSearch();
    }
  }

  void _onSystemBack() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
      return;
    }
    _closeSearch();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _searching) {
          _onSystemBack();
        }
      },
      child: AppBar(
        leading: _searching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n.closeSearch,
                onPressed: _closeSearch,
              )
            : null,
        title: _searching
            ? Builder(
                builder: (context) {
                  final titleColor = DefaultTextStyle.of(context).style.color;
                  final inputStyle = theme.textTheme.bodyLarge?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  );
                  const strutStyle = StrutStyle(
                    fontSize: 16,
                    height: 1.2,
                    forceStrutHeight: true,
                  );
                  return TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    style: inputStyle,
                    strutStyle: strutStyle,
                    cursorColor: titleColor,
                    textAlignVertical: TextAlignVertical.center,
                    keyboardAppearance: theme.brightness,
                    onTapOutside: _onTapOutside,
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      hintStyle: inputStyle?.copyWith(
                        color: titleColor?.withValues(alpha: 0.55),
                        height: 1.2,
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      suffixIconColor: titleColor,
                      suffixIcon: _controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: l10n.clearSearch,
                              visualDensity: VisualDensity.compact,
                              color: titleColor,
                              onPressed: _clearQuery,
                            )
                          : const SizedBox.shrink(),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 24,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                      _onQueryChanged(value);
                    },
                    onSubmitted: (value) {
                      _debounce?.cancel();
                      _focusNode.unfocus();
                      widget.onSearchChanged(value.trim());
                    },
                  );
                },
              )
            : Text(widget.title),
        actions: [
          if (!_searching)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.search,
              onPressed: _openSearch,
            ),
          if (!_searching) ...?widget.actions,
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: widget.showProgress
              ? LinearProgressIndicator(
                  minHeight: 2,
                  color: theme.colorScheme.primary,
                )
              : const SizedBox(height: 2),
        ),
      ),
    );
  }
}
