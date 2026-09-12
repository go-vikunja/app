{ pkgs, lib, config, inputs, ... }:

let
  pkgs-unstable = import inputs.nixpkgs-unstable { system = pkgs.stdenv.system; };
  abi = if pkgs.stdenv.hostPlatform.isAarch64 then "arm64-v8a" else "x86_64";
in
{
  enterShell = ''
    export CHROME_EXECUTABLE=`which chromium`
  '';

  scripts = {
    create-emulator.exec = "avdmanager create avd --force --name android-36 --package 'system-images;android-36;google_apis_playstore;${abi}'";
    # adb must create its key before an AVD's first boot, or the device stays unauthorized.
    # Without its bundled libs the nixpkgs emulator picks up the wrong libc++.
    start-emulator.exec = ''
      adb start-server
      LD_LIBRARY_PATH="$ANDROID_HOME/emulator/lib64" exec emulator -avd android-36 "$@"
    '';
    run-app.exec = "flutter run";
    build-apk-unsigned.exec = "flutter build apk";
    lint.exec = "dart format --set-exit-if-changed .";
    lint-fix.exec = "dart format .";
  };  

  android = {
    enable = true;
    flutter = {
      enable = true;
      package = pkgs-unstable.flutter;
    };

    # Each platform also pulls a ~3G system image; keep to what plugins compile against.
    platforms.version = [ "31" "34" "35" "36" ];
    abis = [ abi ];
    buildTools.version = [ "35.0.0" ];
    cmake.version = [ "3.18.1" "3.22.1" ];
    googleTVAddOns.enable = false;
    ndk = {
      enable = true;
      version = [ "28.2.13676358" ];
    };
    extras = [ ];
    emulator.enable = true;
  };
}
