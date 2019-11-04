from __future__ import print_function

import os, sys
import program_flash

if sys.version_info < (3, 0):
    print("WARNING: This script is no longer tested under Python 2.  "
          "Running under Python 3 is highly recommended.")

HERE = os.path.abspath(os.path.split(sys.argv[0])[0])

start_addr = 4 * 1024 * 1024
romsize = 16 * 1024

# My MGC dumper program sets page_latch from 0-127 and saves the two
# ROM banks as page_latch*2 and page_latch*2+1.  Actually it should
# have saved them as page_latch and page_latch+128.

# As such to translate from a page latch value to a filename, use
# (bank & 0x7f) * 2 + (bank & 128 ? 1 : 0)

# MGC quirk: the bank ID is inverted for single-bank roms... so
# 3d dotty (page latch 89, RBS 0) is actually in bank 89+128 and file 89*2+1=179
def translate(romid):
    bank = ((romid & 0x7f) << 1) | (1 if (romid & 128) else 0)
    print("translate romid %d (%02x) -> %d (%02x)" % (romid, romid, bank, bank))
    return bank
assert translate(0) == 0
assert translate(1) == 2 # arcadians
assert translate(1+128) == 3 # arcadians
assert translate(72) == 144
assert translate(72+128) == 145
assert translate(89+128) == 179 # 3d dotty
assert translate(90+128) == 181
assert translate(91+128) == 183 # alien dropout
assert translate(217-128) == 178 # hopper
assert translate(218-128) == 180 # hunchback
assert translate(219-128) == 182 # jet power jack

def fn(romid):
    # I extracted the roms in a different order...
    translated_romid = translate(romid)
    return '%s/../../../electron/elkjs/elkjs/mgc/mgc_%d.bin' % (HERE, translated_romid)

print("programming 256 mgc roms at %d" % start_addr)

for romid in range(256):
    romfn = fn(romid)
    romstart = start_addr + romid * romsize
    print("- program %s in as rom id %d" % (romfn, romid))
    program_flash.upload(open(romfn, "rb").read(),
                         romstart,
                         romsize,
                         program=True,
                         )
