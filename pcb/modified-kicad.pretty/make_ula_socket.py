import re

f = open("PLCC-68_THT-Socket-Electron-ULA.kicad_mod", "w")

for line in open("PLCC-68_THT-Socket.kicad_mod"):
    line = line.replace("thru_hole rect", "thru_hole circle")
    m = re.search(r"^(\s*\(pad )(\d+)( .*)$", line)
    if m:
        pad_id = int(m.group(2)) - 1
        pad_id = (pad_id - 9 + 68) % 68
        line = m.group(1) + str(pad_id + 1) + m.group(3) + "\n"
        if pad_id == 0:
            line = line.replace("thru_hole circle", "thru_hole rect")
    f.write(line)
