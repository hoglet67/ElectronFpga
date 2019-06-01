from __future__ import print_function

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

import re, sys, os
here = os.path.dirname(sys.argv[0])
sys.path.insert(0, os.path.join(here, "myelin-kicad.pretty"))
import myelin_kicad_pcb
Pin = myelin_kicad_pcb.Pin

# TODO(v2) rename all 10k resistors to PR*
# TODO(v2) rename all 100n caps to DC*
# TODO(v2) put resistor/capacitor values for R*/AR*/C*/AC* on silkscreen

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

# done(v1) wire up direction select for all buffers, to give the option of implementing the CPU inside the ULA.

# Sanity check:
# - 32 x LVT buf (input)
# - 4 x HCT125 OC (output)
# - 8 x HCT245 (output)

ula = myelin_kicad_pcb.Component(
    footprint="modified-kicad:PLCC-68_THT-Socket-Electron-ULA",  # done(v1) check + pinout
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
        Pin(61, "nROM", "ROM_n"),    # O (direct output from FPGA)

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
        Pin(49, "CLOCK_IN", "clk_in_5V"),  # I (LVT buf)

        # Video: direct from FPGA ok as all go straight to buffers
        Pin(67, "nHS",    "nHS_5V"),     # O (HCT245 out) - horizontal sync
        Pin( 3, "red",    "red_5V"),     # O (HCT245 out)
        Pin( 4, "green",  "green_5V"),   # O (HCT245 out)
        Pin(66, "blue",   "blue_5V"),    # O (HCT245 out)
        Pin(65, "csync",  "csync_5V"),  # O (HCT245 out) - composite sync

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

# IO requirements: max 130 IO in U169 package, practically 118 IO + 12 special

# So far 114 IO used -- see fpga_pins.txt.

# done(v1) Serial flash: 6 (flash_nCE, flash_SCK, flash_IO0, flash_IO1, flash_IO2, flash_IO3)
# done(v1) flash_nCE pullup

# done(v1) SDRAM: 39 (D x 16, A x 13, BA x 2, nCS, nWE, nCAS, nRAS, CLK, CKE, UDQM, LDQM)
# done(v1) SDRAM nCS pullup

# done(v1) SD card signals: 6 (sd_CLK_SCK, sd_CMD_MOSI, sd_DAT0_MISO, sd_DAT1, sd_DAT2, sd_DAT3_nCS)

# done(v1) USB signals: 3 (USB_M, USB_P, USB_PU)

# done(v1) clk_osc: 1

# done(v1) DAC signals: 5 (dac_dacdat, dac_lrclk, dac_bclk, dac_mclk, dac_nmute)

# = 60 signals not from the ULA socket

# done(v1) 32+5 x 74lvt162245 signals, A_buf_dir, A_buf_nOE, D_buf_dir, D_buf_nOE, input_buf_nOE (misc dir fixed)

# done(v1) 5 x 74hct125 signals (caps, RST_n_out, IRQ_n_out, RnW_out, RnW_nOE)

# done(v1) RST_n_in via diode

# done(v1) 8+1 x 74hct245 signals, fixed direction, nOE

# done(v1) casIn via comparator
# done(v1) ROM_n direct

# = 54 signals from the ULA socket

# done(v1) check that all 44 digital + 1 analog ULA pins are connected
# done(v1) check that three signals have two connections (nRST, nIRQ, RnW)
# done(v1) check clocks (clk_osc, clk_in) and make sure they work with PLLs

# CLOCK PLANNING

# - Signals that drive PLLs must be on CLK*, not DPCLK*.

# - Each PLL has 5 outputs.

# Pullup resistors on all enables to ensure we don't do anything bad to the
# host machine during FPGA programming
pullups = [
    # chip enables
    myelin_kicad_pcb.R0805("10k", "flash_nCE", "3V3", ref="PR1"),
    myelin_kicad_pcb.R0805("10k", "sdram_nCS", "3V3", ref="PR2"),
    myelin_kicad_pcb.R0805("10k", "sd_DAT3_nCS", "3V3", ref="PR3"),
    # buffer enables
    myelin_kicad_pcb.R0805("10k", "A_buf_nOE", "3V3", ref="PR4"),
    myelin_kicad_pcb.R0805("10k", "D_buf_nOE", "3V3", ref="PR5"),
    myelin_kicad_pcb.R0805("10k", "input_buf_nOE", "3V3", ref="PR6"),
    myelin_kicad_pcb.R0805("10k", "misc_buf_nOE", "5V", ref="PR7"),
    # open collector outputs
    myelin_kicad_pcb.R0805("10k", "RST_n_out", "3V3", ref="PR8"),
    myelin_kicad_pcb.R0805("10k", "IRQ_n_out", "3V3", ref="PR9"),
    myelin_kicad_pcb.R0805("10k", "RnW_nOE", "3V3", ref="PR10"),
]

# rotate array n positions
# e.g. roll_array(a, 5) will move the first 5 elements to the back of the array
def roll_array(a, n):
    return a[n:] + a[:n]

if True:
    # allocate FPGA pins dynamically

    fpga_pins = [
            # IOs

            # The Max 10 Overview says that the U169 package can have up to 130
            # IOs -- but only if you use everything (including the JTAG pins) as
            # IO.

            # Summary, in order of usefulness:
            # - 112 ordinary IOs that have low capacitance
            # - 2 config pins that we can reconfigure safely (DEV_CLRn, xxx)
            # - 6 VREF pins that have 48pF capacitance rather than 7-8pF
            # --- 120 so far
            # - 2 config pins that are a little more dangerous (CRC_ERROR, JTAGEN) -- not using these
            # - 8 required config pins
            # --- total 130

            # So we have 114 normal IOs, plus 6 VREF (slow) IOs, for a grand
            # total of 120.  VREF IOs can be used for slower/fixed outputs like 
            # A_buf_DIR, A_buf_nOE, input_buf_nOE, RnW_nOE, RST_n_out, USB_PU.

            # There are 12 config pins:
            # TCK, TMS, TDI, TDO = required
            # CONFIG_SEL, CONF_DONE, nCONFIG, nSTATUS = required during startup
            # CRC_ERROR, DEV_CLRn, DEV_OE, JTAGEN = usable as IO

            # So there's really 8 global pins that we shouldn't touch, and 4
            # that are fine as IO.

            # The 6 VREFB*N0 pins have higher capacitance, which will affect
            # IO timing.  48 pF instead of 7-9 pF (Table 16, Max 10
            # datasheet).  T=4.8 ns with 100 ohm driver output impedance,
            # T=14.4 ns with 300 ohm, T=4.8 us with 10k.  So no good for
            # SDRAM, fine for anything from Elk except maybe open collector
            # pins.

            # Looks like 10M08 doesn't have bank 4 and 7. 
            # H1 normal: bank=1B elec=IO special=VREFB1N0 diffio= diffout= speed= pin=H1
            # L1 normal: bank=2 elec=IO special=VREFB2N0 diffio= diffout= speed= pin=L1
            # N11 normal: bank=3 elec=IO special=VREFB3N0 diffio= diffout= speed= pin=N11
            # K13 normal: bank=5 elec=IO special=VREFB5N0 diffio= diffout= speed= pin=K13
            # D13 normal: bank=6 elec=IO special=VREFB6N0 diffio= diffout= speed= pin=D13
            # B7 normal: bank=8 elec=IO special=VREFB8N0 diffio= diffout= speed= pin=B7

            # There are 5 pins (A5, C13, L2, N12, L13) that aren't listed as
            # Low_Speed or High_Speed or special or config.  In Quartus these
            # show up as "other dual function, High_Speed", so these are good
            # to use 

            # Escape routing:
            # 35 on bottom layer (8 R 11 B 8 L 8 T)
            # 4 x 11 outer ring (GND in corners) = 44
            # 4 x 12 between gaps in outer ring = 48
            # plus CONFIG_SEL, nCONFIG, and CRC_ERROR connected to power pins
            # = 130

            # So we have:
            # - Top: 31 IO (incl DEV_OE, DEV_CLRn) + nSTATUS, CONF_DONE, JTAGEN
            # - Right: 31 IO
            # - Bottom: 31 IO
            # - Left: 27 IO + TCK, TMS, TDI, TDO

            # Top and left and include banks 1 and 8 (low speed IO, so those
            # should be used for the ULA (requires 54/58 available IO).  Right
            # and bottom are fast, and provide 62 IO.  SDRAM can go on the
            # right, and everything else on top.


            # Top row, left to right
            Pin("B3",  "",         "NEXT_CONN"),
            Pin("A2",  "",         "NEXT_CONN"),
            Pin("A3",  "",         "NEXT_CONN"),
            Pin("B4",  "",         "NEXT_CONN"),
            Pin("A4",  "",         "NEXT_CONN"),
            Pin("A5",  "",         "NEXT_CONN"),
            Pin("B5",  "",         "NEXT_CONN"),
            Pin("E6",  "",         "NEXT_CONN"),
            Pin("A6",  "",         "NEXT_CONN"),
            Pin("B6",  "",         "NEXT_CONN"),
            Pin("F8",  "",         "NEXT_CONN"),
            Pin("A7",  "",         "NEXT_CONN"),
            Pin("B7",  "VREFB8N0", "mcu_debug_RXD"),
            Pin("A8",  "",         "NEXT_CONN"),
            Pin("E8",  "",         "NEXT_CONN"),
            Pin("E9",  "",         "NEXT_CONN"),
            Pin("D9",  "",         "NEXT_CONN"),
            Pin("A9",  "",         "NEXT_CONN"),
            Pin("C9",  "",         "NEXT_CONN"),
            Pin("A10", "",         "NEXT_CONN"),
            Pin("B10", "",         "NEXT_CONN"),
            Pin("C10", "",         "NEXT_CONN"),
            Pin("A11", "",         "NEXT_CONN"),
            Pin("B11", "",         "NEXT_CONN"),
            Pin("A12", "",         "NEXT_CONN"),
            Pin("B12", "",         "NEXT_CONN"),

            # Right column, top to bottom
            Pin("C11", "",         "NEXT_CONN"),
            Pin("B13", "",         "NEXT_CONN"),
            Pin("C12", "",         "NEXT_CONN"),
            Pin("C13", "",         "NEXT_CONN"),
            Pin("D12", "",         "NEXT_CONN"),
            Pin("D13", "VREFB6N0", "mcu_debug_TXD"),
            Pin("F9",  "DPCLK3",   "NEXT_CONN"),
            Pin("E10", "",         "NEXT_CONN"),
            Pin("F10", "DPCLK2",   "NEXT_CONN"),
            Pin("D11", "",         "NEXT_CONN"),
            Pin("E13", "CLK3n",    "NEXT_CONN"),
            Pin("E12", "",         "NEXT_CONN"),
            Pin("F13", "CLK3p",    "NEXT_CONN"),
            Pin("G9",  "CLK2p",    "clk_osc"),
            Pin("F12", "",         "NEXT_CONN"),
            Pin("G13", "",         "NEXT_CONN"),
            Pin("G10", "CLK2n",    "NEXT_CONN"),
            Pin("G12", "",         "NEXT_CONN"),
            Pin("H13", "",         "NEXT_CONN"),
            Pin("H10", "",         "NEXT_CONN"),
            Pin("J12", "",         "NEXT_CONN"),
            Pin("J13", "",         "NEXT_CONN"),
            Pin("K11", "",         "NEXT_CONN"),
            Pin("K13", "VREFB5N0", "serial_TXD"),
            Pin("K12", "",         "NEXT_CONN"),
            Pin("J10", "",         "NEXT_CONN"),
            Pin("L12", "",         "NEXT_CONN"),
            Pin("K10", "",         "NEXT_CONN"),
            Pin("L13", "",         "NEXT_CONN"),
            Pin("M13", "",         "NEXT_CONN"),
            Pin("L11", "",         "NEXT_CONN"),
            # Bottom row, right to left
            Pin("M12", "",         "NEXT_CONN"),
            Pin("N12", "",         "NEXT_CONN"),
            Pin("M11", "",         "NEXT_CONN"),
            Pin("N11", "VREFB3N0", "serial_RXD"),
            Pin("L10", "",         "NEXT_CONN"),
            Pin("H9",  "",         "NEXT_CONN"),
            Pin("N10", "",         "NEXT_CONN"),
            Pin("J9",  "",         "NEXT_CONN"),
            Pin("M10", "",         "NEXT_CONN"),
            Pin("N9",  "",         "NEXT_CONN"),
            Pin("J8",  "",         "NEXT_CONN"),
            Pin("H8",  "",         "NEXT_CONN"),
            Pin("M9",  "",         "NEXT_CONN"),
            Pin("N8",  "",         "NEXT_CONN"),
            Pin("M8",  "",         "NEXT_CONN"),
            Pin("K7",  "",         "NEXT_CONN"),
            Pin("K8",  "",         "NEXT_CONN"),
            Pin("N7",  "",         "NEXT_CONN"),
            Pin("M7",  "",         "NEXT_CONN"),
            Pin("N6",  "",         "NEXT_CONN"),
            Pin("J7",  "",         "NEXT_CONN"),
            Pin("K6",  "",         "NEXT_CONN"),
            Pin("L5",  "",         "NEXT_CONN"),
            Pin("N5",  "",         "NEXT_CONN"),
            Pin("J6",  "",         "NEXT_CONN"),
            Pin("M5",  "",         "NEXT_CONN"),
            Pin("K5",  "",         "NEXT_CONN"),
            Pin("N4",  "",         "NEXT_CONN"),
            Pin("M4",  "",         "NEXT_CONN"),
            Pin("J5",  "",         "NEXT_CONN"),
            Pin("N3",  "DPCLK1",   "NEXT_CONN"),
            Pin("M3",  "PLL_L_CLKOUTn", "NEXT_CONN"),
            Pin("N2",  "DPCLK0",   "NEXT_CONN"),
            Pin("L3",  "PLL_L_CLKOUTp", "NEXT_CONN"),

            # Left column, bottom to top
            Pin("M2",  "",         "NEXT_CONN"),
            Pin("M1",  "",         "NEXT_CONN"),
            Pin("L2",  "",         "NEXT_CONN"),
            Pin("L1",  "VREFB2N0", "dac_nmute"),
            Pin("L4",  "",         "NEXT_CONN"),
            Pin("K1",  "",         "NEXT_CONN"),
            Pin("K2",  "",         "NEXT_CONN"),
            Pin("H5",  "CLK1n",    "NEXT_CONN"),
            Pin("J1",  "",         "NEXT_CONN"),
            Pin("J2",  "",         "NEXT_CONN"),
            Pin("H1",  "VREFB1N0", "D_buf_DIR"),
            Pin("G4",  "",         "NEXT_CONN"),
            Pin("H6",  "CLK0p",    "NEXT_CONN"),
            Pin("H4",  "CLK1p",    "clk_in"),
            Pin("H2",  "",         "NEXT_CONN"),
            Pin("H3",  "",         "NEXT_CONN"),
            Pin("F1",  "",         "NEXT_CONN"),
            Pin("G5",  "CLK0n",    "NEXT_CONN"),
            Pin("F4",  "",         "NEXT_CONN"),
            Pin("E1",  "",         "NEXT_CONN"),
            Pin("E3",  "",         "NEXT_CONN"),
            Pin("D1",  "",         "NEXT_CONN"),
            Pin("E4",  "",         "NEXT_CONN"),
            Pin("C1",  "",         "NEXT_CONN"),
            Pin("C2",  "",         "NEXT_CONN"),
            Pin("B1",  "",         "NEXT_CONN"),
            Pin("B2",  "",         "NEXT_CONN"),

            # 12 JTAG and other special pins
            # These are IO by default unless enabled in Assignments > Device
            Pin("B9",  "DEV_CLRn",   "mcu_MOSI"),
            Pin("D8",  "DEV_OE",     "mcu_SCK"),
            Pin("E5",  "JTAGEN",     "mcu_MISO"),
            Pin("D6",  "CRC_ERROR",  "mcu_SS"),

            # These are reserved by the fitter by default -- leave them alone
            Pin("C4",  "nSTATUS",    "fpga_nSTATUS"),  # MUST be pulled high during init
            Pin("C5",  "CONF_DONE",  "fpga_CONF_DONE"),  # MUST be pulled high during init
            Pin("D7",  "CONFIG_SEL", "GND"),  # unused, so connected to GND
            Pin("E7",  "nCONFIG",    "3V3"),  # can be connected straight to VCCIO
            Pin("F5",  "TDI",        "fpga_TDI"),
            Pin("F6",  "TDO",        "fpga_TDO"),
            Pin("G1",  "TMS",        "fpga_TMS"),
            Pin("G2",  "TCK",        "fpga_TCK"),

            # 39 power and ground pins
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
    ]

    conns_to_allocate = roll_array([
        # USB, SD, flash
        "USB_PU",
        "sd_DAT2",
        "sd_DAT3_nCS",
        "sd_CMD_MOSI",
        "USB_P",
        "USB_M",
        "sd_DAT1",
        "flash_nCE",
        "flash_IO1",
        "flash_IO2",
        "sd_CLK_SCK",
        "flash_IO3",
        "flash_SCK",
        "sd_DAT0_MISO",
        "flash_IO0",

        # Oscillator
        "clk_osc",

        # SDRAM
        "sdram_DQ15",
        "sdram_DQ14",
        "sdram_DQ13",
        "sdram_DQ8",
        "sdram_DQ11",
        "sdram_A11",
        "sdram_DQ12",
        "sdram_DQ10",
        "sdram_DQ9",
        "sdram_UDQM",
        "sdram_A12",
        "sdram_A8",
        "sdram_A5",
        "sdram_A4",
        "sdram_A7",
        "sdram_A6",
        "sdram_CKE",
        "sdram_BA0",
        "sdram_A9",
        "sdram_CLK",
        "sdram_A0",
        "sdram_A3",
        "sdram_nCAS",
        "sdram_A1",
        "sdram_BA1",
        "sdram_A2",
        "sdram_A10",
        "sdram_nCS",
        "sdram_nWE",
        "sdram_DQ6",
        "sdram_nRAS",
        "sdram_LDQM",
        "sdram_DQ2",
        "sdram_DQ7",
        "sdram_DQ1",
        "sdram_DQ5",
        "sdram_DQ4",
        "sdram_DQ0",
        "sdram_DQ3",

        # DAC
        "dac_dacdat",
        "dac_lrclk",
        "dac_nmute",  # slow OK
        "dac_mclk",
        "dac_bclk",

        # ULA
        # - Comparator
        "casIn",
        # - Diode buffer
        "RST_n_in",
        # - DBUF
        "D_buf_DIR",
        "D_buf_nOE",
        "data7",
        "data5",
        "data4",
        "data6",
        "data3",
        "data2",
        "data1",
        #"clk_in",
        "data0",
        "RnW_in",
        "kbd3",
        "kbd2",
        "NMI_n_in",
        "IRQ_n_in",
        "kbd1",
        "input_buf_nOE",  # slow OK
        "ROM_n",  # direct
        "kbd0",
        "addr15",
        "addr9",
        "addr10",
        "addr3",
        "addr11",
        "addr14",
        "addr0",
        "addr8",
        "addr1",
        "A_buf_DIR",  # slow OK
        "addr5",
        "A_buf_nOE",  # slow OK
        "misc_buf_nOE",  # slow OK
        "addr4",
        "casMO",
        "casOut",
        "addr6",
        "addr13",
        "addr7",
        "blue",
        "addr2",
        "csync",
        "HS_n",
        "addr12",
        "green",
        "red",
        "clk_out",
        # - HCT125
        "RST_n_out",  # slow OK
        "caps",  # slow OK
        "RnW_out",
        "RnW_nOE",
        "IRQ_n_out",
    ], 84)

    for pin in fpga_pins:
        if not pin.nets: continue
        net, = pin.nets
        # remove already-allocated connections
        if net in conns_to_allocate:
            print('already allocated fpga pin: %s' % net)
            conns_to_allocate.remove(net)

    for pin in fpga_pins:
        if not pin.nets:
            print('fpga pin %s has no nets' % pin.number)
            continue

        net, = pin.nets

        if net == 'NEXT_CONN':
            pin.nets = [conns_to_allocate.pop(0)]
            print('allocating first available connection for fpga pin %s: new nets==%s' % (pin.number, pin.nets))
 
else:
    # static FPGA pin allocation
    fpga_pins = [
Pin("D1", "", "io_b1A_L1n_D1"),
Pin("C2", "", "io_b1A_L1p_C2"),
Pin("E3", "", "io_b1A_L3n_E3"),
Pin("E4", "", "io_b1A_L3p_E4"),
Pin("C1", "", "io_b1A_L5n_C1"),
Pin("B1", "", "io_b1A_L5p_B1"),
Pin("F1", "", "io_b1A_L7n_F1"),
Pin("E1", "", "io_b1A_L7p_E1"),
Pin("E5", "", "fpga_JTAGEN"),
Pin("G1", "", "fpga_TMS"),
Pin("H1", "", "special_VREFB1N0_nodiff_H1"),
Pin("G2", "", "fpga_TCK"),
Pin("F5", "", "fpga_TDI"),
Pin("F6", "", "fpga_TDO"),
Pin("F4", "", "io_b1B_L14n_F4"),
Pin("G4", "", "io_b1B_L14p_G4"),
Pin("H2", "", "io_b1B_L16n_H2"),
Pin("H3", "", "io_b1B_L16p_H3"),
Pin("G5", "", "special_b2_CLK0n_L18n_G5"),
Pin("J1", "", "io_b2_L19n_J1"),
Pin("H6", "", "special_b2_CLK0p_L18p_H6"),
Pin("J2", "", "io_b2_L19p_J2"),
Pin("H5", "", "special_b2_CLK1n_L20n_H5"),
Pin("M1", "", "io_b2_L21n_M1"),
Pin("H4", "", "special_b2_CLK1p_L20p_H4"),
Pin("M2", "", "io_b2_L21p_M2"),
Pin("N2", "", "special_b2_DPCLK0_L22n_N2"),
Pin("L1", "", "special_VREFB2N0_nodiff_L1"),
Pin("N3", "", "special_b2_DPCLK1_L22p_N3"),
Pin("L2", "", "singleended_unknown_b2_L2"),
Pin("M3", "", "special_b2_PLL_L_CLKOUTn_L27n_M3"),
Pin("K1", "", "io_b2_L28n_K1"),
Pin("L3", "", "special_b2_PLL_L_CLKOUTp_L27p_L3"),
Pin("K2", "", "io_b2_L28p_K2"),
Pin("L5", "", "io_b3_B1n_L5"),
Pin("M4", "", "io_b3_B2n_M4"),
Pin("L4", "", "io_b3_B1p_L4"),
Pin("M5", "", "io_b3_B2p_M5"),
Pin("K5", "", "io_b3_B3n_K5"),
Pin("N4", "", "io_b3_B4n_N4"),
Pin("J5", "", "io_b3_B3p_J5"),
Pin("N5", "", "io_b3_B4p_N5"),
Pin("N6", "", "io_b3_B5n_N6"),
Pin("N7", "", "io_b3_B6n_N7"),
Pin("M7", "", "io_b3_B5p_M7"),
Pin("N8", "", "io_b3_B6p_N8"),
Pin("J6", "", "io_b3_B7n_J6"),
Pin("M8", "", "io_b3_B8n_M8"),
Pin("K6", "", "io_b3_B7p_K6"),
Pin("M9", "", "io_b3_B8p_M9"),
Pin("J7", "", "io_b3_B9n_J7"),
Pin("N11", "", "special_VREFB3N0_nodiff_N11"),
Pin("K7", "", "io_b3_B9p_K7"),
Pin("N12", "", "singleended_unknown_b3_N12"),
Pin("M13", "", "io_b3_B10n_M13"),
Pin("N10", "", "io_b3_B11n_N10"),
Pin("M12", "", "io_b3_B10p_M12"),
Pin("N9", "", "io_b3_B11p_N9"),
Pin("M11", "", "io_b3_B12n_M11"),
Pin("L11", "", "io_b3_B12p_L11"),
Pin("J8", "", "io_b3_B14n_J8"),
Pin("K8", "", "io_b3_B14p_K8"),
Pin("M10", "", "io_b3_B16n_M10"),
Pin("L10", "", "io_b3_B16p_L10"),
Pin("K10", "", "io_b5_R1p_K10"),
Pin("K11", "", "io_b5_R2p_K11"),
Pin("J10", "", "io_b5_R1n_J10"),
Pin("L12", "", "io_b5_R2n_L12"),
Pin("K12", "", "io_b5_R7p_K12"),
Pin("L13", "", "singleended_unknown_b5_L13"),
Pin("J12", "", "io_b5_R7n_J12"),
Pin("K13", "", "special_VREFB5N0_nodiff_K13"),
Pin("J9", "", "io_b5_R8p_J9"),
Pin("J13", "", "io_b5_R9p_J13"),
Pin("H10", "", "io_b5_R8n_H10"),
Pin("H13", "", "io_b5_R9n_H13"),
Pin("H9", "", "io_b5_R10p_H9"),
Pin("G13", "", "io_b5_R11p_G13"),
Pin("H8", "", "io_b5_R10n_H8"),
Pin("G12", "", "io_b5_R11n_G12"),
Pin("G9", "", "special_b6_CLK2p_R14p_G9"),
Pin("G10", "", "special_b6_CLK2n_R14n_G10"),
Pin("F13", "", "special_b6_CLK3p_R16p_F13"),
Pin("E13", "", "special_b6_CLK3n_R16n_E13"),
Pin("F12", "", "io_b6_R18p_F12"),
Pin("E12", "", "io_b6_R18n_E12"),
Pin("F9", "", "special_b6_DPCLK3_R26p_F9"),
Pin("D13", "", "special_VREFB6N0_nodiff_D13"),
Pin("F10", "", "special_b6_DPCLK2_R26n_F10"),
Pin("C13", "", "singleended_unknown_b6_C13"),
Pin("F8", "", "io_b6_R27p_F8"),
Pin("B12", "", "io_b6_R28p_B12"),
Pin("E9", "", "io_b6_R27n_E9"),
Pin("B11", "", "io_b6_R28n_B11"),
Pin("C12", "", "io_b6_R29p_C12"),
Pin("B13", "", "io_b6_R30p_B13"),
Pin("C11", "", "io_b6_R29n_C11"),
Pin("A12", "", "io_b6_R30n_A12"),
Pin("E10", "", "io_b6_R31p_E10"),
Pin("D9", "", "io_b6_R31n_D9"),
Pin("D12", "", "io_b6_R33p_D12"),
Pin("D11", "", "io_b6_R33n_D11"),
Pin("C10", "", "io_b8_T14p_C10"),
Pin("A8", "", "io_b8_T15p_A8"),
Pin("C9", "", "io_b8_T14n_C9"),
Pin("A9", "", "io_b8_T15n_A9"),
Pin("B10", "", "io_b8_T16p_B10"),
Pin("A10", "", "io_b8_T17p_A10"),
Pin("B9", "", "fpga_DEV_CLRn"),
Pin("A11", "", "io_b8_T17n_A11"),
Pin("D8", "", "fpga_DEV_OE"),
Pin("E8", "", "io_b8_T18n_E8"),
Pin("B7", "", "special_VREFB8N0_nodiff_B7"),
Pin("D7", "", "fpga_CONFIG_SEL"),
Pin("A7", "", "io_b8_T19p_A7"),
Pin("E7", "", "fpga_nCONFIG"),
Pin("A6", "", "io_b8_T19n_A6"),
Pin("B6", "", "io_b8_T20p_B6"),
Pin("A4", "", "io_b8_T21p_A4"),
Pin("B5", "", "io_b8_T20n_B5"),
Pin("A3", "", "io_b8_T21n_A3"),
Pin("E6", "", "io_b8_T22p_E6"),
Pin("B3", "", "io_b8_T23p_B3"),
Pin("D6", "", "fpga_CRC_ERROR"),
Pin("B4", "", "io_b8_T23n_B4"),
Pin("C4", "", "fpga_nSTATUS"),
Pin("A5", "", "singleended_unknown_b8_A5"),
Pin("C5", "", "fpga_CONF_DONE"),
Pin("A2", "", "io_b8_T26p_A2"),
Pin("B2", "", "io_b8_T26n_B2"),
Pin("D2", "", "GND"),
Pin("E2", "", "GND"),
Pin("N13", "", "GND"),
Pin("N1", "", "GND"),
Pin("M6", "", "GND"),
Pin("L9", "", "GND"),
Pin("J4", "", "GND"),
Pin("H12", "", "GND"),
Pin("G7", "", "GND"),
Pin("F3", "", "GND"),
Pin("E11", "", "GND"),
Pin("D5", "", "GND"),
Pin("C3", "", "GND"),
Pin("B8", "", "GND"),
Pin("A13", "", "GND"),
Pin("A1", "", "GND"),
Pin("F2", "", "3V3"),
Pin("G3", "", "3V3"),
Pin("K3", "", "3V3"),
Pin("J3", "", "3V3"),
Pin("L8", "", "3V3"),
Pin("L7", "", "3V3"),
Pin("L6", "", "3V3"),
Pin("J11", "", "3V3"),
Pin("H11", "", "3V3"),
Pin("G11", "", "3V3"),
Pin("F11", "", "3V3"),
Pin("C8", "", "3V3"),
Pin("C7", "", "3V3"),
Pin("C6", "", "3V3"),
Pin("K4", "", "3V3"),
Pin("D10", "", "3V3"),
Pin("D3", "", "3V3"),
Pin("D4", "", "3V3"),
Pin("K9", "", "3V3"),
Pin("H7", "", "3V3"),
Pin("G8", "", "3V3"),
Pin("G6", "", "3V3"),
Pin("F7", "", "3V3"),
    ]

fpga = myelin_kicad_pcb.Component(
    footprint="myelin-kicad:intel_ubga169",
    identifier="FPGA",
    value="10M08SCU169",
    desc="https://www.digikey.com/product-detail/en/10M08SCU169C8G/544-3270-ND",
    buses=['addr', 'data', 'sdram_DQ', 'sdram_A', 'sdram_BA', 'kbd'],
    pins=fpga_pins)

#myelin_kicad_pcb.update_intel_qsf(
#    cpld, os.path.join(here, "../altera/ElectronULA_max10.qsf"))
print("FPGA: %s" % repr(fpga))

# Rewrite pin assignment CSV file
# lines = open('../altera/ElectronULA_max10.csv').read()
# print(repr(lines))
# csv = ''
# for line in lines.split("\n"):
#     line = line.rstrip()
#     if line and not line.startswith('#') and not line.startswith('To,Direction,Location') and "PIN_" in line:
#         try:
#             signal, a, pin, b = re.search('^(.*?)(,.*?)(PIN_.*?)(,.*)$', line).groups()
#         except AttributeError:
#             raise Exception("failed to parse %s" % repr(line))
#         # update PIN_... section
#         munged_signal = re.sub(r'[\[\]]', '', signal)
#         pins = [p for p in fpga_pins if p.nets == [munged_signal]]
#         print('pins found for %s: %s' % (signal, repr(pins)))
#         pin = 'PIN_%s' % pins[0].number
#         line = ''.join([signal, a, pin, b])
#     csv += "%s\r\n" % line
# print(repr(csv))
# open('../altera/ElectronULA_max10_from_pcb.csv', 'w').write(csv)

# Write out qsf snippet for pin locations
with open('../altera/ElectronULA_max10_from_pcb_pins_qsf.txt', 'w') as f:
    for pin in fpga_pins:
        if not pin.nets: continue
        net, = pin.nets
        if net in ('3V3', 'GND'): continue
        if net.startswith('fpga_'): continue
        for bus in fpga.buses:
            if net.startswith(bus):
                net = "%s[%s]" % (net[:len(bus)], net[len(bus):])
        print("set_location_assignment PIN_%s -to %s" % (pin.number, net), file=f)


# chip won't init unless this is pulled high
conf_done_pullup = myelin_kicad_pcb.R0805("10k", "fpga_CONF_DONE", "3V3", ref="PR12", handsoldering=False)

# chip goes into error state if this is pulled low
nstatus_pullup = myelin_kicad_pcb.R0805("10k", "fpga_nSTATUS", "3V3", ref="PR13", handsoldering=False)

# prevent spurious jtag clocks
tck_pulldown = myelin_kicad_pcb.R0805("1-10k", "fpga_TCK", "GND", ref="R3", handsoldering=False)

# fpga_nCONFIG doesn't need a pullup, just connect straight to 3V3

# fpga_CONFIG_SEL is connected to GND because we don't use this

fpga_decoupling = [
    myelin_kicad_pcb.C0402("100n", "3V3", "GND", ref="DC?")
    for r in range(10, 24)
]

# done(v1) fpga jtag - verify this works with USB Blaster / Intel Download Cable
# altera jtag header, like in the lc-electronics xc9572xl board
# left column: tck tdo tms nc tdi
# right column: gnd vcc nc nc gnd
jtag = myelin_kicad_pcb.Component(
    footprint="myelin-kicad:jtag_shrouded_2x5",  # TODO(v2) replace with bigger IDC footprint
    identifier="JTAG",
    value="jtag",
    pins=[
        Pin( 1, "TCK", "fpga_TCK"), # top left
        Pin( 2, "GND", "GND"), # top right
        Pin( 3, "TDO", "fpga_TDO"),
        Pin( 4, "3V3", "3V3"),
        Pin( 5, "TMS", "fpga_TMS"),
        Pin( 6, "NC"),
        Pin( 7, "NC"),
        Pin( 8, "NC"),
        Pin( 9, "TDI", "fpga_TDI"),
        Pin(10, "GND", "GND"),
    ],
)

# Quick-connect JTAG header for a Tag-Connect TC2030 series
tag_connect = myelin_kicad_pcb.Component(
    footprint="Tag-Connect_TC2030-IDC-FP_2x03_P1.27mm_Vertical",
    identifier="JTAGTC",
    value="jtagtc",
    pins=[
        # This pinout is for the Tag-Connect TC2030-ALT cable
        # (http://www.tag-connect.com/TC2030-ALT) when used with an Altera USB
        # Blaster.

        # I already have a TC2030-CTX (http://www.tag-connect.com/TC2030-CTX)
        # and don't want to buy another cable, so I'm going to make an adapter
        # which connects a USB Blaster header to a 2x5 Cortex debug header,
        # which will then work with the TC2030-CTX.

        Pin(1, "VCC", "3V3"),       # Cortex pin 1
        Pin(2, "TMS", "fpga_TMS"),  # Cortex pin 2 (SWDIO)
        Pin(3, "TDI", "fpga_TDI"),  # Cortex pin 10 (nRESET)
        Pin(4, "TCK", "fpga_TCK"),  # Cortex pin 4 (SWCLK)
        Pin(5, "GND", "GND"),       # Cortex pin 3, 5, 9
        Pin(6, "TDO", "fpga_TDO"),  # Cortex pin 6 (SWO)
    ],
)

# FPGA serial port
serial_header = myelin_kicad_pcb.Component(
    footprint="Connector_PinHeader_2.54mm:PinHeader_1x03_P2.54mm_Vertical",
    identifier="SERIAL",
    value="fpga serial port",
    pins=[
        Pin( 1, "", "GND"),
        Pin( 2, "", "serial_TXD"),
        Pin( 3, "", "serial_RXD"),
    ],
)


### POWER SUPPLY

# Maybe want more of these?
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

# Helpful power input/output
ext_power = myelin_kicad_pcb.Component(
    footprint="Connector_PinHeader_2.54mm:PinHeader_1x03_P2.54mm_Vertical",
    identifier="EXTPWR",
    value="ext pwr",
    desc="1x3 0.1 inch male header",
    pins=[
        Pin(1, "A", ["GND"]),
        Pin(2, "B", ["3V3"]),
        Pin(3, "C", ["5V"]),
    ],
)


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
    desc="https://www.digikey.com/product-detail/en/microchip-technology/DSC1001CL1-016.0000/DSC1001CL1-016.0000-ND",
    pins=[
        Pin(1, "STANDBY#",  "3V3"),
        Pin(2, "GND",       "GND"),
        Pin(3, "OUT",       "clk_osc"),
        Pin(4, "VDD",       "3V3"),
    ],
)


