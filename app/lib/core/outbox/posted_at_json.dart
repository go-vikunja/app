import 'dart:convert';

/// [payload], a queued create or upload, with [at] as the time its request
/// last left the device. Its encoder writes none, as a payload is encoded
/// afresh only when no attempt can have reached the server, or after a
/// refusal.
String withPostedAt(String payload, DateTime at) => jsonEncode({
  ...jsonDecode(payload) as Map<String, Object?>,
  _postedAtKey: at.toUtc().toIso8601String(),
});

/// When the request of the queued create or upload [payload] last left the
/// device; null when it never did, and for a task create or upload an
/// earlier version sent.
DateTime? postedAtOf(String payload) => switch (jsonDecode(payload)) {
  {_postedAtKey: final String at} => DateTime.tryParse(at)?.toUtc(),
  _ => null,
};

// The key queued label creates already store it under, so their stored rows
// stay readable.
const _postedAtKey = 'posted_at';
