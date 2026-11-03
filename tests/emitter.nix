# SPDX-License-Identifier: MIT
{ pkgs, backend }:
let
  output = backend.makeModule {
    pkg = pkgs.hello;
    name = "proof";
  };
  invalid = builtins.tryEval (
    (backend.makeModule {
      pkg = pkgs.hello;
      hooks = [
        {
          stage = "not-a-stage";
          priority = 1;
          script = pkgs.writeText "hook" "";
        }
      ];
    }).drvPath
  );
in
assert !invalid.success;
pkgs.runCommand "dracut-emitter" { } ''
  test -x ${output}/usr/lib/dracut/modules.d/50proof/module-setup.sh
  test -x ${output}/usr/lib/dracut/modules.d/50proof/payload${pkgs.hello}/bin/hello
  test ! -e ${output}/usr/lib/dracut/modules.d/50proof/payload/nix/var/nix/db/db.sqlite
  touch "$out"
''
