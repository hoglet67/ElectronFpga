#!/usr/bin/python

# Copyright 2019 Google LLC
#
# This source file is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This source file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# ------------------
# max10_electron_ula
# ------------------

# by Phillip Pearson

# A PCB for the Electron ULA replacement project, using an Intel Max 10 FPGA
# chip (10M08).

import sys, os
here = os.path.dirname(sys.argv[0])
sys.path.insert(0, os.path.join(here, "myelin-kicad.pretty"))
import myelin_kicad_pcb
Pin = myelin_kicad_pcb.Pin


### ULA

# Electron ULA header -- this will plug into the PGA socket once one has been
# installed, as shown in Dave Hitchins' post:
# https://stardot.org.uk/forums/viewtopic.php?f=3&t=9223&start=60#p118234

# The ULA came in various different forms over the years, but in all cases the
# PCB can take a standard 68-pin PGA socket once the ULA socket (Issue 4) or
# ULA carrier board (Issue 6) is desoldered.  Details by Hoglet here:
# https://stardot.org.uk/forums/viewtopic.php?f=3&t=9223&start=90#p149175

# The following list of signal details was collated by jms2:
# https://stardot.org.uk/forums/viewtopic.php?f=3&t=9223&start=30#p105883
#
# 16 address lines (inputs only)
# 8 processor data lines (bi-directional)
# 4 keyboard lines, CAPS LK, RST (inputs only)
# IRQ, NMI, Phi0, RnW (outputs only)
# Clock and Divide-by-13 (inputs)
# R, G, B & sync (outputs)
# 4 cassette lines (CASOUT, CASRC and CASMO outputs, CASIN input)
# Sound (output)
# nPOR (power-on reset)

