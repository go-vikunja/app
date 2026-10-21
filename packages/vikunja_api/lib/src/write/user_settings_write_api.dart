import 'package:dio/dio.dart';
import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/task_codec.dart';
import 'package:vikunja_api/src/dto/user_profile_codec.dart';
import 'package:vikunja_api/src/dto/user_settings_codec.dart';
import 'package:vikunja_api/src/write/write_ports.dart';
import 'package:vikunja_api/src/write/write_transport.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

const _generalSettings = '/user/settings/general';
const _frontendSettings = 'frontend_settings';
const _methodNotAllowed = 405;
const _contentTooLarge = 413;
const _uploadTooLarge = 4035;
const _blankFileName = 'avatar';

/// Read-only on the server; v2 would refuse a key its schema lacks.
const _notWritten = {r'$schema', 'extra_settings_links'};

final class UserSettingsWriteApi implements UserSettingsWritePort {
  new({required Dio dio, required ServerConnection connection})
    : _transport = WriteTransport(dio, connection),
      _mergePatch =
          connection.preferredApiVersion == ApiVersion.v2 &&
          connection.capabilities.has(Capability.userSettingsMergePatch);

  final WriteTransport _transport;
  final bool _mergePatch;

  bool get _v2 => _transport.version == ApiVersion.v2;

  @override
  Future<UserSettingsWriteResult> update(UserSettingsChanges changes) async {
    if (!changes.isEmpty) {
      final topLevel = _topLevel(changes);
      final frontend = _frontend(changes);
      if (!_mergePatch || !await _patch(topLevel, frontend)) {
        await _replace(topLevel, frontend);
      }
    }
    return await _read();
  }

  /// False when the server has no merge-patch after all.
  Future<bool> _patch(
    Map<String, Object?> topLevel,
    Map<String, Object?> frontend,
  ) async {
    try {
      await _transport.send(
        'PATCH',
        _generalSettings,
        body: {
          ...topLevel,
          if (frontend.isNotEmpty) _frontendSettings: frontend,
        },
        contentType: mergePatchContentType,
        acceptNotModified: true,
      );
      return true;
    } on UnexpectedResponse catch (failure) {
      if (failure.statusCode != _methodNotAllowed) rethrow;
      return false;
    }
  }

  Future<void> _replace(
    Map<String, Object?> topLevel,
    Map<String, Object?> frontend,
  ) async {
    final stored = _transport.decode(
      await _readUser(),
      (json) => objectOf(objectOf(json, 'user')['settings'], 'settings'),
    );
    final settings = {
      for (final MapEntry(:key, :value) in stored.entries)
        if (!_notWritten.contains(key)) key: value,
      ...topLevel,
    };
    if (frontend.isNotEmpty) {
      final merged = switch (settings[_frontendSettings]) {
        final Map<String, Object?> stored => {...stored},
        _ => <String, Object?>{},
      };
      for (final MapEntry(:key, :value) in frontend.entries) {
        if (value == null) {
          merged.remove(key);
        } else {
          merged[key] = value;
        }
      }
      settings[_frontendSettings] = merged;
    }
    await _transport.send(
      _v2 ? 'PUT' : 'POST',
      _generalSettings,
      body: settings,
    );
  }

  Future<Response<Object?>> _readUser() => _transport.send('GET', '/user');

  Future<UserSettingsWriteResult> _read() async =>
      _transport.decode<UserSettingsWriteResult>(await _readUser(), (json) {
        final profile = parseUserProfile(json);
        if (profile == null) throw const MalformedJson('not a user');
        return (
          profile: profile,
          settings: parseUserSettings(objectOf(json, 'user')['settings']),
        );
      });

  @override
  Future<AvatarProvider?> avatarProvider() async =>
      _transport.decode<AvatarProvider?>(
        await _transport.send(
          'GET',
          _v2 ? '/user/settings/avatar/provider' : '/user/settings/avatar',
        ),
        (json) => AvatarProvider.fromWire(
          objectOf(json, 'avatar')['avatar_provider'],
        ),
      );

