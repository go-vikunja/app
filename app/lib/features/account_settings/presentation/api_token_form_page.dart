import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/core/repositories/account_security_repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/account_settings/application/api_token_expiry.dart';
import 'package:vikunja_mobile/features/account_settings/application/api_token_permissions.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_security_failure.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/one_time_secret_view.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/permission_group_tile.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/common/presentation/app_bar_text_action.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/day_picker.dart';
import 'package:vikunja_mobile/features/common/presentation/form_parts.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_confirmations.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';

final _log = Logger('ApiTokenForm');

/// A new API token as the web makes it: a title, an expiry of 30, 60 or 90
/// days or through a day picked, and the permissions this server offers,
/// with the web's presets and a checkbox per group. Create waits for the
/// server; its answer turns the page into the token's one-time view.
class ApiTokenFormPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ApiTokenFormPage> createState() => _ApiTokenFormPageState();
}

class _ApiTokenFormPageState extends ConsumerState<ApiTokenFormPage> {
  final _title = TextEditingController();
  bool _titleTouched = false;
  ApiTokenExpiryChoice _expiry = ApiTokenExpiryChoice.days30;
  DateTime? _customDay;

  ApiPermissionGroups? _offered;
  Object? _loadFailure;
  final _selected = <String, Set<String>>{};
  final _expanded = <String>{};

  bool _saving = false;
  String? _error;