ula = myelin_kicad_pcb.Component(
    footprint="Package_LCC:PLCC-68_THT-Socket",
    identifier="ULA",
    value="ULA header",
    desc="Set of pin headers to plug into an Acorn Electron ULA socket",
    pins=[
        # Ordered counter-clockwise, as shown in Appendix F of the Electron AUG

        # DRAM (not connected to FPGA)
        Pin(34, "RAM0", ""),     # IO
        Pin(37, "RAM1", ""),     # IO
        Pin(40, "RAM2", ""),     # IO
        Pin(44, "RAM3", ""),     # IO
        Pin(29, "nWE",  "3V3"),  # O
        Pin(52, "nRAS", "3V3"),  # O
        Pin(53, "nCAS", "3V3"),  # O
        Pin(22, "RA0",  "3V3"),  # O
        Pin(19, "RA1",  "3V3"),  # O
        Pin(18, "RA2",  "3V3"),  # O
        Pin(16, "RA3",  "3V3"),  # O
        Pin(11, "RA4",  "3V3"),  # O
        Pin( 8, "RA5",  "3V3"),  # O
        Pin( 7, "RA6",  "3V3"),  # O
        Pin( 6, "RA7",  "3V3"),  # O

        # Keyboard
        Pin(27, "KBD0",      "KBD0_5V"),  # I
        Pin(28, "KBD1",      "KBD1_5V"),  # I
        Pin(31, "KBD2",      "KBD2_5V"),  # I
        Pin(32, "KBD3",      "KBD3_5V"),  # I
        Pin(63, "CAPS_LOCK", "CAPS_LOCK"),  # O, drives caps LED via 470R (~6mA)

        Pin(58, "nRST", "nRESET"),  # OC I
        Pin(61, "nROM", "nROM"),    # O

        # Address bus: input
        Pin( 5, "A0",  "A0_5V"),   # I
        Pin( 1, "A1",  "A1_5V"),   # I
        Pin(12, "A2",  "A2_5V"),   # I
        Pin(24, "A3",  "A3_5V"),   # I
        Pin(21, "A4",  "A4_5V"),   # I
        Pin(20, "A5",  "A5_5V"),   # I
        Pin(17, "A6",  "A6_5V"),   # I
        Pin(15, "A7",  "A7_5V"),   # I
        Pin( 2, "A8",  "A8_5V"),   # I
        Pin(26, "A9",  "A9_5V"),   # I
        Pin(25, "A10", "A10_5V"),  # I
        Pin(23, "A11", "A11_5V"),  # I
        Pin(13, "A12", "A12_5V"),  # I
        Pin(14, "A13", "A13_5V"),  # I
        Pin(10, "A14", "A14_5V"),  # I
        Pin(56, "A15", "A15_5V"),  # I

        # Data bus: input/output
        Pin(33, "PD0", "PD0_5V"),  # IO
        Pin(35, "PD1", "PD1_5V"),  # IO
        Pin(36, "PD2", "PD2_5V"),  # IO
        Pin(38, "PD3", "PD3_5V"),  # IO
        Pin(39, "PD4", "PD4_5V"),  # IO
        Pin(41, "PD5", "PD5_5V"),  # IO
        Pin(42, "PD6", "PD6_5V"),  # IO
        Pin(45, "PD7", "PD7_5V"),  # IO

        Pin(57, "nNMI",    "nNMI_5V"),     # OC I
        Pin(60, "PHI_OUT", "PHI_OUT_5V"),  # O
        Pin(30, "nIRQ",    "nIRQ_5V"),     # OC O
        Pin(46, "RnW",     "RnW_5V"),      # I

        # Clocks and ground
        Pin(55, "DIV13_IN", "CLK_DIV13_5V"),  # I
        Pin(68, "GND", "GND"),
        Pin(51, "GND", "GND"),
        Pin(49, "CLOCK_IN", "CLK_16MHZ_5V"),  # I

        # Video
        Pin(67, "nHS",    "nHS_5V"),     # O: horizontal sync
        Pin( 3, "RED",    "RED_5V"),     # O
        Pin( 4, "GREEN",  "GREEN_5V"),   # O
        Pin(66, "BLUE",   "BLUE_5V"),    # O
        Pin(65, "nCSYNC", "nCSYNC_5V"),  # O: composite sync

        # Power-on reset
        Pin(54, "nPOR", "nPOR_5V"),  # I: power-on reset

        # Audio
        Pin(62, "SOUND_OUT", "SOUND_OUT_5V"),  # O

        # Cassettte
        Pin(59, "CAS_IN",  "CAS_IN_5V"),   # I
        Pin(64, "CAS_MO",  "CAS_MO_5V"),   # O: motor relay
        Pin(47, "CAS_RC",  "CAS_RC_5V"),   # TODO O?  RC filter?  NC?
        Pin(50, "CAS_OUT", "CAS_OUT_5V"),  # O

        # Power
        Pin(48, "VCC1", "5V"),  # direct to 5V
        Pin( 9, "VCC2", "5V"),  # 5V via 24R
        Pin(43, "VCC2", "5V"),  # 5V via 24R
    ],
)


### FPGA