  @override
  Future<void> setAvatarProvider(AvatarProvider provider) async {
    if (provider.isFromSignIn) {
      throw ArgumentError.value(
        provider,
        'provider',
        'set by the sign-in provider only',
      );
    }
    await _transport.send(
      _v2 ? 'PUT' : 'POST',
      _v2 ? '/user/settings/avatar/provider' : '/user/settings/avatar',
      body: {'avatar_provider': provider.wireName},
    );
  }

  @override
  Future<void> uploadAvatar({
    required String fileName,
    required Stream<List<int>> bytes,
    required int length,
    Duration? timeout,
  }) async {
    Object? sourceError;
    StackTrace? sourceStack;
    final source = bytes.handleError((Object error, StackTrace stack) {
      sourceError = error;
      sourceStack = stack;
      Error.throwWithStackTrace(error, stack);
    });
    final form = FormData()
      ..files.add(
        MapEntry(
          'avatar',
          MultipartFile.fromStream(
            () => source,
            length,
            filename: fileName.trim().isEmpty ? _blankFileName : fileName,
          ),
        ),
      );
    try {
      await _transport.sendForm(
        'PUT',
        _v2 ? '/user/settings/avatar' : '/user/settings/avatar/upload',
        form,
        timeout: timeout,
      );
    } on VikunjaFailure catch (failure) {
      if (sourceError case final error?) {
        Error.throwWithStackTrace(error, sourceStack!);
      }
      throw _uploadFailure(failure);
    }
  }

  /// The server's "Uploaded file is no image." is a 400 without a code.
  static VikunjaFailure _uploadFailure(VikunjaFailure failure) =>
      switch (failure) {
        DomainError(statusCode: _contentTooLarge, :final code?) => FileTooLarge(
          code: code,
          message: failure.message,
        ),
        UnexpectedResponse(statusCode: _contentTooLarge) => FileTooLarge(
          code: _uploadTooLarge,
          message: failure.message,
        ),
        UnexpectedResponse(statusCode: 400, :final message) => ValidationFailed(
          fieldErrors: {
            'avatar': [if (message.isNotEmpty) message],
          },
          message: message,
        ),
        _ => failure,
      };

  static Map<String, Object?> _topLevel(UserSettingsChanges changes) => {
    'name': ?changes.name,
    'email_reminders_enabled': ?changes.emailRemindersEnabled,
    'discoverable_by_name': ?changes.discoverableByName,
    'discoverable_by_email': ?changes.discoverableByEmail,
    'overdue_tasks_reminders_enabled': ?changes.overdueTasksRemindersEnabled,
    'overdue_tasks_reminders_time':
        ?changes.overdueTasksRemindersTime?.wireName,
    if (changes.defaultProjectId case final change?)
      'default_project_id': change.value ?? 0,
    'week_start': ?changes.weekStart,
    'timezone': ?changes.timezone,
    'language': ?changes.language,
  };

  /// A null value removes the key, as the merge-patch's `null` does.
  static Map<String, Object?> _frontend(UserSettingsChanges changes) => {
    'quick_add_magic_mode': ?changes.quickAddMagicMode?.wireName,
    if (changes.quickAddDefaultReminders case final reminders?)
      'quick_add_default_reminders': [
        for (final period in reminders)
          {'relative_period': period.inSeconds, 'relative_to': 'due_date'},
      ],
    if (changes.filterIdUsedOnOverview case final change?)
      'filter_id_used_on_overview': change.value,
    'minimum_priority': ?changes.minimumPriority,
    'comment_sort_order': ?changes.commentSortOrder?.wireName,
    if (changes.dateDisplay case final change?)
      'date_display': change.value?.wireName,
    if (changes.timeFormat case final change?)
      'time_format': change.value?.wireName,
    'color_schema': ?changes.colorSchema?.wireName,
    if (changes.defaultViewKind case final change?)
      'default_view': change.value?.wireName,
  };
}
