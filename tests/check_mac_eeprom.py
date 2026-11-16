#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright 7AG (2026) MicroFPGA UG(h)
# https://github.com/micro-FPGA/RiscBasic

"""
Run examples/MAC_EEPROM.bas (bit-banged I2C through READ / WRITE, lib/i2c_bitbang.bas) with a
model I2C EEPROM.

The board model is the MicroBlaze V MCS IO Module: UART TX at +4 (status at +8 never full),
SDA on GPO2 / GPI2 bit 0 and SCL on GPO2 bit 1. SDA is open-drain: the line is low when the
CPU or the device pulls it low. The device decodes START, STOP and the bits from the line
changes, answers at the 7-bit address 0x52 and holds 0x5A in register 0xF0.

Checks, with the device present and without it:
- the transaction on the bus: START, address, register, repeated START, read address,
  one byte read, master NACK, STOP (without the device: address NACKs only)
- the program's output ("Value read 5A" / "No ACK from the device")
- the bus is idle (SCL and SDA high) at the end
- I2C standard-mode timing at the program's CLOCK and CPI: SCL low >= 4.7 us, high >= 4.0 us,
  START hold >= 4.0 us, repeated START setup >= 4.7 us, STOP setup >= 4.0 us

If the example is not there (flat layout), the check is skipped.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, 'source') if os.path.isfile(os.path.join(ROOT, 'source', 'riscbasic.py')) else ROOT
sys.path.insert(0, SRC)

import riscbasic                      # noqa: E402
from rbsim import Sim, MASK           # noqa: E402

EXAMPLE = os.path.join(ROOT, 'examples', 'MAC_EEPROM.bas')
IOM = 0x80000000
REGS = [(r * 0x47 + 0x15) & 0xFF for r in range(256)]   # mixed top bits; reads wrap at 0xFF
STEPS = 10_000_000


class I2CDevice:
    """I2C target driven by the line changes. sda = 1 when it releases SDA."""

    def __init__(self, address):
        self.address = address
        self.sda = 1
        self.events = []              # (step, text)
        self.state = 'idle'
        self.bits = []
        self.reg = self.nbytes = self.out = self.sent = 0

    def change(self, step, scl0, sda0, scl, sda):
        ev = lambda text: self.events.append((step, text))
        if scl0 and scl and sda0 != sda:                    # SDA changes while SCL is high
            if sda == 0:
                ev('START' if self.state in ('idle', 'stopped') else 'RSTART')
                self.state, self.bits, self.nbytes, self.sda = 'addr', [], 0, 1
            else:
                ev('STOP')
                self.state, self.sda = 'stopped', 1
        elif not scl0 and scl:                              # rising SCL: sample
            if self.state in ('addr', 'wdata', 'mack'):
                self.bits.append(sda)
        elif scl0 and not scl:                              # falling SCL: next bit
            self._falling(ev)

    def _falling(self, ev):
        st = self.state
        if st in ('addr', 'wdata') and len(self.bits) == 8:
            b = int(''.join(map(str, self.bits)), 2)
            self.bits = []
            if st == 'addr':
                ok = b >> 1 == self.address
                ev('addr %02X %s' % (b, 'ACK' if ok else 'NACK'))
                self.state = ('ack_rd' if b & 1 else 'ack_wr') if ok else 'ignore'
            else:
                ok = True
                if self.nbytes == 0:
                    self.reg = b
                self.nbytes += 1
                ev('write %02X ACK' % b)
                self.state = 'ack_wr'
            self.sda = 0 if ok else 1                       # our ACK during the 9th clock
        elif st == 'ack_wr':
            self.sda, self.state = 1, 'wdata'
        elif st == 'ack_rd' or (st == 'mack' and self.bits == [0]):
            if st == 'mack':
                ev('master ACK')
            self.out = REGS[self.reg]
            self.reg = (self.reg + 1) & 0xFF
            self.sda, self.sent, self.state, self.bits = self.out >> 7 & 1, 1, 'rdata', []
        elif st == 'rdata':
            if self.sent < 8:
                self.sda = self.out >> (7 - self.sent) & 1
                self.sent += 1
            else:
                ev('read %02X' % self.out)
                self.sda, self.state, self.bits = 1, 'mack', []
        elif st == 'mack':
            ev('master NACK')
            self.state, self.bits = 'done', []
        elif st == 'ignore':
            self.sda = 1


class Board(Sim):
    def __init__(self, image, ram, address):
        super().__init__(image, 0, ram[0], ram[1])
        self.gpo2 = 0
        self.dev = I2CDevice(address)
        self.uart = []
        self.changes = []             # (step, scl, sda) after each change of the lines

    def lines(self):
        return self.gpo2 >> 1 & 1, self.gpo2 & self.dev.sda & 1

    def load(self, addr, size, signed):
        a = addr & MASK
        if IOM <= a < IOM + 0x100:
            v = {0x08: 0, 0x24: self.lines()[1]}.get(a - IOM)
            if v is None:
                raise RuntimeError('load from IO Module offset 0x%02X at pc 0x%X' % (a - IOM, self.pc))
            return v
        return super().load(addr, size, signed)

    def store(self, addr, size, val):
        a = addr & MASK
        if not IOM <= a < IOM + 0x100:
            return super().store(addr, size, val)
        o = a - IOM
        if o == 0x04:
            self.uart.append(chr(val & 0xFF))
        elif o == 0x14:
            before = self.lines()
            self.gpo2 = val
            after = self.lines()
            if after != before:
                self.changes.append((self.steps,) + after)
                self.dev.change(self.steps, *before, *after)
        elif o != 0x10:                                     # GPO1: LEDs
            raise RuntimeError('store to IO Module offset 0x%02X at pc 0x%X' % (o, self.pc))


def timing(s, us):
    """Shortest SCL low / high and START / STOP times, in microseconds."""
    scl = [(st, c) for st, c, _ in s.changes]
    scl = [x for i, x in enumerate(scl) if i == 0 or x[1] != scl[i - 1][1]]
    rises = [st for st, c in scl if c == 1]
    falls = [st for st, c in scl if c == 0]
    high, low = [], []
    for r in rises:
        f = next((f for f in falls if f > r), None)
        if f is not None:
            high.append(f - r)
            r2 = next((x for x in rises if x > f), None)
            if r2 is not None:
                low.append(r2 - f)
    hold, setup_rs, setup_stop = [], [], []
    for step, text in s.dev.events:
        if text in ('START', 'RSTART'):
            f = next((f for f in falls if f > step), None)
            if f is not None:
                hold.append(f - step)
        if text == 'RSTART':
            setup_rs.append(step - max(r for r in rises if r < step))
        if text == 'STOP':
            setup_stop.append(step - max(r for r in rises if r < step))
    m = lambda v: min(v) * us if v else None
    return m(low), m(high), m(hold), m(setup_rs), m(setup_stop)


def run_case(c, address):
    s = Board(c.binary(), (c.ram_base, c.ram_size), address)
    halted = s.run(max_steps=STEPS)
    return s, halted


def run():
    """Build and run the example; returns a list of (description, ok)."""
    c = riscbasic.Compiler('MAC_EEPROM.bas')
    c.src_dir = os.path.dirname(EXAMPLE)
    c.src_path = EXAMPLE
    try:
        with open(EXAMPLE, encoding='utf-8') as f:
            c.compile(f.read())
    except riscbasic.RBError as e:
        where = '%s:%s' % (e.file or os.path.basename(EXAMPLE), e.line)
        return [('compiles: %s: %s' % (where, e), False)]
    us = c.cpi * 1e6 / c.clock                    # microseconds per instruction
    results = []
    try:
        s, halted = run_case(c, 0x52)
        n, nhalted = run_case(c, 0x50)
    except RuntimeError as e:
        return [('runs without a fault: %s' % e, False)]
    seq = [t for _, t in s.dev.events]
    out = ''.join(s.uart)
    head = seq[:5]
    reads = [t for t in seq[5:] if t.startswith('read ')]
    acks = [t for t in seq[5:] if t.startswith('master ')]
    reg = int(head[2].split()[1], 16) if len(head) > 2 and head[2].startswith('write ') else None
    wanted = ['read %02X' % REGS[(reg + k) & 0xFF] for k in range(len(reads))] if reg is not None else None
    results += [
        ('runs to the end', halted and nhalted),
        ('bus transaction: %s' % ', '.join(seq), True),
        ('device address and register written, then a repeated START for reading',
         reg is not None and head == ['START', 'addr A4 ACK', 'write %02X ACK' % reg, 'RSTART', 'addr A5 ACK']),
        ('bytes read are the device registers from the one written (%d bytes)' % len(reads),
         bool(reads) and reads == wanted),
        ('master ACKs every byte but the last, NACKs the last (else the device keeps SDA)',
         bool(acks) and acks == ['master ACK'] * (len(acks) - 1) + ['master NACK'] and len(acks) == len(reads)),
        ('ends with STOP, bus idle (SCL and SDA high)', seq[-1:] == ['STOP'] and s.lines() == (1, 1)),
        ('output shows the bytes read, no "No ACK"',
         'No ACK' not in out and ''.join('%02X' % int(r.split()[1], 16) for r in reads) in out.replace(' ', '')),
    ]
    nseq = [t for _, t in n.dev.events]
    nout = ''.join(n.uart)
    results += [
        ('no device: %s' % ', '.join(nseq),
         nseq == ['START', 'addr A4 NACK', 'RSTART', 'addr A5 NACK', 'STOP']),
        ('no device: output "No ACK from the device"', 'No ACK from the device\r\n' in nout),
    ]
    low, high, hold, su_rs, su_stop = timing(s, us)
    f = lambda v: '-' if v is None else '%.1f' % v
    results.append((
        'standard-mode timing in us (SCL low %s >= 4.7, high %s >= 4.0, START hold %s >= 4.0, '
        'repeated START setup %s >= 4.7, STOP setup %s >= 4.0)' % (f(low), f(high), f(hold), f(su_rs), f(su_stop)),
        None not in (low, high, hold) and low >= 4.7 and high >= 4.0 and hold >= 4.0
        and (su_rs is None or su_rs >= 4.7) and (su_stop is None or su_stop >= 4.0)))
    return results


def main():
    if not os.path.isfile(EXAMPLE):
        print('skip MAC EEPROM example: %s not found' % os.path.relpath(EXAMPLE, ROOT))
        return 0
    failed = 0
    for text, ok in run():
        print('%s MAC EEPROM example: %s' % ('ok  ' if ok else 'FAIL', text))
        failed += not ok
    return failed


if __name__ == '__main__':
    n = main()
    print('all MAC EEPROM checks passed' if n == 0 else '%d MAC EEPROM check(s) failed' % n)
    sys.exit(1 if n else 0)
