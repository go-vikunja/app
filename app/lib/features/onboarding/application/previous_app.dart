import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/previous_app_sign_in.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_import.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_platform.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_record.dart';
import 'package:vikunja_mobile/features/session/application/session_check.dart';

part 'previous_app.g.dart';

final _log = Logger('PreviousApp');

@Riverpod(keepAlive: true)
PreviousAppPlatform previousAppPlatform(Ref ref) =>
    ChannelPreviousAppPlatform();

@Riverpod(keepAlive: true)
PreviousAppSignIn previousAppSignIn(Ref ref) => PreviousAppSignIn(
  connector: ref.watch(serverConnectorProvider),
  tokenGateway: ref.watch(tokenGatewayProvider),
  accountGateway: ref.watch(accountGatewayProvider),
  tokenStore: ref.watch(tokenStoreProvider),
  registry: ref.watch(accountRegistryProvider),
  sessions: ref.watch(sessionManagersProvider),
);

/// The try to keep the previous app's session, made at most once.
sealed class PreviousAppSession {
  const new();
}

final class PreviousAppSessionUntried extends PreviousAppSession {
  const new();
}

final class PreviousAppSessionKeeping extends PreviousAppSession {
  const new(this.server);

  final Uri server;
}

final class PreviousAppSessionKept extends PreviousAppSession {
  const new(this.accountId);

  final String accountId;
}

final class PreviousAppSessionLost extends PreviousAppSession {
  const new();
}

/// The note on the start that found the previous app.
@immutable
final class PreviousAppNote {
  const new({required this.serverFilledIn, required this.placedWidgets});

  final bool serverFilledIn;
  final int placedWidgets;
}

@immutable
final class PreviousAppState {
  const new({
    this.record,
    this.note,
    this.session = const PreviousAppSessionUntried(),
  });

  /// What Connect fills in, until an account is registered.
  final PreviousAppRecord? record;

  /// Null on later starts and on a fresh install.
  final PreviousAppNote? note;
  final PreviousAppSession session;

  PreviousAppState copyWith({
    PreviousAppRecord? record,
    PreviousAppNote? note,
    PreviousAppSession? session,
  }) => PreviousAppState(
    record: record ?? this.record,
    note: note ?? this.note,
    session: session ?? this.session,
  );

  PreviousAppState withoutRecord() =>
      PreviousAppState(note: note, session: session);
}

/// What this app took over from the previous Vikunja app it replaced on
/// Android, for Connect and the first sync.
@Riverpod(keepAlive: true)
class PreviousApp extends _$PreviousApp {
  var _sessionTried = false;
  var _hasAccounts = false;

  @override
  Future<PreviousAppState> build() async {
    final preferences = ref.watch(preferencesStoreProvider);
    // This loads the registry, which on a first start wipes the secure
    // storage the import reads: bootstrap reads this provider only after
    // the import, and the import never does.
    ref.listen(
      accountsProvider.select(
        (accounts) => accounts.value?.accounts.isNotEmpty ?? false,
      ),
      (_, hasAccounts) {
        _hasAccounts = hasAccounts;
        if (hasAccounts) unawaited(_forgetRecord());
      },
      fireImmediately: true,
    );
    final record = await PreviousAppRecord.read(preferences);
    // An account may have been registered meanwhile.
    return PreviousAppState(record: _hasAccounts ? null : record);
  }

  void noteImported(PreviousAppFindings findings) {
    final current = state.value ?? const PreviousAppState();
    final record = findings.record;
    state = AsyncData(
      current.copyWith(
        record: record,
        note: PreviousAppNote(
          serverFilledIn: record.server != null,
          placedWidgets: record.placedWidgets,
        ),
      ),
    );
  }

  /// Signs in with the previous app's refresh token, once per process and
  /// only with a server to sign in to. Never throws.
  Future<void> keepSession(String refreshToken) async {
    final current = state.value;
    final server = current?.record?.server;
    if (_sessionTried || current == null || server == null) return;
    _sessionTried = true;
    // Before the first await, so that the first frame shows it.
    state = AsyncData(
      current.copyWith(session: PreviousAppSessionKeeping(server)),
    );
    final signIn = ref.read(previousAppSignInProvider);
    PreviousAppSession outcome;
    try {
      final entry = await signIn.signIn(
        serverAddress: '$server',
        refreshToken: refreshToken,
      );
      if (!ref.mounted) return;
      ref.read(sessionCheckProvider).noteVerified(entry.id);
      outcome = PreviousAppSessionKept(entry.id);
    } on Object catch (error) {
      _log.info(
        'Could not keep the previous app session: ${error.runtimeType}',
      );
      outcome = const PreviousAppSessionLost();
    }
    if (!ref.mounted) return;
    state = AsyncData((state.value ?? current).copyWith(session: outcome));
  }

  Future<void> _forgetRecord() async {
    if (state.value case final current? when current.record != null) {
      state = AsyncData(current.withoutRecord());
    }
    try {
      await PreviousAppRecord.remove(ref.read(preferencesStoreProvider));
    } on Object catch (error) {
      _log.warning(
        'Could not remove the previous app record: ${error.runtimeType}',
      );
    }
  }
}
