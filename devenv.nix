{ pkgs, lib, config, inputs, ... }:

{
  enterShell = ''
    export CHROME_EXECUTABLE=`which chromium`
  '';

  scripts = {
    create-emulator.exec = "avdmanager create avd --force --name android-32 --package 'system-images;android-32;google_apis_playstore;x86_64'";
    run-app.exec = "flutter run --flavor unsigned";
    build-apk-unsigned.exec = "flutter build apk --flavor unsigned";
    lint.exec = "dart format --set-exit-if-changed .";
    lint-fix.exec = "dart format .";
  };  

  android = {
    enable = true;
    flutter.enable = true;

    platforms.version = [ "31" "33" "34" ];
    cmake.version = [ "3.18.1" "3.22.1" ];
    googleTVAddOns.enable = false;
    ndk = {
      enable = true;
      version = [ "23.1.7779620" "26.1.10909125" ];
    };
    extras = [ ];
    emulator = {
      enable = true;
      version = "34.1.9";
    };
  };
}
