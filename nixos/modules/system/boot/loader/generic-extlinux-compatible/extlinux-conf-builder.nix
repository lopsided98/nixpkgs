{ pkgs }:

pkgs.substituteAll {
  src = ./extlinux-conf-builder.sh;
  isExecutable = true;
  path = pkgs.lib.makeBinPath [ pkgs.coreutils pkgs.gnused ];
  inherit (pkgs) bash;
}
