from __future__ import print_function
# Pad a rom out to 16kB with &FF bytes

import sys

args = sys.argv[1:]
if len(args) == 1:
    fn, = args
    out_fn = "%s.padded" % fn
else:
    fn, out_fn = args

data = open(fn).read()

print("padding %s (%d B) to %s (16384 B)" % (fn, len(data), out_fn))

of = open(out_fn, 'w')
of.write(data)
of.write('\xff' * (16384 - len(data)))
