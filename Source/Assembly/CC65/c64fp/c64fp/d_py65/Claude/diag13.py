#!/usr/bin/env python3
"""
diag13.py - Same sentinel fix as diag1.py/asciisci.py: push a fake
return address before jumping into FP_TO_ASCII_SCI_V2 directly, so its
own genuine RTS has something legitimate to land on instead of
popping garbage and running off into $0000/BRK territory - which is
exactly what the previous run showed (final PC=$0000).
"""

from diag1 import mpu, LABELS, reset_state

SENTINEL = 0x1234

reset_state()
mpu.memory[0x61:0x65] = [0xff, 0x7f, 0xff, 0xff]
mpu.a = 0x00
mpu.x = 7
mpu.y = 0xC0

ret_addr = SENTINEL - 1
mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
mpu.sp -= 1
mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
mpu.sp -= 1

mpu.pc = LABELS['.FP_TO_ASCII_SCI_V2']

error_addr = LABELS['.FP_ERROR_PROC']
for step in range(500000):
    pc = mpu.pc
    if pc == error_addr:
        print(f"TRAPPED at step {step}, code={mpu.memory[0xFE]}")
        break
    if pc == SENTINEL:
        print(f"REAL EXIT reached at step {step} (via sentinel)")
        break
    mpu.step()
else:
    print("still running after 500000 steps - genuinely stuck")
    print(f"current PC=${mpu.pc:04x}, FP1_EXP=${mpu.memory[0x61]:02x}")

# read the output string regardless of how we got here
addr = 0xC000
chars = []
while mpu.memory[addr] != 0:
    chars.append(chr(mpu.memory[addr]))
    addr += 1
    if len(chars) > 30:
        break
print(f"output string: '{''.join(chars)}'")