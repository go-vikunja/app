// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(activeAccountId)
final activeAccountIdProvider = ActiveAccountIdProvider._();

final class ActiveAccountIdProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  ActiveAccountIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeAccountIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeAccountIdHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return activeAccountId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$activeAccountIdHash() => r'07a5feac1a80c62c1728f98bba9dcebb1446c138';

/// Whether the active account is a link-share guest, which sees one
/// project and none of what needs a user.

@ProviderFor(activeAccountIsGuest)
final activeAccountIsGuestProvider = ActiveAccountIsGuestProvider._();

/// Whether the active account is a link-share guest, which sees one
/// project and none of what needs a user.

final class ActiveAccountIsGuestProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the active account is a link-share guest, which sees one
  /// project and none of what needs a user.
  ActiveAccountIsGuestProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeAccountIsGuestProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeAccountIsGuestHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return activeAccountIsGuest(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$activeAccountIsGuestHash() =>
    r'686341394d55e92531e71ee058d822a9972e39b7';

@ProviderFor(accountIsGuest)
final accountIsGuestProvider = AccountIsGuestFamily._();

final class AccountIsGuestProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  AccountIsGuestProvider._({
    required AccountIsGuestFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountIsGuestProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountIsGuestHash();

  @override
  String toString() {
    return r'accountIsGuestProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as String;
    return accountIsGuest(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountIsGuestProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountIsGuestHash() => r'764688f0db8f5813982c4b5e6bbbd7c134bff9a5';

final class AccountIsGuestFamily extends $Family
    with $FunctionalFamilyOverride<bool, String> {
  AccountIsGuestFamily._()
    : super(
        retry: null,
        name: r'accountIsGuestProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountIsGuestProvider call(String accountId) =>
      AccountIsGuestProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountIsGuestProvider';
}

/// The authenticated client of one account, shared by its read and write
/// clients. Kept alive by the sync engine and the outbox sender that use
/// it, so it goes with them on sign-out.

@ProviderFor(accountDio)
final accountDioProvider = AccountDioFamily._();

/// The authenticated client of one account, shared by its read and write
/// clients. Kept alive by the sync engine and the outbox sender that use
/// it, so it goes with them on sign-out.

final class AccountDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// The authenticated client of one account, shared by its read and write
  /// clients. Kept alive by the sync engine and the outbox sender that use
  /// it, so it goes with them on sign-out.
  AccountDioProvider._({
    required AccountDioFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountDioProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountDioHash();

  @override
  String toString() {
    return r'accountDioProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    final argument = this.argument as String;
    return accountDio(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountDioProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountDioHash() => r'd36a61c98b874f43bd96511f6a501f1d3a7c3e8e';

/// The authenticated client of one account, shared by its read and write
/// clients. Kept alive by the sync engine and the outbox sender that use
/// it, so it goes with them on sign-out.

final class AccountDioFamily extends $Family
    with $FunctionalFamilyOverride<Dio, String> {
  AccountDioFamily._()
    : super(
        retry: null,
        name: r'accountDioProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The authenticated client of one account, shared by its read and write
  /// clients. Kept alive by the sync engine and the outbox sender that use
  /// it, so it goes with them on sign-out.

  AccountDioProvider call(String accountId) =>
      AccountDioProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountDioProvider';
}

@ProviderFor(readClient)
final readClientProvider = ReadClientFamily._();

final class ReadClientProvider
    extends
        $FunctionalProvider<
          VikunjaReadClient,
          VikunjaReadClient,
          VikunjaReadClient
        >
    with $Provider<VikunjaReadClient> {
  ReadClientProvider._({
    required ReadClientFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'readClientProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$readClientHash();

  @override
  String toString() {
    return r'readClientProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<VikunjaReadClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VikunjaReadClient create(Ref ref) {
    final argument = this.argument as String;
    return readClient(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VikunjaReadClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VikunjaReadClient>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReadClientProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$readClientHash() => r'7097ffdc6f881435a03fe76d7f6e80dcd576c57e';

final class ReadClientFamily extends $Family
    with $FunctionalFamilyOverride<VikunjaReadClient, String> {
  ReadClientFamily._()
    : super(
        retry: null,
        name: r'readClientProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReadClientProvider call(String accountId) =>
      ReadClientProvider._(argument: accountId, from: this);

  @override
  String toString() => r'readClientProvider';
}

@ProviderFor(writeClient)
final writeClientProvider = WriteClientFamily._();

final class WriteClientProvider
    extends
        $FunctionalProvider<
          VikunjaWriteClient,
          VikunjaWriteClient,
          VikunjaWriteClient
        >
    with $Provider<VikunjaWriteClient> {
  WriteClientProvider._({
    required WriteClientFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'writeClientProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$writeClientHash();

  @override
  String toString() {
    return r'writeClientProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<VikunjaWriteClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VikunjaWriteClient create(Ref ref) {
    final argument = this.argument as String;
    return writeClient(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VikunjaWriteClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VikunjaWriteClient>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WriteClientProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$writeClientHash() => r'8c46173ee9a0c709b9eeeb1afae856734a3529ba';

final class WriteClientFamily extends $Family
    with $FunctionalFamilyOverride<VikunjaWriteClient, String> {
  WriteClientFamily._()
    : super(
        retry: null,
        name: r'writeClientProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WriteClientProvider call(String accountId) =>
      WriteClientProvider._(argument: accountId, from: this);

  @override
  String toString() => r'writeClientProvider';
}

@ProviderFor(userSettingsWritePort)
final userSettingsWritePortProvider = UserSettingsWritePortFamily._();

final class UserSettingsWritePortProvider
    extends
        $FunctionalProvider<
          UserSettingsWritePort,
          UserSettingsWritePort,
          UserSettingsWritePort
        >
    with $Provider<UserSettingsWritePort> {
  UserSettingsWritePortProvider._({
    required UserSettingsWritePortFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'userSettingsWritePortProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userSettingsWritePortHash();

  @override
  String toString() {
    return r'userSettingsWritePortProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<UserSettingsWritePort> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UserSettingsWritePort create(Ref ref) {
    final argument = this.argument as String;
    return userSettingsWritePort(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserSettingsWritePort value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserSettingsWritePort>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is UserSettingsWritePortProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userSettingsWritePortHash() =>
    r'1c2c23388efcd87ff62ddc55c003b9eab147693a';

final class UserSettingsWritePortFamily extends $Family
    with $FunctionalFamilyOverride<UserSettingsWritePort, String> {
  UserSettingsWritePortFamily._()
    : super(
        retry: null,
        name: r'userSettingsWritePortProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UserSettingsWritePortProvider call(String accountId) =>
      UserSettingsWritePortProvider._(argument: accountId, from: this);

  @override
  String toString() => r'userSettingsWritePortProvider';
}

@ProviderFor(accountSecurityPort)
final accountSecurityPortProvider = AccountSecurityPortFamily._();

final class AccountSecurityPortProvider
    extends
        $FunctionalProvider<
          AccountSecurityPort,
          AccountSecurityPort,
          AccountSecurityPort
        >
    with $Provider<AccountSecurityPort> {
  AccountSecurityPortProvider._({
    required AccountSecurityPortFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountSecurityPortProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountSecurityPortHash();

  @override
  String toString() {
    return r'accountSecurityPortProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AccountSecurityPort> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountSecurityPort create(Ref ref) {
    final argument = this.argument as String;
    return accountSecurityPort(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountSecurityPort value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountSecurityPort>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountSecurityPortProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountSecurityPortHash() =>
    r'a6026084c70e82977297884b6376b02d08f5b929';

final class AccountSecurityPortFamily extends $Family
    with $FunctionalFamilyOverride<AccountSecurityPort, String> {
  AccountSecurityPortFamily._()
    : super(
        retry: null,
        name: r'accountSecurityPortProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountSecurityPortProvider call(String accountId) =>
      AccountSecurityPortProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountSecurityPortProvider';
}

@ProviderFor(teamsPort)
final teamsPortProvider = TeamsPortFamily._();

final class TeamsPortProvider
    extends $FunctionalProvider<TeamsPort, TeamsPort, TeamsPort>
    with $Provider<TeamsPort> {
  TeamsPortProvider._({
    required TeamsPortFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'teamsPortProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$teamsPortHash();

  @override
  String toString() {
    return r'teamsPortProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<TeamsPort> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TeamsPort create(Ref ref) {
    final argument = this.argument as String;
    return teamsPort(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TeamsPort value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TeamsPort>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TeamsPortProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$teamsPortHash() => r'7197dc19ec85071f382747f47e48e4e56b1e3bb0';

final class TeamsPortFamily extends $Family
    with $FunctionalFamilyOverride<TeamsPort, String> {
  TeamsPortFamily._()
    : super(
        retry: null,
        name: r'teamsPortProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TeamsPortProvider call(String accountId) =>
      TeamsPortProvider._(argument: accountId, from: this);

  @override
  String toString() => r'teamsPortProvider';
}

@ProviderFor(projectSharingPort)
final projectSharingPortProvider = ProjectSharingPortFamily._();

final class ProjectSharingPortProvider
    extends
        $FunctionalProvider<
          ProjectSharingPort,
          ProjectSharingPort,
          ProjectSharingPort
        >
    with $Provider<ProjectSharingPort> {
  ProjectSharingPortProvider._({
    required ProjectSharingPortFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'projectSharingPortProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$projectSharingPortHash();

  @override
  String toString() {
    return r'projectSharingPortProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ProjectSharingPort> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProjectSharingPort create(Ref ref) {
    final argument = this.argument as String;
    return projectSharingPort(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectSharingPort value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectSharingPort>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ProjectSharingPortProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$projectSharingPortHash() =>
    r'8d564ee956f4587eeac0f1b93f19a669b08facd1';

final class ProjectSharingPortFamily extends $Family
    with $FunctionalFamilyOverride<ProjectSharingPort, String> {
  ProjectSharingPortFamily._()
    : super(
        retry: null,
        name: r'projectSharingPortProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProjectSharingPortProvider call(String accountId) =>
      ProjectSharingPortProvider._(argument: accountId, from: this);

  @override
  String toString() => r'projectSharingPortProvider';
}

@ProviderFor(accountDatabaseFiles)
final accountDatabaseFilesProvider = AccountDatabaseFilesProvider._();

final class AccountDatabaseFilesProvider
    extends
        $FunctionalProvider<
          AccountDatabaseFiles,
          AccountDatabaseFiles,
          AccountDatabaseFiles
        >
    with $Provider<AccountDatabaseFiles> {
  AccountDatabaseFilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountDatabaseFilesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountDatabaseFilesHash();

  @$internal
  @override
  $ProviderElement<AccountDatabaseFiles> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountDatabaseFiles create(Ref ref) {
    return accountDatabaseFiles(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountDatabaseFiles value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountDatabaseFiles>(value),
    );
  }
}

String _$accountDatabaseFilesHash() =>
    r'87b4cc01f96127ac6ebe8dd31c4b798b75a986c4';

/// One account's stored copies of queued uploads, shared by its task
/// repository and outbox sender.

@ProviderFor(accountUploadFiles)
final accountUploadFilesProvider = AccountUploadFilesFamily._();

/// One account's stored copies of queued uploads, shared by its task
/// repository and outbox sender.

final class AccountUploadFilesProvider
    extends $FunctionalProvider<UploadFiles, UploadFiles, UploadFiles>
    with $Provider<UploadFiles> {
  /// One account's stored copies of queued uploads, shared by its task
  /// repository and outbox sender.
  AccountUploadFilesProvider._({
    required AccountUploadFilesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountUploadFilesProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountUploadFilesHash();

  @override
  String toString() {
    return r'accountUploadFilesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<UploadFiles> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UploadFiles create(Ref ref) {
    final argument = this.argument as String;
    return accountUploadFiles(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UploadFiles value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UploadFiles>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountUploadFilesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountUploadFilesHash() =>
    r'1b72ede66d059f865b3c36703011e0a6734d4cef';

/// One account's stored copies of queued uploads, shared by its task
/// repository and outbox sender.

final class AccountUploadFilesFamily extends $Family
    with $FunctionalFamilyOverride<UploadFiles, String> {
  AccountUploadFilesFamily._()
    : super(
        retry: null,
        name: r'accountUploadFilesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// One account's stored copies of queued uploads, shared by its task
  /// repository and outbox sender.

  AccountUploadFilesProvider call(String accountId) =>
      AccountUploadFilesProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountUploadFilesProvider';
}

/// Downloaded attachments of every account; downloads unused for a few
/// days go when this is first read.

@ProviderFor(attachmentDownloads)
final attachmentDownloadsProvider = AttachmentDownloadsProvider._();

/// Downloaded attachments of every account; downloads unused for a few
/// days go when this is first read.

final class AttachmentDownloadsProvider
    extends
        $FunctionalProvider<
          AttachmentDownloads,
          AttachmentDownloads,
          AttachmentDownloads
        >
    with $Provider<AttachmentDownloads> {
  /// Downloaded attachments of every account; downloads unused for a few
  /// days go when this is first read.
  AttachmentDownloadsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'attachmentDownloadsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$attachmentDownloadsHash();

  @$internal
  @override
  $ProviderElement<AttachmentDownloads> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AttachmentDownloads create(Ref ref) {
    return attachmentDownloads(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AttachmentDownloads value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AttachmentDownloads>(value),
    );
  }
}

String _$attachmentDownloadsHash() =>
    r'cc72895c5a239b47d540c8ac4ef6585a92631680';

@ProviderFor(openDatabases)
final openDatabasesProvider = OpenDatabasesProvider._();

final class OpenDatabasesProvider
    extends $FunctionalProvider<OpenDatabases, OpenDatabases, OpenDatabases>
    with $Provider<OpenDatabases> {
  OpenDatabasesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openDatabasesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openDatabasesHash();

  @$internal
  @override
  $ProviderElement<OpenDatabases> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OpenDatabases create(Ref ref) {
    return openDatabases(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OpenDatabases value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OpenDatabases>(value),
    );
  }
}

String _$openDatabasesHash() => r'9977f71812fce1ddaac08f1fecb02a7c66bfa825';

/// One account's database, open until sign-out.

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseFamily._();

/// One account's database, open until sign-out.

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// One account's database, open until sign-out.
  AppDatabaseProvider._({
    required AppDatabaseFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'appDatabaseProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @override
  String toString() {
    return r'appDatabaseProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    final argument = this.argument as String;
    return appDatabase(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppDatabaseProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$appDatabaseHash() => r'81eaa24788cdd32db6aa8790097bcf71920a5b40';

/// One account's database, open until sign-out.

final class AppDatabaseFamily extends $Family
    with $FunctionalFamilyOverride<AppDatabase, String> {
  AppDatabaseFamily._()
    : super(
        retry: null,
        name: r'appDatabaseProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// One account's database, open until sign-out.

  AppDatabaseProvider call(String accountId) =>
      AppDatabaseProvider._(argument: accountId, from: this);

  @override
  String toString() => r'appDatabaseProvider';
}

/// True in a container the OS started without the app (a background run,
/// a notification action): its sync engines leave the daily full pull to
/// the app and give way to a run already in progress.

@ProviderFor(runsHeadless)
final runsHeadlessProvider = RunsHeadlessProvider._();

/// True in a container the OS started without the app (a background run,
/// a notification action): its sync engines leave the daily full pull to
/// the app and give way to a run already in progress.

final class RunsHeadlessProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// True in a container the OS started without the app (a background run,
  /// a notification action): its sync engines leave the daily full pull to
  /// the app and give way to a run already in progress.
  RunsHeadlessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runsHeadlessProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runsHeadlessHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return runsHeadless(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$runsHeadlessHash() => r'c540d3b6e1d9947203596bd1d435eca0ba1f14b7';

/// One account's sync engine; disposed with its database on sign-out.

@ProviderFor(syncEngine)
final syncEngineProvider = SyncEngineFamily._();

/// One account's sync engine; disposed with its database on sign-out.

final class SyncEngineProvider
    extends $FunctionalProvider<SyncEngine, SyncEngine, SyncEngine>
    with $Provider<SyncEngine> {
  /// One account's sync engine; disposed with its database on sign-out.
  SyncEngineProvider._({
    required SyncEngineFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'syncEngineProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$syncEngineHash();

  @override
  String toString() {
    return r'syncEngineProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<SyncEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncEngine create(Ref ref) {
    final argument = this.argument as String;
    return syncEngine(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncEngine>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SyncEngineProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$syncEngineHash() => r'fe01c6aeb6654b057374b242635a39b6693fb278';

/// One account's sync engine; disposed with its database on sign-out.

final class SyncEngineFamily extends $Family
    with $FunctionalFamilyOverride<SyncEngine, String> {
  SyncEngineFamily._()
    : super(
        retry: null,
        name: r'syncEngineProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// One account's sync engine; disposed with its database on sign-out.

  SyncEngineProvider call(String accountId) =>
      SyncEngineProvider._(argument: accountId, from: this);

  @override
  String toString() => r'syncEngineProvider';
}

/// One account's outbox sender; disposed with its database on sign-out.
/// It drains when built (app start), when the app comes back to the front
/// and after every local write; a session that needs a new sign-in pauses
/// it, and the sign-in resumes it.

@ProviderFor(outboxSender)
final outboxSenderProvider = OutboxSenderFamily._();

/// One account's outbox sender; disposed with its database on sign-out.
/// It drains when built (app start), when the app comes back to the front
/// and after every local write; a session that needs a new sign-in pauses
/// it, and the sign-in resumes it.

final class OutboxSenderProvider
    extends $FunctionalProvider<OutboxSender, OutboxSender, OutboxSender>
    with $Provider<OutboxSender> {
  /// One account's outbox sender; disposed with its database on sign-out.
  /// It drains when built (app start), when the app comes back to the front
  /// and after every local write; a session that needs a new sign-in pauses
  /// it, and the sign-in resumes it.
  OutboxSenderProvider._({
    required OutboxSenderFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'outboxSenderProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$outboxSenderHash();

  @override
  String toString() {
    return r'outboxSenderProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<OutboxSender> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OutboxSender create(Ref ref) {
    final argument = this.argument as String;
    return outboxSender(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OutboxSender value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OutboxSender>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OutboxSenderProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$outboxSenderHash() => r'8a5e4de02d6f0c1889c51b0242728328c6c4ed0f';

/// One account's outbox sender; disposed with its database on sign-out.
/// It drains when built (app start), when the app comes back to the front
/// and after every local write; a session that needs a new sign-in pauses
/// it, and the sign-in resumes it.

final class OutboxSenderFamily extends $Family
    with $FunctionalFamilyOverride<OutboxSender, String> {
  OutboxSenderFamily._()
    : super(
        retry: null,
        name: r'outboxSenderProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// One account's outbox sender; disposed with its database on sign-out.
  /// It drains when built (app start), when the app comes back to the front
  /// and after every local write; a session that needs a new sign-in pauses
  /// it, and the sign-in resumes it.

  OutboxSenderProvider call(String accountId) =>
      OutboxSenderProvider._(argument: accountId, from: this);

  @override
  String toString() => r'outboxSenderProvider';
}

/// One account's repositories over its database. Kept alive by the
/// active-account providers below, so they go when another account takes
/// over.

@ProviderFor(accountProjectRepository)
final accountProjectRepositoryProvider = AccountProjectRepositoryFamily._();

/// One account's repositories over its database. Kept alive by the
/// active-account providers below, so they go when another account takes
/// over.

final class AccountProjectRepositoryProvider
    extends
        $FunctionalProvider<
          ProjectRepository,
          ProjectRepository,
          ProjectRepository
        >
    with $Provider<ProjectRepository> {
  /// One account's repositories over its database. Kept alive by the
  /// active-account providers below, so they go when another account takes
  /// over.
  AccountProjectRepositoryProvider._({
    required AccountProjectRepositoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountProjectRepositoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountProjectRepositoryHash();

  @override
  String toString() {
    return r'accountProjectRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ProjectRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProjectRepository create(Ref ref) {
    final argument = this.argument as String;
    return accountProjectRepository(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountProjectRepositoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountProjectRepositoryHash() =>
    r'1a2c96056be7736c7bbe6f840a6df62932f89300';

/// One account's repositories over its database. Kept alive by the
/// active-account providers below, so they go when another account takes
/// over.

final class AccountProjectRepositoryFamily extends $Family
    with $FunctionalFamilyOverride<ProjectRepository, String> {
  AccountProjectRepositoryFamily._()
    : super(
        retry: null,
        name: r'accountProjectRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One account's repositories over its database. Kept alive by the
  /// active-account providers below, so they go when another account takes
  /// over.

  AccountProjectRepositoryProvider call(String accountId) =>
      AccountProjectRepositoryProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountProjectRepositoryProvider';
}

@ProviderFor(accountTaskRepository)
final accountTaskRepositoryProvider = AccountTaskRepositoryFamily._();

final class AccountTaskRepositoryProvider
    extends $FunctionalProvider<TaskRepository, TaskRepository, TaskRepository>
    with $Provider<TaskRepository> {
  AccountTaskRepositoryProvider._({
    required AccountTaskRepositoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountTaskRepositoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountTaskRepositoryHash();

  @override
  String toString() {
    return r'accountTaskRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<TaskRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskRepository create(Ref ref) {
    final argument = this.argument as String;
    return accountTaskRepository(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountTaskRepositoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountTaskRepositoryHash() =>
    r'9714f3a4aca2ceeb47667e6d52efc970764fccf9';

final class AccountTaskRepositoryFamily extends $Family
    with $FunctionalFamilyOverride<TaskRepository, String> {
  AccountTaskRepositoryFamily._()
    : super(
        retry: null,
        name: r'accountTaskRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountTaskRepositoryProvider call(String accountId) =>
      AccountTaskRepositoryProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountTaskRepositoryProvider';
}

@ProviderFor(accountLabelRepository)
final accountLabelRepositoryProvider = AccountLabelRepositoryFamily._();

final class AccountLabelRepositoryProvider
    extends
        $FunctionalProvider<LabelRepository, LabelRepository, LabelRepository>
    with $Provider<LabelRepository> {
  AccountLabelRepositoryProvider._({
    required AccountLabelRepositoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountLabelRepositoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountLabelRepositoryHash();

  @override
  String toString() {
    return r'accountLabelRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<LabelRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LabelRepository create(Ref ref) {
    final argument = this.argument as String;
    return accountLabelRepository(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LabelRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LabelRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountLabelRepositoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountLabelRepositoryHash() =>
    r'a4d33e5e8085a84ccec355e5053a055fd97b6e1a';

final class AccountLabelRepositoryFamily extends $Family
    with $FunctionalFamilyOverride<LabelRepository, String> {
  AccountLabelRepositoryFamily._()
    : super(
        retry: null,
        name: r'accountLabelRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountLabelRepositoryProvider call(String accountId) =>
      AccountLabelRepositoryProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountLabelRepositoryProvider';
}

@ProviderFor(accountUserRepository)
final accountUserRepositoryProvider = AccountUserRepositoryFamily._();

final class AccountUserRepositoryProvider
    extends $FunctionalProvider<UserRepository, UserRepository, UserRepository>
    with $Provider<UserRepository> {
  AccountUserRepositoryProvider._({
    required AccountUserRepositoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountUserRepositoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountUserRepositoryHash();

  @override
  String toString() {
    return r'accountUserRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<UserRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserRepository create(Ref ref) {
    final argument = this.argument as String;
    return accountUserRepository(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountUserRepositoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountUserRepositoryHash() =>
    r'bb746e84d6aa63db4a2b90e606dce974b872b5a3';

final class AccountUserRepositoryFamily extends $Family
    with $FunctionalFamilyOverride<UserRepository, String> {
  AccountUserRepositoryFamily._()
    : super(
        retry: null,
        name: r'accountUserRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountUserRepositoryProvider call(String accountId) =>
      AccountUserRepositoryProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountUserRepositoryProvider';
}

/// The active account's projects; replaced when the active account changes.
/// Null while no account is signed in.

@ProviderFor(projectRepository)
final projectRepositoryProvider = ProjectRepositoryProvider._();

/// The active account's projects; replaced when the active account changes.
/// Null while no account is signed in.

final class ProjectRepositoryProvider
    extends
        $FunctionalProvider<
          ProjectRepository?,
          ProjectRepository?,
          ProjectRepository?
        >
    with $Provider<ProjectRepository?> {
  /// The active account's projects; replaced when the active account changes.
  /// Null while no account is signed in.
  ProjectRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProjectRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProjectRepository? create(Ref ref) {
    return projectRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectRepository?>(value),
    );
  }
}

String _$projectRepositoryHash() => r'e4dc625e518cdb496c9b5f67a5ab243625d3bb63';

@ProviderFor(taskRepository)
final taskRepositoryProvider = TaskRepositoryProvider._();

final class TaskRepositoryProvider
    extends
        $FunctionalProvider<TaskRepository?, TaskRepository?, TaskRepository?>
    with $Provider<TaskRepository?> {
  TaskRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskRepositoryHash();

  @$internal
  @override
  $ProviderElement<TaskRepository?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskRepository? create(Ref ref) {
    return taskRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskRepository?>(value),
    );
  }
}

String _$taskRepositoryHash() => r'b2cd755ae2d6a7f7232b625dfb918977a210cc46';

@ProviderFor(labelRepository)
final labelRepositoryProvider = LabelRepositoryProvider._();

final class LabelRepositoryProvider
    extends
        $FunctionalProvider<
          LabelRepository?,
          LabelRepository?,
          LabelRepository?
        >
    with $Provider<LabelRepository?> {
  LabelRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'labelRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$labelRepositoryHash();

  @$internal
  @override
  $ProviderElement<LabelRepository?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LabelRepository? create(Ref ref) {
    return labelRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LabelRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LabelRepository?>(value),
    );
  }
}

String _$labelRepositoryHash() => r'ceb155f0e97c9b7eb23abc594f6ee22762b4eaa3';

@ProviderFor(userRepository)
final userRepositoryProvider = UserRepositoryProvider._();

final class UserRepositoryProvider
    extends
        $FunctionalProvider<UserRepository?, UserRepository?, UserRepository?>
    with $Provider<UserRepository?> {
  UserRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userRepositoryHash();

  @$internal
  @override
  $ProviderElement<UserRepository?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserRepository? create(Ref ref) {
    return userRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserRepository?>(value),
    );
  }
}

String _$userRepositoryHash() => r'28da8498a99ef2100dbc72f90b776490a8e9c948';

/// The last step of a sign-out: makes a background run in another isolate
/// let go of the account, drops its avatars and attachment images from
/// memory, cancels the account's notifications (scheduled and in the
/// tray) and forgets their preferences, the background notes and the
/// unsent comments, stops its outbox sender and sync engine, closes its
/// database and deletes the files: the database, the stored copies of
/// queued uploads and the downloaded attachments.

@ProviderFor(accountDataWiper)
final accountDataWiperProvider = AccountDataWiperProvider._();

/// The last step of a sign-out: makes a background run in another isolate
/// let go of the account, drops its avatars and attachment images from
/// memory, cancels the account's notifications (scheduled and in the
/// tray) and forgets their preferences, the background notes and the
/// unsent comments, stops its outbox sender and sync engine, closes its
/// database and deletes the files: the database, the stored copies of
/// queued uploads and the downloaded attachments.

final class AccountDataWiperProvider
    extends
        $FunctionalProvider<
          AccountDataWiper,
          AccountDataWiper,
          AccountDataWiper
        >
    with $Provider<AccountDataWiper> {
  /// The last step of a sign-out: makes a background run in another isolate
  /// let go of the account, drops its avatars and attachment images from
  /// memory, cancels the account's notifications (scheduled and in the
  /// tray) and forgets their preferences, the background notes and the
  /// unsent comments, stops its outbox sender and sync engine, closes its
  /// database and deletes the files: the database, the stored copies of
  /// queued uploads and the downloaded attachments.
  AccountDataWiperProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountDataWiperProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountDataWiperHash();

  @$internal
  @override
  $ProviderElement<AccountDataWiper> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AccountDataWiper create(Ref ref) {
    return accountDataWiper(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountDataWiper value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountDataWiper>(value),
    );
  }
}

String _$accountDataWiperHash() => r'8356814b1895112b4901055a7c7d7b2d0d1d6752';
