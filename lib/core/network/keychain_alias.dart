import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:jni/jni.dart';
import 'package:ok_http/ok_http.dart' as ok_http;

/// Prompts the user to pick an Android Keystore alias via the system
/// "Choose certificate" dialog, resolving to the chosen alias or `null` if the
/// user denied or dismissed it.
///
/// Delegates to `package:ok_http`; wrapped here so callers do not have to know
/// which package provides the Keystore integration, and so it sits next to
/// [loadPrivateKeyAndCertificateChain], which cannot delegate.
Future<String?> choosePrivateKeyAlias() => ok_http.choosePrivateKeyAlias();

/// Loads the private key and certificate chain for the Android Keystore
/// [alias], off the platform thread.
///
/// `KeyChain.getPrivateKey` and `KeyChain.getCertificateChain` are blocking
/// binder calls guarded by
/// `IllegalStateException: calling this from your main thread can lead to
/// deadlock`. Flutter merges the Dart UI thread into the Android platform
/// thread (and no longer allows opting out — the
/// `DisableMergedPlatformUIThread` manifest flag is rejected as of Flutter
/// 3.44), so the root isolate *is* the main thread and calling
/// [ok_http.loadPrivateKeyAndCertificateChainFromAlias] there always throws.
/// A helper isolate gets its own OS thread, where `Looper.myLooper()` is null
/// and the guard does not apply.
Future<(ok_http.PrivateKey, List<ok_http.X509Certificate>)>
loadPrivateKeyAndCertificateChain(String alias) async {
  final (privateKeyAddress, chainAddresses) = await Isolate.run(() {
    final (privateKey, chain) = ok_http
        .loadPrivateKeyAndCertificateChainFromAlias(alias);
    return (_handOver(privateKey), chain.map(_handOver).toList());
  });

  return (
    _receive(
      privateKeyAddress,
    ).as(ok_http.PrivateKey.type, releaseOriginal: true),
    chainAddresses
        .map(
          (address) => _receive(
            address,
          ).as(ok_http.X509Certificate.type, releaseOriginal: true),
        )
        .toList(),
  );
}

/// Returns the address of a fresh JNI global reference to [object], for sending
/// to another isolate.
///
/// A [JObject] is not sendable, but a JNI global reference is valid across
/// threads and isolates, so its address travels as a plain int. The reference
/// is a *new* one so that the sending isolate's finalizers — which run when
/// that isolate shuts down — cannot delete it out from under the receiver.
/// `JReference.pointer` is `@internal` to `package:jni`; there is no public
/// way to get the raw `JObjectPtr` needed for a cross-isolate handoff, since
/// [JObject] is not sendable. This reaches past that boundary deliberately and
/// is coupled to the pinned `jni: 0.14.2` — a shift in `.reference`/`.pointer`
/// would break at compile time, not silently at runtime.
int _handOver(JObject object) {
  // ignore: invalid_use_of_internal_member
  final pointer = object.reference.pointer;
  return Jni.env.NewGlobalRef(pointer).address;
}

/// Adopts the global reference at [address], taking over responsibility for
/// deleting it. Pairs with [_handOver]. Callers pass the result straight to
/// `.as(..., releaseOriginal: true)` so the adopted reference is handed
/// through rather than duplicated.
JObject _receive(int address) =>
    JObject.fromReference(JGlobalReference(Pointer<Void>.fromAddress(address)));
