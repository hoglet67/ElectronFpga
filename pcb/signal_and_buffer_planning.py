"""

Buffer planning time!

I've been poring over the schematic in the EAUG Appendix F and thinking through some possibilities, and I think I've come up with a decent plan to buffer all the signals correctly.

The idea is to use:

- 2 x 74LVTH162245: one for the address bus (selectable direction), and one for the data bus (selectable direction) plus KBD0-3, CLOCK IN, nNMI, nIRQ, RnW (input only).
- 1 x diode + resistor: to level shift nRST (input)
- 1 x MIC7221 comparator + pullup resistor: to level shift CAS IN (which has a lower voltage range than TTL)
- 1 x 74HCT125: to drive CAPS LOCK, nRST, nIRQ, RnW, all of which either need a full 0-5V swing or are open collector.
- 1 x 74HCT245: to drive PHI OUT, CAS MO, CAS OUT, and the five video signals: nHS, nCSYNC, RED, GREEN, BLUE
- 1 x WM8524 audio DAC: to drive SOUND OUT.

This should let the board act as a normal ULA, but also drive all the CPU
signals, which would make it possible to remove the 6502 from an Electron and
implement it inside the FPGA as well, e.g. if you want to make a hybrid
Electron-Master.  Plus nicer sound with the DAC, for BeebSid support.  Jumpers
could be fitted to bypass the MIC7221 and WM8524 for cost reduction if
desired.

Sound reasonable?

todo buffer video, dont output nmi

hct125 - 5x6.4mm 0.65 pitch
hct245 - 6.5x6.5 0.65 pitch or 7.2x7.75mm, dhvqfn 0.5 pitch
so 1 x 245 is def smaller than 2 x 125


"""


# Investigate 74lvt(h)162245... looks like BGA version is $1 more than tssop.

5V TTL/CMOS OUTPUTS

# Output summary:
# - 74hct125 for CAPS_LOCK, PHI_OUT, CAS_MO, CAS_OUT
# - 74hct125 for four OC outputs to drive pins listed under I/O below
# - WM8524 DAC for audio

        Pin(63, "CAPS_LOCK", "CAPS_LOCK"),  # O (OC), drives caps LED via 470R (~6mA)

        # PHI_OUT is a 5V signal with CMOS levels.
        Pin(60, "PHI_OUT", "PHI_OUT_5V"),  # O (needs CMOS 5V buffer)

        # Cassettte
        Pin(64, "CAS_MO",  "CAS_MO_5V"),   # O (buf, 3V3 OK) - motor relay (2mA)
        Pin(50, "CAS_OUT", "CAS_OUT_5V"),  # O (buf, 3V3 OK)

        # Audio - connect a WM8524 DAC (and a jumper to just hook the 3.3V output straight through)
        Pin(62, "SOUND_OUT", "SOUND_OUT_5V"),  # O, goes straight to amplifier so we could add in a better DAC

DIRECT OUTPUTS

        # nROM is the ROM chip select, so doesn't need a buffer.
        Pin(61, "nROM", "nROM"),    # O (direct output from FPGA)

        # Video: direct from FPGA ok as all go straight to buffers
        Pin(67, "nHS",    "nHS_5V"),     # O (direct from FPGA) - horizontal sync
        Pin( 3, "RED",    "RED_5V"),     # O (direct from FPGA)
        Pin( 4, "GREEN",  "GREEN_5V"),   # O (direct from FPGA)
        Pin(66, "BLUE",   "BLUE_5V"),    # O (direct from FPGA)
        Pin(65, "nCSYNC", "nCSYNC_5V"),  # O (direct from FPGA) - composite sync

5V TTL INPUTS

# Input summary:
# - 2 x 74lvth162245; one for 16xA, one for 8xD + KBD* + CLOCK_IN + nNMI + nIRQ + RnW
# - Diode + pullup for nRST
# - MIC7221 + voltage divider + pullup for CAS_IN

# 5 ordinary buffered inputs
# 1 one that might need a comparator

        # Keyboard: KBD0-3 are 5V inputs, driven by CPU address lines.
        # CAPS_LOCK is an OC output (low speed).
        Pin(27, "KBD0",      "KBD0_5V"),  # I (buf)
        Pin(28, "KBD1",      "KBD1_5V"),  # I (buf)
        Pin(31, "KBD2",      "KBD2_5V"),  # I (buf)
        Pin(32, "KBD3",      "KBD3_5V"),  # I (buf)

        # Clocks and ground
        Pin(49, "CLOCK_IN", "CLK_16MHZ_5V"),  # I (buf)

        # Cassettte
        # Buffer this with a MIC7221 (open drain) http://ww1.microchip.com/downloads/en/DeviceDoc/mic7211.pdf
        # and a pullup resistor to 3V3.
        Pin(59, "CAS_IN",  "CAS_IN_5V"),   # I (buf via MIC7221+R)

5V SPECIAL INPUT/OUTPUT

# 16 + 8 + 3 ordinary buffers, 1 slow reset buffer
# 4 OC drivers

        # nRST is apparently an input, but being able to drive it seems sensible.
        Pin(58, "nRST", "nRESET"),  # OC I (buf via diode+R + OC)

        # nNMI is an input to the ULA and CPU.
        Pin(57, "nNMI",    "nNMI_5V"),     # OC I (buf)
        # nIRQ is an output from the ULA, input to the CPU.
        Pin(30, "nIRQ",    "nIRQ_5V"),     # OC O (buf + OC)
        # RnW is an input to the ULA, output from the CPU.
        Pin(46, "RnW",     "RnW_5V"),      # I (buf, reversible)

5V LOGIC INPUT/OUTPUT

        # Address bus: input; use 74lvth162245 with A-port (with 22R series
        # resistors) connected to Electron.
        Pin( 5, "A0",  "A0_5V"),   # I (buf, reversible)
        Pin( 1, "A1",  "A1_5V"),   # I (buf, reversible)
        Pin(12, "A2",  "A2_5V"),   # I (buf, reversible)
        Pin(24, "A3",  "A3_5V"),   # I (buf, reversible)
        Pin(21, "A4",  "A4_5V"),   # I (buf, reversible)
        Pin(20, "A5",  "A5_5V"),   # I (buf, reversible)
        Pin(17, "A6",  "A6_5V"),   # I (buf, reversible)
        Pin(15, "A7",  "A7_5V"),   # I (buf, reversible)
        Pin( 2, "A8",  "A8_5V"),   # I (buf, reversible)
        Pin(26, "A9",  "A9_5V"),   # I (buf, reversible)
        Pin(25, "A10", "A10_5V"),  # I (buf, reversible)
        Pin(23, "A11", "A11_5V"),  # I (buf, reversible)
        Pin(13, "A12", "A12_5V"),  # I (buf, reversible)
        Pin(14, "A13", "A13_5V"),  # I (buf, reversible)
        Pin(10, "A14", "A14_5V"),  # I (buf, reversible)
        Pin(56, "A15", "A15_5V"),  # I (buf, reversible)

        # Data bus: input/output
        Pin(33, "PD0", "PD0_5V"),  # IO
        Pin(35, "PD1", "PD1_5V"),  # IO
        Pin(36, "PD2", "PD2_5V"),  # IO
        Pin(38, "PD3", "PD3_5V"),  # IO
        Pin(39, "PD4", "PD4_5V"),  # IO
        Pin(41, "PD5", "PD5_5V"),  # IO
        Pin(42, "PD6", "PD6_5V"),  # IO
        Pin(45, "PD7", "PD7_5V"),  # IO
