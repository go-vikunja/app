import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/status_card.dart';
import 'package:vikunja_mobile/core/network/header_rules.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/common/presentation/form_parts.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/connection/presentation/secret_text_field.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/insecure_connection_dialog.dart';

final _log = Logger('HeadersPage');

/// The custom headers sent with every request to [origin], such as a
/// Cloudflare Access service token. The values are masked and, while one
/// is revealed, kept out of screenshots.
class HeadersPage extends ConsumerStatefulWidget {
  const new({required this.origin, super.key});

  final OriginKey origin;

  @override
  ConsumerState<HeadersPage> createState() => _HeadersPageState();
}

class _HeadersPageState extends ConsumerState<HeadersPage> {
  List<_HeaderRow>? _rows;
  HeaderPreset _preset = HeaderPreset.cloudflareAccessServiceToken;
  _LoadFailure? _loadFailure;
  var _busy = false;
  String? _listError;

  OriginKey get _origin => widget.origin;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final row in _rows ?? const <_HeaderRow>[]) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadFailure = null);
    final profiles = ref.read(networkProfilesProvider);
    final Map<String, String> stored;
    try {
      stored = await _storedHeaders(profiles);
    } on ConnectionProfilesDamagedException {
      if (mounted) setState(() => _loadFailure = _LoadFailure.damaged);
      return;
    } on Object catch (error) {
      _log.info('Headers not readable: ${error.runtimeType}');
      if (mounted) setState(() => _loadFailure = _LoadFailure.unavailable);
      return;
    }
    if (!mounted) return;
    final cloudflare = HeaderPreset.cloudflareAccessServiceToken.names;
    final isCloudflare =
        stored.isEmpty ||
        (stored.length == cloudflare.length &&
            cloudflare.every(stored.containsKey));
    setState(() {
      _preset = isCloudflare
          ? HeaderPreset.cloudflareAccessServiceToken
          : HeaderPreset.custom;
      _rows = isCloudflare
          ? [
              for (final name in cloudflare)
                _HeaderRow(name: name, value: stored[name] ?? '', fixed: true),
            ]
          : [
              for (final MapEntry(:key, :value) in stored.entries)
                _HeaderRow(name: key, value: value),
            ];
    });
  }

  /// Names whose values went missing come back empty, to enter again.
  Future<Map<String, String>> _storedHeaders(NetworkProfiles profiles) async {
    try {
      return (await profiles.forOrigin(_origin))?.headers ?? const {};
    } on ConnectionProfileIncompleteException {
      final profile = await profiles.metadataFor(_origin);
      return {
        for (final name in profile?.headerNames ?? const <String>[]) name: '',
      };
    }
  }

  void _choosePreset(HeaderPreset? preset) {
    final rows = _rows;
    if (preset == null || preset == _preset || rows == null) return;
    final values = {for (final row in rows) row.name.text: row.value.text};
    setState(() {
      for (final row in rows) {
        row.dispose();
      }
      _preset = preset;
      _listError = null;
      _rows = switch (preset) {
        HeaderPreset.cloudflareAccessServiceToken => [
          for (final name in preset.names)
            _HeaderRow(name: name, value: values[name] ?? '', fixed: true),
        ],
        HeaderPreset.custom => [
          for (final MapEntry(:key, :value) in values.entries)
            _HeaderRow(name: key, value: value),
        ],
      };
    });
  }

  void _addRow() => setState(() {
    _rows = [...?_rows, _HeaderRow()];
    _listError = null;
  });

  void _removeRow(_HeaderRow row) => setState(() {
    _rows = [...?_rows]..remove(row);
    row.dispose();
    _listError = null;
  });

  String? _problemText(HeaderProblem? problem) {
    final l10n = context.l10n;
    return switch (problem) {
      null => null,
      HeaderProblem.emptyName => l10n.connectionHeaderNameEmpty,
      HeaderProblem.invalidName => l10n.connectionHeaderNameInvalid,
      HeaderProblem.reservedName => l10n.connectionHeaderNameReserved,
      HeaderProblem.duplicateName => l10n.connectionHeaderNameDuplicate,
      HeaderProblem.emptyValue => l10n.connectionHeaderValueEmpty,
      HeaderProblem.nonAscii => l10n.connectionHeaderValueNonAscii,
      HeaderProblem.valueTooLong => l10n.connectionHeaderValueTooLong,
      HeaderProblem.tooManyHeaders => l10n.connectionHeadersTooMany,
    };
  }

  /// Marks every refused field; true when all pass.
  bool _validate(List<_HeaderRow> rows) {
    final seen = <String>{};
    var valid = true;
    for (final row in rows) {
      final name = row.name.text.trim();
      final nameProblem =
          HeaderRules.validateName(name) ??
          (seen.add(name.toLowerCase()) ? null : HeaderProblem.duplicateName);
      final valueProblem = HeaderRules.validateValue(row.value.text);
      row
        ..nameError = _problemText(nameProblem)
        ..valueError = _problemText(valueProblem);
      if (nameProblem != null || valueProblem != null) valid = false;
    }
    final listProblem = rows.length > HeaderRules.maxHeaders
        ? HeaderProblem.tooManyHeaders
        : null;
    _listError = _problemText(listProblem);
    return valid && listProblem == null;
  }

  Future<void> _save() async {
    final rows = _rows;
    if (rows == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final valid = _validate(rows);
    setState(() {});
    if (!valid) {
      final first = [
        _listError,
        for (final row in rows) ...[row.nameError, row.valueError],
      ].nonNulls.firstOrNull;
      if (first != null) announce(context, first);
      return;
    }
    final profiles = ref.read(networkProfilesProvider);
    if (!_origin.isSecure) {
      final profile = ref
          .read(connectionProfileProvider(_origin))
          .value
          ?.profile;
      if (!(profile?.hasCleartextConsent ?? false)) {
        final accepted = await confirmInsecureConnection(
          context,
          rootUri: _origin.uri,
        );
        if (!accepted || !mounted) return;
        if (!await _store(() => profiles.consentToCleartext(_origin))) return;
      }
    }
    final headers = {
      for (final row in rows)
        row.name.text.trim(): HeaderRules.normalizeValue(row.value.text),
    };
    if (await _store(() => profiles.setHeaders(_origin, headers)) && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _store(Future<void> Function() change) async {
    setState(() => _busy = true);
    try {
      await change();
      return true;
    } on Object catch (error) {
      _log.warning('Storing the headers failed: ${error.runtimeType}');
      if (mounted) {
        final message = context.l10n.connectionSaveFailed;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final rows = _rows;
    final listError = _listError;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.connectionHeadersHeading),
        bottom: SavingProgressBar(saving: _busy),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text('$_origin', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l10n.connectionHeadersIntro('$_origin')),
            if (!_origin.isSecure) ...[
              const SizedBox(height: 12),
              ListNote(
                icon: Icons.warning_amber_outlined,
                text: l10n.connectionHeadersUnencrypted,
              ),
            ],
            const SizedBox(height: 8),
            if (_loadFailure case final failure?)
              StatusCard(
                icon: Icons.error_outline,
                title: switch (failure) {
                  _LoadFailure.unavailable => l10n.connectionProfileLockedTitle,
                  _LoadFailure.damaged => l10n.connectionProfileDamagedTitle,
                },
                body: switch (failure) {
                  _LoadFailure.unavailable => l10n.connectionNotAvailableBody,
                  _LoadFailure.damaged =>
                    l10n.connectionProfileDamagedExplanation,
                },
                background: colors.errorContainer,
                foreground: colors.onErrorContainer,
                liveRegion: true,
                action: TextButton(
                  onPressed: () => unawaited(_load()),
                  child: Text(l10n.retry),
                ),
              )
            else if (rows == null)
              LoadingPlaceholder(label: l10n.connectionHeadersHeading)
            else ...[
              RadioGroup<HeaderPreset>(
                groupValue: _preset,
                onChanged: _busy ? (_) {} : _choosePreset,
                child: Column(
                  children: [
                    RadioListTile<HeaderPreset>.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: HeaderPreset.cloudflareAccessServiceToken,
                      title: Text(l10n.connectionHeaderPresetCloudflare),
                    ),
                    RadioListTile<HeaderPreset>.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: HeaderPreset.custom,
                      title: Text(l10n.connectionHeaderPresetCustom),
                    ),
                  ],
                ),
              ),
              for (final (index, row) in rows.indexed)
                _HeaderFields(
                  key: ObjectKey(row),
                  row: row,
                  enabled: !_busy,
                  last: index == rows.length - 1,
                  onRemove: row.fixed ? null : () => _removeRow(row),
                  onSubmitted: () => unawaited(_save()),
                ),
              if (_preset == HeaderPreset.custom)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _busy || rows.length >= HeaderRules.maxHeaders
                        ? null
                        : _addRow,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.connectionAddHeader),
                  ),
                ),
              if (listError != null) FormErrorText(listError),
              const SizedBox(height: 16),
              ListNote(
                icon: Icons.info_outline,
                text: l10n.connectionServiceTokenHint,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : () => unawaited(_save()),
                child: Text(l10n.connectionSave),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _HeaderRow {
  new({String name = '', String value = '', this.fixed = false})
    : name = TextEditingController(text: name),
      value = TextEditingController(text: value);

  final TextEditingController name;
  final TextEditingController value;

  /// A preset's name, which the user only gives a value.
  final bool fixed;
  String? nameError;
  String? valueError;

  void dispose() {
    name.dispose();
    value.dispose();
  }
}

class _HeaderFields extends StatefulWidget {
  const new({
    required this.row,
    required this.enabled,
    required this.last,
    required this.onRemove,
    required this.onSubmitted,
    super.key,
  });

  final _HeaderRow row;
  final bool enabled;
  final bool last;
  final VoidCallback? onRemove;
  final VoidCallback onSubmitted;

  @override
  State<_HeaderFields> createState() => _HeaderFieldsState();
}

class _HeaderFieldsState extends State<_HeaderFields> {
  _HeaderRow get _row => widget.row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_row.fixed)
            Semantics(
              header: true,
              child: Text(_row.name.text, style: theme.textTheme.titleSmall),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _row.name,
                    enabled: widget.enabled,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      if (_row.nameError != null) {
                        setState(() => _row.nameError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: l10n.connectionHeaderName,
                      errorText: _row.nameError,
                      errorMaxLines: 4,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.connectionRemoveHeader,
                  onPressed: widget.enabled ? widget.onRemove : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          const SizedBox(height: 8),
          SecretTextField(
            controller: _row.value,
            label: _row.fixed ? _row.name.text : l10n.connectionHeaderValue,
            revealTooltip: l10n.connectionShowValue,
            hideTooltip: l10n.connectionHideValue,
            errorText: _row.valueError,
            enabled: widget.enabled,
            textInputAction: widget.last
                ? TextInputAction.done
                : TextInputAction.next,
            onChanged: (_) {
              if (_row.valueError != null) {
                setState(() => _row.valueError = null);
              }
            },
            onSubmitted: widget.last ? (_) => widget.onSubmitted() : null,
          ),
        ],
      ),
    );
  }
}

enum _LoadFailure { unavailable, damaged }
