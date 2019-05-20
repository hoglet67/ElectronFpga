#!/usr/bin/python

# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ---------------------
# rgb_to_vga
# ---------------------

# by Phillip Pearson

# A sync separator board, to allow connecting a VGA monitor to the RGB output
# of an Electron with the Ultimate Upgrade (http://myelin.nz/elkula).


# VGA devices expect 0-0.7V into 75 ohms on the R/G/B lines, i.e. they sink
# ~9.3mA at max brightness.  Ideally we would use a video buffer like a
# THS7316DR -- http://www.ti.com/lit/ds/symlink/ths7316.pdf -- which has the
# correct output impedance, but 5V CMOS with 460R in series, or 3.3V with 270R
# in series, will work.

# The CSYNC signal needs to be split into HSYNC and VSYNC; the EL1883 does
# this.  These are terminated in the display device with 2kR to +5V, so normal
# TTL outputs are OK; I've seen series termination of 82.5R used with 3.3V
# CMOS outputs.

# See VESA PND spec: http://web.archive.org/web/20030704041337/www.vesa.org/public/PnD/pnd.pdf


# Early Elks just passed the ULA pins directly out to the RGB socket; later
# ones buffer with a 74LS08 and 68R.  The Ultimate Upgrade buffers everything
# with a 74HCT245, so either you get a 5V CMOS signal, or a 74LS08 (~1250R
# output impedance) + 68R.

# In this case we're just handling 1-bit signals, so it should be sufficient
# to buffer R/G/B with a 74HCT125 then 480R.

# The EL1883 needs a video input between 0.5-2V p-p, so we buffer CSYNC then
# pass it through a 1:5 resistor divider to give a 1V signal.

# The EL1883's HSYNC and VSYNC outputs are not specified to be able to pull
# 2kR down to 0.5V, so we buffer those too.


PROJECT_NAME = "rgb_to_vga"


import sys, os
here = os.path.dirname(sys.argv[0])
sys.path.insert(0, os.path.join(here, "../../third_party/myelin-kicad.pretty"))
import myelin_kicad_pcb
Pin = myelin_kicad_pcb.Pin


caps = [
    # bulk
    myelin_kicad_pcb.C0805("10u", "GND", "5V", ref="C1"),
    # 74HCT245
    myelin_kicad_pcb.C0805("100n", "GND", "5V", ref="C2"),
    # EL1883
    myelin_kicad_pcb.C0805("100n", "GND", "5V", ref="C3"),
    myelin_kicad_pcb.C0805("100n", "CS_divided", "CS_coupled", ref="C4"),
    myelin_kicad_pcb.C0805("100n", "RSET", "GND", ref="C5"),
]

resistors = [
    # Some very light termination on the inputs
    myelin_kicad_pcb.R0805("10k NF", "R_in", "GND", ref="R1"),
    myelin_kicad_pcb.R0805("10k NF", "G_in", "GND", ref="R2"),
    myelin_kicad_pcb.R0805("10k NF", "B_in", "GND", ref="R3"),
    myelin_kicad_pcb.R0805("10k NF", "CS_in", "GND", ref="R4"),
    # Divide buffered sync down for EL1883
    myelin_kicad_pcb.R0805("4k TBD", "CS_buf", "CS_divided", ref="R5"),
    myelin_kicad_pcb.R0805("1k TBD", "CS_divided", "GND", ref="R6"),  # TODO need 1:4 ratio, find better values
    # Output resistors for R/G/B (remote temination is 75R to GND)
    myelin_kicad_pcb.R0805("480R", "R_buf", "R_out", ref="R7"),
    myelin_kicad_pcb.R0805("480R", "G_buf", "G_out", ref="R8"),
    myelin_kicad_pcb.R0805("480R", "B_buf", "B_out", ref="R9"),
    # Output resistors for HS/VS (remote termination is 2kR to +5V)
    myelin_kicad_pcb.R0805("100R", "HS_buf", "HS_out", ref="R10"),
    myelin_kicad_pcb.R0805("100R", "VS_buf", "VS_out", ref="R11"),
    # RSET on EL1883
    myelin_kicad_pcb.R0805("681k 1%", "RSET", "GND", ref="R12"),
]

signal_buf = [
    myelin_kicad_pcb.Component(
        footprint="Package_SO:SSOP-20_4.4x6.5mm_P0.65mm",
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
    )
    for power, ident, DIR, nOE, conn in [
        (
            "5V",
            "BUF",
            "5V",  # DIR = A -> B
            "GND", # always active
            [
                # [A port, B port]
                ["R_in", "R_buf"],   # from input cable
                ["G_in", "G_buf"],   # from input cable
                ["B_in", "B_buf"],   # from input cable
                ["GND", ""],         # spare
                ["VS", "VS_buf"],    # from EL1883
                ["HS", "HS_buf"],    # from EL1883
                ["GND", ""],         # spare
                ["CS_in", "CS_buf"], # from input cable
            ]
        )
    ]
]

el1883 = [
    myelin_kicad_pcb.Component(
        # 8-SOIC (0.154", 3.90mm Width)
        footprint="Package_SO:SOIC-8_3.9x4.9mm_P1.27mm",
        identifier="SYNC",
        value="EL1883",
        pins=[
            Pin( 1, "CSYNC_out"),
            Pin( 2, "COMPOSITE_in",    "CS_coupled"),
            Pin( 3, "VSYNC_out",       "VS"),
            Pin( 4, "GND",             "GND"),
            Pin( 5, "BURST/PORCH_out"),
            Pin( 6, "RSET",            "RSET"),
            Pin( 7, "HSYNC_out",       "HS"),
            Pin( 8, "VDD",             "5V"),
        ],
    )
]

rgb_in =  [
    myelin_kicad_pcb.Component(
        footprint="Connector_PinHeader_2.54mm:PinHeader_1x06_P2.54mm_Vertical",
        identifier="RGB",
        value="RGB",
        pins=[
            Pin(1, "5V", "5V"),
            Pin(2, "GND", "GND"),
            Pin(3, "R", "R_in"),
            Pin(4, "G", "G_in"),
            Pin(5, "B", "B_in"),
            Pin(6, "CS", "CS_in"),
        ],
    )
]

vga_out = [
    myelin_kicad_pcb.Component(
        footprint="Connector_Dsub:DSUB-15-HD_Female_Horizontal_P2.29x1.98mm_EdgePinOffset3.03mm_Housed_MountingHolesOffset4.94mm",
        identifier="VGA",
        value="VGA",
        pins=[
            Pin( 1, "R", "R_out"),
            Pin( 2, "G", "G_out"),
            Pin( 3, "B", "B_out"),
            Pin( 4, "ID2/RES"),
            Pin( 5, "HS_GND", "GND"),
            Pin( 6, "RED_RTN", "GND"),
            Pin( 7, "GREEN_RTN", "GND"),
            Pin( 8, "BLUE_RTN", "GND"),
            Pin( 9, "KEY/PWR"),
            Pin(10, "VS_GND", "GND"),
            Pin(11, "ID0/RES"),
            Pin(12, "ID1/SDA"),
            Pin(13, "HS", "HS_out"),
            Pin(14, "VS", "VS_out"),
            Pin(15, "ID3/SCL"),
        ],
    )
]

myelin_kicad_pcb.dump_netlist("%s.net" % PROJECT_NAME)
myelin_kicad_pcb.dump_bom("bill_of_materials.txt",
                          "readable_bill_of_materials.txt")
