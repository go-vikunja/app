import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/network/certificate_info.dart';
import 'package:vikunja_mobile/core/network/client_certificate.dart';
import 'package:vikunja_mobile/core/network/header_rules.dart';
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/network_profile_secrets.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';

final _log = Logger('NetworkProfiles');

enum ConnectionProfileStatus {
  ok,

  /// The server showed a certificate other than the pinned one.
  pinMismatch,

  /// Secrets the metadata names are missing or unreadable.
  needsReentry,

  /// Storage cannot be read yet, as before the first unlock.
  unavailable,

  /// The stored settings cannot be parsed; only a reset helps.
  damaged,
}

/// What a screen shows for one origin. [profile] is metadata only; it is
/// null without a profile, when the settings are damaged, and when the
/// preferences could not be read.
@immutable
final class ConnectionProfileState {
  const new({required this.origin, required this.status, this.profile});

  final OriginKey origin;
  final ConnectionProfileStatus status;
  final NetworkProfile? profile;

  // Every edit bumps the revision; a recorded mismatch is the only change
  // that does not.
  @override
  bool operator ==(Object other) =>
      other is ConnectionProfileState &&
      other.origin == origin &&
      other.status == status &&
      other.profile?.revision == profile?.revision &&
      other.profile?.lastPinMismatch == profile?.lastPinMismatch;

  @override
  int get hashCode =>
      Object.hash(origin, status, profile?.revision, profile?.lastPinMismatch);

  @override
  String toString() => 'ConnectionProfileState($origin, ${status.name})';
}

/// Every origin's connection settings (D65): metadata in preferences under
/// [storageKey], secrets in secure storage. Storage is the truth: other
/// isolates (background sync, notification actions, widgets) read the same
/// keys, so reads are cached briefly and every write reads afresh, changes
/// only its origin and keeps everything else as stored.
///
/// Reads fail closed with the domain's connection-settings exceptions, so
/// a request never goes out without the pin or headers it should carry.
final class NetworkProfiles {
  new({
    required this._preferences,
    required SecureStore secureStore,
    Future<List<Uri>> Function()? accountRoots,
    DateTime Function()? clock,
  }) : _secrets = NetworkProfileSecrets(secureStore),
       _accountRoots = accountRoots ?? (() async => const []),
       _clock = clock ?? DateTime.now;

  static const storageKey = 'network.profiles';
  static const schemaVersion = 1;
  static const metadataMaxAge = Duration(seconds: 30);
  static const lockedRetryAfter = Duration(seconds: 5);
  static const int maxCaPemLength = 64 * 1024;

  // Per isolate, so every instance (one per ProviderContainer) of this
  // isolate writes one at a time and sees the others' writes at once. No
  // future is kept between writes: one from a zone that is gone (a test's
  // fake clock) would never deliver.
  static bool _writing = false;
  static final _waitingWriters = Queue<Completer<void>>();
  static int _generation = 0;
  static final _isolateChanges = StreamController<OriginKey?>.broadcast();

  final PreferencesStore _preferences;
  final NetworkProfileSecrets _secrets;
  final Future<List<Uri>> Function() _accountRoots;
  final DateTime Function() _clock;

  _Snapshot? _snapshot;
  Future<_Snapshot>? _loading;
  DateTime? _metadataFailedAt;
  final _secretCache = <OriginKey, (int, ProfileSecrets)>{};
  final _secretReads = <OriginKey, (int, Future<ProfileSecrets>)>{};
  final _secretFailedAt = <OriginKey, DateTime>{};

  /// The origin whose settings this isolate just changed, or null when all
  /// may have changed.
  Stream<OriginKey?> get changes => _isolateChanges.stream;

  /// [origin]'s profile with its secrets, or null without one. Throws
  /// [ConnectionProfilesDamagedException], [ConnectionProfileLockedException]
  /// or [ConnectionProfileIncompleteException].
  Future<NetworkProfile?> forOrigin(OriginKey origin) async {
    final profile = await metadataFor(origin);
    if (profile == null || !profile.namesSecrets) return profile;
    return profile.withSecrets(await _secretsFor(profile));
  }

  /// Like [forOrigin] without touching secure storage.
  Future<NetworkProfile?> metadataFor(OriginKey origin) async =>
      (await _document(origin)).profiles[origin];

