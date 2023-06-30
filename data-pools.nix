# This entire file gets merged in with the rest of my system config.
# Separating out my config into distinct modules that get merged into
# a whole system definition makes it easy to plug and unplug different
# configuration sections.
{ pkgs, config, ... }:
let
  disks = import ./disks.nix { inherit pkgs; };
in
{
  environment.systemPackages = with pkgs; [
    zfs
    smartmontools

  # By adding `disks.unlockers`, my system PATH includes a set of shell scripts
  # for e.g. `unlock-wdc-0`, `unlock-samsung-1`, etc.
  # Useful when the array was not yet built and I was doing system config stuff
  # before configuring ZFS, but not used so much now.
  ] ++ disks.unlockers;

  # Here is where I generate the /etc/crypttab
  environment.etc."crypttab".text = disks.crypttabLines disks.allDisks;
  boot.zfs.extraPools = [ "data" ];
  # Unfortunately, some of the disks I use *really* don't like being TRIMmed while online
  services.zfs.trim.enable = false;

  boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
  boot.supportedFilesystems = [ "zfs" ];

  networking.hostId = "beefface";
}
