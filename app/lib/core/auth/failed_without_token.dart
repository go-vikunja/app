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

/// A request that failed on its way to or from the server; not one that got
/// no token and so never left ([failedWithoutToken]).
bool failedOnTheNetwork(Object? error) =>
    error is NetworkFailure && !failedWithoutToken(error);

/// A request that failed for a reason that may pass, which shows as offline:
/// not one the stored connection settings stopped, which retrying at once
/// does not get through, nor one that got no token (decision log:
/// Connections).
bool failedAsOutage(Object? error) =>
    error is NetworkFailure &&
    !error.problem.concernsConnectionSettings &&
    !failedWithoutToken(error);
