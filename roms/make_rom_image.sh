#!/bin/bash

# Create the 256K ROM image
#
# This contains 12x 16K ROMS images for the electron

mkdir -p tmp

IMAGE=tmp/rom_image.bin

rm -f $IMAGE

# Slots 0-3
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE
cat smelk3006.rom              >> $IMAGE
# cat mmfs-b.rom                 >> $IMAGE

# Slots 4-7 (sideways RAM)
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE

# Slots 8-B
cat os100.rom                  >> $IMAGE
cat os100.rom                  >> $IMAGE
cat Basic2.rom                 >> $IMAGE
cat Basic2.rom                 >> $IMAGE

# Slots C-F
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE
cat blank.rom                  >> $IMAGE
