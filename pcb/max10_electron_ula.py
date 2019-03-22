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


# TODO renumber resistors and capacitors

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

# 16 + 8 + 16 buffers needed

# TODO wire up direction select for all buffers, to give the option of implementing the CPU inside the ULA.

# Sanity check:
# - 32 x LVT buf (input)
# - 4 x HCT125 OC (output)
# - 8 x HCT245 (output)

ula = myelin_kicad_pcb.Component(
    footprint="modified-kicad:PLCC-68_THT-Socket-Electron-ULA",
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

        # Keyboard: KBD0-3 are 5V inputs, driven by CPU address lines.
        # CAPS_LOCK is an OC output (low speed).
        Pin(27, "KBD0",      "KBD0_5V"),  # I (LVT buf)
        Pin(28, "KBD1",      "KBD1_5V"),  # I (LVT buf)
        Pin(31, "KBD2",      "KBD2_5V"),  # I (LVT buf)
        Pin(32, "KBD3",      "KBD3_5V"),  # I (LVT buf)
        Pin(63, "CAPS_LOCK", "CAPS_LOCK_5V"),  # O (HCT125 OC), drives caps LED via 470R (~6mA)

        # nRST is apparently an input, but being able to drive it seems sensible.
        Pin(58, "nRST", "nRESET_5V"),  # OC I (diode/resistor buf + HCT125 OC)

        # nROM is the TTL ROM chip select, so doesn't need a buffer.
        Pin(61, "nROM", "nROM"),    # O (direct output from FPGA)

        # Address bus: input; use 74lvth162245 with A-port (with 22R series
        # resistors) connected to Electron.
        Pin( 5, "A0",  "A0_5V"),   # IO (LVT buf, reversible)
        Pin( 1, "A1",  "A1_5V"),   # IO (LVT buf, reversible)
        Pin(12, "A2",  "A2_5V"),   # IO (LVT buf, reversible)
        Pin(24, "A3",  "A3_5V"),   # IO (LVT buf, reversible)
        Pin(21, "A4",  "A4_5V"),   # IO (LVT buf, reversible)
        Pin(20, "A5",  "A5_5V"),   # IO (LVT buf, reversible)
        Pin(17, "A6",  "A6_5V"),   # IO (LVT buf, reversible)
        Pin(15, "A7",  "A7_5V"),   # IO (LVT buf, reversible)
        Pin( 2, "A8",  "A8_5V"),   # IO (LVT buf, reversible)
        Pin(26, "A9",  "A9_5V"),   # IO (LVT buf, reversible)
        Pin(25, "A10", "A10_5V"),  # IO (LVT buf, reversible)
        Pin(23, "A11", "A11_5V"),  # IO (LVT buf, reversible)
        Pin(13, "A12", "A12_5V"),  # IO (LVT buf, reversible)
        Pin(14, "A13", "A13_5V"),  # IO (LVT buf, reversible)
        Pin(10, "A14", "A14_5V"),  # IO (LVT buf, reversible)
        Pin(56, "A15", "A15_5V"),  # IO (LVT buf, reversible)

        # Data bus: input/output
        Pin(33, "PD0", "PD0_5V"),  # IO (LVT buf, bidirectional)
        Pin(35, "PD1", "PD1_5V"),  # IO (LVT buf, bidirectional)
        Pin(36, "PD2", "PD2_5V"),  # IO (LVT buf, bidirectional)
        Pin(38, "PD3", "PD3_5V"),  # IO (LVT buf, bidirectional)
        Pin(39, "PD4", "PD4_5V"),  # IO (LVT buf, bidirectional)
        Pin(41, "PD5", "PD5_5V"),  # IO (LVT buf, bidirectional)
        Pin(42, "PD6", "PD6_5V"),  # IO (LVT buf, bidirectional)
        Pin(45, "PD7", "PD7_5V"),  # IO (LVT buf, bidirectional)

        # nNMI is an input to the ULA and CPU.
        Pin(57, "nNMI",    "nNMI_5V"),     # I (LVT buf) (OC externally but not for us)
        # PHI_OUT is a 5V signal with CMOS levels.
        Pin(60, "PHI_OUT", "PHI_OUT_5V"),  # O (HCT245 out)
        # nIRQ is an output from the ULA, input to the CPU.
        Pin(30, "nIRQ",    "nIRQ_5V"),     # OC IO (LVT buf + HCT125 OC)
        # RnW is an input to the ULA, output from the CPU.
        Pin(46, "RnW",     "RnW_5V"),      # IO (LVT buf + HCT125 optional out)

        # Clocks and ground
        Pin(55, "DIV13_IN"),                  # NC - unused by FPGA
        Pin(68, "GND", "GND"),
        Pin(51, "GND", "GND"),
        Pin(49, "CLOCK_IN", "CLK_16MHZ_5V"),  # I (LVT buf)

        # Video: direct from FPGA ok as all go straight to buffers
        Pin(67, "nHS",    "nHS_5V"),     # O (HCT245 out) - horizontal sync
        Pin( 3, "RED",    "RED_5V"),     # O (HCT245 out)
        Pin( 4, "GREEN",  "GREEN_5V"),   # O (HCT245 out)
        Pin(66, "BLUE",   "BLUE_5V"),    # O (HCT245 out)
        Pin(65, "nCSYNC", "nCSYNC_5V"),  # O (HCT245 out) - composite sync

        # Power-on reset
        Pin(54, "nPOR"),  # NC - FPGA already has power on detect

        # Audio
        Pin(62, "SOUND_OUT", "SOUND_OUT_5V"),  # O (via WM8524 DAC), goes straight to amplifier

        # Cassettte
        Pin(59, "CAS_IN",  "CAS_IN_5V"),   # I (via MIC7221 comparator)
        Pin(64, "CAS_MO",  "CAS_MO_5V"),   # O (HCT245 out) - motor relay (2mA)
        Pin(50, "CAS_OUT", "CAS_OUT_5V"),  # O (HCT245 out)
        Pin(47, "CAS_RC"),                 # NC - cassette high tone detect

        # Power
        Pin(48, "VCC1", "5V"),  # direct to 5V
        Pin( 9, "VCC2", "5V"),  # 5V via 24R
        Pin(43, "VCC2", "5V"),  # 5V via 24R
    ],
)


### FPGA

# IO requirements: max 130 IO in U169 package.

# So far 113 IO used:

# TODO Serial flash: 6 (flash_nCE, flash_SCK, flash_IO0, flash_IO1, flash_IO2, flash_IO3)
# TODO flash_nCE pullup

# TODO SDRAM: 39 (D x 16, A x 13, BA x 2, nCS, nWE, nCAS, nRAS, CLK, CKE, UDQM, LDQM)
# TODO SDRAM nCS pullup

# TODO SD card signals: 6 (sd_CLK_SCK, sd_CMD_MOSI, sd_DAT0_MISO, sd_DAT1, sd_DAT2, sd_DAT3_nCS)

# TODO USB signals: 3 (USB_M, USB_P, USB_PU)

# TODO clock_osc

# TODO DAC signals: 5 (dac_dacdat, dac_lrclk, dac_bclk, dac_mclk, dac_nmute)

# TODO 32 x 74lvt162245 signals, A_buf_dir, A_buf_nOE, D_buf_dir, D_buf_nOE, input_buf_nOE (misc dir fixed)

# TODO 5 x 74hct125 signals (CAPS_LOCK, nRESET_out, nIRQ_out, RnW_out, RnW_nOE)

# TODO nRESET_in via diode

# TODO 8 x 74hct245 signals, fixed direction, nOE

# TODO CAS IN via comparator
# TODO nROMCS signal

# TODO check that all 44 digital + 1 analog ULA pins are connected
# TODO check that three signals have two connections (nRST, nIRQ, RnW)
# TODO check clocks (clock_osc, CLK_16MHZ) and make sure they work with PLLs

# Pullup resistors on all enables to ensure we don't do anything bad to the
# host machine during FPGA programming
pullups = [
    # chip enables
    myelin_kicad_pcb.R0805("10k", "flash_nCE", "3V3", ref="PR?"),
    myelin_kicad_pcb.R0805("10k", "sdram_nCS", "3V3", ref="PR?"),
    myelin_kicad_pcb.R0805("10k", "sd_DAT3_nCS", "3V3", ref="PR?"),
    # buffer enables
    myelin_kicad_pcb.R0805("10k", "A_buf_nOE", "3V3", ref="PR?"),
    myelin_kicad_pcb.R0805("10k", "D_buf_nOE", "3V3", ref="PR?"),
    myelin_kicad_pcb.R0805("10k", "input_buf_nOE", "3V3", ref="PR?"),
    myelin_kicad_pcb.R0805("10k", "misc_buf_nOE", "5V", ref="PR?"),
    # open collector outputs
    myelin_kicad_pcb.R0805("10k", "nRESET_out", "3V3", ref="PR?"),
    myelin_kicad_pcb.R0805("10k", "nIRQ_out", "3V3", ref="PR?"),
    myelin_kicad_pcb.R0805("10k", "RnW_nOE", "3V3", ref="PR?"),
]

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
    myelin_kicad_pcb.C0402("100n", "3V3", "GND", ref="DC?")
    for r in range(10, 24)
]


### POWER SUPPLY

bulk = [
    myelin_kicad_pcb.C0805("1u", "3V3", "GND", ref="C%d" % r, handsoldering=False)
    for r in range(8, 10)
]

# TODO maybe want more of these
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


### OSCILLATOR (optional)

# With any luck we'll be able to clock everything from the Electron's 16MHz
# oscillator, but just in case that doesn't work, here's a standalone clock
# that the FPGA can use.

osc = myelin_kicad_pcb.Component(
    footprint="Oscillator:Oscillator_SMD_Abracon_ASE-4Pin_3.2x2.5mm_HandSoldering",
    identifier="OSC",
    value="osc",
    # When ordering: double check it's the 3.2x2.5mm package
    # http://ww1.microchip.com/downloads/en/DeviceDoc/20005529B.pdf
    #    DSC100X-C-X-X-096.000-X
    pins=[
        Pin(1, "STANDBY#",  "3V3"),
        Pin(2, "GND",       "GND"),
        Pin(3, "OUT",       "clock_osc"),  # TODO connect to a clock pin on the FPGA
        Pin(4, "VDD",       "3V3"),
    ],
)


### FLASH MEMORY (optional)

# A serial flash chip (cmorley suggests QSPI IS25LP016D, which can receive
# instructions via QPI, so a byte at a random address can be read in 16 cycles
# -- https://stardot.org.uk/forums/viewtopic.php?p=228781#p228781) and either
# use it directly or copy it to RAM before use. This will make room for more
# pins to use for RAM.

# It looks like "QPI" chips can read the instruction in two clocks on all four
# IOs, whereas "Quad SPI" chips typically require 8 clocks on one IO.

# Not sure on the ideal footprint here; we might be able to fit an 8-SO chip,
# but if not, there are some tiny QFN options.

# Note that lots of QPI chips come in 8-SO; make sure to get the right
# footprint (5.3mm 8-SOIJ or 3.9mm 8-SOIC).

flash = [
    myelin_kicad_pcb.Component(
        footprint="Package_SO:SOIJ-8_5.3x5.3mm_P1.27mm",
        identifier="FLASH",
        value="package TBD",
        pins=[
            Pin("1", "CE#",              "flash_nCE"),
            Pin("2", "SO_IO1",           "flash_IO1"),
            Pin("3", "WP#_IO2",          "flash_IO2"),
            Pin("4", "GND",              "GND"),
            Pin("5", "SI_IO0",           "flash_IO0"),
            Pin("6", "SCK",              "flash_SCK"),
            Pin("7", "HOLD#_RESET#_IO3", "flash_IO3"),
            Pin("8", "VCC",              "3V3"),
        ],
    ),
]
flash_cap = myelin_kicad_pcb.C0805("100n", "3V3", "GND", ref="DC?")


# The original plan was to include an S29GL064S chip in LAE064 (9x9mm 64-ball
# 1.0mm pitch) package, as used in Arcflash, except in 8-bit mode.  Retaining
# this here in case we want to resurrect it at some point.
#
# flash = [
#     myelin_kicad_pcb.Component(
#         footprint="myelin-kicad:cypress_lae064_fbga",
#         identifier="FLASH",
#         value="S29GL064S70DHI010",  # 64-ball FBGA, 1mm pitch, 9x9mm (c.f. 20x14 in TQFP)
#         buses=[""],
#         pins=[
#             Pin("F1", "Vio",     "3V3"),
#             Pin("A2", "A3",      "flash_A3"),
#             Pin("B2", "A4",      "flash_A4"),
#             Pin("C2", "A2",      "flash_A2"),
#             Pin("D2", "A1",      "flash_A1"),
#             Pin("E2", "A0",      "flash_A0"),
#             Pin("F2", "CE#",     "flash_nCE"),
#             Pin("G2", "OE#",     "flash_nOE"),
#             Pin("H2", "VSS",     "GND"),
#             Pin("A3", "A7",      "flash_A7"),
#             Pin("B3", "A17",     "flash_A17"),
#             Pin("C3", "A6",      "flash_A6"),
#             Pin("D3", "A5",      "flash_A5"),
#             Pin("E3", "DQ0",     "flash_DQ0"),
#             Pin("F3", "DQ8",     ""),  # tristated in byte mode
#             Pin("G3", "DQ9",     ""),  # tristated in byte mode
#             Pin("H3", "DQ1",     "flash_DQ1"),
#             Pin("A4", "RY/BY#",  "flash_READY"),
#             Pin("B4", "WP#/ACC"),  # contains an internal pull-up so we can leave it NC
#             Pin("C4", "A18",     "flash_A18"),
#             Pin("D4", "A20",     "flash_A20"),
#             Pin("E4", "DQ2",     "flash_DQ2"),
#             Pin("F4", "DQ10",    ""),  # tristated in byte mode
#             Pin("G4", "DQ11",    ""),  # tristated in byte mode
#             Pin("H4", "DQ3",     "flash_DQ3"),
#             Pin("A5", "WE#",     "flash_nWE"),
#             Pin("B5", "RESET#",  "flash_nRESET"),
#             Pin("C5", "A21",     "flash_A21"),
#             Pin("D5", "A19",     "flash_A19"),
#             Pin("E5", "DQ5",     "flash_DQ5"),
#             Pin("F5", "DQ12",    ""),  # tristated in byte mode
#             Pin("G5", "Vcc",     "3V3"),
#             Pin("H5", "DQ4",     "flash_DQ4"),
#             Pin("A6", "A9",      "flash_A9"),
#             Pin("B6", "A8",      "flash_A8"),
#             Pin("C6", "A10",     "flash_A10"),
#             Pin("D6", "A11",     "flash_A11"),
#             Pin("E6", "DQ7",     "flash_DQ7"),
#             Pin("F6", "DQ14",    ""),  # tristated in byte mode
#             Pin("G6", "DQ13",    ""),  # tristated in byte mode
#             Pin("H6", "DQ6",     "flash_DQ6"),
#             Pin("A7", "A13",     "flash_A13"),
#             Pin("B7", "A12",     "flash_A12"),
#             Pin("C7", "A14",     "flash_A14"),
#             Pin("D7", "A15",     "flash_A15"),
#             Pin("E7", "A16",     "flash_A16"),
#             Pin("F7", "BYTE#",   "GND"),  # always in byte mode
#             Pin("G7", "DQ15/A-1","flash_A-1"),  # extra A bit in byte mode, DQ15 in word mode
#             Pin("H7", "VSS",     "GND"),
#             Pin("D8", "Vio",     "3V3"),
#             Pin("E8", "VSS",     "GND"),
#         ],
#     )
# ]
# # Three capacitors per chip (2 x Vio, 1 x Vcc)
# flash_caps = [
#     myelin_kicad_pcb.C0805("100n", "3V3", "GND", ref="DC?")
#     for n in range(3)
# ]

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

ram = [
    myelin_kicad_pcb.Component(
        footprint="myelin-kicad:sdram_54tfbga",
        identifier="RAM",
        value="MT48LC16M16A2",
        desc="MT48LC16M16A2F4-6A:GTR",
        buses=[""],
        pins=[
            Pin("A1", "VSS", "GND"),
            Pin("A2", "DQ15", "sdram_DQ15"),
            Pin("A3", "VSSQ", "GND"),
            Pin("A7", "VDDQ", "3V3"),
            Pin("A8", "DQ0", "sdram_DQ0"),
            Pin("A9", "VDD", "3V3"),

            Pin("B1", "DQ14", "sdram_DQ14"),
            Pin("B2", "DQ13", "sdram_DQ13"),
            Pin("B3", "VDDQ", "3V3"),
            Pin("B7", "VSSQ", "GND"),
            Pin("B8", "DQ2", "sdram_DQ2"),
            Pin("B9", "DQ1", "sdram_DQ1"),

            Pin("C1", "DQ12", "sdram_DQ12"),
            Pin("C2", "DQ11", "sdram_DQ11"),
            Pin("C3", "VSSQ", "GND"),
            Pin("C7", "VDDQ", "3V3"),
            Pin("C8", "DQ4", "sdram_DQ4"),
            Pin("C9", "DQ3", "sdram_DQ3"),

            Pin("D1", "DQ10", "sdram_DQ10"),
            Pin("D2", "DQ9", "sdram_DQ9"),
            Pin("D3", "VDDQ", "3V3"),
            Pin("D7", "VSSQ", "GND"),
            Pin("D8", "DQ6", "sdram_DQ6"),
            Pin("D9", "DQ5", "sdram_DQ5"),

            Pin("E1", "DQ8", "sdram_DQ8"),
            Pin("E2", "NC"),
            Pin("E3", "VSS", "GND"),
            Pin("E7", "VDD", "3V3"),
            Pin("E8", "LDQM", "sdram_LDQM"),
            Pin("E9", "DQ7", "sdram_DQ7"),

            Pin("F1", "UDQM", "sdram_UDQM"),
            Pin("F2", "CLK", "sdram_CLK"),
            Pin("F3", "CKE", "sdram_CKE"),
            Pin("F7", "CAS#", "sdram_nCAS"),
            Pin("F8", "RAS#", "sdram_nRAS"),
            Pin("F9", "WE#", "sdram_nWE"),

            Pin("G1", "A12", "sdram_A12"),
            Pin("G2", "A11", "sdram_A11"),
            Pin("G3", "A9", "sdram_A9"),
            Pin("G7", "BA0", "sdram_BA0"),
            Pin("G8", "BA1", "sdram_BA1"),
            Pin("G9", "CS#", "sdram_nCS"),

            Pin("H1", "A8", "sdram_A8"),
            Pin("H2", "A7", "sdram_A7"),
            Pin("H3", "A6", "sdram_A6"),
            Pin("H7", "A0", "sdram_A0"),
            Pin("H8", "A1", "sdram_A1"),
            Pin("H9", "A10", "sdram_A10"),

            Pin("J1", "VSS", "GND"),
            Pin("J2", "A5", "sdram_A5"),
            Pin("J3", "A4", "sdram_A4"),
            Pin("J7", "A3", "sdram_A3"),
            Pin("J8", "A2", "sdram_A2"),
            Pin("J9", "VDD", "3V3"),
        ],
    ),
]

