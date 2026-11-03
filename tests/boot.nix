# SPDX-License-Identifier: MIT
{
  pkgs,
  impurifier,
  revision ? "1",
}:
let
  nativeDracut = impurifier.nativeClient;
  proof = pkgs.writeShellScriptBin "early-proof" ''
    test ! -e /sysroot/etc/os-release || exit 1
    test ! -e /nix/var/nix/db/db.sqlite || exit 1
    echo IMPURIFIER_EARLY_USERSPACE_OK:${revision} > /dev/console
  '';
  hook = pkgs.writeShellScript "proof-hook" ''
    ${proof}/bin/early-proof || exit 1
    ${pkgs.busybox}/bin/poweroff -f
  '';
  module = impurifier.makeModule {
    pkg = proof;
    name = "nixproof";
    hooks = [
      {
        stage = "cmdline";
        priority = 1;
        script = hook;
      }
    ];
  };
  image =
    pkgs.runCommand "dracut-proof-initramfs"
      {
        nativeBuildInputs = [
          nativeDracut
          pkgs.kmod
          pkgs.cpio
          pkgs.gzip
          pkgs.systemd
          pkgs.bash
          pkgs.util-linux
          pkgs.glibc.bin
        ];
      }
      ''
        mkdir -p dracut
        cp -r ${nativeDracut}/lib/dracut/. dracut/
        chmod -R u+w dracut
        cp -r ${module}/usr/lib/dracut/modules.d/. dracut/modules.d/
        export dracutbasedir="$PWD/dracut"
        export DRACUT_PATH="$PATH"
        export LD_LIBRARY_PATH=${pkgs.glibc}/lib
        export systemdutildir=${pkgs.systemd}/lib/systemd
        export udevdir=${pkgs.systemd}/lib/udev
        dracut --force --no-hostonly --no-kernel --no-early-microcode --nostrip --nohardlink --gzip --include ${pkgs.busybox}/bin /usr/bin --include ${pkgs.bash}/bin/bash /bin/bash --libdirs ${pkgs.glibc}/lib --modules 'base bash shell-interpreter nixproof' "$out" ${pkgs.linuxPackages.kernel.modDirVersion}
      '';
in
pkgs.runCommand "dracut-impurifier-boot"
  {
    nativeBuildInputs = [
      pkgs.qemu
      pkgs.python3
    ];
  }
  ''
    python3 ${./boot.py} ${pkgs.linuxPackages.kernel}/bzImage ${image} IMPURIFIER_EARLY_USERSPACE_OK:${revision}
    touch "$out"
  ''