  /// Never throws.
  Future<ConnectionProfileState> stateFor(OriginKey origin) async {
    ConnectionProfileState state(
      ConnectionProfileStatus status, [
      NetworkProfile? profile,
    ]) => ConnectionProfileState(
      origin: origin,
      status: status,
      profile: profile,
    );
    final NetworkProfile? profile;
    try {
      profile = await metadataFor(origin);
    } on ConnectionProfilesDamagedException {
      return state(ConnectionProfileStatus.damaged);
    } on Object catch (error) {
      _log.info('Metadata not readable: ${error.runtimeType}');
      return state(ConnectionProfileStatus.unavailable);
    }
    if (profile == null) return state(ConnectionProfileStatus.ok);
    if (profile.namesSecrets) {
      try {
        await _secretsFor(profile);
      } on ConnectionProfileIncompleteException {
        return state(ConnectionProfileStatus.needsReentry, profile);
      } on Object catch (error) {
        _log.info('Secrets not readable: ${error.runtimeType}');
        return state(ConnectionProfileStatus.unavailable, profile);
      }
    }
    if (profile.lastPinMismatch != null) {
      return state(ConnectionProfileStatus.pinMismatch, profile);
    }
    return state(ConnectionProfileStatus.ok, profile);
  }

  /// Drops every cache and every wait after a failed read, so the next
  /// read goes to storage.
  Future<void> reload() async {
    _snapshot = null;
    _metadataFailedAt = null;
    _secretCache.clear();
    _secretFailedAt.clear();
  }

  /// Pins exactly [certificate] for [origin], replacing a trusted CA.
  Future<void> trustCertificate(OriginKey origin, CertificateInfo certificate) {
    _requireSecure(origin);
    final pin = PinnedCertificate(
      certificate: CertificateInfo(
        sha256: certificate.sha256,
        subject: certificate.subject,
        issuer: certificate.issuer,
        notBefore: certificate.notBefore,
        notAfter: certificate.notAfter,
      ),
      trustedAt: _clock().toUtc(),
    );
    return _edit(
      origin,
      (current, revision) => current.copyWith(
        revision: revision,
        pin: pin,
        clearCaCertificate: true,
        clearLastPinMismatch: true,
      ),
    );
  }

  /// Trusts the certificates in [pem] for [origin], replacing a pin.
  /// Refuses a file with a private key or larger than [maxCaPemLength]
  /// with an [ArgumentError].
  Future<void> trustCaCertificate(
    OriginKey origin, {
    required String fileName,
    required String pem,
  }) {
    _requireSecure(origin);
    if (pem.length > maxCaPemLength || pem.contains('PRIVATE KEY')) {
      throw ArgumentError('Not a CA certificate file');
    }
    final ca = CaCertificate(
      fileName: fileName,
      pem: pem,
      importedAt: _clock().toUtc(),
    );
    return _edit(
      origin,
      (current, revision) => current.copyWith(
        revision: revision,
        caCertificate: ca,
        clearPin: true,
        clearLastPinMismatch: true,
      ),
    );
  }

  /// Removes the pin and the trusted CA.
  Future<void> removeCertificateTrust(OriginKey origin) => _edit(
    origin,
    (current, revision) => current.pin == null && current.caCertificate == null
        ? null
        : current.copyWith(
            revision: revision,
            clearPin: true,
            clearCaCertificate: true,
            clearLastPinMismatch: true,
          ),
  );

  /// Throws an [ArgumentError] unless [validateClientCertificate] accepts
  /// the file.
  Future<void> setClientCertificate(
    OriginKey origin, {
    required String fileName,
    required Uint8List bytes,
    required String password,
  }) async {
    _requireSecure(origin);
    if (validateClientCertificate(bytes, password) case final problem?) {
      throw ArgumentError('Client certificate refused: ${problem.name}');
    }
    final client = ClientCertificate(
      fileName: fileName,
      importedAt: _clock().toUtc(),
    );
    await _locked(() async {
      final document = await _readForWrite(origin);
      final current = document.profileOrEmpty(origin);
      final kept = current.hasHeaders
          ? await _storedSecrets(current)
          : ProfileSecrets.none;
      await _secrets.write(
        current.id,
        ProfileSecrets(
          headers: _named(kept.headers, current.headerNames),
          pkcs12: bytes,
          pkcs12Password: password,
        ),
      );
      await _save(document, {
        origin: current.copyWith(
          revision: document.nextRevision(current),
          clientCertificate: client,
        ),
      });
    });
  }

