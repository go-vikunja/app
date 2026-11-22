import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';

/// No token could be had for the request, so the server never processed
/// it: the refresh was put off, or secure storage refused to read.
/// Neither is an outage, though both arrive as a `NetworkFailure`.
bool failedWithoutToken(Object? error) =>
    error is NetworkFailure &&
    switch (error.cause) {
      RefreshDeferred() || SecureStorageUnreadable() => true,
      _ => false,
    };

/// A request that failed on its way to or from the server, which counts as
/// offline; not one that got no token and so never left ([failedWithoutToken]).
bool failedOnTheNetwork(Object? error) =>
    error is NetworkFailure && !failedWithoutToken(error);