fpga = myelin_kicad_pcb.Component(
    footprint="myelin-kicad:intel_ubga169",
    identifier="FPGA",
    value="10M08SCU169",
    pins=[
        # IOs

        # Outer ring -- 45 IOs (4 x 13 - 1 for TMS on G1)
        Pin("A2",  "", "C1_11"),
        Pin("A3",  "", "C1_9"),
        Pin("A4",  "", "C1_14"),
        Pin("A5",  "", "C1_19"),
        Pin("A6",  "", "C1_17"),
        Pin("A7",  "", "C1_23"),
        Pin("A8",  "", "C1_16"),
        Pin("A9",  "", "C1_20"),
        Pin("A10", "", "C1_26"),
        Pin("A11", "", "C1_25"),
        Pin("A12", "", "C1_30"),
        Pin("N4",  "", "C4_17"),
        Pin("N5",  "", "C4_19"),
        Pin("N6",  "", "C4_24"),
        Pin("N7",  "", "C4_25"),
        Pin("N8",  "", "C4_22"),
        Pin("N9",  "", "C4_28"),
        Pin("N10", "", "C4_26"),
        Pin("N11", "", "C4_31"),
        Pin("N12", "", "C4_36"),
        Pin("B1",  "", "C1_2"),
        Pin("C1",  "", "C1_1"),
        Pin("D1",  "", "C2_1"),
        Pin("E1",  "", "C2_5"),
        Pin("F1",  "", "C2_8"),
        Pin("H1",  "", "C1_3"),
        Pin("J1",  "", "C4_4"),
        Pin("K1",  "", "C2_12"),
        Pin("M1",  "", "C4_12"),
        Pin("B13", "", "C1_36"),
        Pin("C13", "", "C1_33"),
        Pin("D13", "", "C1_37"),
        Pin("G13", "", "C3_4"),
        Pin("H13", "", "C4_34"),
        Pin("J13", "", "C3_10"),
        Pin("K13", "", "C4_35"),
        Pin("L13", "", "C4_37"),
        Pin("M13", "", "C4_39"),

        # Next ring in -
        Pin("B2",  "", "C1_6"),
        Pin("B3",  "", "C1_5"),
        Pin("B4",  "", "C1_10"),
        Pin("B5",  "", "C1_13"),
        Pin("B6",  "", "C1_18"),
        Pin("B7",  "", "C1_12"),
        Pin("B10", "", "C1_24"),
        Pin("B11", "", "C1_31"),
        Pin("M2",  "", "C4_11"),
        Pin("M3",  "", "C4_13"),
        Pin("M4",  "", "C4_14"),
        Pin("M5",  "", "C4_20"),
        Pin("M7",  "", "C4_21"),
        Pin("M8",  "", "C4_23"),
        Pin("M9",  "", "C4_33"),
        Pin("M10", "", "C4_27"),
        Pin("M11", "", "C4_30"),
        Pin("M12", "", "C4_38"),

        Pin("C2",  "", "C2_4"),
        Pin("H2",  "", "C1_7"),
        Pin("J2",  "", "C4_7"),
        Pin("K2",  "", "C4_8"),
        Pin("L2",  "", "C4_6"),
        Pin("L3",  "", "C4_10"),
        Pin("C9",  "", "C1_22"),
        Pin("C10", "", "C1_27"),
        Pin("B12", "", "C1_29"),
        Pin("C12", "", "C1_34"),
        Pin("D11", "", "C1_38"),
        Pin("D12", "", "C3_3"),
        Pin("E12", "", "C3_1"),
        Pin("F12", "", "C3_6"),
        Pin("G12", "", "C3_8"),
        Pin("J12", "", "C3_7"),
        Pin("K11", "", "C3_12"),
        Pin("K12", "", "C3_9"),
        Pin("L11", "", "C3_11"),
        Pin("L12", "", "C4_40"),
        Pin("L10", "", "C4_32"),
        Pin("C11", "", "C1_28"),
        Pin("E3",  "", "C2_3"),
        Pin("L5",  "", "C4_18"),

        # Special pins
        Pin("G5", "CLK0n", "CLK0n"),
        Pin("H6", "CLK0p", "CLK0p"),
        Pin("H5", "CLK1n", "CLK1n"),
        Pin("H4", "CLK1p", "CLK1p"),
        Pin("G10", "CLK2n", "CLK2n"),
        Pin("G9", "CLK2p", "CLK2p"),
        Pin("E13", "CLK3n", "C3_2_CLK3n"),
        Pin("F13", "CLK3p", "C3_5_CLK3p"),
        Pin("N2", "DPCLK0", "C4_16_DPCLK0"),
        Pin("N3", "DPCLK1", "C4_15_DPCLK1"),
        Pin("F10", "DPCLK2", "DPCLK2"),
        Pin("F9", "DPCLK3", "DPCLK3"),
        Pin("L1", "VREFB2N0", "C4_3_VREFB2N0"),

        # JTAG and other config pins
        Pin("E5",  "JTAGEN",     "fpga_JTAGEN"),
        Pin("G1",  "TMS",        "fpga_TMS"),
        Pin("G2",  "TCK",        "fpga_TCK"),
        Pin("F5",  "TDI",        "fpga_TDI"),
        Pin("F6",  "TDO",        "fpga_TDO"),
        Pin("B9",  "DEV_CLRn",   "fpga_DEV_CLRn"),  # measures high on first soldered board
        Pin("D8",  "DEV_OE",     "fpga_DEV_OE"),
        Pin("D7",  "CONFIG_SEL", "GND"),  # unused, so connected to GND
        Pin("E7",  "nCONFIG",    "3V3"),  # can be connected straight to VCCIO
        Pin("D6",  "CRC_ERROR",  "GND"),  # WARNING: disable Error Detection CRC option
        Pin("C4",  "nSTATUS",    "fpga_nSTATUS"),  # measures high on first soldered board
        Pin("C5",  "CONF_DONE",  "fpga_CONF_DONE"),  # measures high on first soldered board

        # Signals used as power/ground to enable vias in the 2-layer version
        # TODO none of these are listed as IOs; add them
        Pin("E4",  "",     ""),  # TODO
        Pin("J5",  "",     ""),  # TODO
        Pin("J6",  "",     ""),  # TODO
        Pin("K10", "",     ""),  # TODO
        Pin("E10", "",     ""),  # TODO
        Pin("J10", "",     ""),  # TODO
        Pin("E8",  "",     ""),  # TODO
        Pin("H8",  "",     ""),  # TODO
        Pin("D9",  "",     ""),  # TODO
        Pin("K7",  "",     ""),  # TODO
        Pin("K8",  "",     ""),  # TODO
        Pin("E6",  "",     ""),  # TODO
        Pin("F8",  "",     ""),  # TODO
        Pin("G4",  "",     ""),  # TODO
        Pin("L4",  "",     ""),  # TODO

        # Power and ground
        Pin("D2",  "GND",     "GND"),
        Pin("E2",  "GND",     "GND"),
        Pin("N13", "GND",     "GND"),
        Pin("N1",  "GND",     "GND"),
        Pin("M6",  "GND",     "GND"),
        Pin("L9",  "GND",     "GND"),
        Pin("J4",  "GND",     "GND"),
        Pin("H12", "GND",     "GND"),
        Pin("G7",  "GND",     "GND"),
        Pin("F3",  "GND",     "GND"),
        Pin("E11", "GND",     "GND"),
        Pin("D5",  "GND",     "GND"),
        Pin("C3",  "GND",     "GND"),
        Pin("B8",  "GND",     "GND"),
        Pin("A13", "GND",     "GND"),
        Pin("A1",  "GND",     "GND"),
        Pin("F2",  "VCCIO1A", "3V3"),
        Pin("G3",  "VCCIO1B", "3V3"),
        Pin("K3",  "VCCIO2",  "3V3"),
        Pin("J3",  "VCCIO2",  "3V3"),
        Pin("L8",  "VCCIO3",  "3V3"),
        Pin("L7",  "VCCIO3",  "3V3"),
        Pin("L6",  "VCCIO3",  "3V3"),
        Pin("J11", "VCCIO5",  "3V3"),
        Pin("H11", "VCCIO5",  "3V3"),
        Pin("G11", "VCCIO6",  "3V3"),
        Pin("F11", "VCCIO6",  "3V3"),
        Pin("C8",  "VCCIO8",  "3V3"),
        Pin("C7",  "VCCIO8",  "3V3"),
        Pin("C6",  "VCCIO8",  "3V3"),
        Pin("K4",  "VCCA1",   "3V3"),
        Pin("D10", "VCCA2",   "3V3"),
        Pin("D3",  "VCCA3",   "3V3"),
        Pin("D4",  "VCCA3",   "3V3"),
        Pin("K9",  "VCCA4",   "3V3"),
        Pin("H7",  "VCC_ONE", "3V3"),
        Pin("G8",  "VCC_ONE", "3V3"),
        Pin("G6",  "VCC_ONE", "3V3"),
        Pin("F7",  "VCC_ONE", "3V3"),
    ],
)