### FLASH MEMORY (optional)

# A serial flash chip (cmorley suggests QSPI IS25LP016D, which can receive
# instructions via QPI, so a byte at a random address can be read in 16 cycles
# -- https://stardot.org.uk/forums/viewtopic.php?p=228781#p228781) and either
# use it directly or copy it to RAM before use. This will make room for more
# pins to use for RAM.

# With a 190 ns window, 16 clocks means our clock has to be > 84MHz.  Our PLL
# VCO runs at 960 MHz, so 96 MHz might work well to stay in sync with the
# 16MHz ULA.

# It looks like "QPI" chips can read the instruction in two clocks on all four
# IOs, whereas "Quad SPI" chips typically require 8 clocks on one IO.

# Not sure on the ideal footprint here; we might be able to fit an 8-SO chip,
# but if not, there are some tiny QFN options.

# Note that lots of QPI chips come in 8-SO; make sure to get the right
# footprint (5.3mm 8-SOIJ or 3.9mm 8-SOIC).

flash = [
    myelin_kicad_pcb.Component(
        footprint="Package_SO:SOIJ-8_5.3x5.3mm_P1.27mm",  # done(v1) check + pinout
        identifier="FLASH",
        value="W25Q128JVSIM",  # 133MHz max clock
        desc="https://www.digikey.com/product-detail/en/winbond-electronics/W25Q128JVSIM/W25Q128JVSIM-ND/6819721",
        # $1 2MB version: https://www.digikey.com/product-detail/en/issi-integrated-silicon-solution-inc/IS25LP016D-JBLE/706-1582-ND
        # $2.50 16MB version: https://www.digikey.com/product-detail/en/issi-integrated-silicon-solution-inc/IS25LP128-JBLE/706-1341-ND
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
        desc="MT48LC16M16A2F4-6A:GTR",  # done(v1) check pinout
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

# TODO(v2) make a jumper option to not use dac and just have one IO for sound_out

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
        footprint="Package_SO:TSSOP-16_4.4x5mm_P0.65mm",  # done(v1) check + pinout
        identifier="DAC",
        value="WM8524CGEDT",
        desc="https://www.digikey.com/product-detail/en/cirrus-logic-inc/WM8524CGEDT/598-2458-ND",
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
            # TODO(v2) use a ferrite between 3V3 and AVDD
            Pin(15, "AVDD",      "3V3"),
            Pin(16, "LINEVOUTR", "dac_out_right"),
        ],
    ),
]
audio_caps = [
    # as recommended in the WM8524 datasheet.
    # use very low ESR caps.
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
    # pulldown for dac_out_right to prevent startup pops (maybe unnecessary)
    myelin_kicad_pcb.R0805("10k NF", "dac_out_right", "GND", ref="AR3"),
    # coupling capacitor for dac output (center voltage 0V) to SOUND_OUT_5V (center 2.5V)
    myelin_kicad_pcb.C0805("10u", "dac_out_right", "SOUND_OUT_5V", ref="AC8"),
    # pull resistor to center sound output on 2.5V
    myelin_kicad_pcb.R0805("10k", "SOUND_OUT_5V", "audio_bias", ref="AR4"),
    # voltage divider to generate ~2.5V
    myelin_kicad_pcb.R0805("10k", "audio_bias", "GND", ref="AR5"),
    myelin_kicad_pcb.R0805("10k", "audio_bias", "5V", ref="AR6"),
    # decoupling capacitor to stabilize voltage divider
    myelin_kicad_pcb.C0805("10u", "audio_bias", "GND", ref="AC9"),
]

