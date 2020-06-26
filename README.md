# ElectronFpga

Inspired by [a thread on
Stardot](https://stardot.org.uk/forums/viewtopic.php?f=3&t=9223), this project
implements the Acorn Electron ULA in various FPGAs, and can emulate a full
Electron system on an FPGA eval board.

Features:
- Everything that was in the original Elk ULA (including cassette I/O)
- Turbo mode (memory access at 2MHz)
- JAFA Mode 7
- VGA output
- SD card access and MMFS

## Hardware targets

### Papilio Duo (Xilinx Spartan 6)

This can be used as a standalone Electron emulator, or with an adapter board
and some level shifters, as a ULA replacement.

### Altera DE1

This can be used as a standalone Electron emulator.

### Intel Max 10 (pcb/ folder in this repository)

This is a board designed specifically for this project, to fit inside an
Electron with its ULA replaced with turned-pin sockets.  Components:

- Intel Max 10 10M08SCU169 FPGA with 8k LUTs and 42kB block RAM.
- 32MB SDRAM
- 8+MB flash
- micro SD socket
- micro USB port
- stereo DAC for audio
