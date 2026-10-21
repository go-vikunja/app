import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/avatar_crop_page.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';

import '../../helpers/account_settings_fakes.dart';
import '../../helpers/attachment_picker_fake.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import 'avatar_fakes.dart';

void main() {
  late AuthFakes auth;
  late SyncFakes data;
  late FakeAttachmentPicker picker;
  late FakeAvatarFiles files;

  FakeAccountSettingsRepository repository() => data.shared.accountSettings;

  setUp(() {
    auth = AuthFakes();
    data = SyncFakes();
    picker = FakeAttachmentPicker()
      ..photos = [
        const PickedFile(path: '/picked/IMG_1.png', name: 'IMG_1.png'),
      ];
    files = FakeAvatarFiles();
  });

  Future<void> pumpAvatarPage(
    WidgetTester tester, {
    AccountSettingsState? state,
    bool needsReauth = false,
    FakeServerConnector? connector,
    List<Override> overrides = const [],
  }) async {
    usePhoneSurface(tester);
    if (state != null) repository().state = state;
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      needsReauth: needsReauth,
    );
    await pumpVikunjaApp(
      tester,
      auth: auth,
      sync: data,
      connector: connector,
      overrides: [
        picker.providerOverride,
        files.providerOverride,
        ...overrides,
      ],
    );
    unawaited(
      containerOf(tester).read(appRouterProvider).push(AppRoutes.accountAvatar),
    );
    await tester.pumpAndSettle();
  }

  Finder tile(String title) => find.widgetWithText(ListTile, title);

  /// The crop page decodes and encodes with the engine, outside the test's
  /// fake time; a progress indicator shows meanwhile.
  Future<void> letTheEngineWork(WidgetTester tester) async {
    bool busy() =>
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
        find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (!busy()) break;
    }
    await tester.pumpAndSettle();
  }

  Future<void> pickAndCrop(WidgetTester tester, String source) async {
    await tester.tap(tile(en.avatarProviderUpload));
    await tester.pumpAndSettle();
    await tester.tap(find.text(source));
    await tester.pump();
    await letTheEngineWork(tester);
  }

  testWidgets('offers the web providers in its order, the current one '
      'ticked', (tester) async {
    await pumpAvatarPage(tester);

    final titles = [
      en.avatarProviderDefault,
      en.avatarProviderInitials,
      en.avatarProviderGravatar,
      en.avatarProviderMarble,
      en.avatarProviderUpload,
    ];
    final tops = [
      for (final title in titles) tester.getTopLeft(tile(title)).dy,
    ];
    expect(tops, [...tops]..sort());
    expect(
      tester.widget<ListTile>(tile(en.avatarProviderInitials)).selected,
      isTrue,
    );
    expect(
      tester.widget<ListTile>(tile(en.avatarProviderMarble)).selected,
      isFalse,
    );
    expect(find.text(en.avatarAppShowsInitials), findsOneWidget);
    expect(repository().calls, ['refresh']);
  });

  testWidgets('a provider saves at once', (tester) async {
    await pumpAvatarPage(tester);

    await tester.tap(tile(en.avatarProviderMarble));
    await tester.pumpAndSettle();

    expect(repository().calls, ['refresh', 'setAvatarProvider marble']);
    expect(find.text(en.avatarChanged), findsOneWidget);
    expect(
      tester.widget<ListTile>(tile(en.avatarProviderMarble)).selected,
      isTrue,
    );

    await tester.tap(tile(en.avatarProviderMarble));
    await tester.pumpAndSettle();
    expect(repository().calls, hasLength(2));
  });

  testWidgets('saving keeps the page in place, with a named progress bar', (
    tester,
  ) async {
    final saved = Completer<void>();
    repository().beforeCall = (call) async {
      if (call.startsWith('setAvatarProvider')) await saved.future;
    };
    await pumpAvatarPage(tester);
    final before = tester.getTopLeft(tile(en.avatarProviderMarble)).dy;

    await tester.tap(tile(en.avatarProviderMarble));
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is LinearProgressIndicator &&
            widget.semanticsLabel == en.accountSettingsSaving,
      ),
      findsOneWidget,
    );
    expect(tester.getTopLeft(tile(en.avatarProviderMarble)).dy, before);
    saved.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a session that ended offers to sign in again', (tester) async {
    auth.serveUser(
      const User(id: 7, username: 'alice', name: 'Alice Example'),
      now: DateTime.now().toUtc(),
    );
    await pumpAvatarPage(
      tester,
      needsReauth: true,
      connector: FakeServerConnector.succeeding(fullServer270()),
    );
    expect(
      tester.widget<ListTile>(tile(en.avatarProviderMarble)).enabled,
      isFalse,
    );

    await tester.tap(find.widgetWithText(TextButton, en.reauthAction));
    await tester.pumpAndSettle();

    expect(auth.webAuthenticator.urls, hasLength(1));
    expect(find.text(en.accountSettingsSignInAgain), findsNothing);
    expect(
      tester.widget<ListTile>(tile(en.avatarProviderMarble)).enabled,
      isTrue,
    );
  });

  testWidgets('a refused change says why and keeps the provider', (
    tester,
  ) async {
    repository().failures['setAvatarProvider'] = const NetworkFailure(
      NetworkProblem.timeout,
    );
    await pumpAvatarPage(tester);

    await tester.tap(tile(en.avatarProviderGravatar));
    await tester.pumpAndSettle();

    expect(find.text(en.accountSettingsUnconfirmed), findsOneWidget);
    expect(
      tester.widget<ListTile>(tile(en.avatarProviderInitials)).selected,
      isTrue,
    );
  });

  testWidgets('a photo is cropped to a square, uploaded, and only then is '
      'it the avatar', (tester) async {
    await pumpAvatarPage(tester);

    await pickAndCrop(tester, en.avatarChoosePhoto);
    expect(picker.calls, ['photos images single']);
    expect(files.readPaths, ['/picked/IMG_1.png']);
    expect(find.byType(AvatarCropPage), findsOneWidget);
    expect(repository().calls, ['refresh']);

    await tester.tap(find.text(en.avatarCropUpload));
    await letTheEngineWork(tester);

    expect(find.byType(AvatarCropPage), findsNothing);
    expect(find.text(en.avatarUploaded), findsOneWidget);
    expect(repository().calls, ['refresh', 'uploadAvatar avatar.png']);
    expect(files.deleted, ['/no-such-folder/avatar-1/avatar.png']);
    expect(
      tester.widget<ListTile>(tile(en.avatarProviderUpload)).selected,
      isTrue,
    );
    expect(find.text(en.avatarProviderUploadReplace), findsOneWidget);

    final image = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(files.written.single);
      return (await codec.getNextFrame()).image;
    });
    final pixels = await tester.runAsync(() => image!.toByteData());
    expect((image!.width, image.height), (20, 20));
    final rgba = pixels!.buffer.asUint8List();
    // The middle square of the photo: green, the red and blue sides at most
    // blended into its edge by the scaling filter.
    for (final offset in [0, (20 * 10 + 10) * 4, (20 * 20 - 1) * 4]) {
      final [red, green, blue] = rgba.sublist(offset, offset + 3);
      expect(green, greaterThan(200));
      expect(red, lessThan(40));
      expect(blue, lessThan(40));
    }
    expect(rgba.sublist((20 * 10 + 10) * 4, (20 * 10 + 10) * 4 + 3), [
      0,
      255,
      0,
    ]);
  });

  testWidgets('a photo can be taken with the camera', (tester) async {
    picker.camera = const PickedFile(
      path: '/picked/camera.png',
      name: 'IMG_20261020_143005.png',
    );
    await pumpAvatarPage(tester);

    await pickAndCrop(tester, en.avatarTakePhoto);

    expect(picker.calls, ['camera']);
    expect(find.byType(AvatarCropPage), findsOneWidget);
  });

  testWidgets('a cancelled pick changes nothing', (tester) async {
    picker.photos = [];
    await pumpAvatarPage(tester);

    await pickAndCrop(tester, en.avatarChoosePhoto);

    expect(find.byType(AvatarCropPage), findsNothing);
    expect(repository().calls, ['refresh']);
  });

  testWidgets('a picker that cannot open says so', (tester) async {
    picker.failure = Exception('no photo library');
    await pumpAvatarPage(tester);

    await pickAndCrop(tester, en.avatarChoosePhoto);

    expect(find.text(en.avatarPickFailed), findsOneWidget);
  });

  testWidgets('a picture this device cannot read is never uploaded', (
    tester,
  ) async {
    files.picked = Uint8List.fromList([1, 2, 3, 4]);
    await pumpAvatarPage(tester);

    await pickAndCrop(tester, en.avatarChoosePhoto);

    expect(find.text(en.avatarImageUnusable), findsOneWidget);
    final upload = tester.widget<TextButton>(
      find.widgetWithText(TextButton, en.avatarCropUpload),
    );
    expect(upload.onPressed, isNull);
  });

  for (final (name, failure, text) in [
    (
      'not an image to the server',
      const ValidationFailed(message: 'Uploaded file is no image.'),
      () => en.avatarImageUnusable,
    ),
    (
      'too many pixels',
      const DomainError(400, code: 4032),
      () => en.avatarImageTooLarge,
    ),
    (
      'above the limit',
      const FileTooLarge(code: 4035),
      () => en.avatarImageTooLarge,
    ),
    (
      'without a connection',
      const NetworkFailure(NetworkProblem.unreachable),
      () => en.accountSettingsNeedsConnection,
    ),
  ]) {
    testWidgets('an upload refused as $name stays on the crop page', (
      tester,
    ) async {
      repository().failures['uploadAvatar'] = failure;
      await pumpAvatarPage(tester);

      await pickAndCrop(tester, en.avatarChoosePhoto);
      await tester.tap(find.text(en.avatarCropUpload));
      await letTheEngineWork(tester);

      expect(find.byType(AvatarCropPage), findsOneWidget);
      expect(find.text(text()), findsOneWidget);
      expect(files.deleted, hasLength(1));
      expect(repository().state.avatarProvider, AvatarProvider.initials);
    });
  }

  for (final (provider, auth, message) in [
    (AvatarProvider.ldap, 'ldap', () => en.avatarManagedLdap),
    (
      AvatarProvider.openid,
      'Keycloak',
      () => en.avatarManagedOpenId('Keycloak'),
    ),
  ]) {
    testWidgets('an avatar from ${provider.wireName} is explained instead', (
      tester,
    ) async {
      await pumpAvatarPage(
        tester,
        state: fakeAccountSettingsState(
          isLocalUser: false,
          authProvider: auth,
          avatarProvider: provider,
        ),
      );

      expect(find.text(message()), findsOneWidget);
      expect(tile(en.avatarProviderInitials), findsNothing);
      expect(tile(en.avatarProviderUpload), findsNothing);
    });
  }

  testWidgets('offline the providers only show', (tester) async {
    data = SyncFakes(
      status: SyncFailed(
        failure: const NetworkFailure(NetworkProblem.unreachable),
        lastSyncedAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    );
    data.engine.onRefresh = () async =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    data.shared.accountSettings.failures['refresh'] = const NetworkFailure(
      NetworkProblem.unreachable,
    );
    await pumpAvatarPage(tester);

    expect(find.text(en.accountSettingsOffline), findsOneWidget);
    expect(
      tester.widget<ListTile>(tile(en.avatarProviderMarble)).enabled,
      isFalse,
    );
    await tester.tap(tile(en.avatarProviderMarble));
    await tester.scrollUntilVisible(tile(en.avatarProviderUpload), 100);
    await tester.tap(tile(en.avatarProviderUpload));
    await tester.pumpAndSettle();

    expect(repository().calls, ['refresh']);
    expect(picker.calls, isEmpty);
  });
}