audio_out_header = myelin_kicad_pcb.Component(
    footprint="Connector_PinHeader_2.54mm:PinHeader_2x02_P2.54mm_Vertical",
    identifier="AUDIO_OUT",
    value="audio out",
    pins=[
        Pin( 1, "", "GND"),
        Pin( 2, "", "audio_out_right"),
        Pin( 3, "", "GND"),
        Pin( 4, "", "audio_out_left"),
    ],
)


### FPGA-ULA BUFFERS

# No need for a low pass filter on CAS_OUT_5V to allow the FPGA to generate a
# nicer signal. I  imagine we'll want to do PWM at 1MHz, which gives us 96
# levels assuming a 96 MHz clock. CAS OUT already has a filter (100k + 2n2, so
# 220us time constant / knee at 4.5 kHz) so we can just connect an HCT output
# directly to CAS_OUT_5V.

# Reset level conversion using diode + pullup
reset_3v3_pullup = myelin_kicad_pcb.R0805("10k", "3V3", "RST_n_in", ref="R4")
reset_3v3_diode = myelin_kicad_pcb.DSOD323("BAT54", "nRESET_5V", "RST_n_in", ref="D?")

big_buffers = [
    [
        myelin_kicad_pcb.Component(
            footprint="myelin-kicad:ti_zrd_54_pbga",  # done(v1): check + pinout
            identifier=ident,
            value="74LVTH162245ZRDR",
            desc="https://www.digikey.com/product-detail/en/texas-instruments/74LVTH162245ZRDR/296-16878-1-ND",
            pins=[
                Pin("A3", "1DIR", DIR1),
                Pin("A4", "1nOE", nOE1),

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

                Pin("J3", "2DIR", DIR2),
                Pin("J4", "2nOE", nOE2),

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
            ["A15_5V", "addr15"],
            ["A10_5V", "addr10"],
            ["A9_5V",  "addr9"],
            ["A11_5V", "addr11"],
            ["A3_5V",  "addr3"],
            ["A4_5V",  "addr4"],
            ["A5_5V",  "addr5"],
            ["A13_5V", "addr13"],
        ],
        "A_buf_nOE",  # pulled up
        "A_buf_DIR",
        [
            ["A6_5V",  "addr6"],
            ["A2_5V",  "addr2"],
            ["A7_5V",  "addr7"],
            ["A14_5V", "addr14"],
            ["A12_5V", "addr12"],
            ["A8_5V",  "addr8"],
            ["A0_5V",  "addr0"],
            ["A1_5V",  "addr1"],
        ],
    ],
    [
        # 74LVTH162245 for D_buf + input_buf
        "DBUF",
        # A port (with series 22R) should connect to ULA pins, B port should connect to FPGA
        "D_buf_nOE",  # pulled up
        "D_buf_DIR",  # 1 = A->B (ULA->FPGA), 0 = B->A (FPGA->ULA)
        [
            # [A port, B port]
            ["PD7_5V", "data7"],
            ["PD4_5V", "data4"],
            ["PD5_5V", "data5"],
            ["PD1_5V", "data1"],
            ["PD6_5V", "data6"],
            ["PD3_5V", "data3"],
            ["PD2_5V", "data2"],
            ["PD0_5V", "data0"],
        ],
        # These are always inputs - fixed direction
        "input_buf_nOE",  # pulled up
        "3V3",  # input_buf_DIR = A -> B
        [
            # [A port, B port]
            ["clk_in_5V",    "clk_in"],
            ["RnW_5V",       "RnW_in"],
            ["KBD3_5V",      "kbd3"],
            ["KBD2_5V",      "kbd2"],
            ["nIRQ_5V",      "IRQ_n_in"],
            ["nNMI_5V",      "NMI_n_in"],
            ["KBD1_5V",      "kbd1"],
            ["KBD0_5V",      "kbd0"],
        ]
    ],
]

oc_buf = [
    [
        myelin_kicad_pcb.Component(
            footprint="Package_SO:TSSOP-14_4.4x5mm_P0.65mm",  # done(v1) check + pinout
            identifier=ident,
            value="74HCT125PW",
            desc="https://www.digikey.com/product-detail/en/nexperia-usa-inc/74HCT125PW112/1727-6443-ND",
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
                ["GND",        "caps",      "CAPS_LOCK_5V"],
                ["RST_n_out",  "GND",       "nRESET_5V"],
                ["RnW_nOE",    "RnW_out",   "RnW_5V"],
                ["IRQ_n_out",  "GND",       "nIRQ_5V"],
            ]
        )
    ]
]

