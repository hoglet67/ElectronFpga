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

import argparse
import re
import sys
import time

import mcu_port

# Arduino USB serial ports seem to crash out if you send more than 63 (or sometimes 127)
# bytes at a time.  The ASF version works fine with full blocks.
usb_block_size = 1024 * 1024

# Flash sector size
sector_size = 4096

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

def parse_address(addr):
    # pNN = page NN
    m = re.search(r"^p(\d+)$", addr)
    if m:
        return int(m.group(1)) * 16384
    # NNk = NN kB
    m = re.search(r"^(\d+)k$", addr)
    if m:
        return int(m.group(1)) * 1024
    # 0xNN = hex
    m = re.search(r"^0x(.*?)$", addr)
    if m:
        return int(m.group(1), 16)
    return int(addr)

def upload(rom, start_addr, length, program=True, verify=True, port=None):
    assert not (start_addr % sector_size), "start_addr must be a multiple of %s" % sector_size
    assert not (length % sector_size), "length must be a multiple of %s" % sector_size

    with mcu_port.Port(port=port) as ser:
        print("\n* Port open.  Giving it a kick, and waiting for OK.")
        ser.write("\n")
        r = read_until(ser, "OK")

        program_start_time = time.time()

        if program:
            print("\n* Start programming process")
            cmd = "p%d+%d\n" % (start_addr, length)
            print("programming command: %s" % cmd)
            ser.write(cmd)  # program chip

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
                    print("* Sending data from %d-%d (%d-%d in our buffer)" % (start, start+size, start-start_addr, start-start_addr+size))
                    blk = rom[start-start_addr:start-start_addr+size]
                    print("First 64 bytes: %s" % `blk[:64]`)
                    assert len(blk) == size, "Remote requested %d+%d but we only have up to %d" % (start, size, len(rom))
                    while len(blk):
                        n = ser.write(blk[:usb_block_size])
                        if n:
                            blk = blk[n:]
                            print("wrote %d bytes" % n)
                        else:
                            time.sleep(0.01)

        program_end_time = time.time()

        if verify:
            print("read back")
            cmd = "r%d+%d\n" % (start_addr, length)
            print("command: %s" % cmd)
            ser.write(cmd)  # program chip
            resp = ''
            while True:
                r = ser.read(1024)
                if r:
                    resp += r
                    print(repr(r))
                    p = resp.find("DATA:")
                    if p != -1 and len(resp) >= p+5 + length:
                        print("got %d bytes" % length)
                        open("readback.rom", "wb").write(resp[p+5:p+5+length])
                        break
                time.sleep(0.1)

        readback_end_time = time.time()

        ser.write("x")
        time.sleep(0.5)
        print(ser.read(1024))

        print("programming took %.1f s; readback took %.1f s" % (
            program_end_time - program_start_time,
            readback_end_time - program_end_time,
        ))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Program flash on a UEU board.')
    parser.add_argument('--port', type=str, help='Serial port to use')
    parser.add_argument('rest', nargs=argparse.REMAINDER)
    args = parser.parse_args()

    filename, start_addr, length = args.rest
    start_addr = parse_address(start_addr)
    length = parse_address(length)

    data = open(filename, 'rb').read()
    assert len(data) <= length, "file %s is %d bytes long and we only want to program %d" % (filename, len(data), length)
    if len(data) < length:
        pad = length - len(data)
        print("padding data with %d FF bytes" % pad)
        data += '\xff' * pad

    upload(data, start_addr, len(data), program=True, verify=True, port=args.port)

    if data == open("readback.rom").read():
        print("verified")
    else:
        raise Exception("verification failed")