  Future<void> removeClientCertificate(OriginKey origin) => _locked(() async {
    final document = await _readForWrite(origin);
    final current = document.profiles[origin];
    if (current?.clientCertificate == null) return;
    final next = current!.copyWith(
      revision: document.nextRevision(current),
      clearClientCertificate: true,
    );
    await _save(document, {origin: next.isEmpty ? null : next});
    await _rewriteSecrets(next, keepPkcs12: false);
  });

  /// Replaces the headers; an empty map removes them. Throws an
  /// [ArgumentError] for a set [HeaderRules] refuses, and a [StateError] for
  /// new headers on an http origin without consent to unencrypted
  /// connections.
  Future<void> setHeaders(OriginKey origin, Map<String, String> headers) async {
    if (HeaderRules.validateAll([
          for (final MapEntry(:key, :value) in headers.entries) (key, value),
        ])
        case final problem?) {
      throw ArgumentError('Header refused: ${problem.name}');
    }
    final normalized = {
      for (final MapEntry(:key, :value) in headers.entries)
        key: HeaderRules.normalizeValue(value),
    };
    await _locked(() async {
      final document = await _readForWrite(origin);
      final current = document.profileOrEmpty(origin);
      if (normalized.isNotEmpty &&
          !origin.isSecure &&
          !current.hasCleartextConsent) {
        throw StateError('Unencrypted connections are not allowed here');
      }
      final next = current.copyWith(
        revision: document.nextRevision(current),
        headerNames: List.unmodifiable(normalized.keys),
      );
      if (normalized.isEmpty) {
        await _save(document, {origin: next.isEmpty ? null : next});
        await _rewriteSecrets(next, keepPkcs12: true);
        return;
      }
      final kept = current.clientCertificate != null
          ? await _storedSecrets(current)
          : ProfileSecrets.none;
      await _secrets.write(
        current.id,
        ProfileSecrets(
          headers: normalized,
          pkcs12: kept.pkcs12,
          pkcs12Password: kept.pkcs12Password,
        ),
      );
      await _save(document, {origin: next});
    });
  }

  Future<void> consentToCleartext(OriginKey origin) {
    _requireCleartext(origin);
    final now = _clock().toUtc();
    return _edit(
      origin,
      (current, revision) => current.hasCleartextConsent
          ? null
          : current.copyWith(revision: revision, cleartextConsentAt: now),
    );
  }

  Future<void> revokeCleartext(OriginKey origin) {
    _requireCleartext(origin);
    return _edit(
      origin,
      (current, revision) => current.hasCleartextConsent
          ? current.copyWith(revision: revision, clearCleartextConsent: true)
          : null,
    );
  }

  /// Keeps what [seen] looked like for the review; never trusts it and
  /// never bumps the revision. Only an origin with another pin records.
  Future<void> recordPinMismatch(OriginKey origin, CertificateInfo seen) =>
      _locked(() async {
        final document = await _readForWrite(origin);
        final current = document.profiles[origin];
        final pin = current?.pin;
        if (current == null || pin == null || pin.sha256 == seen.sha256) {
          return;
        }
        if (current.lastPinMismatch?.sha256 == seen.sha256) return;
        await _save(document, {
          origin: current.copyWith(
            lastPinMismatch: PinMismatch(
              certificate: CertificateInfo(
                sha256: seen.sha256,
                subject: seen.subject,
                issuer: seen.issuer,
                notBefore: seen.notBefore,
                notAfter: seen.notAfter,
              ),
              seenAt: _clock().toUtc(),
            ),
          ),
        });
      });

  Future<void> dismissPinMismatch(OriginKey origin) => _locked(() async {
    final document = await _readForWrite(origin);
    final current = document.profiles[origin];
    if (current?.lastPinMismatch == null) return;
    await _save(document, {
      origin: current!.copyWith(clearLastPinMismatch: true),
    });
  });

  /// Metadata first, then the secrets, so the metadata never names secrets
  /// that are gone.
  Future<void> forget(OriginKey origin) => _locked(() async {
    final document = await _readForWrite(origin);
    await _save(document, {origin: null});
    await _deleteSecrets(NetworkProfile.idFor(origin));
  });

