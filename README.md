# dracut-impurifier

Expose Nix-built software through native dracut modules and early-boot hooks.
Dracut builds the initramfs. The generated module carries complete runtime
closures as plain files; neither the build host consuming the module nor early
userspace needs a Nix daemon or database. Files retain their original store paths.
Original adapter code is MIT.

```nix
let adapter = inputs.dracut-impurifier.lib.dracut-impurifier { inherit pkgs; };
in adapter.makeModule {
  pkg = myEarlyBootTool;
  name = "my-tool";
  hooks = [{ stage = "pre-mount"; priority = 20; script = myBootHook; }];
}
```

Install the output's `/usr` tree through your normal packaging/deployment tools,
then add `my-tool` to dracut's module selection (`dracut --add my-tool ...`). The
module is opt-in. `dependencies` names other native dracut modules. Hook scripts
are sourced by dracut; reference tools by their original absolute output paths.
Their own Nix runtime closures are included too. Compatible target outputs may
come from any Nix producer, not necessarily nixpkgs or NixOS.

Modules stage their files privately under `modules.d/50<name>/payload`, then
populate the initramfs's `/nix/store`. Shared immutable objects coalesce at their
original paths. The module switches dracut to eager native dependency resolution
so its generic final ELF scan does not reinterpret complete Nix closures as
host-linked libraries. Staging directories remain writable for subsequent
modules. No package realization, registration, GC, signing or disk installation
occurs. The kernel and matching modules remain the caller's/dracut's concern.

`native-client` is a pinned dracut 112 SDK for tests. Its Nix packaging adds the
selected glibc library directory to dracut-install's native search locations and
supplies bash from its actual package path. The boot fixture supplies conventional
command links using real BusyBox tools. These are build-environment adaptations;
the emitted module also targets ordinary upstream dracut installations.

The QEMU test boots the generated image with the Linux kernel and no root disk or
shared host store. A native cmdline hook executes the supplied tool, checks that
no real root or Nix database exists, emits its proof and powers off. This proves
early userspace integration, not a complete distribution install or real hardware
coverage. Secure Boot and ukify are separate consumers.

Run `nix flake check -L`; software QEMU emulation requires no KVM.
