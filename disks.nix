{ pkgs ? null, ... }:
let
  # byNames is my source of truth for what disks I have installed in the system,
  # which lists all disks by the human-readable name I labeled each disk with
  byName = builtins.mapAttrs annotateDisk {
    "samsung-0" = mkDisk "MZ-77Q4T0" "SOME_SERIAL" "bc56e81d-5291-4927-964a-0912dce0d88a" "veryLongRandomPassword";
    "samsung-1" = mkDisk "MZ-77Q4T0" "ANOTHER_SERIAL" "36c6f2b6-179d-11ee-be56-0242ac120002" "aDifferentLongRandomPassword";
    "wdc-0" = mkDisk "WDS400T2B0A-00SM50" "WDC_SERIAL" "4d7947d4-179d-11ee-be56-0242ac120002" "YETaNOTHERlONGpASSWORD";
  };

  mkDisk = modelNumber: serial: uuid: luksKey: {
    inherit modelNumber serial uuid luksKey;
    modelName = modelName modelNumber;
    manufacturer = manufacturer modelNumber;
  };

  # Nice human readable name, because I separately wrote a little python script
  # to invoke some utilities when my array is degraded / being worked on,
  # and this lets me give some nicer output
  modelName = modelNumber: {
    "MZ-77Q4T0" = "870 QVO";
    "CT4000MX500SSD1" = "MX500";
    "SSD7CS900-4TB-RB" = "CS900";
    "WDS400T2B0A-00SM50" = "WD Blue";
  }.${modelNumber};

  manufacturer = modelNumber: {
    "MZ-77Q4T0" = "Samsung";
    "CT4000MX500SSD1" = "Crucial";
    "SSD7CS900-4TB-RB" = "PNY";
    "WDS400T2B0A-00SM50" = "Western Digital";
  }.${modelNumber};

  # annotateDisk is lastly used on each disk defined with `mkDisk` to add some
  # extra attrs that are used for unlocking the disks in several different ways
  annotateDisk = name: disk: let
    cryptsetup = if pkgs == null then "cryptsetup" else "${pkgs.cryptsetup}/bin/cryptsetup";
  in
    disk // {
      diskName = name;

      # unlockCmd is a string with the command to unlock the current disk
      unlockCmd = if disk.uuid != null && disk.luksKey != null then
          "${cryptsetup} open /dev/disk/by-uuid/${disk.uuid} \"${name}\" ${toKeyFileArg disk.luksKey}"
        else null;

      # crypttabLine is the line in /etc/crypttab that unlocks this disk
      crypttabLine = if disk.uuid != null && disk.luksKey != null then
          "${name}\tUUID=${disk.uuid}\t${toKeyFile disk.luksKey}\tdiscard"
        else null;

      # openscript is a shell script that unlocks the current disk.
      openscript = pkgs.writeShellScriptBin "unlock-${name}" ''
        ${cryptsetup} open /dev/disk/by-uuid/${disk.uuid} ${name} --key-file=${toKeyFile disk.luksKey}
      '';
    };

  # Helper functions for the above `annotateDisk`
  toKeyFile = key: if pkgs != null then "${pkgs.writeText "file" key}" else null;
  toKeyFileArg = key:
    if pkgs != null then "--key-file ${toKeyFile key}"
    else null;

  # Some more helper functions
  byKey = keyname: builtins.listToAttrs (map (a: { name = a.${keyname}; value = a; }) (builtins.filter (v: v.${keyname} != null) (builtins.attrValues byName)));
  groupByKey = keyname: builtins.foldl'
    (grouped: next: let key = builtins.toString next."${keyname}"; in
      grouped // { "${key}" =
        if grouped ? "${key}" then grouped."${key}" ++ [ next ]
        else [ next ];
      })
    {} (builtins.attrValues byName);
in rec {
  # I simply include any mapping of `key` -> `disk` I think might be useful, and if
  # I have a disk die, I have a python utility that knows how to check these until it
  # finds *some* route to the actual disk definition
  inherit byName;

  # Disks mapped by various attributes
  bySerial = byKey "serial";
  byModelNumber = groupByKey "modelNumber";
  byModelName = groupByKey "modelName";
  byUuid = byKey "uuid";
  byManufacturer = groupByKey "manufacturer";

  # A list of all disks in the system
  allDisks = builtins.attrValues byName;

  # Some lists useful in other parts of my system config
  unlockCmds = disks: builtins.concatStringsSep "\n" (builtins.filter (v: v != null) (map (disk: disk.unlockCmd) disks));
  crypttabLines = disks: builtins.concatStringsSep "\n" (builtins.filter (v: v != null) (map (disk: disk.crypttabLine) disks));
  unlockers = map (d: d.openscript) allDisks;

  # Recording which disks are in which vdev
  vdevs = {
    raidz2-0 = with byName; [ samsung-0 samsung-2 samsung-4 samsung-6 crucial-0 crucial-2 crucial-4 wdc-0 ];
    raidz2-1 = with byName; [ samsung-1 samsung-3 samsung-5 samsung-7 crucial-1 crucial-6 pny-0 wdc-1 ];
  };
}
