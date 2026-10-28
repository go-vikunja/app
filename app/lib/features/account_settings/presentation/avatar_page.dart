import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository_providers.dart';
import 'package:vikunja_mobile/features/account_settings/application/avatar_files.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_failure.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/avatar_crop_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/avatar_labels.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/sign_in_provider_name.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/initials_avatar.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/connection/presentation/browser_leg_hint.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';

final _log = Logger('AvatarPage');

/// Where the account's avatar comes from, in the web's order: picking one
/// saves it at once; Your photo always picks or takes a photo first and
/// uploads it, so the server never draws an avatar from a missing upload.
/// An avatar from the sign-in provider (LDAP, OpenID) is explained instead.
class AvatarPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<AvatarPage> createState() => _AvatarPageState();
}

class _AvatarPageState extends ConsumerState<AvatarPage> {
  AvatarProvider? _saving;

  /// Whether the server answered this page's last request; null before
  /// one, while the last sync run's outcome decides.
  bool? _reachable;

  @override
  void initState() {
    super.initState();
    // The sync does not read the avatar's source.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_refresh()));
  }

  Future<void> _refresh() async {
    final repository = ref.read(accountSettingsRepositoryProvider);
    if (repository == null) return;
    try {
      await repository.refresh();
      if (mounted) setState(() => _reachable = true);
    } on NetworkFailure {
      if (mounted) setState(() => _reachable = false);
    } on Object catch (error) {
      _log.info('Refreshing the avatar failed: ${error.runtimeType}');
    }
  }

  void _show(ScaffoldMessengerState messenger, String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _choose(AvatarProvider provider) async {
    final repository = ref.read(accountSettingsRepositoryProvider);
    if (repository == null || _saving != null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = provider);
    try {
      await repository.setAvatarProvider(provider);
      if (mounted) setState(() => _reachable = true);
      _show(messenger, l10n.avatarChanged);
    } on Object catch (error) {
      _log.warning('Changing the avatar failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      if (error case NetworkFailure(problem: NetworkProblem.unreachable)) {
        if (mounted) setState(() => _reachable = false);
      }
      _show(messenger, accountSettingsFailureText(l10n, error));
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  Future<void> _uploadPhoto() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final source = await showOptionSheet<AttachmentSource>(
      context,
      title: l10n.avatarProviderUpload,
      options: [
        SheetOption(
          value: AttachmentSource.photos,
          label: l10n.avatarChoosePhoto,
        ),
        SheetOption(
          value: AttachmentSource.camera,
          label: l10n.avatarTakePhoto,
        ),
      ],
    );
    if (source == null || !mounted) return;
    final picker = ref.read(attachmentPickerProvider);
    final files = ref.read(avatarFilesProvider);
    final Uint8List bytes;
    try {
      final picked = switch (source) {
        AttachmentSource.camera => await picker.takePhoto(),
        _ => (await picker.pickPhotos(
          imagesOnly: true,
          multiple: false,
        )).firstOrNull,
      };
      if (picked == null) return;
      bytes = await files.readPicked(picked.path);
    } on Object catch (error) {
      _log.warning('Picking the avatar failed: ${error.runtimeType}');
      _show(messenger, l10n.avatarPickFailed);
      return;
    }
    final repository = ref.read(accountSettingsRepositoryProvider);
    if (!mounted || repository == null) return;
    final uploaded = await navigator.push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => AvatarCropPage(
          source: bytes,
          onUpload: (png) => _upload(repository, files, png),
        ),
      ),
    );
    if (uploaded ?? false) _show(messenger, l10n.avatarUploaded);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entry = ref.watch(
      accountsProvider.select((accounts) => accounts.value?.activeAccount),
    );
    final state = ref.watch(accountSettingsProvider).value;
    final lastSyncOffline = ref.watch(offlineProvider) != null;
    final offline = switch (_reachable) {
      null => lastSyncOffline,
      final reachable => !reachable,
    };
    final saving = _saving != null;
    final signingIn = ref.watch(signInControllerProvider) is SignInInProgress;

    return Scaffold(
      appBar: AppBar(
        title: ScreenTitle(l10n.avatarTitle),
        bottom: SavingProgressBar(saving: saving),
      ),
      body: switch ((entry, state)) {
        (final entry?, final state?) => _AvatarChoices(
          user: User(
            id: entry.account.userId,
            username: entry.account.username,
            name: entry.account.displayName,
          ),
          accountId: entry.id,
          state: state,
          saving: _saving,
          offline: offline,
          needsReauth: entry.account.needsReauth,
          canChange: !offline && !saving && !entry.account.needsReauth,
          onRetry: () => unawaited(_refresh()),
          onSignInAgain: signingIn
              ? null
              : () => unawaited(signInAgainAfterHint(context, ref, entry)),
          onChoose: (provider) => unawaited(_choose(provider)),
          onUpload: () => unawaited(_uploadPhoto()),
        ),
        _ => CenteredScrollView(
          child: LoadingPlaceholder(label: l10n.accountSettingsLoading),
        ),
      },
    );
  }
}