# buffer to generate 5V signals with rail to rail swing for clock, video, cassette
misc_buf = [
    [
        myelin_kicad_pcb.Component(
            footprint="Package_SO:SSOP-20_4.4x6.5mm_P0.65mm",  # done(v1) check + pinout
            identifier=ident,
            value="74HCT245PW",
            desc="https://www.digikey.com/product-detail/en/nexperia-usa-inc/74HCT245PW118/1727-6353-1-ND",
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
            "5V",  # misc_buf_DIR = A -> B
            "misc_buf_nOE",  # pulled up
            [
                # [A port, B port]
                ["casMO",   "CAS_MO_5V"],
                ["casOut",  "CAS_OUT_5V"],
                ["blue",    "blue_5V"],
                ["csync",   "csync_5V"],
                ["HS_n",    "nHS_5V"],
                ["green",   "green_5V"],
                ["red",     "red_5V"],
                ["clk_out", "PHI_OUT_5V_prefilter"],
            ]
        )
    ]
]

# Low pass filter on PHI_OUT_5V to bring rise time down to ~25 ns
phi_out_filter = [
    myelin_kicad_pcb.R0805("100R", "PHI_OUT_5V_prefilter", "PHI_OUT_5V", ref="R5"),
    myelin_kicad_pcb.C0805("2.7n", "PHI_OUT_5V", "GND", ref="C4"),
]

