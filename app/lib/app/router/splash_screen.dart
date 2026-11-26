import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';

/// Shown for the moment it takes to read the account registry at start.
class SplashScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;
  var _slow = false;

  @override
  void initState() {
    super.initState();
    _wait();
  }

  void _wait() {
    _timer?.cancel();
    _timer = Timer(startupReadLimit, () => setState(() => _slow = true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(accountsProvider.select(accountsStillOpening));
    final l10n = context.l10n;
    return Scaffold(
      body: loading
          ? CenteredScrollView(
              maxWidth: ReadableWidth.form,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _slow
                            ? l10n.startupAccountsSlow
                            : l10n.startupAccountsLoading,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_slow)
                      TextButton(
                        onPressed: () {
                          setState(() => _slow = false);
                          _wait();
                          ref.invalidate(accountsProvider);
                        },
                        child: Text(l10n.retry),
                      ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
