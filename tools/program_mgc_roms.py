import os

start_addr = 4 * 1024 * 1024
romsize = 16 * 1024

def fn(romid):
    # I extracted the roms in a different order...
    translated_romid = ((romid & 0xfe) >> 1) | (128 if (romid & 1) else 0)
    return '../../../electron/elkjs/elkjs/mgc/mgc_%d.bin' % translated_romid

print("programming 256 mgc roms at %d" % start_addr)

for romid in range(256):
    romfn = fn(romid)
    romstart = start_addr + romid * romsize
    print("- program %s in as rom id %d" % (romfn, romid))
    if os.system("python program_flash.py %s %d %d" % (romfn, romstart, romsize)):
        break