# MIC7221 comparator for CAS IN
comparator = [
    myelin_kicad_pcb.Component(
        footprint="Package_TO_SOT_SMD:SOT-23-5_HandSoldering",  # done(v1) check + pinout
        identifier="CMP",
        value="MIC7221YM5-TR",
        desc="https://www.digikey.com/product-detail/en/microchip-technology/MIC7221YM5-TR/576-2901-1-ND",
        pins=[
            Pin( 1, "OUT", "casIn"),  # open drain, pulled to 3V3
            Pin( 2, "V+",  "5V"),
            Pin( 3, "IN+", "CAS_IN_5V"),
            Pin( 4, "IN-", "CAS_IN_divider"),
            Pin( 5, "V-",  "GND"),
        ],
    ),
]

comparator_misc = [
    # MIC7221 pullup to 3V3
    myelin_kicad_pcb.R0805("1k", "casIn", "3V3", ref="R6"),
    # TODO(v2) calculate CAS_IN_divider values to make the center voltage for casIn.
    # Currently this gives 2.5V.
    myelin_kicad_pcb.R0805("1k", "GND", "CAS_IN_divider", ref="R7"),
    myelin_kicad_pcb.R0805("1k", "CAS_IN_divider", "5V", ref="R8"),
    # decoupling
    myelin_kicad_pcb.C0805("100n", "5V", "GND", ref="DC?"),
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
        Pin(1, "V", "VUSB"),
        Pin(2, "-", "USBDM"),
        Pin(3, "+", "USBDP"),
        Pin(4, "ID"),
        Pin(5, "G", "GND"),
    ],
)
usb_misc = [
    # series resistors between USB and FPGA
    myelin_kicad_pcb.R0805("68R", "USBDM", "USB_M", ref="R9"),
    myelin_kicad_pcb.R0805("68R", "USBDP", "USB_P", ref="R10"),
    # configurable pullup on D+
    myelin_kicad_pcb.R0805("1k5", "USBDP", "USB_PU", ref="R11"),
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
        Pin(    1, "DAT2",       "sd_DAT2"),
        Pin("SH1", "",           "GND",),
        Pin("SH2", "",           "GND"),
    ],
)
# Just in case -- I don't think this is needed for [micro] SD cards
sd_cmd_pullup = myelin_kicad_pcb.R0805("10k NF", "3V3", "sd_CMD_MOSI", ref="PR11")


