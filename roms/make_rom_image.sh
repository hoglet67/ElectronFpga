#!/bin/bash

# Create the 256K ROM image
#
# This contains 12x 16K ROMS images for the electron

mkdir -p tmp

IMAGE=tmp/rom_image.bin

echo Making $IMAGE

rm -f $IMAGE

# Slots 0-3 (ABR cartridge sideways RAM) so cannot be preloaded
# So we borrow these for the various OS images and Stop Press 64 in Slot A
cat os100.rom                  >> $IMAGE
cat 524-OS-3.00-alt4.rom       >> $IMAGE
cat sp64_lower.rom             >> $IMAGE
cat sp64_upper.rom             >> $IMAGE

# Slots 4-7
cat mmfs_swram.rom             >> $IMAGE
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE

# Slots 8-B
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE
cat Basic2.rom                 >> $IMAGE
cat Basic2.rom                 >> $IMAGE

# Slots C-F
cat amx_rom_elk.rom            >> $IMAGE
cat ADJI_v0_08.rom             >> $IMAGE
cat M7_191.rom                 >> $IMAGE
cat AP6v134t.rom               >> $IMAGE


IMAGE=tmp/os10_basic.bit

echo Making $IMAGE

rm -f $IMAGE

cat os100.rom Basic2.rom | xxd  -c1 -b | awk '{print $2}' > $IMAGE
