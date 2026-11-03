# Testing

Run `nix flake check -L`. The boot check invokes the real native builder,
then QEMU boots the resulting initramfs without a root disk or shared store.
The provided tool must execute from a native early hook and power off.
Archive generation alone is not a passing test.