# chip won't init unless this is pulled high
conf_done_pullup = myelin_kicad_pcb.R0805("10k", "fpga_CONF_DONE", "3V3", ref="R1", handsoldering=False)

# chip goes into error state if this is pulled low
nstatus_pullup = myelin_kicad_pcb.R0805("10k", "fpga_nSTATUS", "3V3", ref="R2", handsoldering=False)

# prevent spurious jtag clocks
tck_pulldown = myelin_kicad_pcb.R0805("1-10k", "fpga_TCK", "GND", ref="R3", handsoldering=False)

# fpga_nCONFIG doesn't need a pullup, just connect straight to 3V3

# fpga_CONFIG_SEL is connected to GND because we don't use this

fpga_decoupling = [
    myelin_kicad_pcb.C0402("100n", "3V3", "GND", ref="C%d" % r)
    for r in range(10, 24)
]


### POWER SUPPLY

bulk = [
    myelin_kicad_pcb.C0805("1u", "3V3", "GND", ref="C%d" % r, handsoldering=False)
    for r in range(8, 10)
]

power_in_cap = myelin_kicad_pcb.C0805("10u", "GND", "5V", ref="C1")

# Power regulation from 5V down to 3.3V.
regulator = myelin_kicad_pcb.Component(
    footprint="Package_TO_SOT_SMD:SOT-89-3",
    identifier="REG",
    value="AP7365-33YG-XX",  # 600 mA, 0.3V dropout
    desc="3.3V LDO regulator, e.g. Digikey AP7365-33YG-13DICT-ND.  Search for the exact part number because there are many variants.",
    pins=[
        # AP7365-Y: VOUT GND VIN  AP7365-33YG-...
        Pin(1, "VOUT", ["3V3"]),
        Pin(2, "GND", ["GND"]),  # sot-89 tab
        Pin(3, "VIN", ["5V"]),
    ],
)
reg_in_cap = myelin_kicad_pcb.C0805("1u", "GND", "5V", ref="C2")
reg_out_cap = myelin_kicad_pcb.C0805("1u", "3V3", "GND", ref="C3")