  /// Starts over with no settings at all, also from damaged metadata.
  /// Consents to unencrypted connections are not migrated again.
  Future<void> resetAll() => _locked(() async {
    final origins = <OriginKey>{};
    var revisionCounter = 0;
    try {
      final stored = await _preferences.getString(storageKey);
      final json = stored == null ? null : jsonDecode(stored);
      if (json case {'profiles': final Map<String, Object?> profiles}) {
        origins.addAll(profiles.keys.map(OriginKey.tryParse).nonNulls);
      }
      if (json case {'revisionCounter': final int counter}) {
        revisionCounter = counter;
      }
    } on Object catch (error) {
      _log.info(
        'Old settings not readable for the reset: ${error.runtimeType}',
      );
    }
    await _preferences.setString(
      storageKey,
      jsonEncode({
        'schemaVersion': schemaVersion,
        'cleartextMigrated': true,
        'revisionCounter': revisionCounter + 1,
        'profiles': <String, Object?>{},
      }),
    );
    _changed(null);
    try {
      for (final root in await _accountRoots()) {
        if (OriginKey.tryOf(root) case final origin?) origins.add(origin);
      }
    } on Object catch (error) {
      _log.info('Accounts not readable for the reset: ${error.runtimeType}');
    }
    for (final origin in origins) {
      await _deleteSecrets(NetworkProfile.idFor(origin));
    }
  });

  Future<_Document> _document(OriginKey origin) async {
    final cached = _snapshot;
    final now = _clock();
    if (cached != null &&
        cached.generation == _generation &&
        now.difference(cached.readAt) < metadataMaxAge) {
      return cached.document(origin);
    }
    if (_metadataFailedAt case final failedAt?
        when now.difference(failedAt) < lockedRetryAfter) {
      throw ConnectionProfileLockedException(origin.toString());
    }
    final Future<_Snapshot> loading;
    if (_loading case final shared?) {
      loading = shared;
    } else {
      loading = _loading = _load().whenComplete(() => _loading = null);
    }
    try {
      return (await loading).document(origin);
    } on _PreferencesUnreadable {
      throw ConnectionProfileLockedException(origin.toString());
    }
  }

  Future<_Snapshot> _load({bool migrate = true}) async {
    final generation = _generation;
    final String? stored;
    try {
      stored = await _preferences.getString(storageKey);
    } on Object catch (error) {
      _metadataFailedAt = _clock();
      _log.info('Metadata not readable: ${error.runtimeType}');
      throw const _PreferencesUnreadable();
    }
    _metadataFailedAt = null;
    final _Document document;
    try {
      document = _Document.parse(stored);
    } on FormatException {
      _log.warning('Stored connection settings are damaged');
      return _snapshot = _Snapshot(null, _clock(), generation);
    }
    if (migrate && !document.migrated) {
      try {
        await _locked(() async {
          final fresh = await _readForWrite(null);
          if (fresh.migratingNow) await _save(fresh, const {});
        });
      } on Object catch (error) {
        _log.info('Cleartext migration failed: ${error.runtimeType}');
        throw const _PreferencesUnreadable();
      }
      return await _load(migrate: false);
    }
    return _snapshot = _Snapshot(document, _clock(), generation);
  }

  /// The stored document with the one-time migration applied (written by
  /// the caller's save): consent for the http origins of existing accounts
  /// that have no entry yet. It never changes an existing entry, so a
  /// revoked consent stays revoked.
  Future<_Document> _readForWrite(OriginKey? origin) async {
    final String? stored;
    try {
      stored = await _preferences.getString(storageKey);
    } on Object catch (error) {
      _log.info('Metadata not readable for a write: ${error.runtimeType}');
      throw ConnectionProfileLockedException(origin?.toString() ?? '');
    }
    final _Document document;
    try {
      document = _Document.parse(stored);
    } on FormatException {
      throw const ConnectionProfilesDamagedException();
    }
    if (document.migrated) return document;
    final now = _clock().toUtc();
    final added = <OriginKey, NetworkProfile>{};
    for (final root in await _accountRoots()) {
      final origin = OriginKey.tryOf(root);
      if (origin == null || origin.isSecure) continue;
      if (document.hasEntry(origin) || added.containsKey(origin)) continue;
      added[origin] = NetworkProfile(origin: origin, cleartextConsentAt: now);
    }
    return document..migrate(added);
  }

  Future<void> _edit(
    OriginKey origin,
    NetworkProfile? Function(NetworkProfile current, int revision) change,
  ) => _locked(() async {
    final document = await _readForWrite(origin);
    final current = document.profileOrEmpty(origin);
    final next = change(current, document.nextRevision(current));
    if (next == null) {
      if (!document.migrated) await _save(document, const {});
      return;
    }
    await _save(document, {origin: next.isEmpty ? null : next});
    if (next.isEmpty) await _deleteSecrets(next.id);
  });

