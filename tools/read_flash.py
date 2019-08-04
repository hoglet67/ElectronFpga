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

usb_block_size = 63

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

def download():
    with mcu_port.Port() as ser:
        print("\n* Port open.  Giving it a kick, and waiting for OK.")
        ser.write("\n")
        r = read_until(ser, "OK")

        read_from = 0
        read_length = 16384 * 16

        ser.write("r%d+%d\n" % (read_from, read_length))
        resp = ''
        while True:
            r = ser.read(1024)
            if r:
                resp += r
                print(repr(r))
                p = resp.find("DATA:")
                if p != -1 and len(resp) >= p+5 + read_length:
                    print("got %d bytes" % read_length)
                    open("download.rom", "wb").write(resp[p+5:p+5+read_length])
                    break
            time.sleep(0.1)

        ser.write("x")
        time.sleep(0.5)
        print(ser.read(1024))

if __name__ == '__main__':
    download()