class _AvatarChoices extends StatelessWidget {
  const new({
    required this.user,
    required this.accountId,
    required this.state,
    required this.saving,
    required this.offline,
    required this.needsReauth,
    required this.canChange,
    required this.onRetry,
    required this.onSignInAgain,
    required this.onChoose,
    required this.onUpload,
  });

  final User user;
  final String accountId;
  final AccountSettingsState state;
  final AvatarProvider? saving;
  final bool offline;
  final bool needsReauth;
  final bool canChange;
  final VoidCallback onRetry;

  /// Null while a sign-in runs.
  final VoidCallback? onSignInAgain;
  final ValueChanged<AvatarProvider> onChoose;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final current = saving ?? state.avatarProvider;
    final fromSignIn = current?.isFromSignIn ?? false;
    final authProvider = signInProviderName(state.profile?.authProvider ?? '');

    Widget preview(AvatarProvider provider) => switch (provider) {
      AvatarProvider.initials => InitialsAvatar(
        name: user.displayName,
        radius: 20,
        primary: true,
      ),
      AvatarProvider.upload when current == AvatarProvider.upload => UserAvatar(
        user: user,
        radius: 20,
        accountId: accountId,
        primary: true,
      ),
      _ => ExcludeSemantics(
        child: CircleAvatar(
          radius: 20,
          backgroundColor: colors.secondaryContainer,
          child: Icon(
            avatarProviderIcon(provider),
            color: colors.onSecondaryContainer,
          ),
        ),
      ),
    };

    return ListView(
      padding: const EdgeInsets.only(top: 24, bottom: 32),
      children: [
        Center(
          child: Semantics(
            image: true,
            label: l10n.avatarCurrent,
            child: UserAvatar(
              user: user,
              radius: 56,
              accountId: accountId,
              primary: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (needsReauth)
          SettingsNote(
            text: l10n.accountSettingsSignInAgain,
            icon: Icons.lock_clock_outlined,
            emphasized: true,
            action: TextButton(
              onPressed: onSignInAgain,
              child: Text(l10n.reauthAction),
            ),
          )
        else if (offline)
          SettingsNote(
            text: l10n.accountSettingsOffline,
            icon: Icons.cloud_off_outlined,
            emphasized: true,
            action: TextButton(onPressed: onRetry, child: Text(l10n.retry)),
          ),
        if (fromSignIn)
          SettingsNote(
            text: current == AvatarProvider.ldap
                ? l10n.avatarManagedLdap
                : l10n.avatarManagedOpenId(authProvider),
            icon: avatarProviderIcon(current!),
          )
        else ...[
          for (final provider in AvatarProvider.choices)
            ListTile(
              leading: preview(provider),
              title: Text(avatarProviderLabel(l10n, provider)),
              subtitle: Text(
                provider == AvatarProvider.upload &&
                        current == AvatarProvider.upload
                    ? l10n.avatarProviderUploadReplace
                    : avatarProviderDescription(l10n, provider),
              ),
              selected: provider == current,
              trailing: provider == current
                  ? const Icon(Icons.check)
                  : provider == AvatarProvider.upload
                  ? const Icon(Icons.chevron_right)
                  : null,
              enabled: canChange,
              onTap: switch (provider) {
                AvatarProvider.upload => onUpload,
                _ when provider == current => null,
                _ => () => onChoose(provider),
              },
            ),
          SettingsNote(
            text: l10n.avatarAppShowsInitials,
            icon: Icons.info_outline,
          ),
        ],
      ],
    );
  }
}

/// Throws what the upload failed with.
Future<void> _upload(
  AccountSettingsRepository repository,
  AvatarFiles files,
  Uint8List png,
) async {
  final file = await files.write(png);
  try {
    await repository.uploadAvatar(file);
  } on Object catch (error) {
    _log.warning('Uploading the avatar failed: ${error.runtimeType}');
    rethrow;
  } finally {
    unawaited(files.delete(file));
  }
}
