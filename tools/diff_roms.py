import sys

a, b = [open(f).read() for f in sys.argv[1:3]]

for i, c in enumerate(zip(a, b)):
    ac, bc = c
    if ac != bc:
        print i, i/16, i%16, `ac`, `bc`
