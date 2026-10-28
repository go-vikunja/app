import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/core/network/client_certificate.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/common/presentation/form_parts.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/connection/application/certificate_file.dart';
import 'package:vikunja_mobile/features/connection/presentation/secret_text_field.dart';

final _log = Logger('ClientCertificatePage');

/// Imports a client certificate (PKCS#12) for [origin]: the file's bytes
/// stay in this page until they are checked with the password and stored
/// in secure storage; the picker's copy is gone as soon as they are read.
class ClientCertificatePage extends ConsumerStatefulWidget {
  const new({required this.origin, super.key});

  final OriginKey origin;

  @override
  ConsumerState<ClientCertificatePage> createState() =>
      _ClientCertificatePageState();
}

class _ClientCertificatePageState extends ConsumerState<ClientCertificatePage> {
  final _password = TextEditingController();
  String? _fileName;
  Uint8List? _bytes;
  String? _fileError;
  String? _passwordError;
  var _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  /// A new or changed error speaks itself as a live region: the file's on
  /// every platform, the password field's where the platform cannot
  /// announce. An unchanged one is announced.
  void _showError({String? file, String? password}) {
    final announcer = Announcer.of(context);
    final fileUnchanged = file == _fileError;
    final passwordChanged = password != _passwordError;
    setState(() {
      _fileError = file;
      _passwordError = password;
    });
    if (file != null) {
      if (fileUnchanged) announcer.say(file);
    } else if (password != null) {
      announcer.say(password, onlyIfPlatformAnnounces: passwordChanged);
    }
  }

  Future<void> _choose() async {
    final l10n = context.l10n;
    final PickedCertificateFile picked;
    try {
      picked = await pickCertificateFile(ref.read(attachmentPickerProvider));
    } on Object catch (error) {
      _log.info('The file picker failed: ${error.runtimeType}');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.connectionPickerFailed)));
      }
      return;
    }
    if (!mounted) return;
    switch (picked) {
      case CertificateFileCancelled():
        return;
      case CertificateFileTooLarge():
        _showError(file: l10n.connectionFileTooLarge);
      case CertificateFileUnreadable():
        _showError(file: l10n.connectionFileUnreadable);
      case CertificateFileRead(:final name, :final bytes):
        setState(() {
          _fileName = name;
          _bytes = bytes;
          _fileError = null;
          _passwordError = null;
        });
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final bytes = _bytes;
    final fileName = _fileName;
    if (bytes == null || fileName == null) {
      _showError(file: l10n.connectionNoFileChosen);
      return;
    }
    final password = _password.text;
    switch (validateClientCertificate(bytes, password)) {
      case ClientCertificateProblem.empty:
        _showError(file: l10n.connectionFileEmpty);
        return;
      case ClientCertificateProblem.tooLarge:
        _showError(file: l10n.connectionFileTooLarge);
        return;
      case ClientCertificateProblem.wrongPasswordOrUnsupported:
        _showError(password: l10n.connectionWrongPasswordOrUnsupported);
        return;
      case null:
    }
    setState(() {
      _busy = true;
      _fileError = null;
      _passwordError = null;
    });
    try {
      await ref
          .read(networkProfilesProvider)
          .setClientCertificate(
            widget.origin,
            fileName: fileName,
            bytes: bytes,
            password: password,
          );
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      _log.warning(
        'Storing the client certificate failed: '
        '${error.runtimeType}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.connectionSaveFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final profile = ref
        .watch(connectionProfileProvider(widget.origin))
        .value
        ?.profile;
    final fileName = _fileName;
    final fileError = _fileError;
    final trustsServerInApp =
        profile?.pin != null || profile?.caCertificate != null;

    return Scaffold(
      appBar: AppBar(
        title: ScreenTitle(l10n.connectionClientCertificateHeading),
        bottom: SavingProgressBar(saving: _busy),
      ),
      body: SafeArea(
        top: false,
        child: ReadableWidth.builder(
          maxWidth: ReadableWidth.form,
          builder: (_, _, inset) => ListView(
            padding: EdgeInsets.fromLTRB(16 + inset, 12, 16 + inset, 32),
            children: [
              Text('${widget.origin}', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                l10n.connectionClientCertificateIntroFor('${widget.origin}'),
              ),
              const SizedBox(height: 16),
              if (fileName != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(fileName),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => unawaited(_choose()),
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(
                    fileName == null
                        ? l10n.connectionChooseFile
                        : l10n.connectionChooseOtherFile,
                  ),
                ),
              ),
              if (fileError != null) FormErrorText(fileError),
              const SizedBox(height: 16),
              SecretTextField(
                controller: _password,
                label: l10n.connectionFilePassword,
                revealTooltip: l10n.connectionShowPassword,
                hideTooltip: l10n.connectionHidePassword,
                errorText: _passwordError,
                enabled: !_busy,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() => _passwordError = null);
                  }
                },
                onSubmitted: (_) => unawaited(_save()),
              ),
              if (!trustsServerInApp) ...[
                const SizedBox(height: 16),
                ListNote(
                  icon: Icons.info_outline,
                  text: l10n.connectionClientCertificatePrivateCaHint,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : () => unawaited(_save()),
                child: Text(l10n.connectionSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
