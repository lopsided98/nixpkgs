{ pkgs, lib, stdenv, substituteAll, bash, coreutils, raspberrypifw, version
, ubootEnabled ? false }:

let
  isAarch64 = stdenv.hostPlatform.isAarch64;

  uboot =
    if version == 0 then
      pkgs.ubootRaspberryPiZero
    else if version == 1 then
      pkgs.ubootRaspberryPi
    else if version == 2 then
      pkgs.ubootRaspberryPi2
    else
      if isAarch64 then
        pkgs.ubootRaspberryPi3_64bit
      else
        pkgs.ubootRaspberryPi3_32bit;
in
substituteAll {
  src = ./firmware-builder.sh;
  isExecutable = true;
  path = lib.makeBinPath [ coreutils ];
  inherit bash raspberrypifw;
  uboot = lib.optionalString ubootEnabled uboot;
}