  Future<void> _save(
    _Document document,
    Map<OriginKey, NetworkProfile?> changes,
  ) async {
    await _preferences.setString(storageKey, document.encode(changes));
    changes.keys.forEach(_secretCache.remove);
    _changed(changes.length == 1 ? changes.keys.single : null);
  }

  void _changed(OriginKey? origin) {
    _generation++;
    _snapshot = null;
    if (origin == null) _secretCache.clear();
    _isolateChanges.add(origin);
  }

  Future<ProfileSecrets> _secretsFor(NetworkProfile profile) async {
    final origin = profile.origin;
    if (_secretCache[origin] case (final revision, final secrets)
        when revision == profile.revision) {
      return secrets;
    }
    if (_secretFailedAt[origin] case final failedAt?
        when _clock().difference(failedAt) < lockedRetryAfter) {
      throw ConnectionProfileLockedException(origin.toString());
    }
    final Future<ProfileSecrets> reading;
    if (_secretReads[origin] case (final revision, final shared)
        when revision == profile.revision) {
      reading = shared;
    } else {
      reading = _readSecrets(profile);
      _secretReads[origin] = (profile.revision, reading);
    }
    try {
      final secrets = await reading;
      _secretCache[origin] = (profile.revision, secrets);
      return secrets;
    } finally {
      if (identical(_secretReads[origin]?.$2, reading)) {
        _secretReads.remove(origin);
      }
    }
  }

  Future<ProfileSecrets> _readSecrets(NetworkProfile profile) async {
    final origin = profile.origin;
    final ProfileSecrets? stored;
    try {
      stored = await _secrets.read(profile.id);
    } on FormatException {
      throw ConnectionProfileIncompleteException(origin.toString());
    } on Object catch (error) {
      _secretFailedAt[origin] = _clock();
      _log.info('Secrets not readable: ${error.runtimeType}');
      throw ConnectionProfileLockedException(origin.toString());
    }
    _secretFailedAt.remove(origin);
    if (stored == null) {
      throw ConnectionProfileIncompleteException(origin.toString());
    }
    final headers = _named(stored.headers, profile.headerNames);
    final client = profile.clientCertificate != null;
    if (headers.length != profile.headerNames.length ||
        (client &&
            (stored.pkcs12 == null ||
                stored.pkcs12!.isEmpty ||
                stored.pkcs12Password == null))) {
      throw ConnectionProfileIncompleteException(origin.toString());
    }
    return ProfileSecrets(
      headers: headers,
      pkcs12: client ? stored.pkcs12 : null,
      pkcs12Password: client ? stored.pkcs12Password : null,
    );
  }

  /// For an edit that keeps the other secrets: whatever is stored, nothing
  /// when the entry is gone or unreadable as JSON.
  Future<ProfileSecrets> _storedSecrets(NetworkProfile profile) async {
    try {
      return await _secrets.read(profile.id) ?? ProfileSecrets.none;
    } on FormatException {
      return ProfileSecrets.none;
    } on Object catch (error) {
      _log.info('Secrets not readable for an edit: ${error.runtimeType}');
      throw ConnectionProfileLockedException(profile.origin.toString());
    }
  }

  /// After the metadata dropped a secret: keeps only what [profile] still
  /// names, or deletes the entry.
  Future<void> _rewriteSecrets(
    NetworkProfile profile, {
    required bool keepPkcs12,
  }) async {
    final needsPkcs12 = keepPkcs12 && profile.clientCertificate != null;
    if (!profile.hasHeaders && !needsPkcs12) {
      await _deleteSecrets(profile.id);
      return;
    }
    try {
      final stored = await _secrets.read(profile.id) ?? ProfileSecrets.none;
      await _secrets.write(
        profile.id,
        ProfileSecrets(
          headers: _named(stored.headers, profile.headerNames),
          pkcs12: needsPkcs12 ? stored.pkcs12 : null,
          pkcs12Password: needsPkcs12 ? stored.pkcs12Password : null,
        ),
      );
    } on Object catch (error) {
      // The metadata no longer names it, so the leftover is never sent.
      _log.info('Leftover secret not removed: ${error.runtimeType}');
    }
  }

  Future<void> _deleteSecrets(String profileId) async {
    try {
      await _secrets.delete(profileId);
    } on Object catch (error) {
      _log.info('Secrets not deleted: ${error.runtimeType}');
    }
  }

  static Future<T> _locked<T>(Future<T> Function() body) async {
    if (_writing) {
      final turn = Completer<void>();
      _waitingWriters.add(turn);
      await turn.future;
    } else {
      _writing = true;
    }
    try {
      return await body();
    } finally {
      if (_waitingWriters.isEmpty) {
        _writing = false;
      } else {
        _waitingWriters.removeFirst().complete();
      }
    }
  }

