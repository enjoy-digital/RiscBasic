#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright 7AG (2026) MicroFPGA UG(h)
# https://github.com/micro-FPGA/RiscBasic

"""
Run examples/i2c_detect.bas (an I2C bus scan like Linux "i2cdetect -y") with model I2C devices.

The board and device models come from check_mac_eeprom.py: SDA open-drain on GPO2 / GPI2 bit 0,
SCL on GPO2 bit 1. Several devices share the bus, and a bus monitor that never answers records
every transfer. Devices sit at the first and last scanned address, in the read-probe range
(an EEPROM at 0x50) and in the quick-write range.

Checks, with the devices and with an empty bus:
- the printed map is the i2cdetect layout, with the devices and nothing else
- every address 0x03..0x77 is probed once, in order, with a read for 0x30-0x37 and 0x50-0x5F
  and a write (address only) elsewhere, each probe ending with a STOP
- the bus is idle at the end

If the example is not there (flat layout), the check is skipped.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import check_mac_eeprom as mac        # noqa: E402  (also puts the compiler on the path)
import riscbasic                      # noqa: E402
from rbsim import MASK                # noqa: E402

EXAMPLE = os.path.join(mac.ROOT, 'examples', 'i2c_detect.bas')
DEVICES = (0x03, 0x1A, 0x50, 0x68, 0x77)
STEPS = 20_000_000


class Bus(mac.Board):
    """The MAC EEPROM board with several devices; self.dev (address None) only listens."""

    def __init__(self, image, ram, addresses):
        super().__init__(image, ram, None)
        self.devs = [mac.I2CDevice(a) for a in addresses]

    def lines(self):
        sda = self.gpo2 & 1
        for d in [self.dev] + getattr(self, 'devs', []):
            sda &= d.sda
        return self.gpo2 >> 1 & 1, sda

    def store(self, addr, size, val):
        if addr & MASK != mac.IOM + 0x14:
            return super().store(addr, size, val)
        before = self.lines()
        self.gpo2 = val
        after = self.lines()
        if after != before:
            self.changes.append((self.steps,) + after)
            for d in [self.dev] + self.devs:
                d.change(self.steps, *before, *after)


def read_probe(a):
    return 0x30 <= a <= 0x37 or 0x50 <= a <= 0x5F


def expected_map(devices):
    out = ['     0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F\r\n']
    for row in range(8):
        cells = []
        for col in range(16):
            a = row * 16 + col
            cells.append('   ' if a < 3 or a > 0x77 else ' %02X' % a if a in devices else ' --')
        out.append('%02X:%s\r\n' % (row * 16, ''.join(cells)))
    out.append('%d device(s) found\r\n' % len(devices))
    return ''.join(out)


def check(c, devices, label):
    s = Bus(c.binary(), (c.ram_base, c.ram_size), devices)
    try:
        halted = s.run(max_steps=STEPS)
    except RuntimeError as e:
        return [('%s: runs without a fault: %s' % (label, e), False)]
    out = ''.join(s.uart)
    events = [t for _, t in s.dev.events]
    probed = [int(t.split()[1], 16) for t in events if t.startswith('addr ')]
    want = [(a << 1) | read_probe(a) for a in range(0x03, 0x78)]
    starts = sum(1 for t in events if t in ('START', 'RSTART'))
    stops = events.count('STOP')
    answered = True
    for d in s.devs:                      # each device: one ACKed address; a read probe ends with NACK
        ev = [t for _, t in d.events]
        acks = [t for t in ev if t.startswith('addr ') and t.endswith(' ACK')]
        ok = acks == ['addr %02X ACK' % ((d.address << 1) | read_probe(d.address))]
        if read_probe(d.address):
            ok = ok and 'master NACK' in ev and 'master ACK' not in ev
        answered = answered and ok
    return [
        ('%s: runs to the end' % label, halted),
        ('%s: address map as i2cdetect prints it' % label,
         out.endswith(expected_map(devices)) and out.startswith('RiscBasic i2cdetect\r\n')),
        ('%s: 0x03..0x77 probed once each, read for 0x30-0x37 / 0x50-0x5F, write elsewhere' % label,
         probed == want),
        ('%s: every probe ends with a STOP (%d STARTs, %d STOPs)' % (label, starts, stops),
         starts == len(want) and stops == len(want) + 1),        # + the STOP of I2CBusClear
        ('%s: bus idle at the end' % label, s.lines() == (1, 1)),
        ('%s: each device answered its probe once; the read probe ends with NACK' % label, answered),
    ]


def run():
    c = riscbasic.Compiler('i2c_detect.bas')
    c.src_dir = os.path.dirname(EXAMPLE)
    c.src_path = EXAMPLE
    try:
        with open(EXAMPLE, encoding='utf-8') as f:
            c.compile(f.read())
    except riscbasic.RBError as e:
        where = '%s:%s' % (e.file or os.path.basename(EXAMPLE), e.line)
        return [('compiles: %s: %s' % (where, e), False)]
    return check(c, DEVICES, 'devices at %s' % ' '.join('%02X' % a for a in DEVICES)) + \
        check(c, (), 'empty bus')


def main():
    if not os.path.isfile(EXAMPLE):
        print('skip i2cdetect example: %s not found' % os.path.relpath(EXAMPLE, mac.ROOT))
        return 0
    failed = 0
    for text, ok in run():
        print('%s i2cdetect example: %s' % ('ok  ' if ok else 'FAIL', text))
        failed += not ok
    return failed


if __name__ == '__main__':
    n = main()
    print('all i2cdetect checks passed' if n == 0 else '%d i2cdetect check(s) failed' % n)
    sys.exit(1 if n else 0)
