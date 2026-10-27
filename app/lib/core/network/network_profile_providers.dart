import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/network/certificate_probe.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';

part 'network_profile_providers.g.dart';

/// One table for both Dios and the realtime socket. It depends only on the
/// stores, so nothing rebuilds the Dios when a profile changes, and every
/// container (background ones too) loads it lazily on the first request.
@Riverpod(keepAlive: true)
NetworkProfiles networkProfiles(Ref ref) {
  final preferences = ref.watch(preferencesStoreProvider);
  return NetworkProfiles(
    preferences: preferences,
    secureStore: ref.watch(secureStoreProvider),
    // A registry instance of its own: the shared one runs its operations one
    // at a time, and one of them may be waiting for the very request that
    // triggers the migration.
    accountRoots: () async {
      final registry = AccountRegistry(preferences);
      try {
        return [
          for (final entry in (await registry.load()).accounts)
            entry.connection.rootUri,
        ];
      } finally {
        unawaited(registry.dispose());
      }
    },
  );
}

/// [origin]'s settings for screens, read afresh when first listened to and
/// on every resume, and again after every change made in this isolate.
@riverpod
Stream<ConnectionProfileState> connectionProfile(Ref ref, OriginKey origin) {
  final profiles = ref.watch(networkProfilesProvider);
  final states = StreamController<ConnectionProfileState>();
  var reading = Future<void>.value();
  void read({bool reload = false}) {
    reading = reading.then((_) async {
      if (reload) await profiles.reload();
      final state = await profiles.stateFor(origin);
      if (!states.isClosed) states.add(state);
    });
  }

  final changes = profiles.changes
      .where((changed) => changed == null || changed == origin)
      .listen((_) => read());
  final lifecycle = AppLifecycleListener(onResume: () => read(reload: true));
  ref.onDispose(() {
    unawaited(changes.cancel());
    lifecycle.dispose();
    unawaited(states.close());
  });
  read(reload: true);
  return states.stream;
}

/// What the realtime socket depends on: an edit or a revoke restarts it, a
/// recorded mismatch does not.
typedef ConnectionProfileRevision = ({int revision, bool hasConsent});

/// Null until [connectionProfileProvider] read [origin] once.
@riverpod
ConnectionProfileRevision? connectionProfileRevision(
  Ref ref,
  OriginKey origin,
) => ref.watch(
  connectionProfileProvider(origin).select(
    (state) => switch (state) {
      AsyncValue(hasValue: true, :final value?) => (
        revision: value.profile?.revision ?? 0,
        hasConsent: value.profile?.hasCleartextConsent ?? false,
      ),
      AsyncValue(hasError: true) => (revision: -1, hasConsent: false),
      _ => null,
    },
  ),
);

@Riverpod(keepAlive: true)
CertificateProbe certificateProbe(Ref ref) =>
    CertificateProbe(profiles: ref.watch(networkProfilesProvider));