### DAC for audio output

# This is a bit of a stretch because I've never worked with DACs before.  The
# WM8524 is $2 at Digikey and apparently good quality.  It has some
# interesting clocking requirements -- MCLK needs to be 128 or 256 times the
# fs (sample rate), or maybe just an integer ratio, but the datasheet isn't
# clear on exactly what's required.  The Altera DE1 version of ElectronFpga
# uses MCLK=32MHz and LRCLK=125kHz for its Wolfson DAC, so with any luck
# that'll work here as well, and we won't need to use one of the PLLs to
# generate the audio clocks.

# If we *do* need to generate a precise clock, we could generate a 12.288MHz
# clock (48kHz x 256) from 16MHz.  (16MHz x 3 x 256 / 1000, or 16/5x192/50.)

dac = [
    myelin_kicad_pcb.Component(
        footprint="Package_SO:TSSOP-16_4.4x5mm_P0.65mm",
        identifier="DAC",
        value="WM8524",
        pins=[
            Pin( 1, "LINEVOUTL", "dac_out_left"),
            Pin( 2, "CPVOUTN",   "dac_power_cpvoutn"),
            Pin( 3, "CPCB",      "dac_power_cpcb"),
            Pin( 4, "LINEGND",   "GND"),
            Pin( 5, "CPCA",      "dac_power_cpca"),
            Pin( 6, "LINEVDD",   "3V3"),
            Pin( 7, "DACDAT",    "dac_dacdat"),  # to fpga
            Pin( 8, "LRCLK",     "dac_lrclk"),  # to fpga
            Pin( 9, "BCLK",      "dac_bclk"),  # to fpga
            Pin(10, "MCLK",      "dac_mclk"),  # to fpga
            Pin(11, "nMUTE",     "dac_nmute"),  # to fpga
            Pin(12, "AIFMODE",   "3V3"),  # tie high for 12 bit i2s
            Pin(13, "AGND",      "GND"),
            Pin(14, "VMID",      "dac_power_vmid"),
            # TODO use a ferrite between 3V3 and AVDD
            Pin(15, "AVDD",      "3V3"),
            Pin(16, "LINEVOUTR", "dac_out_right"),
        ],
    ),
]
audio_caps = [
    # as recommended in the WM8524 datasheet.
    # TODO use very low ESR caps.
    myelin_kicad_pcb.C0805("1u", "dac_power_cpvoutn", "GND", ref="AC1"),
    myelin_kicad_pcb.C0805("4.7u", "3V3", "GND", ref="AC2"),
    myelin_kicad_pcb.C0805("4.7u", "3V3", "GND", ref="AC3"),
    myelin_kicad_pcb.C0805("2.2u", "dac_power_vmid", "GND", ref="AC4"),
    myelin_kicad_pcb.C0805("1u", "dac_power_cpca", "dac_power_cpcb", ref="AC5"),
]
audio_filters = [
    # NF if we're not using the external left/right outputs (i.e. pure ULA mode)
    myelin_kicad_pcb.R0805("560R NF", "dac_out_left", "audio_out_left", ref="AR1"),
    myelin_kicad_pcb.C0805("2.7n NF", "audio_out_left", "GND", ref="AC6"),
    myelin_kicad_pcb.R0805("560R NF", "dac_out_right", "audio_out_right", ref="AR2"),
    myelin_kicad_pcb.C0805("2.7n NF", "audio_out_right", "GND", ref="AC7"),
]
ula_audio_output = [
    # pulldown for dac_out_left to prevent startup pops (maybe unnecessary)
    myelin_kicad_pcb.R0805("NF 10k", "dac_out_left", "GND", ref="AR3"),
    # coupling capacitor for dac output (center voltage 0V) to SOUND_OUT_5V (center 2.5V)
    myelin_kicad_pcb.C0805("10u", "dac_out_left", "SOUND_OUT_5V", ref="AC8"),
    # pull resistor to center sound output on 2.5V
    myelin_kicad_pcb.R0805("10k", "SOUND_OUT_5V", "audio_bias", ref="AR4"),
    # voltage divider to generate ~2.5V
    myelin_kicad_pcb.R0805("10k", "audio_bias", "GND", ref="AR5"),
    myelin_kicad_pcb.R0805("10k", "audio_bias", "5V", ref="AR6"),
    # decoupling capacitor to stabilize voltage divider
    myelin_kicad_pcb.C0805("10u", "audio_bias", "GND", ref="AC9"),
]


### FPGA-ULA BUFFERS

# No need for a low pass filter on CAS_OUT_5V to allow the FPGA to generate a
# nicer signal. I  imagine we'll want to do PWM at 1MHz, which gives us 96
# levels assuming a 96 MHz clock. CAS OUT already has a filter (100k + 2n2, so
# 220us time constant / knee at 4.5 kHz) so we can just connect an HCT output
# directly to CAS_OUT_5V.

# Reset level conversion using diode + pullup
reset_3v3_pullup = myelin_kicad_pcb.R0805("10k", "3V3", "nRESET_in", ref="R?")
reset_3v3_diode = myelin_kicad_pcb.DSOD323("BAT54", "nRESET_5V", "nRESET_in", ref="D?")

big_buffers = [
    [
        myelin_kicad_pcb.Component(
            footprint="myelin-kicad:ti_zrd_54_pbga",
            identifier=ident,
            value="74LVTH162245", # TODO exact part number
            pins=[
                Pin("A3", "1DIR", nOE1),
                Pin("A4", "1nOE", DIR1),

                Pin("A6", "1A1", conn1[0][0]),
                Pin("A1", "1B1", conn1[0][1]),
                Pin("B5", "1A2", conn1[1][0]),
                Pin("B2", "1B2", conn1[1][1]),
                Pin("B6", "1A3", conn1[2][0]),
                Pin("B1", "1B3", conn1[2][1]),
                Pin("C5", "1A4", conn1[3][0]),
                Pin("C2", "1B4", conn1[3][1]),
                Pin("C6", "1A5", conn1[4][0]),
                Pin("C1", "1B5", conn1[4][1]),
                Pin("D5", "1A6", conn1[5][0]),
                Pin("D2", "1B6", conn1[5][1]),
                Pin("D6", "1A7", conn1[6][0]),
                Pin("D1", "1B7", conn1[6][1]),
                Pin("E5", "1A8", conn1[7][0]),
                Pin("E2", "1B8", conn1[7][1]),

                Pin("J3", "2DIR", nOE2),
                Pin("J4", "2nOE", DIR2),

                Pin("E6", "2A1", conn2[0][0]),
                Pin("E1", "2B1", conn2[0][1]),
                Pin("F5", "2A2", conn2[1][0]),
                Pin("F2", "2B2", conn2[1][1]),
                Pin("F6", "2A3", conn2[2][0]),
                Pin("F1", "2B3", conn2[2][1]),
                Pin("G5", "2A4", conn2[3][0]),
                Pin("G2", "2B4", conn2[3][1]),
                Pin("G6", "2A5", conn2[4][0]),
                Pin("G1", "2B5", conn2[4][1]),
                Pin("H5", "2A6", conn2[5][0]),
                Pin("H2", "2B6", conn2[5][1]),
                Pin("H6", "2A7", conn2[6][0]),
                Pin("H1", "2B7", conn2[6][1]),
                Pin("J6", "2A8", conn2[7][0]),
                Pin("J1", "2B8", conn2[7][1]),

                Pin("C3", "VCC", "3V3"),
                Pin("C4", "VCC", "3V3"),
                Pin("G3", "VCC", "3V3"),
                Pin("G4", "VCC", "3V3"),

                Pin("D3", "GND", "GND"),
                Pin("D4", "GND", "GND"),
                Pin("E3", "GND", "GND"),
                Pin("E4", "GND", "GND"),
                Pin("F3", "GND", "GND"),
                Pin("F4", "GND", "GND"),
            ],
        ),
        # Four caps per buffer -- lots of power pins
        myelin_kicad_pcb.C0402("100n", "GND", "3V3", ref="DC?"),
        myelin_kicad_pcb.C0402("100n", "GND", "3V3", ref="DC?"),
        myelin_kicad_pcb.C0402("100n", "GND", "3V3", ref="DC?"),
        myelin_kicad_pcb.C0402("100n", "GND", "3V3", ref="DC?"),
    ]
    for ident, nOE1, DIR1, conn1, nOE2, DIR2, conn2 in
    [
        # 74LVTH162245 for A_buf
        "ABUF",
        # A port (with series 22R) should connect to ULA pins, B port should connect to FPGA
        "A_buf_nOE",  # pulled up
        "A_buf_DIR",
        [
            # [A port, B port]
            ["A0_5V",  "A0"],
            ["A1_5V",  "A1"],
            ["A2_5V",  "A2"],
            ["A3_5V",  "A3"],
            ["A4_5V",  "A4"],
            ["A5_5V",  "A5"],
            ["A6_5V",  "A6"],
            ["A7_5V",  "A7"],
        ],
        "A_buf_nOE",  # pulled up
        "A_buf_DIR",
        [
            ["A8_5V",  "A8"],
            ["A9_5V",  "A9"],
            ["A10_5V", "A10"],
            ["A11_5V", "A11"],
            ["A12_5V", "A12"],
            ["A13_5V", "A13"],
            ["A14_5V", "A14"],
            ["A15_5V", "A15"],
        ],
    ],
    [
        # 74LVTH162245 for D_buf + input_buf
        "DBUF",
        # A port (with series 22R) should connect to ULA pins, B port should connect to FPGA
        "D_buf_nOE",  # pulled up
        "D_buf_DIR",
        [
            # [A port, B port]
            ["PD0_5V", "PD0"],
            ["PD1_5V", "PD1"],
            ["PD2_5V", "PD2"],
            ["PD3_5V", "PD3"],
            ["PD4_5V", "PD4"],
            ["PD5_5V", "PD5"],
            ["PD6_5V", "PD6"],
            ["PD7_5V", "PD7"],
        ],
        # These are always inputs - fixed direction
        "input_buf_nOE",  # pulled up
        "3V3",  # input_buf_DIR = A -> B
        [
            # [A port, B port]
            ["KBD0_5V",      "KBD0"],
            ["KBD1_5V",      "KBD1"],
            ["KBD2_5V",      "KBD2"],
            ["KBD3_5V",      "KBD3"],
            ["nNMI_5V",      "nNMI_in"],
            ["nIRQ_5V",      "nIRQ_in"],
            ["RnW_5V",       "RnW_in"],
            ["CLK_16MHZ_5V", "CLK_16MHZ"],
        ]
    ],
]

