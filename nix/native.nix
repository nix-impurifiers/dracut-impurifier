# SPDX-License-Identifier: MIT
{ pkgs }:
pkgs.dracut.overrideAttrs (old: {
  postPatch = (old.postPatch or "") + ''
    substituteInPlace src/install/dracut-install.c \
      --replace-fail 'search_via_ldconf("/etc/ld.so.conf", soname, match64, match32)' 'search_libdir("${pkgs.glibc}/lib", soname, match64, match32) ?: search_via_ldconf("/etc/ld.so.conf", soname, match64, match32)'
    substituteInPlace modules.d/10bash/module-setup.sh \
      --replace-fail 'inst /bin/bash' 'inst_binary ${pkgs.bash}/bin/bash /bin/bash'
  '';
})
