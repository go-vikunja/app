import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/share/share_intent_source.dart';
import 'package:vikunja_mobile/core/share/share_providers.dart';
import 'package:vikunja_mobile/features/onboarding/application/connect_server_controller.dart';
import 'package:vikunja_mobile/features/share/presentation/open_shared_link_sheet.dart';
import 'package:vikunja_mobile/features/share/presentation/share_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/account_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/task_opener.dart';

final _log = Logger('ShareIntent');

/// Takes what other apps share into Rurana, the share that started the app
/// and the ones that arrive while it runs: once the app is past the splash
/// and the first sync, with several accounts the user picks one first (a
/// switch follows), then the share sheet opens over the current screen.
/// Signed out it says so. A shared project's link is offered to open as a
/// guest and an admin's invite goes to its check, signed in or out, both on
/// the connect screen. Whatever happens, the share is cleared at the end,
/// which deletes the inbox copies that did not move into uploads. A newer
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
    _waiting = share;
    if (_handling != null) {
      // Its sheet or account question closes; that run then ends.
      ref.read(rootModalRoutesProvider).closeAll();
    }
    _runWhenReady();
  }

  void _runWhenReady() {
    final share = _waiting;
    if (share == null || _handling != null || !mounted) return;
    final delegate = _router.routerDelegate;
    if (delegate.currentConfiguration.isEmpty) return;
    final location = delegate.state.matchedLocation;
    if (location == AppRoutes.splash ||
        location == AppRoutes.firstSync ||
        location == AppRoutes.notificationsSetup) {
      return;
    }
    _waiting = null;
    _handling = share;
    final generation = _generation;
    unawaited(
      _handle(share, generation, signedIn: location.startsWith(AppRoutes.home))
          .catchError((Object error) {
            _log.warning('Handling a share failed: ${error.runtimeType}');
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
  }) async {
    bool current() => mounted && generation == _generation;
    if (share.isEmpty) {
      await _clear(generation);
      return;
    }
    if (await _openedAsLink(share, generation, signedIn: signedIn)) return;
    if (!current()) return;
    if (!signedIn) {
      await _opener.showMessage((l10n) => l10n.shareSignedOut);
      await _clear(generation);
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
      if (accountId == null || !await _opener.activate(accountId)) {
        await _clear(generation);
        return;
      }
    }
    if (!current()) return;
    ref.read(rootModalRoutesProvider).closeAll();
    final shown = Completer<ShareOutcome?>();
    Future<ShareOutcome?>? submitted;
    await _opener.showAfterFrame(
      (context) => shown.complete(
        showShareSheet(
          context,
          share: share,
          onSubmit: (work) => submitted = work,
        ),
      ),
    );
    if (!shown.isCompleted) shown.complete(null);
    var outcome = await shown.future;
    // The sheet went while its files were still being moved out of the
    // inbox; clearing it now would delete the rest.
    if (outcome == null && submitted != null) outcome = await submitted;
    if (!current()) return;
    await _clear(generation);
    if (outcome != null) await _announce(outcome);
  }

  /// True when [share] was a project's link or an invite and is done with;
  /// false to treat it as any other share.
  Future<bool> _openedAsLink(
    IncomingShare share,
    int generation, {
    required bool signedIn,
  }) async {
    if (share.files.isNotEmpty) return false;
    final text = [?share.text, ?share.subject].join('\n');
    final String address;
    if (parseLinkShareUrl(text) case final link?) {
      final choice = Completer<SharedLinkChoice?>();
      await _opener.showAfterFrame(
        (context) => choice.complete(
          askToOpenSharedLink(context, link: link, offerNewTask: signedIn),
        ),
      );
      if (!choice.isCompleted) choice.complete(null);
      final chosen = await choice.future;
      if (!mounted || generation != _generation) return true;
      if (chosen == SharedLinkChoice.newTask) return false;
      if (chosen == null) {
        await _clear(generation);
        return true;
      }
      address = link.url.toString();
    } else if (parseInviteLink(text) case final invite?) {
      address = inviteUrl(invite).toString();
    } else {
      return false;
    }
    await _clear(generation);
    await _connect(address, signedIn: signedIn);
    return true;
  }

  /// Opens [address] on the connect screen, for another account when
  /// [signedIn].
  Future<void> _connect(String address, {required bool signedIn}) async {
    ref.read(rootModalRoutesProvider).closeAll();
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

  /// Only for the share still current: a newer one owns the platform's
  /// pending share by now.
  Future<void> _clear(int generation) async {
    if (generation != _generation) return;
    try {
      await _source.clear();
    } on Object catch (error) {
      _log.warning('Clearing a share failed: ${error.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
