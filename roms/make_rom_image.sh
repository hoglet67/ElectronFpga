#!/bin/bash

# Create the 256K ROM image
#
# This contains 12x 16K ROMS images for the electron

mkdir -p tmp

IMAGE=tmp/rom_image.bin

rm -f $IMAGE

# Slots 0-3 (sideways RAM)
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE

# Slots 4-7 (sideways RAM)
cat mmfs_swram_v1_02.rom       >> $IMAGE
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE

# Slots 8-B
cat os100.rom                  >> $IMAGE
cat os100.rom                  >> $IMAGE
cat Basic2.rom                 >> $IMAGE
cat Basic2.rom                 >> $IMAGE

# Slots C-F
cat pres_ap2_v1_23.rom         >> $IMAGE
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE
