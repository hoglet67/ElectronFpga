from __future__ import print_function

# Copyright 2017 Google Inc.
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

# Program a ROM image into an Arcflash board.

# TODO figure out a less CPU intensive way to do this.  We can probably use
# blocking serial comms (that would hang on the ATMEGA32U4) for Arcflash with
# its ATSAMD21.

import re
import sys
import time

import mcu_port

# Anything over 127 claims to be written but doesn't seem to make it to the other end.
# TODO trace this with tcpdump and see what's going on.
usb_block_size = 1024

def read_until(ser, match):
    resp = ''
    while True:
        r = ser.read(1024)
        if r:
            print(repr(r))
            resp += r
            if resp.find(match) != -1:
                break
            else:
                time.sleep(0.1)
    return resp

def upload(rom):
    with mcu_port.Port() as ser:
        print("\n* Port open.  Giving it a kick, and waiting for OK.")
        ser.write("\n")
        r = read_until(ser, "OK")

        print("\n* Start programming process")
        ser.write("P")  # program chip

        input_buf = ''
        done = 0
        while not done:
            input_buf += read_until(ser, "\n")
            while input_buf.find("\n") != -1:
                p = input_buf.find("\n") + 1
                line, input_buf = input_buf[:p], input_buf[p:]
                line = line.strip()
                print("parse",repr(line))
                if line == "OK":
                    print("All done!")
                    done = 1
                    break
                m = re.search(r"^([0-9a-f]+)\+([0-9a-f]+)$", line)
                if not m: continue

                start, size = int(m.group(1), 16), int(m.group(2), 16)
                print("* Sending data from %d-%d" % (start, start+size))
                blk = rom[start:start+size]
                print(`blk[:64]`)
                assert len(blk) == size, "Remote requested %d+%d but we only have up to %d" % (start, size, len(rom))
                while len(blk):
                    n = ser.write(blk[:usb_block_size])
                    if n:
                        blk = blk[n:]
                        print("wrote %d bytes" % n)
                    else:
                        time.sleep(0.01)

        ser.write("R")
        resp = ''
        while True:
            r = ser.read(1024)
            if r:
                resp += r
                print(repr(r))
                p = resp.find("DATA:")
                if p != -1 and len(resp) >= p+5 + 64*1024:
                    print("got 64k")
                    open("readback.rom", "wb").write(resp[p+5:p+5+64*1024])
                    break
            time.sleep(0.1)

        ser.write("x")
        time.sleep(0.5)
        print(ser.read(1024))

if __name__ == '__main__':
    data = open(sys.argv[1], 'rb').read()
    if len(data) < 64*1024:
        data += '\xff' * (64*1024 - len(data))
    upload(data)
    if data == open("readback.rom").read():
        print("verified")
    else:
        raise Exception("verification failed")
