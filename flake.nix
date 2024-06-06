{
  description = "Vikunja Flutter app dev environment";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { system = system; config.allowUnfree = true; };
      in {
        defaultPackage = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Originally copied from https://github.com/zulip/zulip-flutter/blob/d882f50bf7d917ce7e040d7ee1f66f1d803ef988/shell.nix
              clang
              cmake
              ninja
              pkg-config

              gtk3  # Curiously `nix-env -i` can't handle this one adequately.
                    # But `nix-shell` on this shell.nix does fine.
              pcre
              epoxy

              flutter

              # This group all seem not strictly necessary -- commands like
              # `flutter run -d linux` seem to *work* fine without them, but
              # the build does print messages about missing packages, like:
              #   Package mount was not found in the pkg-config search path.
              #   Perhaps you should add the directory containing `mount.pc'
              #   to the PKG_CONFIG_PATH environment variable
              # To add to this list on NixOS upgrades, the Nix package
              # `nix-index` is handy: then `nix-locate mount.pc`.
              libuuid  # for mount.pc
              xorg.libXdmcp.dev
              libsepol.dev
              libthai.dev
              libdatrie.dev
              libxkbcommon.dev
              dbus.dev
              at-spi2-core.dev
              xorg.libXtst.out
              pcre2.dev

              jdk11
              android-studio
              android-tools
          ];
        };
      });
}
