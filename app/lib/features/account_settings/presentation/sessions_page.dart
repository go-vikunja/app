import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/account_security_repository.dart';
import 'package:vikunja_mobile/core/repositories/account_security_repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_security_failure.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/security_list_body.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/session_labels.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

final _log = Logger('Sessions');

/// Where the account is signed in, read from the server each time, the
/// most recently active first: the device, its address and when it was
/// last active, this device tagged. Every other session can be ended, one
/// or all at once; this device's is ended by signing out.
class SessionsPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends ConsumerState<SessionsPage> {
  List<UserSession>? _sessions;
  String? _currentId;
  Object? _failure;
  bool _loading = false;

  /// The session being ended, or `*` while all others are.
  String? _busy;

  static const _allOthers = '*';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final repository = ref.read(accountSecurityRepositoryProvider);
    if (repository == null || _loading) return;
    setState(() => _loading = true);
    try {
      final sessions = await repository.sessions();
      final currentId = await repository.currentSessionId();
      if (mounted) {
        setState(() {
          _sessions = _newestActiveFirst(sessions);
          _currentId = currentId;
          _failure = null;
        });
      }
    } on Object catch (error) {
      _log.info('Reading the sessions failed: ${error.runtimeType}');
      if (mounted) setState(() => _failure = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showFailure(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _end(UserSession session, String device) async {
    final repository = ref.read(accountSecurityRepositoryProvider);
    if (repository == null || _busy != null) return;
    final l10n = context.l10n;
    final confirmed = await confirmAdaptive(
      context,
      title: l10n.sessionsEndTitle,
      body: l10n.sessionsEndBody(device),
      confirmLabel: l10n.sessionsEnd,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = session.id);
    try {
      await repository.revokeSession(session.id);
      if (!mounted) return;
      setState(
        () => _sessions = _sessions
            ?.where((each) => each.id != session.id)
            .toList(),
      );
      unawaited(HapticFeedback.selectionClick());
      announce(context, l10n.sessionsEnded);
    } on Object catch (error) {
      _log.warning('Ending a session failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      if (mounted) _showFailure(accountSecurityFailureText(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _endOthers(int count) async {
    final repository = ref.read(accountSecurityRepositoryProvider);
    if (repository == null || _busy != null) return;
    final l10n = context.l10n;
    final confirmed = await confirmAdaptive(
      context,
      title: l10n.sessionsEndOthersTitle,
      body: l10n.sessionsEndOthersBody(count),
      confirmLabel: l10n.sessionsEndOthers,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = _allOthers);
    try {
      final ended = await repository.revokeOtherSessions();
      if (!mounted) return;
      unawaited(HapticFeedback.selectionClick());
      announce(context, l10n.sessionsEndedOthers(ended));
    } on OtherSessionsNotAllEnded catch (partial) {
      _log.warning(
        'Ending the other sessions stopped after ${partial.ended}: '
        '${partial.failure.runtimeType}',
      );
      unawaited(HapticFeedback.heavyImpact());
      if (mounted) {
        _showFailure(
          '${l10n.sessionsNotAllEnded(partial.ended, partial.notEnded)} '
          '${accountSecurityFailureText(l10n, partial.failure)}',
        );
      }
    } on Object catch (error) {
      _log.warning('Ending the other sessions failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      if (mounted) _showFailure(accountSecurityFailureText(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
    if (mounted) await _load();
  }

  Future<void> _showDetails(
    UserSession session,
    DeviceDescription device,
  ) async {
    final current = session.id == _currentId;
    final line = sessionDeviceLine(context.l10n, device);
    final end = await showPickerSheet<bool>(
      context,
      builder: (context, scrollController) => _SessionDetails(
        session: session,
        device: device,
        current: current,
        scrollController: scrollController,
        canEnd: !current && _busy == null,
      ),
    );
    if ((end ?? false) && mounted) await _end(session, line);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatter = MomentFormatter.watch(context, ref);
    final now = ref.watch(clockProvider)();
    final sessions = _sessions;
    final others = [
      for (final session in sessions ?? const <UserSession>[])
        if (session.id != _currentId) session,
    ];
    final busy = _busy != null;
    return Scaffold(
      appBar: AppBar(
        title: ScreenTitle(l10n.sessionsTitle),
        actions: [
          RefreshButton(onPressed: _loading ? null : () => unawaited(_load())),
        ],
      ),
      body: SecurityListBody(
        loading: _loading && sessions == null,
        loadingLabel: l10n.sessionsLoading,
        failure: _failure,
        hasData: sessions != null,
        onRefresh: _load,
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            l10n.sessionsIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        footer: switch ((sessions, others)) {
          (null, _) => null,
          (_, []) => SecurityEmptyNote(
            icon: Icons.devices_outlined,
            title: l10n.sessionsNoOthers,
            body: l10n.sessionsNoOthersBody,
          ),
          (_, final others) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => unawaited(_endOthers(others.length)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                icon: _busy == _allOthers
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: l10n.accountSecurityWorking,
                        ),
                      )
                    : const Icon(Icons.logout),
                label: Text(l10n.sessionsEndOthers),
              ),
            ),
          ),
        },
        children: [
          for (final session in sessions ?? const <UserSession>[])
            _SessionRow(
              key: ValueKey(session.id),
              session: session,
              device: describeUserAgent(session.deviceInfo),
              current: session.id == _currentId,
              lastActive: switch (session.lastActive ?? session.created) {
                final moment? => l10n.sessionsLastActive(
                  formatter.relative(moment, now: now),
                ),
                null => null,
              },
              busy: _busy == session.id,
              enabled: !busy,
              onTap: _showDetails,
              onEnd: _end,
            ),
        ],
      ),
    );
  }
}

enum _SessionAction { end }

List<UserSession> _newestActiveFirst(List<UserSession> sessions) {
  DateTime when(UserSession session) =>
      session.lastActive ??
      session.created ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  return [...sessions]..sort((a, b) => when(b).compareTo(when(a)));
}

class _SessionRow extends StatelessWidget {
  const new({
    required this.session,
    required this.device,
    required this.current,
    required this.lastActive,
    required this.busy,
    required this.enabled,
    required this.onTap,
    required this.onEnd,
    super.key,
  });

  final UserSession session;
  final DeviceDescription device;
  final bool current;
  final String? lastActive;
  final bool busy;
  final bool enabled;
  final void Function(UserSession session, DeviceDescription device) onTap;
  final void Function(UserSession session, String deviceLine) onEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final line = sessionDeviceLine(l10n, device);
    final details = [
      if (session.ipAddress.isNotEmpty) session.ipAddress,
      ?lastActive,
    ];
    return ListTile(
      enabled: enabled,
      leading: Icon(sessionDeviceIcon(device), color: colors.onSurfaceVariant),
      title: Text(line),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (current)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Text(
                    l10n.sessionsThisDevice,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          for (final detail in details) Text(detail),
        ],
      ),
      onTap: () => onTap(session, device),
      trailing: switch ((busy, current)) {
        (true, _) => SizedBox.square(
          dimension: kMinInteractiveDimension,
          child: Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                semanticsLabel: l10n.accountSecurityWorking,
              ),
            ),
          ),
        ),
        (_, true) => null,
        _ => PopupMenuButton<_SessionAction>(
          tooltip: l10n.sessionsOptionsFor(line),
          enabled: enabled,
          icon: const Icon(Icons.more_vert),
          onSelected: (_) => onEnd(session, line),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _SessionAction.end,
              child: IgnorePointer(
                child: ListTile(
                  leading: Icon(Icons.logout, color: colors.error),
                  title: Text(
                    l10n.sessionsEnd,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ),
            ),
          ],
        ),
      },
    );
  }
}

