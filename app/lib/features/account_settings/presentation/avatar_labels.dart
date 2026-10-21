import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

String avatarProviderLabel(AppLocalizations l10n, AvatarProvider provider) =>
    switch (provider) {
      AvatarProvider.defaultAvatar => l10n.avatarProviderDefault,
      AvatarProvider.initials => l10n.avatarProviderInitials,
      AvatarProvider.gravatar => l10n.avatarProviderGravatar,
      AvatarProvider.marble => l10n.avatarProviderMarble,
      AvatarProvider.upload => l10n.avatarProviderUpload,
      AvatarProvider.ldap => l10n.avatarProviderLdap,
      AvatarProvider.openid => l10n.avatarProviderOpenId,
    };

String avatarProviderDescription(
  AppLocalizations l10n,
  AvatarProvider provider,
) => switch (provider) {
  AvatarProvider.defaultAvatar => l10n.avatarProviderDefaultSubtitle,
  AvatarProvider.initials => l10n.avatarProviderInitialsSubtitle,
  AvatarProvider.gravatar => l10n.avatarProviderGravatarSubtitle,
  AvatarProvider.marble => l10n.avatarProviderMarbleSubtitle,
  AvatarProvider.upload => l10n.avatarProviderUploadSubtitle,
  AvatarProvider.ldap => l10n.avatarManagedLdap,
  AvatarProvider.openid => l10n.avatarProviderOpenId,
};

IconData avatarProviderIcon(AvatarProvider provider) => switch (provider) {
  AvatarProvider.defaultAvatar => Icons.account_circle_outlined,
  AvatarProvider.initials => Icons.abc,
  AvatarProvider.gravatar => Icons.public,
  AvatarProvider.marble => Icons.blur_circular,
  AvatarProvider.upload => Icons.add_a_photo_outlined,
  AvatarProvider.ldap => Icons.corporate_fare,
  AvatarProvider.openid => Icons.verified_user_outlined,
};