### FLASH MEMORY (optional)

# Arcflash uses an S29GL064S chip in LAE064 (9x9mm 64-ball 1.0mm pitch)
# package.  We can go even smaller with the VBK048 (8.15 x 6.15 mm 48-ball
# 0.8mm pitch) package, but I already have a verified footprint for the LAE064
# chip, so let's start with that.

# I'm assuming we want the chip in 8-bit mode, although if it would be useful
# to have 16-bit access, I can easily revert the pinout here to the Arcflash
# one.

# Alternatively we could switch this out for a serial flash chip (cmorley
# suggests QSPI) and either use it directly or copy it to RAM before use.
# This might make room for more pins to use for RAM.

flash = [
    myelin_kicad_pcb.Component(
        footprint="myelin-kicad:cypress_lae064_fbga",
        identifier="FLASH",
        value="S29GL064S70DHI010",  # 64-ball FBGA, 1mm pitch, 9x9mm (c.f. 20x14 in TQFP)
        buses=[""],
        pins=[
            Pin("F1", "Vio",     "3V3"),
            Pin("A2", "A3",      "flash_A3"),
            Pin("B2", "A4",      "flash_A4"),
            Pin("C2", "A2",      "flash_A2"),
            Pin("D2", "A1",      "flash_A1"),
            Pin("E2", "A0",      "flash_A0"),
            Pin("F2", "CE#",     "flash_nCE"),
            Pin("G2", "OE#",     "flash_nOE"),
            Pin("H2", "VSS",     "GND"),
            Pin("A3", "A7",      "flash_A7"),
            Pin("B3", "A17",     "flash_A17"),
            Pin("C3", "A6",      "flash_A6"),
            Pin("D3", "A5",      "flash_A5"),
            Pin("E3", "DQ0",     "flash_DQ0"),
            Pin("F3", "DQ8",     ""),  # tristated in byte mode
            Pin("G3", "DQ9",     ""),  # tristated in byte mode
            Pin("H3", "DQ1",     "flash_DQ1"),
            Pin("A4", "RY/BY#",  "flash_READY"),
            Pin("B4", "WP#/ACC"),  # contains an internal pull-up so we can leave it NC
            Pin("C4", "A18",     "flash_A18"),
            Pin("D4", "A20",     "flash_A20"),
            Pin("E4", "DQ2",     "flash_DQ2"),
            Pin("F4", "DQ10",    ""),  # tristated in byte mode
            Pin("G4", "DQ11",    ""),  # tristated in byte mode
            Pin("H4", "DQ3",     "flash_DQ3"),
            Pin("A5", "WE#",     "flash_nWE"),
            Pin("B5", "RESET#",  "flash_nRESET"),
            Pin("C5", "A21",     "flash_A21"),
            Pin("D5", "A19",     "flash_A19"),
            Pin("E5", "DQ5",     "flash_DQ5"),
            Pin("F5", "DQ12",    ""),  # tristated in byte mode
            Pin("G5", "Vcc",     "3V3"),
            Pin("H5", "DQ4",     "flash_DQ4"),
            Pin("A6", "A9",      "flash_A9"),
            Pin("B6", "A8",      "flash_A8"),
            Pin("C6", "A10",     "flash_A10"),
            Pin("D6", "A11",     "flash_A11"),
            Pin("E6", "DQ7",     "flash_DQ7"),
            Pin("F6", "DQ14",    ""),  # tristated in byte mode
            Pin("G6", "DQ13",    ""),  # tristated in byte mode
            Pin("H6", "DQ6",     "flash_DQ6"),
            Pin("A7", "A13",     "flash_A13"),
            Pin("B7", "A12",     "flash_A12"),
            Pin("C7", "A14",     "flash_A14"),
            Pin("D7", "A15",     "flash_A15"),
            Pin("E7", "A16",     "flash_A16"),
            Pin("F7", "BYTE#",   "GND"),  # always in byte mode
            Pin("G7", "DQ15/A-1","flash_A-1"),  # extra A bit in byte mode, DQ15 in word mode
            Pin("H7", "VSS",     "GND"),
            Pin("D8", "Vio",     "3V3"),
            Pin("E8", "VSS",     "GND"),
        ],
    )
]
# Three capacitors per chip (2 x Vio, 1 x Vcc)
flash_caps = [
    myelin_kicad_pcb.C0805("100n", "3V3", "GND", ref="FC%d" % n)
    for n in range(3)
]


