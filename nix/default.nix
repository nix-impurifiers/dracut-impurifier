# SPDX-License-Identifier: MIT
{ pkgs, coreSrc }:
let
  inherit (pkgs) lib;
  core = import (coreSrc + "/nix") { inherit pkgs; };
  makeModule =
    {
      pkg,
      name ? "nix-${pkg.pname}",
      hooks ? [ ],
      dependencies ? [ ],
    }:
    assert lib.assertMsg (builtins.match "[a-z][a-z0-9-]*" name != null) "invalid dracut module name";
    assert lib.assertMsg (lib.all (
      n: builtins.match "[a-z][a-z0-9-]*" n != null
    ) dependencies) "invalid dracut dependency";
    assert lib.assertMsg (lib.all (
      h:
      lib.elem h.stage [
        "cmdline"
        "pre-udev"
        "pre-trigger"
        "initqueue"
        "pre-mount"
        "mount"
        "pre-pivot"
        "cleanup"
      ]
      && builtins.isInt h.priority
      && h.priority >= 0
      && h.priority <= 99
    ) hooks) "invalid dracut hook stage or priority";
    let
      payload = core.makeNativePayload { inherit pkg; };
      hookInputs = map (hook: core.makeNativePayload { pkg = hook.script; }) hooks;
    in
    pkgs.runCommand "${name}-dracut-module" { } ''
      module="$out/usr/lib/dracut/modules.d/50${name}"
      mkdir -p "$module/payload/nix/store" "$module/hooks"
      for tree in ${lib.escapeShellArgs (map toString ([ payload ] ++ hookInputs))}; do
        for object in "$tree"/nix/store/*; do
          destination="$module/payload/nix/store/$(basename "$object")"
          test -e "$destination" || test -L "$destination" || cp -a "$object" "$destination"
        done
      done
      ${lib.concatImapStringsSep "\n" (
        i: h: ''cp ${h.script} "$module/hooks/${name}-${toString i}.sh"''
      ) hooks}
      install -Dm644 ${../LICENSE} "$out/usr/share/licenses/dracut-impurifier/LICENSE"
      cat > "$module/module-setup.sh" <<'SCRIPT'
      #!/bin/bash
      check() { return 255; }
      depends() { echo ${lib.escapeShellArg (lib.concatStringsSep " " dependencies)}; }
      install() {
          [[ -n "$initdir" && "$initdir" != / && -n "$moddir" ]] || return 1
          # Nix supplied the complete closure. Eager resolution for subsequent
          # native installs avoids rescanning opaque store plugins as host DSOs.
          unset DRACUT_RESOLVE_LAZY
          # Keep absolute runtime paths; staging under moddir avoids requiring a
          # host store or database when another tool installs this module.
          mkdir -p "$initdir/nix/store" || return
          find "$initdir/nix/store" -type d -exec chmod u+w {} + || return
          cp -a --remove-destination "$moddir/payload/nix/store/." "$initdir/nix/store/" || return
          find "$initdir/nix/store" -type d -exec chmod u+w {} + || return
          ${lib.concatImapStringsSep "\n" (
            i: h:
            ''inst_hook ${h.stage} ${toString h.priority} "$moddir/hooks/${name}-${toString i}.sh" || return''
          ) hooks}
      }
      SCRIPT
      chmod 755 "$module/module-setup.sh"
    '';
in
{
  inherit makeModule;
  nativeClient = import ./native.nix { inherit pkgs; };
}
