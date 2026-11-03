# SPDX-License-Identifier: MIT
{ ... }:
{ lib, inputs, ... }:
{
  flake.lib = lib.mkForce {
    dracut-impurifier =
      { pkgs }:
      import ../../../nix {
        inherit pkgs;
        coreSrc = inputs.impurifier;
      };
  };
  perSystem =
    { pkgs, ... }:
    let
      backend = import ../../../nix {
        inherit pkgs;
        coreSrc = inputs.impurifier;
      };
    in
    {
      packages.default = backend.makeModule { pkg = pkgs.hello; };
      packages.native-client = backend.nativeClient;
      checks.emitter = import ../../../tests/emitter.nix { inherit pkgs backend; };
      checks.boot = import ../../../tests/boot.nix {
        inherit pkgs;
        impurifier = backend;
      };
      checks.boot-regenerated = import ../../../tests/boot.nix {
        inherit pkgs;
        impurifier = backend;
        revision = "2";
      };
      formatter = pkgs.nixfmt-tree;
    };
}
