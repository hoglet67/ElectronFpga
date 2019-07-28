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

def read_timeout(ser, bytes, secs):
    now = time.time()
    buf = ''
    while 1:
        data = ser.read(bytes - len(buf))
        buf += data
        if len(buf) >= bytes:
            break
        if time.time() - now > secs:
            #print("timeout with %d bytes" % len(buf))
            break
    return buf

def test_port():
    with mcu_port.Port(baud=115200) as ser:

        def echo_test(x):
            print("send %s (%d bytes long)" % (repr(x), len(x)))
            ser.write(x)
            a = read_timeout(ser, len(x), 0.5)
            print("got %s" % repr(a))
            assert a == x

        # double check we're in the right mode
        ser.write('x')
        time.sleep(0.5)
        a = ser.read()
        print(a)
        assert "Unlock" not in a

        # clear buffer
        while 1:
            a = ser.read()
            if not a: break
            print(repr(a))

        while 1:
            # test writing a bunch of single bytes
            for x in range(256):
                echo_test(chr(x))

            # test writing blocks of bytes
            for x in range(256):
                echo_test("this is a test")

            # bigger and bigger blocks now
            msg = ''
            for x in range(10240):
                msg += chr(x & 0xff)
                echo_test(msg)

if __name__ == '__main__':
    test_port()
