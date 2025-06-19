#!/bin/bash

# Create the 256K ROM image
#
# This contains 12x 16K ROMS images for the electron

mkdir -p tmp

IMAGE=tmp/rom_image.bin

echo Making $IMAGE

rm -f $IMAGE

# Slots 0-3 (sideways RAM)
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE

# Slots 4-7 (sideways RAM)
cat mmfs_swram.rom             >> $IMAGE
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE

# Slots 8-B
cat os100.rom                  >> $IMAGE
cat os100.rom                  >> $IMAGE
cat Basic2.rom                 >> $IMAGE
cat Basic2.rom                 >> $IMAGE

# Slots C-F
cat AP6v134t.rom               >> $IMAGE
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE
cat M7_191.rom                 >> $IMAGE


IMAGE=tmp/os10_basic.bit

echo Making $IMAGE

rm -f $IMAGE

cat os100.rom Basic2.rom | xxd  -c1 -b | awk '{print $2}' > $IMAGE