  /// The new token's value, from the create answer until this page goes.
  String? _secret;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _title.dispose();
    _secret = null;
    super.dispose();
  }

  Future<void> _load() async {
    final repository = ref.read(accountSecurityRepositoryProvider);
    if (repository == null) return;
    setState(() => _loadFailure = null);
    try {
      final offered = await repository.apiPermissions();
      if (mounted) setState(() => _offered = offered);
    } on Object catch (error) {
      _log.info('Reading the token permissions failed: ${error.runtimeType}');
      if (mounted) setState(() => _loadFailure = error);
    }
  }

  DateTime get _now => ref.read(clockProvider)();

  bool get _hasTitle => _title.text.trim().isNotEmpty;

  bool get _hasPermission => _selected.values.any((names) => names.isNotEmpty);

  bool get _expiryValid => switch (_expiry) {
    ApiTokenExpiryChoice.custom => switch (_customDay) {
      final day? => isCustomExpiryValid(day, _now),
      null => false,
    },
    _ => true,
  };

  bool get _dirty => _hasTitle || _hasPermission;

  bool get _canCreate =>
      !_saving &&
      _offered != null &&
      _hasTitle &&
      _hasPermission &&
      _expiryValid;

  DateTime _expiresAt() => switch (_expiry) {
    ApiTokenExpiryChoice(:final days?) => presetExpiry(days, _now),
    _ => endOfDay(_customDay!),
  };

  void _applyPreset(ApiTokenPreset preset) {
    final offered = _offered;
    if (offered == null) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(presetSelection(preset, offered));
      _error = null;
    });
  }

  void _setGroup(String group, bool all) {
    final names = _offered?.groups[group] ?? const <String>[];
    setState(() {
      _selected[group] = all ? {...names} : <String>{};
      _error = null;
    });
  }

  void _setPermission(String group, String permission, {required bool picked}) {
    setState(() {
      final names = _selected.putIfAbsent(group, () => <String>{});
      if (picked) {
        names.add(permission);
      } else {
        names.remove(permission);
      }
      _error = null;
    });
  }

  Future<void> _chooseExpiry() async {
    final l10n = context.l10n;
    // Otherwise the closing sheet hands focus back to the title and the
    // keyboard covers the permissions.
    FocusScope.of(context).unfocus();
    final picked = await showOptionSheet<ApiTokenExpiryChoice>(
      context,
      title: l10n.apiTokenFormExpiry,
      options: [
        for (final choice in ApiTokenExpiryChoice.values)
          SheetOption(
            value: choice,
            label: switch (choice.days) {
              final days? => l10n.apiTokenFormExpiryDays(days),
              null => l10n.apiTokenFormExpiryCustom,
            },
            selected: choice == _expiry,
          ),
      ],
    );
    if (picked == null || !mounted) return;
    if (picked != ApiTokenExpiryChoice.custom) {
      setState(() => _expiry = picked);
      return;
    }
    final now = _now;
    // Starts from what the preset would have given, as on the web.
    final initial = _customDay ?? presetExpiry(_expiry.days ?? 30, now);
    final display = ref.read(displaySettingsProvider);
    final day = await pickDay(
      context,
      initial: initial,
      first: now,
      last: DateTime(now.year + 50, 12, 31),
      now: now,
      firstDayOfWeekIndex: display.firstDayOfWeekIndex,
      title: l10n.apiTokenFormExpiryPick,
    );
    if (day == null || !mounted) return;
    setState(() {
      _expiry = ApiTokenExpiryChoice.custom;
      _customDay = day;
    });
  }

  Future<void> _create() async {
    final repository = ref.read(accountSecurityRepositoryProvider);
    final offered = _offered;
    if (repository == null || offered == null || !_canCreate) return;
    final l10n = context.l10n;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await repository.createApiToken(
        NewApiToken(
          title: _title.text.trim(),
          permissions: selectedPermissions(offered, _selected),
          expiresAt: _expiresAt().toUtc(),
        ),
      );
      if (!mounted) return;
      unawaited(HapticFeedback.selectionClick());
      setState(() => _secret = created.secret);
      // The page stays and its Create button goes, so nothing else tells a
      // screen reader that the token now shows, and only now.
      announce(
        context,
        '${l10n.oneTimeSecretApiTitle} ${l10n.oneTimeSecretOnce}',
      );
    } on Object catch (error) {
      _log.warning('Creating an API token failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      if (mounted) {
        setState(() => _error = accountSecurityFailureText(l10n, error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leaveIfConfirmed() async {
    final navigator = Navigator.of(context);
    final discard = await confirmDiscardChanges(
      context,
      body: context.l10n.apiTokenFormDiscardBody,
    );
    if (discard && mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final secret = _secret;
    if (secret != null) {
      return Scaffold(
        appBar: AppBar(title: ScreenTitle(l10n.apiTokenFormTitle)),
        body: SafeArea(
          top: false,
          child: OneTimeSecretView(
            secret: secret,
            title: l10n.oneTimeSecretApiTitle,
            usage: l10n.oneTimeSecretApiUsage,
          ),
        ),
      );
    }
    final offered = _offered;
    final loadFailure = _loadFailure;
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) unawaited(_leaveIfConfirmed());
      },
      child: Scaffold(
        appBar: AppBar(
          title: ScreenTitle(l10n.apiTokenFormTitle),
          actions: [
            AppBarTextAction(
              onPressed: _canCreate ? () => unawaited(_create()) : null,
              child: Text(
                _saving ? l10n.apiTokenFormCreating : l10n.apiTokenFormCreate,
              ),
            ),
            const SizedBox(width: 8),
          ],
          bottom: _saving
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(4),
                  child: LinearProgressIndicator(),
                )
              : null,
        ),
        body: switch ((offered, loadFailure)) {
          (final offered?, _) => _form(context, offered),
          (_, final failure?) => CenteredScrollView(
            maxWidth: ReadableWidth.form,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DataFailureCard(
                error: failure,
                stale: false,
                onRetry: () => unawaited(_load()),
              ),
            ),
          ),
          _ => CenteredScrollView(
            maxWidth: ReadableWidth.form,
            child: LoadingPlaceholder(label: l10n.apiTokenFormLoading),
          ),
        },
      ),
    );
  }

  Widget _form(BuildContext context, ApiPermissionGroups offered) {
    final error = _error;
    // A refusal stays in view above the list, which is usually scrolled
    // down to the permissions when Create is tapped.
    return SafeArea(
      top: false,
      bottom: false,
      child: ReadableWidth.builder(
        maxWidth: ReadableWidth.form,
        builder: (_, _, inset) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null)
              Padding(
                padding: EdgeInsets.fromLTRB(inset, 0, inset, 8),
                child: FormErrorText(error),
              ),
            Expanded(child: _fields(context, offered, inset)),
          ],
        ),
      ),
    );
  }

  Widget _fields(
    BuildContext context,
    ApiPermissionGroups offered,
    double inset,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = _now;
    final dateFormat = intl.DateFormat.yMMMd(l10n.localeName);
    final enabled = !_saving;
    final expiryLabel = switch ((_expiry, _customDay)) {
      (ApiTokenExpiryChoice(:final days?), _) =>
        '${l10n.apiTokenFormExpiryDays(days)} · '
            '${dateFormat.format(presetExpiry(days, now))}',
      (_, final day?) => l10n.apiTokenFormExpiryThrough(dateFormat.format(day)),
      _ => l10n.apiTokenFormExpiryCustom,
    };
    return ListView(
      padding: EdgeInsets.fromLTRB(
        inset,
        8,
        inset,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _title,
            enabled: enabled,
            maxLines: null,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [CodePointLimitFormatter(apiTokenTitleMaxLength)],
            decoration: InputDecoration(
              labelText: l10n.apiTokenFormName,
              helperText: l10n.apiTokenFormNameHint,
              helperMaxLines: 3,
              errorText: _titleTouched && !_hasTitle
                  ? l10n.apiTokenFormNameRequired
                  : null,
              errorMaxLines: 3,
            ),
            onChanged: (_) => setState(() {
              _titleTouched = true;
              _error = null;
            }),
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          enabled: enabled,
          leading: Icon(Icons.event_outlined, color: colors.onSurfaceVariant),
          title: Text(l10n.apiTokenFormExpiry),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(expiryLabel),
              if (!_expiryValid)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.apiTokenFormExpiryPast,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.error,
                    ),
                  ),
                ),
            ],
          ),
          trailing: const Icon(Icons.arrow_drop_down),
          onTap: () => unawaited(_chooseExpiry()),
        ),
        FormSectionTitle(l10n.apiTokenFormPermissions),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.apiTokenFormPermissionsHelp,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        if (offered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.apiTokenFormNoPermissions),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              l10n.apiTokenFormPresets,
              style: theme.textTheme.labelLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final preset in ApiTokenPreset.values)
                  ActionChip(
                    onPressed: enabled ? () => _applyPreset(preset) : null,
                    label: Text(_presetLabel(l10n, preset)),
                  ),
              ],
            ),
          ),
          if (!_hasPermission)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                l10n.apiTokenFormPermissionsRequired,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 8),
          for (final group in offered.groupNames)
            PermissionGroupTile(
              key: ValueKey(group),
              group: group,
              permissions: offered.groups[group] ?? const [],
              selected: _selected[group] ?? const {},
              expanded: _expanded.contains(group),
              enabled: enabled,
              onGroupChanged: (all) => _setGroup(group, all),
              onPermissionChanged: (permission, {required selected}) =>
                  _setPermission(group, permission, picked: selected),
              onExpandedChanged: (expanded) => setState(() {
                if (expanded) {
                  _expanded.add(group);
                } else {
                  _expanded.remove(group);
                }
              }),
            ),
        ],
      ],
    );
  }
}

String _presetLabel(AppLocalizations l10n, ApiTokenPreset preset) =>
    switch (preset) {
      ApiTokenPreset.readOnly => l10n.apiTokenPresetReadOnly,
      ApiTokenPreset.tasks => l10n.apiTokenPresetTasks,
      ApiTokenPreset.projects => l10n.apiTokenPresetProjects,
      ApiTokenPreset.fullAccess => l10n.apiTokenPresetFullAccess,
    };