class _SessionDetails extends ConsumerWidget {
  const new({
    required this.session,
    required this.device,
    required this.current,
    required this.scrollController,
    required this.canEnd,
  });

  final UserSession session;
  final DeviceDescription device;
  final bool current;
  final ScrollController? scrollController;

  /// False for this device's session, which only signing out ends; pops
  /// true for End session.
  final bool canEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final formatter = MomentFormatter.watch(context, ref);
    final now = ref.watch(clockProvider)();
    final created = session.created;
    final lastActive = session.lastActive;
    Widget field(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          SelectableText(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
    return ListView(
      controller: scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Semantics(
          header: true,
          headingLevel: 1,
          child: Text(
            sessionDeviceLine(l10n, device),
            style: theme.textTheme.titleLarge,
          ),
        ),
        if (current)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.sessionsThisDeviceHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (device.raw.isNotEmpty) field(l10n.sessionsDevice, device.raw),
        if (session.ipAddress.isNotEmpty)
          field(l10n.sessionsIpAddress, session.ipAddress),
        if (lastActive != null)
          field(
            l10n.sessionsLastActiveLabel,
            formatter.relative(lastActive, now: now),
          ),
        if (created != null)
          field(l10n.sessionsSignedIn, formatter.absolute(created)),
        if (canEnd) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              style: OutlinedButton.styleFrom(foregroundColor: colors.error),
              icon: const Icon(Icons.logout),
              label: Text(l10n.sessionsEnd),
            ),
          ),
        ],
      ],
    );
  }
}