oc_buf = [
    [
        myelin_kicad_pcb.Component(
            footprint="Package_SO:TSSOP-14_4.4x5mm_P0.65mm",  # TODO the pins are really fat here, make my own?
            identifier=ident,
            value="74HCT125PW",
            pins=[
                Pin( 1, "1nOE", conn[0][0]),
                Pin( 2, "1A",   conn[0][1]),
                Pin( 3, "1Y",   conn[0][2]),
                Pin( 4, "2nOE", conn[1][0]),
                Pin( 5, "2A",   conn[1][1]),
                Pin( 6, "2Y",   conn[1][2]),
                Pin( 7, "GND",  "GND"),
                Pin( 8, "3Y",   conn[2][2]),
                Pin( 9, "3A",   conn[2][1]),
                Pin(10, "3nOE", conn[2][0]),
                Pin(11, "4Y",   conn[3][2]),
                Pin(12, "4A",   conn[3][1]),
                Pin(13, "4nOE", conn[3][0]),
                Pin(14, "VCC",  power),
            ],
        ),
        myelin_kicad_pcb.C0805("100n", "GND", power, ref="DC?"),
    ]
    for ident, power, conn in [
        (
            "OC",
            "5V",
            [
                # [nOE, input, output]
                ["GND",        "CAPS_LOCK", "CAPS_LOCK_5V"],
                ["nRESET_out", "GND",       "nRESET_5V"],
                ["nIRQ_out",   "GND",       "nIRQ_5V"],
                ["RnW_out",    "RnW_nOE",   "RnW_5V"],
            ]
        )
    ]
]

# buffer to generate 5V signals with rail to rail swing for clock, video, cassette
misc_buf = [
    [
        myelin_kicad_pcb.Component(
            footprint="Package_SO:SSOP-20_4.4x6.5mm_P0.65mm",
            identifier=ident,
            value="74HCT245PW",
            pins=[
                Pin( 1, "A->B", DIR),
                Pin( 2, "A0",   conn[0][0]),
                Pin( 3, "A1",   conn[1][0]),
                Pin( 4, "A2",   conn[2][0]),
                Pin( 5, "A3",   conn[3][0]),
                Pin( 6, "A4",   conn[4][0]),
                Pin( 7, "A5",   conn[5][0]),
                Pin( 8, "A6",   conn[6][0]),
                Pin( 9, "A7",   conn[7][0]),
                Pin(10, "GND",  "GND"),
                Pin(11, "B7",   conn[7][1]),
                Pin(12, "B6",   conn[6][1]),
                Pin(13, "B5",   conn[5][1]),
                Pin(14, "B4",   conn[4][1]),
                Pin(15, "B3",   conn[3][1]),
                Pin(16, "B2",   conn[2][1]),
                Pin(17, "B1",   conn[1][1]),
                Pin(18, "B0",   conn[0][1]),
                Pin(19, "nCE",  nOE),
                Pin(20, "VCC",  power),
            ],
        ),
        myelin_kicad_pcb.C0805("100n", "GND", power, ref="DC?"),
    ]
    for power, ident, DIR, nOE, conn in [
        (
            "5V",
            "MISC",
            "5V",  # misc_buf_DIR = A -> B  # TODO verify
            "misc_buf_nOE",  # pulled up
            [
                # [A port, B port]
                ["PHI_OUT", "PHI_OUT_5V_prefilter"],
                ["nHS",     "nHS_5V"],
                ["RED",     "RED_5V"],
                ["GREEN",   "GREEN_5V"],
                ["BLUE",    "BLUE_5V"],
                ["nCSYNC",  "nCSYNC_5V"],
                ["CAS_MO",  "CAS_MO_5V"],
                ["CAS_OUT", "CAS_OUT_5V"],
            ]
        )
    ]
]

