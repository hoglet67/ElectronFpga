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

# CDC USB serial testing!

# Send a variety of different packets over the link and see what we get back.

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

def test_port():
    with mcu_port.Port(baud=115200) as ser:

        def echo_test(x):
            print("TEST: send %s (%d bytes long)" % (repr(x), len(x)))
            ser.write(x)
            a = read_until(ser, ";")
            print("REPORT: %s" % a.strip())

        # clear buffer
        while 1:
            a = ser.read()
            if not a: break
            print(repr(a))

        while 1:
            # bigger and bigger blocks
            msg = ''
            for x in range(10240):
                msg += chr(x & 0xff)
                echo_test(msg)

if __name__ == '__main__':
    test_port()