### RAM (optional)

# The MT48LC16M16A2F4-6A:GTR looks like a good candidate; it comes in 8x8
# 54FBGA package (0.8mm pitch) and gives us 256 Mbit (32MB if we have a 16 bit
# bus, 16MB if only 8-bit.)

# Datasheet:
# https://media.digikey.com/pdf/Data%20Sheets/Alliance%20Memory%20PDFs/MT48LC64M4A2,%2032M8A2,%2016M16A2.pdf

# A simpler to use alternative would be the AS1C512K16P PSRAM, which is a DRAM
# which handles all the DRAM details internally and provides an SRAM-like
# interface.  1MB (512kb x 16) using 40 pins, or 512kB (512kb x 8) using 30
# pins.  6 x 7 mm BGA, 0.75 mm pitch. ($1.65)

# Another option: AS1C1M16P, 6 x 7 mm BGA, 0.75mm pitch, 1M x 16 PSRAM ($1.95)

# Another option: AS1C2M16P, 6 x 7 mm BGA, 0.75mm pitch, 2M x 16 PSRAM ($2.28)

# Another option: IS61WV25616EDBLL, 6 x 8 mm BGA, 0.75mm pitch, 256k x 16 10ns SRAM ($2.50)


### 


### END

myelin_kicad_pcb.dump_netlist("max10_electron_ula.net")