### DEBUG SERIAL PORT / MCU

# Micro USB socket
mcu_micro_usb = myelin_kicad_pcb.Component(
    footprint="myelin-kicad:micro_usb_b_smd_molex",
    identifier="MUSB",
    value="usb",
    desc="Molex 1050170001 (Digikey WM1399CT-ND) surface mount micro USB socket with mounting holes.",
    pins=[
        Pin(1, "V", ["mcu_VUSB"]),
        Pin(2, "-", ["mcu_USBDM"]),
        Pin(3, "+", ["mcu_USBDP"]),
        Pin(4, "ID"),
        Pin(5, "G", ["GND"]),
    ],
)

# SWD header for programming and debug using a Tag-Connect TC2030-CTX
mcu_swd = myelin_kicad_pcb.Component(
    footprint="Tag-Connect_TC2030-IDC-FP_2x03_P1.27mm_Vertical",
    identifier="MSWD",
    value="swd",
    pins=[
        # Tag-Connect SWD layout: http://www.tag-connect.com/Materials/TC2030-CTX.pdf
        Pin(1, "VCC",       "3V3"),
        Pin(2, "SWDIO/TMS", "mcu_SWDIO"),
        Pin(3, "nRESET",    "mcu_RESET"),
        Pin(4, "SWCLK/TCK", "mcu_SWCLK"),
        Pin(5, "GND",       "GND"),
        Pin(6, "SWO/TDO"),  # NC because Cortex-M0 doesn't use these
    ],
)

