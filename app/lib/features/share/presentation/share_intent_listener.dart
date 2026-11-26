import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/security/app_lock_controller.dart';
import 'package:vikunja_mobile/core/share/share_intent_source.dart';
import 'package:vikunja_mobile/core/share/share_providers.dart';
import 'package:vikunja_mobile/features/onboarding/application/connect_server_controller.dart';
import 'package:vikunja_mobile/features/share/presentation/open_shared_link_sheet.dart';
import 'package:vikunja_mobile/features/share/presentation/share_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/account_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/task_opener.dart';

final _log = Logger('ShareIntent');

const _clearLimit = Duration(seconds: 5);

/// Takes what other apps share into this app, the share that started the app
/// and the ones that arrive while it runs: once the app is past the splash
/// and the first sync and the app lock is open (the platform keeps the
/// share meanwhile) and, signed in, About or Connection over the shell has
/// gone as for [TaskOpener.reachHome]; with several accounts the user picks
/// one first (a switch follows, before which an edit page asks; when it
/// stays, the share is dropped with a note). Then the dialogs and sheets go
/// as if the user went back: a New task sheet with typed text asks, and when
/// it stays, the share is dropped with the same note. Then the share sheet
/// opens over the current screen. Signed out it says so. A shared project's
/// link is offered to open as a guest and an admin's invite to open for its
/// check, signed in or out, both on the connect screen; nothing closes and
/// no server is asked before the user chooses that, and signed in either
/// can become a task instead. Whatever happens, the share is cleared at the
/// end, which deletes the inbox copies that did not move into uploads; a
/// clear the platform does not answer in time is not waited for. A newer
/// share replaces one still being handled. Nothing shared is logged.
class ShareIntentListener extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ShareIntentListener> createState() =>
      _ShareIntentListenerState();
}

