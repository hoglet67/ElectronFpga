#!/bin/bash

XILINX=/opt/Xilinx/14.7
PAPILIO_LOADER=/opt/GadgetFactory/papilio-loader/programmer
PROG=${PAPILIO_LOADER}/linux32/papilio-prog
BSCAN=${PAPILIO_LOADER}/bscan_spi_xc6slx9.bit
IMAGE=tmp/rom_image.bin

# Build a fresh ROM image
./make_rom_image.sh

# Run bitmerge to merge in the ROM images
gcc -o tmp/bitmerge bitmerge.c 
./tmp/bitmerge ../working/ElectronFpga_duo.bit 60000:$IMAGE tmp/merged.bit
rm -f ./tmp/bitmerge

# Program the Papilo Duo
${PROG} -v -f tmp/merged.bit -b ${BSCAN}  -sa -r

# Reset the Papilio Duo
${PROG} -c
