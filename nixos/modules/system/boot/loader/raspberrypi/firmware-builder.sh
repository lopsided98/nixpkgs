#! @bash@/bin/sh -e

shopt -s nullglob

export PATH='@path@'

usage() {
    echo "usage: $0 -c <path-to-default-configuration> [-d <boot-dir>]" >&2
    exit 1
}

configTxt=
target=/boot # Target directory

while getopts "c:d:" opt; do
    case "$opt" in
        c) configTxt="$OPTARG" ;;
        d) target="$OPTARG" ;;
        \?) usage ;;
    esac
done

[ -z "$configTxt" ] && usage

copyForced() {
    local src="$1"
    local dst="$2"
    cp "$src" "$dst.tmp"
    mv "$dst.tmp" "$dst"
}

# Add the firmware files
fwdir='@raspberrypifw@/share/raspberrypi/boot/'
copyForced "$fwdir/bootcode.bin" "$target/bootcode.bin"
copyForced "$fwdir/fixup.dat"    "$target/fixup.dat"
copyForced "$fwdir/fixup_cd.dat" "$target/fixup_cd.dat"
copyForced "$fwdir/fixup_db.dat" "$target/fixup_db.dat"
copyForced "$fwdir/fixup_x.dat"  "$target/fixup_x.dat"
copyForced "$fwdir/start.elf"    "$target/start.elf"
copyForced "$fwdir/start_cd.elf" "$target/start_cd.elf"
copyForced "$fwdir/start_db.elf" "$target/start_db.elf"
copyForced "$fwdir/start_x.elf"  "$target/start_x.elf"

if [ -n '@uboot@' ]; then
    # Add the uboot file
    copyForced '@uboot@/u-boot.bin' "$target/u-boot-rpi.bin"
fi

# Add the config.txt
copyForced "$configTxt" "$target/config.txt"