  static Map<String, String> _named(
    Map<String, String> headers,
    List<String> names,
  ) => {
    for (final name in names)
      if (headers[name] case final value? when value.isNotEmpty) name: value,
  };

  static void _requireSecure(OriginKey origin) {
    if (!origin.isSecure) {
      throw ArgumentError.value(origin, 'origin', 'Needs an https origin');
    }
  }

  static void _requireCleartext(OriginKey origin) {
    if (origin.isSecure) {
      throw ArgumentError.value(origin, 'origin', 'Needs an http origin');
    }
  }
}

final class _PreferencesUnreadable implements Exception {
  const new();
}

final class _Snapshot {
  new(this._document, this.readAt, this.generation);

  /// Null when damaged.
  final _Document? _document;
  final DateTime readAt;
  final int generation;

  _Document document(OriginKey origin) =>
      _document ?? (throw const ConnectionProfilesDamagedException());
}

/// The stored JSON with the entries this version understands. Entries
/// under keys that are no origin key and unknown fields are written back
/// as they were.
final class _Document {
  new(this._raw, this._rawProfiles, this.profiles);

  /// Throws a [FormatException] for a damaged document: not JSON, a newer
  /// schema, or an entry that cannot be read (such as one with both a pin
  /// and a CA).
  factory parse(String? stored) {
    if (stored == null) return _Document(const {}, const {}, const {});
    final Object? json;
    try {
      json = jsonDecode(stored);
    } on FormatException {
      throw const FormatException('Not JSON');
    }
    if (json is! Map<String, Object?>) {
      throw const FormatException('Not an object');
    }
    final version = json['schemaVersion'];
    if (version is! int ||
        version < 1 ||
        version > NetworkProfiles.schemaVersion) {
      throw const FormatException('Unknown schema version');
    }
    final rawProfiles = switch (json['profiles']) {
      null => const <String, Object?>{},
      final Map<String, Object?> map => map,
      _ => throw const FormatException('profiles is not an object'),
    };
    final profiles = <OriginKey, NetworkProfile>{};
    for (final MapEntry(:key, :value) in rawProfiles.entries) {
      final origin = OriginKey.tryParse(key);
      if (origin == null) continue;
      profiles[origin] = NetworkProfile.fromJson(origin, value);
    }
    return _Document(json, rawProfiles, Map.unmodifiable(profiles));
  }

  final Map<String, Object?> _raw;
  final Map<String, Object?> _rawProfiles;
  final Map<OriginKey, NetworkProfile> profiles;
  final _pending = <OriginKey, NetworkProfile>{};
  var _migratedNow = false;

  bool get migrated => _raw['cleartextMigrated'] == true || _migratedNow;

  /// The migration ran on this copy and still has to be written.
  bool get migratingNow => _migratedNow;

  bool hasEntry(OriginKey origin) => _rawProfiles.containsKey('$origin');

  NetworkProfile profileOrEmpty(OriginKey origin) =>
      _pending[origin] ??
      profiles[origin] ??
      NetworkProfile(origin: origin, revision: 0);

  int get _revisionCounter => switch (_raw['revisionCounter']) {
    final int counter => counter,
    _ => 0,
  };

  /// Unique within the document's lifetime, so a profile forgotten and set
  /// up again never repeats a revision an adapter or cache still holds.
  int nextRevision(NetworkProfile current) =>
      (current.revision > _revisionCounter
          ? current.revision
          : _revisionCounter) +
      1;

  void migrate(Map<OriginKey, NetworkProfile> added) {
    _pending.addAll(added);
    _migratedNow = true;
  }

  String encode(Map<OriginKey, NetworkProfile?> changes) {
    final entries = <String, Object?>{..._rawProfiles};
    for (final MapEntry(:key, :value) in {..._pending, ...changes}.entries) {
      if (value == null) {
        entries.remove('$key');
      } else {
        entries['$key'] = value.toJson();
      }
    }
    var counter = _revisionCounter;
    for (final profile in changes.values.nonNulls) {
      if (profile.revision > counter) counter = profile.revision;
    }
    return jsonEncode({
      ..._raw,
      'schemaVersion': NetworkProfiles.schemaVersion,
      'cleartextMigrated': true,
      'revisionCounter': counter,
      'profiles': entries,
    });
  }
}