class _ShareIntentListenerState extends ConsumerState<ShareIntentListener> {
  late final GoRouter _router;
  late final ShareIntentSource _source;
  late final TaskOpener _opener;
  StreamSubscription<IncomingShare>? _shares;
  IncomingShare? _waiting;
  IncomingShare? _handling;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _opener = ref.read(taskOpenerProvider);
    _source = ref.read(shareIntentSourceProvider);
    _router = ref.read(appRouterProvider)
      ..routerDelegate.addListener(_runWhenReady);
    ref.listenManual(
      appLockControllerProvider.select(
        (state) => state.locked || state.checking,
      ),
      (_, waits) {
        if (!waits) _runWhenReady();
      },
    );
    _shares = _source.shares.listen(_onShare);
    unawaited(
      _source.pending().then(
        (share) {
          if (share != null) _onShare(share);
        },
        onError: (Object error) =>
            _log.fine('Could not read the pending share: ${error.runtimeType}'),
      ),
    );
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_runWhenReady);
    unawaited(_shares?.cancel());
    super.dispose();
  }

  void _onShare(IncomingShare share) {
    if (!mounted) return;
    // The platform reports a share it is still holding again at start.
    if (share == _waiting || share == _handling) return;
    _generation++;
    final abandoned = _waiting;
    _waiting = share;
    if (abandoned != null) unawaited(_clear(abandoned));
    if (_handling != null) {
      // Its sheet or account question closes; that run then ends. A sheet that
      // asks before it goes stays for the newer share's own leave.
      ref.read(rootModalRoutesProvider).closeDownToGuarded();
    }
    _runWhenReady();
  }

  void _runWhenReady() {
    final share = _waiting;
    if (share == null || _handling != null || !mounted) return;
    if (ref.read(appLockControllerProvider.notifier).isLockedNow()) return;
    if (_opener.starting) return;
    final signedIn = _opener.signedIn;
    if (signedIn && !_opener.reachHome(_runWhenReady)) return;
    _waiting = null;
    _handling = share;
    final generation = _generation;
    Future<void>? clearing;
    Future<void> clear() => clearing ??= _clear(share);
    unawaited(
      _handle(share, generation, signedIn: signedIn, clear: clear)
          .catchError((Object error) {
            _log.warning('Handling a share failed: ${error.runtimeType}');
          })
          .whenComplete(() async {
            // A newer share does not own this one's paths or cleanup.
            if (generation == _generation) {
              await clear();
            } else {
              unawaited(clear());
            }
          })
          .whenComplete(() {
            _handling = null;
            _runWhenReady();
          }),
    );
  }

  Future<void> _handle(
    IncomingShare share,
    int generation, {
    required bool signedIn,
    required Future<void> Function() clear,
  }) async {
    bool current() => mounted && generation == _generation;
    if (share.isEmpty) return;
    if (await _openedAsLink(
      share,
      generation,
      signedIn: signedIn,
      clear: clear,
    )) {
      return;
    }
    if (!current()) return;
    if (!signedIn) {
      await _opener.showMessage((l10n) => l10n.shareSignedOut);
      return;
    }
    final registry = ref.read(accountsProvider).value;
    final accounts = registry?.accountsByRecency ?? const [];
    if (accounts.length > 1) {
      final picked = Completer<String?>();
      await _opener.showAfterFrame(
        (context) => picked.complete(
          pickAccount(
            context,
            accounts,
            title: context.l10n.sharePickAccountTitle,
            body: context.l10n.sharePickAccountBody,
          ),
        ),
      );
      if (!picked.isCompleted) picked.complete(null);
      final accountId = await picked.future;
      if (!current()) return;
      var pageStays = false;
      if (accountId == null ||
          !await _opener.activate(
            accountId,
            pageStays: () => pageStays = true,
          )) {
        if (pageStays && current()) {
          await _opener.showMessage((l10n) => l10n.shareKeptEditing);
        }
        return;
      }
    }
    if (!current()) return;
    if (!await _opener.leaveDialogsAndSheets()) {
      if (current()) {
        await _opener.showMessage((l10n) => l10n.shareKeptEditing);
      }
      return;
    }
    if (!current()) return;
    final shown = Completer<ShareOutcome?>();
    Future<void> Function()? stopPreparing;
    Future<ShareOutcome?>? submitted;
    var submittedSettled = false;
    ShareOutcome? outcome;
    bool unseen;
    try {
      await _opener.showAfterFrame((context) {
        if (!current()) return;
        shown.complete(
          showShareSheet(
            context,
            share: share,
            onPrepare: (stop) => stopPreparing = stop,
            onSubmit: (work) {
              submittedSettled = false;
              submitted = work;
              unawaited(work.whenComplete(() => submittedSettled = true));
            },
          ),
        );
      });
      if (!shown.isCompleted) shown.complete(null);
      outcome = await shown.future;
      // Its sheet went before the work ended, so a failure shows nowhere else.
      unseen = outcome == null && submitted != null && !submittedSettled;
    } finally {
      try {
        await stopPreparing?.call();
      } finally {
        // The sheet can leave while its files are moving into uploads.
        final finished = await submitted;
        outcome ??= finished;
      }
    }
    if (!current()) return;
    await clear();
    if (!current()) return;
    if (outcome != null) {
      await _announce(outcome);
    } else if (unseen) {
      await _opener.showMessage((l10n) => l10n.shareFailed);
    }
  }

  /// True when [share] was a project's link or an invite and is done with;
  /// false to treat it as any other share.
  Future<bool> _openedAsLink(
    IncomingShare share,
    int generation, {
    required bool signedIn,
    required Future<void> Function() clear,
  }) async {
    if (share.files.isNotEmpty) return false;
    final text = [?share.text, ?share.subject].join('\n');
    final Future<SharedLinkChoice?> Function(BuildContext context) ask;
    final String address;
    if (parseLinkShareUrl(text) case final link?) {
      ask = (context) =>
          askToOpenSharedLink(context, link: link, offerNewTask: signedIn);
      address = link.url.toString();
    } else if (parseInviteLink(text) case final invite?) {
      ask = (context) => askToOpenSharedInvite(
        context,
        invite: invite,
        offerNewTask: signedIn,
      );
      address = inviteUrl(invite).toString();
    } else {
      return false;
    }
    final choice = Completer<SharedLinkChoice?>();
    await _opener.showAfterFrame((context) => choice.complete(ask(context)));
    if (!choice.isCompleted) choice.complete(null);
    final chosen = await choice.future;
    if (!mounted || generation != _generation) return true;
    if (chosen == SharedLinkChoice.newTask) return false;
    await clear();
    if (chosen == null) return true;
    await _connect(address, generation, signedIn: signedIn);
    return true;
  }

  /// Opens [address] on the connect screen, for another account when
  /// [signedIn], unless a newer share has replaced this one meanwhile.
  Future<void> _connect(
    String address,
    int generation, {
    required bool signedIn,
  }) async {
    bool current() => mounted && generation == _generation;
    if (!signedIn) {
      ref.read(rootModalRoutesProvider).closeAll();
    } else if (!await _opener.leaveDialogsAndSheets()) {
      if (current()) {
        await _opener.showMessage((l10n) => l10n.shareKeptEditing);
      }
      return;
    }
    if (!current()) return;
    final location = _router.routerDelegate.state.matchedLocation;
    if (!signedIn) {
      if (location != AppRoutes.connect) _router.go(AppRoutes.connect);
    } else if (location == AppRoutes.addAccountServer) {
      _router.pop();
    } else if (location != AppRoutes.addAccount) {
      unawaited(_router.push(AppRoutes.addAccount));
    }
    // The screen owns the controller; it listens from its first frame on.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    unawaited(
      ref.read(connectServerControllerProvider.notifier).connect(address),
    );
  }

  Future<void> _announce(ShareOutcome outcome) =>
      _opener.showAfterFrame((context) {
        final l10n = context.l10n;
        final text = [
          if (outcome.created)
            l10n.shareTaskCreated(outcome.queued)
          else
            l10n.shareAddedToTask(outcome.queued),
          ?outcome.problems,
        ].join(' ');
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(text),
              persist: MediaQuery.accessibleNavigationOf(context),
              action: SnackBarAction(
                label: l10n.taskDuplicateOpen,
                onPressed: () => unawaited(_opener.showTask(outcome.task)),
              ),
            ),
          );
      });

  Future<void> _clear(IncomingShare share) async {
    try {
      await _source.clear(share).timeout(_clearLimit);
    } on Object catch (error) {
      _log.warning('Clearing a share failed: ${error.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
