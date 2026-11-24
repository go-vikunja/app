import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';

/// An upload op taken out of the queue for a delete's Undo, as it was
/// there, until [until].
@immutable
final class SetAsideUpload {
  const new({required this.op, required this.until});

  final OutboxRow op;
  final DateTime until;
}

/// The kind is always an upload's and the sequence is handed out anew when
/// the op goes back to the queue, so neither is stored.
String encodeSetAsideUploads(Iterable<SetAsideUpload> entries) => jsonEncode([
  for (final SetAsideUpload(:op, :until) in entries)
    {
      'id': op.id,
      'task': op.taskId,
      'payload': op.payload,
      'created': _millis(op.createdAt),
      'attempts': op.attempts,
      'next': ?_optionalMillis(op.nextAttemptAt),
      'last': ?_optionalMillis(op.lastAttemptAt),
      'state': op.state,
      'error': ?op.lastError,
      'sent': ?_optionalMillis(op.sentAt),
      'until': _millis(until),
    },
]);

/// Empty for a null or unreadable value; an unreadable entry is skipped.
List<SetAsideUpload> decodeSetAsideUploads(String? json) {
  if (json == null) return const [];
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  if (decoded is! List<Object?>) return const [];
  return [for (final entry in decoded) ?_decodeEntry(entry)];
}

SetAsideUpload? _decodeEntry(Object? json) => switch (json) {
  {
            'id': final String id,
            'task': final int taskId,
            'payload': final String payload,
            'created': final int created,
            'attempts': final int attempts,
            'state': final String state,
            'until': final int until,
          } &&
          final Map<String, Object?> map
      when _isOptional<int>(map['next']) &&
          _isOptional<int>(map['last']) &&
          _isOptional<String>(map['error']) &&
          _isOptional<int>(map['sent']) =>
    SetAsideUpload(
      op: OutboxRow(
        id: id,
        sequence: 0,
        kind: OutboxOperationKind.uploadAttachment.name,
        taskId: taskId,
        payload: payload,
        createdAt: _instant(created),
        attempts: attempts,
        nextAttemptAt: _optionalInstant(map['next'] as int?),
        lastAttemptAt: _optionalInstant(map['last'] as int?),
        state: state,
        lastError: map['error'] as String?,
        sentAt: _optionalInstant(map['sent'] as int?),
      ),
      until: _instant(until),
    ),
  _ => null,
};

bool _isOptional<T>(Object? value) => value == null || value is T;

int _millis(DateTime instant) => instant.toUtc().millisecondsSinceEpoch;

int? _optionalMillis(DateTime? instant) =>
    instant == null ? null : _millis(instant);

DateTime _instant(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

DateTime? _optionalInstant(int? millis) =>
    millis == null ? null : _instant(millis);