# 0.1" header bringing out most of the microcontroller pins
mcu_header = myelin_kicad_pcb.Component(
    footprint="Connector_PinHeader_2.54mm:PinHeader_2x06_P2.54mm_Vertical",
    identifier="MSWD2",
    value="swd",
    pins=[
        Pin( 1, "SWDIO/TMS", "mcu_SWDIO"),
        Pin( 2, "VCC",       "3V3"),
        Pin( 3, "SWCLK/TCK", "mcu_SWCLK"),
        Pin( 4, "GND",       "GND"),
        Pin( 5, "nRESET",    "mcu_RESET"),
        Pin( 6, "RXD",       "mcu_debug_RXD"),
        Pin( 7, "SPI",       "mcu_MISO"),
        Pin( 8, "TXD",       "mcu_debug_TXD"),
        Pin( 9, "SPI",       "mcu_SCK"),
        Pin(10, "SPI",       "mcu_SS"),
        Pin(11, "SPI",       "mcu_MOSI"),
        Pin(12, "gpio",      "mcu_PA02"),
    ],
)

# ATSAMD11C microcontroller (tiny SO-14 version)
mcu = myelin_kicad_pcb.Component(
    footprint="Package_SO:SOIC-14_3.9x8.7mm_P1.27mm",  # done(v1) check + pinout
    identifier="MCU",
    value="atsamd11c",
    desc="https://www.digikey.com/product-detail/en/microchip-technology/ATSAMD11C14A-SSUT/ATSAMD11C14A-SSUTCT-ND",
    pins=[
        # SERCOM notes:

        # UART: any pin can be RXD, and options are TXD=0 XCK=1 or TXD=2 XCK=3
        # SPI: any pin can be MISO, and options are MOSI=0 SCK=1 SS=2 / MOSI=2 SCK=3 SS=1 /
        #                                           MOSI=3 SCK=1 SS=2 / MOSI=0 SCK=3 SS=1

        # connecting PA04/05/08/09/14/15 through to the FPGA gives us:
        # - one full SPI connection (sercom0.*) + one UART (sercom2.{0, 1})
        # - three UARTs (sercom0.{0, 1}, sercom1.{2, 3}, sercom2.{0, 1})

        # connecting PA14/15 up to some VREF pins is also an option -- they
        # should still work fine up to 20MHz or so.

        Pin( 1, "PA05",        "mcu_SCK"),       # sercom0.1/0.3: 0.1 SPI
        Pin( 2, "PA08",        "mcu_SS"),        # sercom0.2/1.2: 0.2 SPI or 1.2 TXD
        Pin( 3, "PA09",        "mcu_MISO"),      # sercom0.3/1.3: 0.3 SPI or 1.3 RXD
        Pin( 4, "PA14",        "mcu_debug_TXD"), # sercom0.0/2.0: 2.0 TXD
        Pin( 5, "PA15",        "mcu_debug_RXD"), # sercom0.1/2.1: 2.1 RXD
        Pin( 6, "PA28_nRESET", "mcu_RESET"),
        Pin( 7, "PA30_SWCLK",  "mcu_SWCLK"),
        Pin( 8, "PA31_SWDIO",  "mcu_SWDIO"),
        Pin( 9, "PA24_USBDM",  "mcu_USBDM"),
        Pin(10, "PA25_USBDP",  "mcu_USBDP"),
        Pin(11, "GND",         "GND"),
        Pin(12, "VDD",         "3V3"),
        Pin(13, "PA02",        "mcu_PA02"),      # no sercom
        Pin(14, "PA04",        "mcu_MOSI"),      # sercom0.2/0.0: 0.0 SPI
    ],
)
mcu_cap = myelin_kicad_pcb.C0805("100n", "GND", "3V3", ref="MC1")
# SAM D11 has an internal pull-up, so this is optional
mcu_reset_pullup = myelin_kicad_pcb.R0805("10k", "mcu_RESET", "3V3", ref="MR1")
# The SAM D11 datasheet says a 1k pullup on SWCLK is critical for reliability
mcu_swclk_pullup = myelin_kicad_pcb.R0805("1k", "mcu_SWCLK", "3V3", ref="MR2")

### Ground staples

staples = [
    myelin_kicad_pcb.Component(
        footprint="myelin-kicad:via_single",
        identifier="staple_single%d" % (n+1),
        value="",
        pins=[Pin(1, "GND", ["GND"])],
    )
    for n in range(53)
]


### END

myelin_kicad_pcb.dump_netlist("max10_electron_ula.net")
myelin_kicad_pcb.dump_bom("bill_of_materials.txt",
                          "readable_bill_of_materials.txt")