# Low pass filter on PHI_OUT_5V to bring rise time down to ~25 ns
phi_out_filter = [
    myelin_kicad_pcb.R0805("100R", "PHI_OUT_5V_prefilter", "PHI_OUT_5V", ref="R?"),
    myelin_kicad_pcb.C0805("2.7n", "PHI_OUT_5V", "GND", ref="C?"),
]

# MIC7221 comparator for CAS IN
comparator = [
    myelin_kicad_pcb.Component(
        footprint="", # TODO
        identifier="CMP",
        value="MIC7221",
        pins=[
            Pin( 1, "OUT", "CAS_IN"),  # open drain, pulled to 3V3
            Pin( 2, "V+",  "5V"),
            Pin( 3, "IN+", "CAS_IN_5V"),
            Pin( 4, "IN-", "CAS_IN_divider"),
            Pin( 5, "V-",  "GND"),
        ],
    ),
]

comparator_misc = [
    # MIC7221 pullup to 3V3
    myelin_kicad_pcb.R0805("1k", "CAS_IN", "3V3", ref="R?"),
    # TODO calculate CAS_IN_divider values to make the center voltage for CAS_IN
    myelin_kicad_pcb.R0805("1k", "GND", "CAS_IN_divider", ref="R?"),
    myelin_kicad_pcb.R0805("1k", "CAS_IN_divider", "5V", ref="R?"),
    # decoupling
    myelin_kicad_pcb.C0805("100n", "3V3", "GND", ref="DC?"),
]


### MICRO USB SOCKET

# Optional part; this is intended to support the TinyFPGA Bootloader or a
# similar soft USB stack.  Unlike the ATSAMD devices, series resistors and a
# D+ pullup are needed.

micro_usb = myelin_kicad_pcb.Component(
    footprint="myelin-kicad:micro_usb_b_smd_molex",
    identifier="USB",
    value="usb",
    desc="Molex 1050170001 (Digikey WM1399CT-ND) surface mount micro USB socket with mounting holes.",
    pins=[
        # TODO add a jumper and/or a diode so we can power the system from VUSB during bringup
        Pin(1, "V", "VUSB"),
        Pin(2, "-", "USBDM"),
        Pin(3, "+", "USBDP"),
        Pin(4, "ID"),
        Pin(5, "G", "GND"),
    ],
)
usb_misc = [
    # series resistors between USB and FPGA
    myelin_kicad_pcb.R0805("68R", "USBDM", "USB_M", ref="R?"),
    myelin_kicad_pcb.R0805("68R", "USBDP", "USB_P", ref="R?"),
    # configurable pullup on D+
    myelin_kicad_pcb.R0805("1k5", "USBDP", "USB_PU", ref="R?"),
]


### MICRO SD SOCKET

sd_card = myelin_kicad_pcb.Component(
    footprint="myelin-kicad:hirose_micro_sd_card_socket",
    identifier="SD",
    value="Micro SD socket",
    pins=[
        Pin(    8, "DAT1",       "sd_DAT1"),
        Pin(    7, "DAT0_MISO",  "sd_DAT0_MISO"),
        Pin(    6, "VSS",        "GND"),
        Pin(    5, "CLK_SCK",    "sd_CLK_SCK"),
        Pin(    4, "VDD",        "3V3"),
        Pin(    3, "CMD_MOSI",   "sd_CMD_MOSI"),
        Pin(    2, "CD_DAT3_CS", "sd_DAT3_nCS"),
        Pin(    1, "DAT2"        "sd_DAT2"),
        Pin("SH1", "",           "GND",),
        Pin("SH2", "",           "GND"),
    ],
)
# Just in case -- I don't think this is needed for [micro] SD cards
sd_cmd_pullup = myelin_kicad_pcb.R0805("10k NF", "3V3", "sd_CMD_MOSI", ref="PR?")


### END

myelin_kicad_pcb.dump_netlist("max10_electron_ula.net")
