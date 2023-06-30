# My NixOS Disk Config

These are a couple files taken from my NixOS config. The file `data-pools.nix` is included in my NAS using `imports = [ ... ];`, and relies on `disks.nix` to define all the disks installed in my system.

I've removed any PII and some miscellaneous stuff from both, and added comments to explain why I'm doing what I'm doing.
