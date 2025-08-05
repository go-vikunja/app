{ pkgs, lib, config, inputs, ... }:

let
  pkgs-unstable = import inputs.nixpkgs-unstable { system = pkgs.stdenv.system; };
in
{
  enterShell = ''
    export CHROME_EXECUTABLE=`which chromium`
  '';

  scripts = {
    create-emulator.exec = "avdmanager create avd --force --name android-32 --package 'system-images;android-32;google_apis_playstore;x86_64'";
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

    platforms.version = [ "31" "33" "34" "35" ];
    buildTools.version = [ "34.0.0" ];
    cmake.version = [ "3.18.1" "3.22.1" ];
    googleTVAddOns.enable = false;
    ndk = {
      enable = true;
      version = [ "23.1.7779620" "26.3.11579264" "27.0.12077973" ];
    };
    extras = [ ];
    emulator = {
      enable = true;
      version = "34.1.9";
    };
  };
}
